import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import "../engine" as Engine
import "../lib" as Lib
import "ui" as UI
import "data" as Data
import "factory.js" as Factory
import "scripts/battlegrid.js" as BattleGridLogic
import "." as Scenes
Engine.GameScene {
    id: debugScene
    anchors.fill: parent
    property var blocks: []
    property alias checkRefillTimer: checkRefillTimer
    property var currentTurn: "top"
    property var turnsLeft: 3
    property var turnCoordinator: ({ offense: null, defense: null })
    property var playerLoadout: []
    property var opponentLoadout: []
    property var providedLoadout: []
    property var sidebarRegistry: ({})
    readonly property int loadoutSlots: 4
    property bool battleResolved: false
    property string battleOutcome: ""
    property Item outcomeScene: null

    signal battleOutcomeDismissed(string result)

    Data.PowerupDatabase {
        id: powerupDatabase
    }


    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Timer {
        id: handleTurnSwitchTimer
        interval: 1750
        triggeredOnStart: false
        repeat: false
        running: true
        onTriggered: {
            turnBanner.opacity = 0;


        }
    }
    onCurrentTurnChanged: {
        if (currentTurn === "top") { turnBanner.bannerText = "Opponent's Turn"; battleGrid_bottom.opacity = 0.5; battleGrid_top.opacity = 1.0;}
        if (currentTurn === "bottom") { turnBanner.bannerText = "Your turn"; battleGrid_bottom.opacity = 1.0; battleGrid_top.opacity = 0.5; }
        turnBanner.opacity = 1.0
        handleTurnSwitchTimer.running = true;
        handleTurnSwitchTimer.restart();
        handleTurnSwitch();
        //handleTurnSwitch()
    }

    function getBattleGridOffense() {

        if (currentTurn == "top") { return battleGrid_top } else { return battleGrid_bottom }
    }
    function getBattleGridDefense() {
        if (currentTurn == "top") { return battleGrid_bottom } else { return battleGrid_top }
    }

    function receiveBattleGridLaunchPayload(payload) {
        if (battleResolved)
            return;
        if (!payload || !payload.battleGrid)
            return;
        //    console.log("received launch payload", JSON.stringify(payload))
        var sourceGrid = null;
        if (battleGrid_top.uuid === payload.battleGrid)
            sourceGrid = battleGrid_top;
        else if (battleGrid_bottom.uuid === payload.battleGrid)
            sourceGrid = battleGrid_bottom;

        if (!sourceGrid)
            return;

        const targetBattleGrid = sourceGrid === battleGrid_top ? battleGrid_bottom : battleGrid_top;
        if (!targetBattleGrid || typeof targetBattleGrid.calculateLaunchDamage !== "function")
            return;

        var damageResult = targetBattleGrid.calculateLaunchDamage(payload);
        processLaunchDamageRewards(sourceGrid, damageResult);
    }

    function forwardBlockLaunchEndPoint(payload, endX, endY) {
        if (battleResolved)
            return;
        if (!payload || !payload.uuid)
            return;

        var originalBattleGrid = null;
        var targetBG
        if (battleGrid_top.uuid === payload.uuid) {
            originalBattleGrid = battleGrid_top;
            targetBG = battleGrid_bottom
        }
        else if (battleGrid_bottom.uuid === payload.uuid) {
            originalBattleGrid = battleGrid_bottom;
            targetBG = battleGrid_top
        }



        if (!originalBattleGrid || typeof originalBattleGrid.getEntryAt !== "function")
            return;

        const entry = originalBattleGrid.getBlockWrapper(payload.row, payload.column);
        if (!entry)
            return;

        if (endY !== undefined && endY !== null) {
            entry.z = 25
            entry.y = originalBattleGrid.mapFromGlobal(endX, endY).y;
            //      console.log("launching to position", entry.y);
        }

        entry.entry.blockState = "launch";
    }

    function normalizeState(value) {
        if (value === null || value === undefined)
            return "";
        return value.toString().toLowerCase();
    }

    function finalizeTurnStateSync() {
        const offense = turnCoordinator.offense;
        const defense = turnCoordinator.defense;
        if (defense && typeof defense.requestState === "function")
            defense.requestState("wait");
        if (offense && typeof offense.requestState === "function")
            offense.requestState("idle");
        turnStateMonitor.stop();
        turnCoordinator = { offense: null, defense: null };
    }

    function synchronizeTurnStateIfReady() {
        const offense = turnCoordinator.offense;
        const defense = turnCoordinator.defense;
        if (!offense || !defense) {
            turnStateMonitor.stop();
            return;
        }
        if (normalizeState(defense.currentState) === "idle")
            finalizeTurnStateSync();
    }

    function handleTurnSwitch() {
        const offense = getBattleGridOffense();
        const defense = offense === battleGrid_top ? battleGrid_bottom : battleGrid_top;
        if (!offense || !defense)
            return;

        turnCoordinator = { offense: offense, defense: defense };

        if (typeof offense.requestState === "function")
            offense.requestState("wait");

        if (normalizeState(defense.currentState) === "idle") {
            finalizeTurnStateSync();
        } else {
            if (turnStateMonitor.running)
                turnStateMonitor.restart();
            else
                turnStateMonitor.start();
        }
    }

    function distributePostSwapCascade(payload) {
        if (!payload || !payload.battleGrid)
            return;
        var sourceGrid = null;
        if (battleGrid_top.uuid === payload.battleGrid)
            sourceGrid = battleGrid_top;
        else if (battleGrid_bottom.uuid === payload.battleGrid)
            sourceGrid = battleGrid_bottom;
        if (!sourceGrid)
            return;
        const targetGrid = sourceGrid === battleGrid_top ? battleGrid_bottom : battleGrid_top;
        if (targetGrid && typeof targetGrid.informOpponentPostSwapCascadeStatus === "function")
            targetGrid.informOpponentPostSwapCascadeStatus(payload);
    }

    function handleGridDefeat(payload) {
        if (battleResolved)
            return;

        battleResolved = true;
        lockBattlefield();

        var defeatedGrid = payload && payload.grid ? payload.grid : null;
        if (!defeatedGrid && payload && payload.uuid) {
            if (battleGrid_top && battleGrid_top.uuid === payload.uuid)
                defeatedGrid = battleGrid_top;
            else if (battleGrid_bottom && battleGrid_bottom.uuid === payload.uuid)
                defeatedGrid = battleGrid_bottom;
        }
        if (!defeatedGrid) {
            defeatedGrid = (payload && payload.playerControlled) ? battleGrid_bottom : battleGrid_top;
        }
        var outcome = (defeatedGrid === battleGrid_top) ? "win" : "lose";
        battleOutcome = outcome;
        presentBattleOutcome(outcome);
    }

    function lockBattlefield() {
        turnsLeft = 0;
        if (postSwapCascadeCheckTimer.running)
            postSwapCascadeCheckTimer.stop();
        if (launchTimer.running)
            launchTimer.stop();
        handleTurnSwitchTimer.stop();

        if (battleGrid_top) {
            battleGrid_top.playerControlled = false;
            battleGrid_top.postSwapCascading = false;
        }
        if (battleGrid_bottom) {
            battleGrid_bottom.playerControlled = false;
            battleGrid_bottom.postSwapCascading = false;
        }

        if (playerSidebar)
            playerSidebar.interactionsEnabled = false;
        if (opponentSidebar)
            opponentSidebar.interactionsEnabled = false;
        if (topGridAi)
            topGridAi.enabled = false;
    }

    function presentBattleOutcome(result) {
        if (outcomeScene) {
            outcomeScene.destroy();
            outcomeScene = null;
        }
        var component = result === "win" ? battleWinnerComponent : battleLoserComponent;
        if (!component)
            return;
        outcomeScene = component.createObject(debugScene);
        if (!outcomeScene)
            return;
        outcomeScene.anchors.fill = debugScene;
        outcomeScene.z = 200;
        if (outcomeScene.closeRequested)
            outcomeScene.closeRequested.connect(handleOutcomeClose);
    }

    function handleOutcomeClose() {
        if (outcomeScene) {
            if (outcomeScene.closeRequested)
                outcomeScene.closeRequested.disconnect(handleOutcomeClose);
            outcomeScene.destroy();
            outcomeScene = null;
        }
        battleOutcomeDismissed(battleOutcome);
    }

    onProvidedLoadoutChanged: {
        if (!applyProvidedLoadout(providedLoadout) && !playerLoadout.length)
            refreshPlayerLoadout();
    }

    function applyProvidedLoadout(entries) {
        if (!entries || !entries.length) {
            console.log("Powerup loadout gating: provided entries missing or empty");
            return false;
        }
        playerLoadout = normalizeLoadout(entries, "player");
        return true;
    }

    function refreshPlayerLoadout() {
        if (!powerupDatabase) {
            // console.log("Powerup loadout gating: powerupDatabase unavailable for player loadout");
            return;
        }
        var records = powerupDatabase.fetchLoadout() || [];
        playerLoadout = normalizeLoadout(records, "player");
    }

    function refreshOpponentLoadout() {
        if (!powerupDatabase) {
            // console.log("Powerup loadout gating: powerupDatabase unavailable for opponent loadout");
            return;
        }
        var pool = powerupDatabase.fetchAllPowerups() || [];
       // if (!pool.length && powerupDatabase.builtinPowerups)
        //    pool = powerupDatabase.builtinPowerups();
        var selections = [];
        var cursor = 0;
        for (var i = 0; i < loadoutSlots; ++i) {
            if (!pool.length)
                break;
            selections.push(pool[cursor % pool.length]);
            cursor += 1;
        }
        opponentLoadout = normalizeLoadout(selections, "opponent", true);
    }

    function safeString(value, fallback) {
        if (typeof value === "string" && value.length)
            return value;
        return fallback;
    }

    function normalizedPowerupRecord(sourceRecord, slotIndex, prefix) {
        var record = sourceRecord;
        if (record && record.powerup)
            record = record.powerup;
        var uuid = safeString(record && record.powerupUuid, Factory.uid(prefix + "_card"));
        var name = safeString(record && record.powerupName, qsTr("Powerup %1").arg(slotIndex + 1));
        var target = safeString(record && record.powerupTarget, "Self");
        var targetSpec = safeString(record && record.powerupTargetSpec, "PlayerHealth");
        var specData = record && record.powerupTargetSpecData !== undefined ? record.powerupTargetSpecData : null;
        if (typeof specData === "string") {
            try {
                specData = JSON.parse(specData);
            } catch (err) {
                specData = null;
            }
        }
        var color = safeString(record && record.powerupCardColor, "blue");
        var heroRows = Math.max(1, Math.min(6, Number(record && record.powerupHeroRowSpan) || 1));
        var heroCols = Math.max(1, Math.min(6, Number(record && record.powerupHeroColSpan) || 1));
        var iconIndex = Number(record && record.powerupIcon);
        if (!isFinite(iconIndex))
            iconIndex = 0;
        iconIndex = Math.floor(iconIndex);
        if (iconIndex < 0)
            iconIndex = 0;
        if (iconIndex >= 25 && 25 > 0)
            iconIndex = iconIndex % 25;
        return {
            powerupUuid: uuid,
            powerupName: name,
            powerupTarget: target,
            powerupTargetSpec: targetSpec,
            powerupTargetSpecData: specData,
            powerupCardHealth: Number(record && record.powerupCardHealth) || 0,
            powerupActualAmount: Number(record && record.powerupActualAmount) || 0,
            powerupOperation: safeString(record && record.powerupOperation, "increase"),
            powerupIsCustom: !!(record && record.powerupIsCustom),
            powerupCardEnergyRequired: Number(record && record.powerupCardEnergyRequired) || 0,
            powerupCardColor: color,
            powerupHeroRowSpan: heroRows,
            powerupHeroColSpan: heroCols,
            powerupIcon: iconIndex
        };
    }

    function recordForSlot(records, slotIndex) {
        if (!records) {
            // console.log("Powerup loadout gating: record lookup failed because records argument is null");
            return null;
        }
        if (slotIndex < records.length && records[slotIndex] && records[slotIndex].slot === undefined)
            return records[slotIndex];
        for (var i = 0; i < records.length; ++i) {
            if (records[i] && records[i].slot === slotIndex)
                return records[i];
        }
        return null;
    }

    function normalizeLoadout(records, prefix, fillMissingSlots) {
        var normalized = [];
        for (var slot = 0; slot < loadoutSlots; ++slot) {
            var rawEntry = recordForSlot(records, slot);
            var record = rawEntry && rawEntry.powerup ? rawEntry.powerup : rawEntry;
            if ((!record || !record.powerupUuid) && !fillMissingSlots) {
                normalized.push({ slot: slot, powerup: null });
                continue;
            }
            var normalizedRecord = normalizedPowerupRecord(record, slot, prefix || "card");
            normalized.push({ slot: slot, powerup: normalizedRecord });
        }
        return normalized;
    }

    function registerSidebarForGrid(grid, sidebar) {
        if (!grid || !sidebar || !grid.uuid) {
            /* console.log("BattleCardSidebar gating: failed to register sidebar because grid/sidebar/uuid missing", {
                hasGrid: !!grid,
                hasSidebar: !!sidebar,
                gridUuid: grid && grid.uuid
            }); */
            return;
        }
        sidebarRegistry[grid.uuid] = sidebar;
    }

    function sidebarForGrid(grid) {
        if (!grid || !grid.uuid) {
            /*   console.log("BattleCardSidebar gating: sidebar lookup skipped due to invalid grid or uuid", {
                hasGrid: !!grid
            }); */
            return null;
        }
            var sidebar = sidebarRegistry[grid.uuid] || null;
            if (!sidebar)
                 console.log("BattleCardSidebar gating: no sidebar registered for grid", grid.uuid);
                return sidebar;
        }

        function handleHeroPlacementRequest(targetGrid, cardData, heroItem, sceneX, sceneY) {
            if (!cardData || !targetGrid) {
                /*   console.log("BattleCardSidebar gating: missing cardData or targetGrid", {
                hasCardData: !!cardData,
                hasGrid: !!targetGrid
            }); */
                return;
            }
            if (!targetGrid.playerControlled) {
                // console.log("BattleCardSidebar gating: hero placement restricted to player grid", targetGrid.uuid);
                return;
            }
            if (cardData.heroPlaced) {
                // console.log("BattleCardSidebar gating: card already placed", cardData.powerupUuid);
                return;
            }
            if (cardData.powerupCardHealth !== undefined && cardData.powerupCardHealth <= 0) {
                /*  console.log("BattleCardSidebar gating: card health depleted", {
                cardUuid: cardData.powerupUuid,
                currentHealth: cardData.powerupCardHealth
            }); */
                return;
            }
            var gridStateOk = targetGrid.normalizeStateName
                    ? targetGrid.normalizeStateName(targetGrid.currentState) === "idle"
                    : (targetGrid.currentState || "").toString().toLowerCase() === "idle";
            var entriesIdle = BattleGridLogic.allEntriesIdleNoMissing(targetGrid);
            if (!gridStateOk || !entriesIdle) {
                // console.log("BattleCardSidebar gating: hero placement requires idle, fully populated grid", {
                //     gridState: targetGrid.currentState,
                //     entriesIdle: entriesIdle
                // });
                return;
            }
            var placement = heroPlacementInfo(targetGrid, cardData, sceneX, sceneY);
            if (!placement.valid) {
                // console.log("BattleCardSidebar gating: hero placement rejected because drop was out of bounds", placement);
                return;
            }
            if (typeof targetGrid.canPlaceHero === "function") {
                if (!targetGrid.canPlaceHero(cardData.powerupUuid, placement.row, placement.column, cardData.powerupHeroRowSpan, cardData.powerupHeroColSpan)) {
                    // console.log("BattleCardSidebar gating: hero collision detected or slot unavailable", {
                    //     cardUuid: cardData.powerupUuid,
                    //     row: placement.row,
                    //     column: placement.column
                    // });
                    return;
                }
            } else {
                // console.log("BattleCardSidebar gating: target grid missing canPlaceHero implementation", targetGrid.uuid);
            }
            var placedHero = spawnHeroOnGrid(targetGrid, cardData, placement);
            if (!placedHero) {
                // console.log("BattleCardSidebar gating: spawnHeroOnGrid failed", {
                //     cardUuid: cardData.powerupUuid,
                //     placement: placement
                // });
                return;
            }
            finalizeHeroPlacement(targetGrid, cardData, heroItem, placedHero, placement);
        }

        function heroPlacementInfo(grid, cardData, sceneX, sceneY) {
            if (!grid || sceneX === undefined || sceneY === undefined) {
                // console.log("Hero placement gating: missing grid or coordinates for placement info", {
                //     hasGrid: !!grid,
                //     sceneX: sceneX,
                //     sceneY: sceneY
                // });
                return { valid: false };
            }
            var heroCols = Math.max(1, cardData.powerupHeroColSpan || 1);
            var heroRows = Math.max(1, cardData.powerupHeroRowSpan || 1);
            var heroWidth = heroCols * grid.cellW + Math.max(0, heroCols - 1) * grid.gapX;
            var heroHeight = heroRows * grid.cellH + Math.max(0, heroRows - 1) * grid.gapY;
            var localPoint = grid.mapFromGlobal(sceneX, sceneY);
            if (!localPoint) {
                // console.log("Hero placement gating: mapFromGlobal failed to resolve localPoint");
                return { valid: false };
            }
            var gridWidth = grid.gridCols * grid.cellW + Math.max(0, grid.gridCols - 1) * grid.gapX;
            var gridHeight = grid.gridRows * grid.cellH + Math.max(0, grid.gridRows - 1) * grid.gapY;
            var gridLeft = grid.originX;
            var gridTop = grid.originY;
            var left = localPoint.x - heroWidth / 2;
            var top = localPoint.y - heroHeight / 2;
            var withinHorizontal = left >= gridLeft && (left + heroWidth) <= (gridLeft + gridWidth);
            var withinVertical = top >= gridTop && (top + heroHeight) <= (gridTop + gridHeight);
            var valid = withinHorizontal && withinVertical;
            var strideX = grid.cellW + grid.gapX;
            var strideY = grid.cellH + grid.gapY;
            var maxColumn = Math.max(0, grid.gridCols - heroCols);
            var maxRow = Math.max(0, grid.gridRows - heroRows);
            var column = Math.round((left - gridLeft) / strideX);
            var row = Math.round((top - gridTop) / strideY);
            column = Math.max(0, Math.min(maxColumn, column));
            row = Math.max(0, Math.min(maxRow, row));
            var snappedX = gridLeft + column * strideX;
            var snappedY = gridTop + row * strideY;
            return {
                valid: valid,
                column: column,
                row: row,
                x: snappedX,
                y: snappedY,
                width: heroWidth,
                height: heroHeight
            };
        }

        function heroPlacementBoundsValid(grid, cardData, sceneX, sceneY) {
            var placement = heroPlacementInfo(grid, cardData, sceneX, sceneY);
            return placement.valid;
        }

        function attemptHeroPlacementAtCell(grid, cardData, row, column) {
            if (!grid || !cardData)
                return false;
            if (cardData.heroPlaced || cardData.heroDefeated)
                return false;
            if (cardData.powerupCardHealth !== undefined && cardData.powerupCardHealth <= 0)
                return false;
            var normalizedState = grid.normalizeStateName
                    ? grid.normalizeStateName(grid.currentState)
                    : (grid.currentState || "").toString().toLowerCase();
            if (normalizedState !== "idle")
                return false;
            if (!BattleGridLogic.allEntriesIdleNoMissing(grid))
                return false;
            var heroCols = Math.max(1, cardData.powerupHeroColSpan || 1);
            var heroRows = Math.max(1, cardData.powerupHeroRowSpan || 1);
            if (row < 0 || column < 0)
                return false;
            if ((row + heroRows) > grid.gridRows)
                return false;
            if ((column + heroCols) > grid.gridCols)
                return false;
            if (typeof grid.canPlaceHero === "function") {
                if (!grid.canPlaceHero(cardData.powerupUuid, row, column, heroRows, heroCols))
                    return false;
            }
            var strideX = grid.cellW + grid.gapX;
            var strideY = grid.cellH + grid.gapY;
            var placement = {
                valid: true,
                row: row,
                column: column,
                x: grid.originX + column * strideX,
                y: grid.originY + row * strideY,
                width: heroCols * grid.cellW + Math.max(0, heroCols - 1) * grid.gapX,
                height: heroRows * grid.cellH + Math.max(0, heroRows - 1) * grid.gapY
            };
            var hero = spawnHeroOnGrid(grid, cardData, placement);
            if (!hero)
                return false;
            finalizeHeroPlacement(grid, cardData, null, hero, placement);
            return true;
        }

        function spawnHeroOnGrid(grid, cardData, placement) {
            if (!grid || !cardData || !placement || !placement.valid) {
                // console.log("Hero placement gating: invalid arguments for spawnHeroOnGrid", {
                //     hasGrid: !!grid,
                //     hasCardData: !!cardData,
                //     placementValid: placement && placement.valid
                // });
                return null;
            }
            if (!placedHeroComponent) {
                // console.log("Hero placement gating: placedHeroComponent missing");
                return null;
            }
            var hero = placedHeroComponent.createObject(grid, {
                                                            previewMode: false,
                                                            powerupName: cardData.powerupName,
                                                            powerupCardColor: cardData.powerupCardColor,
                                                            powerupHeroRowSpan: cardData.powerupHeroRowSpan,
                                                            powerupHeroColSpan: cardData.powerupHeroColSpan,
                                                            cellWidth: grid.cellW,
                                                            cellHeight: grid.cellH,
                                                            cellSpacing: Math.max(grid.gapX, grid.gapY),
                                                            x: placement.x,
                                                            y: placement.y,
                                                            z: 40,
                                                            visible: true
                                                        });
            if (!hero) {
                // console.log("Hero placement gating: createObject failed to instantiate hero", {
                //     cardUuid: cardData.powerupUuid
                // });
                return null;
            }
            hero.cardData = cardData;
            hero.anchoredRow = placement.row;
            hero.anchoredColumn = placement.column;
            return hero;
        }

        function finalizeHeroPlacement(grid, cardData, heroItem, placedHero, placement) {
            if (!grid || !cardData || !placement) {
                // console.log("Hero placement gating: finalizeHeroPlacement missing grid/cardData/placement", {
                //     hasGrid: !!grid,
                //     hasCardData: !!cardData,
                //     hasPlacement: !!placement
                // });
                return;
            }
            if (typeof cardData.resetEnergy === "function")
                cardData.resetEnergy();
            cardData.activationReady = false;
            if (heroItem)
                heroItem.visible = false;
            if (placedHero) {
                cardData.heroInstance = placedHero;
                placedHero.cardData = cardData;
            }
            if (grid && typeof grid.registerHeroPlacement === "function") {
                // console.log("Hero placement flow: invoking registerHeroPlacement", {
                //     gridUuid: grid.uuid,
                //     cardUuid: cardData.powerupUuid,
                //     row: placement.row,
                //     column: placement.column
                // });
                grid.registerHeroPlacement(
                            cardData.powerupUuid,
                            placedHero,
                            placement.row,
                            placement.column,
                            cardData.powerupHeroRowSpan,
                            cardData.powerupHeroColSpan,
                            { cardUuid: cardData.powerupUuid, cardData: cardData });
            }
            // console.log("Hero placement flow: registerHeroPlacement complete, firing trigger", {
            //     cardUuid: cardData.powerupUuid
            // });
            triggerPowerupActivation(cardData, { trigger: "placement", skipEnergyDrain: true, resetEnergy: true });
        }

        function processLaunchDamageRewards(sourceGrid, damageResult) {
            if (!sourceGrid || !damageResult)
                return;
            var sidebar = sidebarForGrid(sourceGrid);
            if (!sidebar)
                return;
            var blocks = damageResult.blocksDamaged || [];
            for (var i = 0; i < blocks.length; ++i) {
                var blockInfo = blocks[i];
                if (!blockInfo || !blockInfo.destroyed)
                    continue;
                if (!blockInfo.color || !blockInfo.energyReward)
                    continue;
                sidebar.distributeEnergy(blockInfo.color, blockInfo.energyReward);
            }
            if (damageResult.breachOccurred && damageResult.breachHealth > 0 && damageResult.sourceBlockColor) {
                var breachReward = Math.floor(damageResult.breachHealth * 2);
                if (breachReward > 0)
                    sidebar.distributeEnergy(damageResult.sourceBlockColor, breachReward);
            }
        }

        function opposingGrid(grid) {
            if (!grid)
                return null;
            return grid === battleGrid_top ? battleGrid_bottom : grid === battleGrid_bottom ? battleGrid_top : null;
        }

    function adjustGridHealth(targetGrid, amount, operation) {
        if (!targetGrid)
            return;
        var delta = Math.max(0, Math.floor(amount || 0));
        if (delta <= 0)
            return;
        var op = (operation || "decrease").toString().toLowerCase();
        if (op === "increase") {
            var maxHealth = targetGrid.mainHealthMax !== undefined ? targetGrid.mainHealthMax : targetGrid.mainHealth;
            if (maxHealth === undefined || maxHealth <= 0)
                maxHealth = delta;
            targetGrid.mainHealth = Math.min(maxHealth, targetGrid.mainHealth + delta);
        } else
            targetGrid.mainHealth = Math.max(0, targetGrid.mainHealth - delta);
    }

    function normalizedLaunchDirection(grid) {
        var direction = grid && grid.launchDirection ? grid.launchDirection.toString().toLowerCase() : "down";
        return direction === "up" ? "up" : "down";
    }

    function gridRowBaseOffset(grid, rowCount) {
        if (!grid)
            return 0;
        var rows = Math.max(1, rowCount !== undefined ? rowCount : (grid.gridRows || 6));
        return normalizedLaunchDirection(grid) === "up" ? rows : 0;
    }

    function heroPlacementCenter(cardData) {
        var hero = cardData && cardData.heroInstance ? cardData.heroInstance : null;
        if (!hero)
            return { valid: false, row: 0, column: 0 };
        var rowSpan = Math.max(1, cardData.powerupHeroRowSpan || 1);
        var colSpan = Math.max(1, cardData.powerupHeroColSpan || 1);
        var anchorRow = hero.anchoredRow !== undefined ? hero.anchoredRow : 0;
        var anchorColumn = hero.anchoredColumn !== undefined ? hero.anchoredColumn : 0;
        return {
            valid: true,
            row: anchorRow + Math.floor((rowSpan - 1) / 2),
            column: anchorColumn + Math.floor((colSpan - 1) / 2)
        };
    }

    function sanitizeRelativeGridAreaData(specData) {
        function normalizeDimension(value) {
            var dimension = Number(value);
            if (!isFinite(dimension))
                dimension = 1;
            dimension = Math.floor(dimension);
            if (dimension < 1)
                dimension = 1;
            if (dimension > 5)
                dimension = 5;
            return dimension;
        }
        function normalizeDistance(value) {
            var distance = Number(value);
            if (!isFinite(distance))
                distance = 6;
            distance = Math.floor(distance);
            if (distance < -6)
                distance = -6;
            if (distance > 6)
                distance = 6;
            return distance;
        }
        var payload = specData && typeof specData === "object" ? specData : {};
        var rowsValue = payload.rows !== undefined ? payload.rows : (payload.rowCount !== undefined ? payload.rowCount : 1);
        var colsValue = payload.columns !== undefined ? payload.columns : (payload.colCount !== undefined ? payload.colCount : 1);
        var distanceValue = payload.distance !== undefined ? payload.distance : (payload.rowOffset !== undefined ? payload.rowOffset : 6);
        return {
            rows: normalizeDimension(rowsValue),
            columns: normalizeDimension(colsValue),
            distance: normalizeDistance(distanceValue)
        };
    }

    function buildRelativeGridAreaCells(cardData, targetGrid) {
        if (!cardData || !targetGrid)
            return [];
        var center = heroPlacementCenter(cardData);
        if (!center.valid)
            return [];
        var specData = sanitizeRelativeGridAreaData(cardData.powerupTargetSpecData);
        var sourceGrid = cardData.battleGrid || null;
        var forwardDirection = normalizedLaunchDirection(sourceGrid);
        var forwardSign = forwardDirection === "up" ? -1 : 1;
        var sourceGridRows = Math.max(1, (sourceGrid && sourceGrid.gridRows) || 6);
        var targetGridRows = Math.max(1, targetGrid.gridRows || 6);
        var sourceBaseRow = gridRowBaseOffset(sourceGrid, sourceGridRows);
        var targetBaseRow = gridRowBaseOffset(targetGrid, targetGridRows);
        var centerGlobalRow = sourceBaseRow + center.row;
        var globalTargetRow = centerGlobalRow + forwardSign * specData.distance;
        var targetMinRow = targetBaseRow;
        var targetMaxRow = targetBaseRow + targetGridRows - 1;
        if (globalTargetRow < targetMinRow)
            globalTargetRow = targetMinRow;
        if (globalTargetRow > targetMaxRow)
            globalTargetRow = targetMaxRow;
        var projectedRow = globalTargetRow - targetBaseRow;
        var gridCols = Math.max(1, targetGrid.gridCols || 6);
        var areaRows = Math.max(1, Math.min(targetGridRows, specData.rows));
        var areaCols = Math.max(1, Math.min(gridCols, specData.columns));
        var rowOffset = Math.floor((areaRows - 1) / 2);
        var colOffset = Math.floor((areaCols - 1) / 2);
        var startRow = projectedRow - rowOffset;
        var maxRowStart = Math.max(0, targetGridRows - areaRows);
        if (startRow < 0)
            startRow = 0;
        if (startRow > maxRowStart)
            startRow = maxRowStart;
        var startCol = center.column - colOffset;
        var maxColStart = Math.max(0, gridCols - areaCols);
        if (startCol < 0)
            startCol = 0;
        if (startCol > maxColStart)
            startCol = maxColStart;
        var cells = [];
        for (var r = 0; r < areaRows; ++r) {
            var rowValue = startRow + r;
            if (rowValue < 0 || rowValue >= targetGridRows)
                continue;
            for (var c = 0; c < areaCols; ++c) {
                var columnValue = startCol + c;
                if (columnValue < 0 || columnValue >= gridCols)
                    continue;
                cells.push({ row: rowValue, column: columnValue });
            }
        }
        return cells;
    }

    function triggerPowerupActivation(cardData, options) {
        if (!cardData) {
            // console.log("Powerup activation gating: missing cardData");
            return false;
        }
            var sourceGrid = cardData.battleGrid || null;
            if (!sourceGrid) {
                // console.log("Powerup activation gating: card missing battleGrid binding", cardData.powerupUuid);
                return false;
            }
            if (!cardData.heroPlaced || !cardData.heroAlive) {
                // console.log("Powerup activation gating: hero not placed or already defeated", {
                //     heroPlaced: cardData.heroPlaced,
                //     heroAlive: cardData.heroAlive,
                //     cardUuid: cardData.powerupUuid
                // });
                return false;
            }
            var normalizedState = sourceGrid.normalizeStateName
                    ? sourceGrid.normalizeStateName(sourceGrid.currentState)
                    : (sourceGrid.currentState || "").toString().toLowerCase();
            if (normalizedState !== "idle") {
                // console.log("Powerup activation gating: source grid not idle", {
                //     gridUuid: sourceGrid.uuid,
                //     state: sourceGrid.currentState
                // });
                return false;
            }
            if (!BattleGridLogic.allEntriesIdleNoMissing(sourceGrid)) {
                // console.log("Powerup activation gating: source grid entries not fully idle", sourceGrid.uuid);
                return false;
            }

            var triggerInfo = options || {};
            var targetType = (cardData.powerupTarget || "Self").toString().toLowerCase();
            var targetGrid = targetType === "enemy" ? opposingGrid(sourceGrid) : sourceGrid;
            if (!targetGrid) {
                // console.log("Powerup activation gating: target grid unavailable", {
                //     targetType: targetType,
                //     sourceUuid: sourceGrid.uuid
                // });
                return false;
            }

            var amount = Math.max(0, Math.floor(cardData.powerupActualAmount || 0));
            var operation = (cardData.powerupOperation || "increase").toString().toLowerCase();
            var spec = cardData.powerupTargetSpec || "PlayerHealth";

            console.log("Powerup activation flow: executing spec", JSON.stringify({
                                                                                      cardUuid: cardData.powerupUuid,
                                                                                      spec: spec,
                                                                                      targetType: targetType,
                                                                                      targetGridUuid: targetGrid.uuid,
                                                                                      amount: amount,
                                                                                      operation: operation
                                                                                  }));

            var activationApplied = false;
            function normalizeSpecArray(specData) {
                if (!specData)
                    return [];
                if (Array.isArray(specData))
                    return specData;
                var coerced = [];
                var length = specData.length !== undefined ? Number(specData.length) : NaN;
                if (isFinite(length) && length > 0) {
                    for (var idx = 0; idx < length; ++idx) {
                        if (specData[idx] !== undefined)
                            coerced.push(specData[idx]);
                    }
                    return coerced;
                }
                for (var key in specData) {
                    if (specData.hasOwnProperty && !specData.hasOwnProperty(key))
                        continue;
                    coerced.push(specData[key]);
                }
                if (coerced.length)
                    return coerced;
                return [specData];
            }

            switch (spec) {
            case "Blocks": {
                if (targetGrid.applyBlockDeltaList) {
                    var rawCells = normalizeSpecArray(cardData.powerupTargetSpecData);
                    // console.log("Powerup activation flow: normalized block targets", JSON.stringify(rawCells));
                    var cells = [];
                    for (var i = 0; i < rawCells.length; ++i) {
                        var cell = rawCells[i];
                        if (!cell)
                            continue;
                        var rowValue = cell.row !== undefined ? cell.row : cell.r;
                        var columnValue = cell.column !== undefined ? cell.column : (cell.col !== undefined ? cell.col : cell.c);
                        if (rowValue === undefined || columnValue === undefined)
                            continue;
                        var numericRow = Number(rowValue);
                        var numericColumn = Number(columnValue);
                        if (!isFinite(numericRow) || !isFinite(numericColumn))
                            continue;
                        cells.push({
                                       row: Math.floor(numericRow),
                                       column: Math.floor(numericColumn)
                                   });
                    }
                    if (cells.length) {
                        // console.log("Powerup activation flow: dispatching block delta list", JSON.stringify({
                        //     cardUuid: cardData.powerupUuid,
                        //     cellCount: cells.length
                        // }));
                        var results = targetGrid.applyBlockDeltaList(cells, amount, operation, { trigger: triggerInfo.trigger || "manual", sourceCard: cardData });
                        // console.log("Powerup activation flow: block delta results", JSON.stringify(results));
                        activationApplied = results && results.length > 0;
                    } else {
                        // console.log("Powerup activation flow: no valid cells for block spec", JSON.stringify(cardData.powerupTargetSpecData));
                    }
                }
                break;
            }
            case "PlayerPowerupInGameCards": {
                if (targetGrid.applyHeroDeltaByColor) {
                    var colorFilter = cardData.powerupTargetSpecData || "";
                    var heroImpacts = targetGrid.applyHeroDeltaByColor(colorFilter, amount, operation, { trigger: triggerInfo.trigger || "manual", sourceCard: cardData });
                    // console.log("Powerup activation flow: hero delta results", JSON.stringify(heroImpacts));
                    activationApplied = heroImpacts && heroImpacts.length > 0;
                }
                break;
            }
            case "RelativeGridArea": {
                if (targetGrid.applyBlockDeltaList) {
                    var relativeCells = buildRelativeGridAreaCells(cardData, targetGrid);
                    if (relativeCells.length) {
                        var relativeResults = targetGrid.applyBlockDeltaList(relativeCells, amount, operation, {
                                                                                                                 trigger: triggerInfo.trigger || "manual",
                                                                                                                 sourceCard: cardData,
                                                                                                                 spec: "RelativeGridArea"
                                                                                                             });
                        activationApplied = relativeResults && relativeResults.length > 0;
                    }
                }
                break;
            }
            case "PlayerHealth":
            default:
                adjustGridHealth(targetGrid, amount, operation);
                // console.log("Powerup activation flow: adjusted grid health", JSON.stringify({
                //     gridUuid: targetGrid.uuid,
                //     mainHealth: targetGrid.mainHealth
                // }));
                activationApplied = true;
                break;
            }

            if (!triggerInfo.skipEnergyDrain && typeof cardData.consumeEnergy === "function")
                cardData.consumeEnergy();
            var shouldResetEnergy = triggerInfo.resetEnergy;
            if (shouldResetEnergy === undefined)
                shouldResetEnergy = !!triggerInfo.skipEnergyDrain;
            if (shouldResetEnergy && typeof cardData.resetEnergy === "function")
                cardData.resetEnergy();
            console.log("Powerup activation flow: activation completed", JSON.stringify({
                                                                                            cardUuid: cardData.powerupUuid,
                                                                                            spec: spec,
                                                                                            applied: activationApplied
                                                                                        }));
            return true;
        }
        /* Engine.GameDragItem {
        id: test_rect

        gameScene: debugScene
        itemName: "test_rect"
        width: 64
        height: 64
        x: Math.random() * 300
        y: Math.random() * 300
        z: 4
        entry:  redBlock
        payload: ["itemName"]
        UI.Block {
                   id: redBlock
                   blockColor: "red"
                   itemName: "red_block"
                   gameScene: debugScene
                   width: 64
                   height: 64
               }


    }
   Engine.GameDragItem {
        id: test_rect2

        gameScene: debugScene
        itemName: "test_rect2"
        width: 64
        height: 64
        x: Math.random() * 300
        y: Math.random() * 300
        z: 4
        entry: redBlock2
        payload: ["itemName"]
        UI.Block {
            id: redBlock2
            blockColor: "blue"
            itemName: "red_block2"
            gameScene: debugScene
            width: 64
            height: 64
        }


    } */
        Component.onCompleted: {
            if (!applyProvidedLoadout(providedLoadout))
            refreshPlayerLoadout();
            refreshOpponentLoadout();
            if (battleGrid_top && typeof battleGrid_top.requestState === "function")
            battleGrid_top.requestState("compact");
            if (battleGrid_bottom && typeof battleGrid_bottom.requestState === "function")
            battleGrid_bottom.requestState("wait");
        }

        property int launchIndex: 0
        Timer {
            id: checkRefillTimer
            interval: 200
            repeat: false
            triggeredOnStart: false
            running: false
            onTriggered: {
                var grid = getBattleGridOffense();
                if (grid && typeof grid.requestState === "function")
                grid.requestState("compact");
            }
        }
        Timer {
            id: turnStateMonitor
            interval: 120
            repeat: true
            running: false
            onTriggered: synchronizeTurnStateIfReady()
        }
        onItemDroppedNowhere: function(itemName) {
            // console.log("drag item dropped nowhere")
            var playerGrid = battleGrid_bottom;
            if (!playerGrid)
                return
            var dragItem = getSceneItem(itemName);
            if (!dragItem || dragItem.entry.battleGrid !== playerGrid)
                return
            function snapItemToGrid(item, row, col) {
                item.x = playerGrid.cellPosition(row, col).x
                item.y = playerGrid.cellPosition(row, col).y

            }
            snapItemToGrid(dragItem, dragItem.entry.row, dragItem.entry.column)
        }
        onItemDroppedInNonDropArea: function(dragItemName, dropItemName, startx, starty, endx, endy) {
            var playerGrid = battleGrid_bottom;
            if (!playerGrid)
                return
            function snapItemToGrid(item, row, col) {
                item.x = playerGrid.cellPosition(row, col).x
                item.y = playerGrid.cellPosition(row, col).y


            }

            var dragItem = getSceneItem(dragItemName);
            var dropItem = getSceneItem(dropItemName)
            if (!dragItem || dragItem.entry.battleGrid !== playerGrid) {
                if (dragItem)
                    snapItemToGrid(dragItem, dragItem.entry.row, dragItem.entry.col);
                return
            }
            if (!dropItem || dropItem.entry.battleGrid !== playerGrid) {
                if (dragItem)
                    snapItemToGrid(dragItem, dragItem.entry.row, dragItem.entry.col);
                return
            }

            if ((dragItemName.indexOf("block_drag") == 0) && (dropItemName.indexOf("block_drag") == 0)) {



                // switch request..
                var row1 = dragItem.entry.row
                var row2 = dropItem.entry.row
                var col1 = dragItem.entry.column
                var col2 = dropItem.entry.column
                var rowDelta = Math.abs(row1 - row2)
                var colDelta = Math.abs(col1 - col2)
                if ((rowDelta == 1) && (colDelta == 1)) { snapItemToGrid(dragItem, row1, col1); return }
                if ((rowDelta == 0) && (colDelta == 0)) { snapItemToGrid(dragItem, row1, col1); return }
                if (rowDelta > 1) { snapItemToGrid(dragItem, row1, col1); return }
                if (colDelta > 1) { snapItemToGrid(dragItem, row1, col1); return }

                var bg = playerGrid;
                var swapSuccess = bg.requestSwapWrappers(row1, col1, row2, col2);
                if (!swapSuccess) {
                    snapItemToGrid(dragItem, row1, col1)
                    snapItemToGrid(dropItem, row2, col2)
                    return
                }

                // console.log("got valid swap  -- ",dragItemName, dropItemName, startx, starty, endx, endy)
                snapItemToGrid(dragItem, dragItem.entry.row, dragItem.entry.column)
                snapItemToGrid(dropItem, dropItem.entry.row, dropItem.entry.column)
                bg.requestState("match")
                bg.postSwapCascading = true
                turnsLeft--


            }

        }

        onTurnsLeftChanged: {
            var offenseGrid = getBattleGridOffense();
            postSwapCascadeCheckTimer.running = true;

        }

        Timer {
            id: postSwapCascadeCheckTimer
            running: false
            interval: 200
            repeat: true
            onTriggered: {
                checkActiveGridPostSwapCascadeComplete()
            }
        }

        function checkActiveGridPostSwapCascadeComplete() {
            var bg = getBattleGridOffense();
            var newbg = getBattleGridDefense();
            if (bg.currentState === "idle") {
                if (turnsLeft <= 0) {
                    if (currentTurn == "top") { currentTurn = "bottom"; } else { currentTurn = "top"; }
                    turnsLeft = 3;
                    // console.log("turn switched to",currentTurn);
                    postSwapCascadeCheckTimer.running = false;
                    if (newbg && typeof newbg.requestState === "function")
                        newbg.requestState("compact");
                    if (bg && typeof bg.requestState === "function")
                        bg.requestState("wait");
                }
            }
        }

        onItemEnteredNonDropArea: {
            //console.log("item dragged and entered non-drop area", dragItemName, dropItemName)
        }
        Timer {
            id: launchTimer
            interval: 90
            running: false
            repeat: true

            onTriggered: {
                if (debugScene.blocks.length > 0)  {
                    var itm3 = (debugScene.blocks.pop() as Engine.GameDragItem)


                    itm3.y += 400


                    itm3.entry.blockState = "launch"
                    if (debugScene.blocks.length == 0) {
                        launchTimer.running = false;
                        // console.log("got last block launched, connecting destroyed state change to fill timer");
                        var grid = getBattleGridOffense();
                        if (grid && typeof grid.requestState === "function")
                        grid.requestState("compact");
                    }

                }

            }
        }


        UI.BattleGrid {
            id:battleGrid_top
            width: 300
            height: 300
            x: 200
            y: 60
            gameScene: debugScene
            mainHealthMax: 2000
            mainHealth: 2000
            playerControlled: false
            onCurrentStateChanged: {
                if (battleGrid_top.currentState == "idle") {
                    if (debugScene.turnsLeft > 0) {

                        if (battleGrid_top.postSwapCascading === false) {
                            topGridAi.planMove()
                        }
                    }
                }
            }
            launchDirection: "down"
            uuid: "top"
            Component.onCompleted: {

            }
        }

        UI.BattleGridHealthBar {
            id: battleGridTopHealth
            battleGrid: battleGrid_top
            anchors.bottom: battleGrid_top.top
            anchors.bottomMargin: 12
            anchors.horizontalCenter: battleGrid_top.horizontalCenter
            z: battleGrid_top.z + 1
        }

        AIGamePlayer {
            id: topGridAi
            gameScene: debugScene
            battleGrid: battleGrid_top
            battleCardSidebar: opponentSidebar
            controlledTurn: "top"
        }

        Connections {
            target: topGridAi
            function onSwapRequested(row1, column1, row2, column2) {
                if (currentTurn !== "top")
                    return;
                if (getBattleGridOffense() !== battleGrid_top)
                    return;
                if (!battleGrid_top || typeof battleGrid_top.requestSwapWrappers !== "function")
                    return;
                var success = battleGrid_top.requestSwapWrappers(row1, column1, row2, column2);
                if (!success)
                    return;
                battleGrid_top.requestState("match");
                battleGrid_top.postSwapCascading = true;
                turnsLeft--;
            }
        }

        UI.BattleCardSidebar {
            id: opponentSidebar
            gameScene: debugScene
            battleGrid: battleGrid_top
            loadout: opponentLoadout
            interactionsEnabled: false
            heroCellWidth: battleGrid_top.cellW
            heroCellHeight: battleGrid_top.cellH
            heroCellSpacing: Math.max(battleGrid_top.gapX, battleGrid_top.gapY)
            anchors.top: battleGrid_top.top
            anchors.bottom: battleGrid_top.bottom
            anchors.leftMargin: 72
            onHeroPlacementRequested: function(cardData, heroItem, sceneX, sceneY) {
                handleHeroPlacementRequest(battleGrid_top, cardData, heroItem, sceneX, sceneY)
            }
            Component.onCompleted: registerSidebarForGrid(battleGrid_top, opponentSidebar)
        }

        Connections {
            target: opponentSidebar
            function onPowerupActivationRequested(cardData) {
                triggerPowerupActivation(cardData, { trigger: "manual" });
            }
        }

        UI.BattleGrid {
            id:battleGrid_bottom
            width: 300
            height: 300
            x: 200
            y: 340
            gameScene: debugScene
            uuid: "bottom"
            launchDirection: "up"
            mainHealthMax: 2000
            mainHealth: 2000
            playerControlled: true

            Component.onCompleted: {

            }
        }

        UI.BattleGridHealthBar {
            id: battleGridBottomHealth
            battleGrid: battleGrid_bottom
            anchors.top: battleGrid_bottom.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: battleGrid_bottom.horizontalCenter
            z: battleGrid_bottom.z + 1
        }

        UI.BattleCardSidebar {
            id: playerSidebar
            gameScene: debugScene
            battleGrid: battleGrid_bottom
            loadout: playerLoadout
            interactionsEnabled: true
            heroCellWidth: battleGrid_bottom.cellW
            heroCellHeight: battleGrid_bottom.cellH
            heroCellSpacing: Math.max(battleGrid_bottom.gapX, battleGrid_bottom.gapY)
            anchors.top: battleGrid_bottom.top
            anchors.bottom: battleGrid_bottom.bottom
            anchors.leftMargin: 72
            onHeroPlacementRequested: function(cardData, heroItem, sceneX, sceneY) {
                // console.log("Hero Placement Requested",JSON.stringify(cardData), heroItem, sceneX, sceneY);
                handleHeroPlacementRequest(battleGrid_bottom, cardData, heroItem, sceneX, sceneY)
            }
            Component.onCompleted: registerSidebarForGrid(battleGrid_bottom, playerSidebar)
        }

        Connections {
            target: playerSidebar
            function onPowerupActivationRequested(cardData) {
                triggerPowerupActivation(cardData, { trigger: "manual" });
            }
        }

        Connections {
            target: battleGrid_top
            function onDistributedBlockLaunchPayload(payload) {
                receiveBattleGridLaunchPayload(payload);
            }
            function onInformBlockLaunchEndPoint(payload, endX, endY) {
                forwardBlockLaunchEndPoint(payload, endX, endY);
            }
            function onInformPostSwapCascadeStatus(payload) {
                distributePostSwapCascade(payload);
            }
            function onHealthDepleted(payload) {
                handleGridDefeat(payload);
            }
        }

        Connections {
            target: battleGrid_bottom
            function onDistributedBlockLaunchPayload(payload) {
                receiveBattleGridLaunchPayload(payload);
            }
            function onInformBlockLaunchEndPoint(payload, endX, endY) {
                forwardBlockLaunchEndPoint(payload, endX, endY);
            }
            function onInformPostSwapCascadeStatus(payload) {
                distributePostSwapCascade(payload);
            }
            function onHealthDepleted(payload) {
                handleGridDefeat(payload);
            }
        }










        Component {
            id: battleWinnerComponent
            Scenes.BattleWinnerScene { }
        }

        Component {
            id: battleLoserComponent
            Scenes.BattleLoserScene { }
        }

        Component {
            id: dragComp
            Engine.GameDragItem { }   // has required: gameScene, itemName, entry
        }

        Component {
            id: blockComp
            UI.Block { }              // has blockColor, itemName, gameScene...
        }

        Component {
            id: placedHeroComponent
            UI.PowerupHero { previewMode: false }
        }
        Rectangle {
            color: "grey"
            id: turnBanner
            property var bannerText: "Opponent's Turn"
            Text {
                id: turnBannerTextBox
                font.pixelSize: 28
                text: turnBanner.bannerText
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 1000
                }
            }
            opacity: 1
            anchors.centerIn: parent
            width: 300
            height: 60
            z: 20

        }
        // Example call
        function createBlock(color) {
            return Factory.createBlock(
                        blockComp,
                        dragComp,
                        debugScene,          // final visual parent
                        debugScene,    // scene for registration
                        { color: color, namePrefix: color + "Block" }
                        );
        }

    }
