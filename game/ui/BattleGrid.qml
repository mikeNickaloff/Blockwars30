import QtQuick 2.15
import "../../engine" as Engine
import "../../lib" as Lib
import "." as UI
import "../data" as Data
import "../factory.js" as Factory
import "../layouts.js" as Layout
import QtQuick.Layouts

Item {
    id: root
    width: 400
    height: 400

    // Scene reference supplied by the parent view.
    property var gameScene

    signal queueItemStarted(var item)
    signal queueItemCompleted(var item, var context)
    signal wrapperLaunched(var wrapperItem)
    signal distributeBlockLaunchPayload(var payload)
    signal distributedBlockLaunchPayload(var payload)
    signal informBlockLaunchEndPoint(var payload, var endX, var endY)
    signal informPostSwapCascadeStatus(var payload)

    // Grid configuration.
    property int gridCols: 6
    property int gridRows: 6
    property int cellW: 50
    property int cellH: 50
    property int gapX: 2
    property int gapY: 2
    property int originX: 40
    property int originY: 40
    readonly property int gridHeight: (gridRows * cellH) + Math.max(0, gridRows - 1) * gapY

    property var instances: []
    property int blockSequence: 0
    property string launchDirection: "down"
    readonly property var blockPalette: ["red", "blue", "green", "yellow"]
    readonly property string blockIdPrefix: "grid_block"

    property string uuid: Factory.uid("battleGrid")
    property int mainHealth: 100
    property bool postSwapCascading: false
    property var launchSequence: []
    property int launchSequenceIndex: 0

    property string currentState: "init"
    property string previousState: ""
    property bool suppressStateHandler: false
    readonly property var stateList: [
        "init", "initializing", "initialized",
        "compact", "compacting", "compacted",
        "fill", "filling", "filled",
        "match", "matching", "matched",
        "launch", "launching", "launched",
        "idle", "idling", "idled",
        "wait", "waiting", "waited"
    ]

    // Compact representation of the grid.
    property var blockMatrix: []

    property var __launchRelayRegistered: false
    property var heroPlacements: ({})
    property var heroCellMap: []

    UI.GridShakeEffector {
        id: shakeEffector
        impactAmplitude: Math.max(2, cellW * 0.05)
        impactDuration: 120
        breachAmplitude: Math.max(impactAmplitude * 1.8, cellW * 0.1)
        breachDuration: 200
    }

    transform: [
        Translate {
            x: shakeEffector.offsetX
            y: shakeEffector.offsetY
        }
    ]

    onPostSwapCascadingChanged: distributePostSwapCascadeStatus()

    function normalizeStateName(value) {
        if (value === null || value === undefined)
            return "";
        return value.toString().trim().toLowerCase();
    }

    function stateFormsFor(stateValue) {
        const normalized = normalizeStateName(stateValue);
        const index = stateList.indexOf(normalized);
        if (index === -1)
            return null;

        const baseIndex = index - (index % 3);
        return {
            base: stateList[baseIndex],
            active: stateList[baseIndex + 1] || stateList[baseIndex],
            completed: stateList[baseIndex + 2] || stateList[baseIndex + 1] || stateList[baseIndex]
        };
    }

    function setGridStateInternal(stateName, suppressHandler) {
        const normalized = normalizeStateName(stateName);
        if (!normalized || currentState === normalized)
            return false;

        const previous = currentState;
        const suppress = suppressHandler !== undefined ? suppressHandler : true;
        if (suppress)
            suppressStateHandler = true;
        currentState = normalized;
        previousState = previous;
        if (suppress)
            suppressStateHandler = false;
        return true;
    }

    function requestState(baseState) {
        if (currentState == "wait") {
            if (gameScene.getBattleGridOffense() !== root) {
                if (baseState == "compact") { return false; }

                if (baseState == "match") { return false; }
                if (baseState == "launch") { return false; }

            }
        }
        const forms = stateFormsFor(baseState);
        if (!forms)
            return false;
        setGridStateInternal(forms.base, false);
        return true;
    }

    onCurrentStateChanged: handleStateChange(currentState, previousState)

    function handleStateChange(newState, oldState) {
        console.log("state changed from", root, "from", oldState, "to", newState);
        if (suppressStateHandler)
            return;

        previousState = oldState || "";
        stopAllStateTimers();

        const normalized = normalizeStateName(newState);

        switch (normalized) {
        case "wait":
            break;
        case "compact":
            compactColumns();
            compactStateCheckTimer.start();
            break;
        case "fill":
            fillMissingBlocks();
            fillStateCheckTimer.start();
            break;
        case "match":
            markMatchedBlocks();
            matchStateCheckTimer.start();
            Qt.callLater(function() { evaluateMatchState(); });
            break;
        case "launch":
            prepareLaunchSequence();
            launchBlocksTimer.start();
            break;
        case "idle":
            postSwapCascading = false;
            updateBlockScenePositions();
            break;
        case "init":
            fillGrid();
            requestState("compact");
            break;
        default:
            break;
        }
    }

    function ensureMatrix() {
        if (!blockMatrix || blockMatrix.length !== gridRows) {
            var newMatrix = [];
            for (var r = 0; r < gridRows; ++r)
                newMatrix.push(new Array(gridCols));
            blockMatrix = newMatrix;
            return;
        }

        for (var idx = 0; idx < gridRows; ++idx) {
            if (!blockMatrix[idx] || blockMatrix[idx].length !== gridCols)
                blockMatrix[idx] = new Array(gridCols);
        }
    }

    function cellPosition(row, column) {
        return {
            x: originX + column * (cellW + gapX),
            y: originY + row * (cellH + gapY)
        };
    }

    function setWrapperAt(row, column, wrapper) {
        ensureMatrix();
        if (row < 0 || row >= gridRows || column < 0 || column >= gridCols)
            return;

        blockMatrix[row][column] = wrapper;
        if (!wrapper)
            return;



        if (wrapper.entry) {
            wrapper.entry.row = row;
            wrapper.entry.column = column;
            if (!wrapper.entry.blockState)
                wrapper.entry.blockState = "idle";
        }

        wrapper.width = cellW;
        wrapper.height = cellH;
        const pos = cellPosition(row, column);
        wrapper.x = pos.x;
        wrapper.y = pos.y;
    }

    function heroPlacementKey(cardUuid) {
        return cardUuid || "";
    }

    function hasHeroForCard(cardUuid) {
        var key = heroPlacementKey(cardUuid);
        return !!heroPlacements[key];
    }

    function heroAreaWithinBounds(row, column, rowSpan, colSpan) {
        if (row < 0 || column < 0)
            return false;
        if ((row + rowSpan) > gridRows)
            return false;
        if ((column + colSpan) > gridCols)
            return false;
        return true;
    }

    function heroCellsForArea(row, column, rowSpan, colSpan) {
        var cells = [];
        for (var r = row; r < row + rowSpan; ++r) {
            for (var c = column; c < column + colSpan; ++c) {
                cells.push({ row: r, column: c });
            }
        }
        return cells;
    }

    function heroAreasOverlap(a, b) {
        if (!a || !b)
            return false;
        var aBottom = a.row + a.rowSpan - 1;
        var aRight = a.column + a.colSpan - 1;
        var bBottom = b.row + b.rowSpan - 1;
        var bRight = b.column + b.colSpan - 1;
        var horizontal = !(a.column > bRight || b.column > aRight);
        var vertical = !(a.row > bBottom || b.row > aBottom);
        return horizontal && vertical;
    }

    function canPlaceHero(cardUuid, row, column, rowSpan, colSpan) {
        if (!heroAreaWithinBounds(row, column, rowSpan, colSpan))
            return false;
        if (hasHeroForCard(cardUuid))
            return false;
        var placement = { row: row, column: column, rowSpan: rowSpan, colSpan: colSpan };
        for (var key in heroPlacements) {
            if (!heroPlacements.hasOwnProperty(key))
                continue;
            var existing = heroPlacements[key];
            if (!existing)
                continue;
            if (heroAreasOverlap(existing, placement))
                return false;
        }
        return true;
    }

    function collectBoundBlocks(row, column, rowSpan, colSpan) {
        var cells = heroCellsForArea(row, column, rowSpan, colSpan);
        var bound = [];
        for (var i = 0; i < cells.length; ++i) {
            var cell = cells[i];
            var wrapper = getBlockWrapper(cell.row, cell.column);
            if (wrapper)
                bound.push({ row: cell.row, column: cell.column, wrapper: wrapper });
        }
        return bound;
    }

    function ensureHeroCellMap() {
        if (!heroCellMap || heroCellMap.length !== gridRows) {
            var map = [];
            for (var r = 0; r < gridRows; ++r)
                map.push(new Array(gridCols));
            heroCellMap = map;
            return;
        }
        for (var r = 0; r < gridRows; ++r) {
            if (!heroCellMap[r] || heroCellMap[r].length !== gridCols)
                heroCellMap[r] = new Array(gridCols);
        }
    }

    function setHeroCellKey(row, column, key) {
        ensureHeroCellMap();
        if (row < 0 || row >= gridRows || column < 0 || column >= gridCols)
            return;
        heroCellMap[row][column] = key || null;
    }

    function heroKeyAt(row, column) {
        ensureHeroCellMap();
        if (row < 0 || row >= gridRows || column < 0 || column >= gridCols)
            return null;
        return heroCellMap[row][column] || null;
    }

    function heroPlacementForKey(key) {
        if (!key)
            return null;
        return heroPlacements[key] || null;
    }

    function heroPlacementForWrapper(wrapper) {
        if (!wrapper)
            return null;
        var key = wrapper.heroBindingKey || (wrapper.entry ? wrapper.entry.heroBindingKey : null);
        return heroPlacementForKey(key);
    }

    function heroPlacementForCell(row, column) {
        var key = heroKeyAt(row, column);
        return heroPlacementForKey(key);
    }

    function clearHeroPlacementCells(placement) {
        if (!placement || !placement.boundBlocks)
            return;
        ensureHeroCellMap();
        for (var i = 0; i < placement.boundBlocks.length; ++i) {
            var record = placement.boundBlocks[i];
            if (!record)
                continue;
            if (record.row !== undefined && record.column !== undefined)
                setHeroCellKey(record.row, record.column, null);
            var wrap = record.wrapper;
            if (!wrap)
                continue;
            wrap.heroBindingKey = null;
            if (wrap.entry)
                wrap.entry.heroBindingKey = null;
        }
    }

    function bindHeroPlacement(placement) {
        if (!placement)
            return;
        clearHeroPlacementCells(placement);
        var bound = collectBoundBlocks(placement.row, placement.column, placement.rowSpan, placement.colSpan);
        placement.boundBlocks = [];
        for (var i = 0; i < bound.length; ++i) {
            var record = bound[i];
            if (!record || !record.wrapper)
                continue;
            var wrapper = record.wrapper;
            wrapper.heroBindingKey = placement.key;
            if (wrapper.entry) {
                wrapper.entry.heroBindingKey = placement.key;
                if (placement.cardData)
                    wrapper.entry.health = Math.max(0, placement.cardData.heroCurrentHealth);
            }
            placement.boundBlocks.push({ row: record.row, column: record.column, wrapper: wrapper });
            setHeroCellKey(record.row, record.column, placement.key);
        }
        if (placement.heroItem) {
            placement.heroItem.anchoredRow = placement.row;
            placement.heroItem.anchoredColumn = placement.column;
        }
    }

    function refreshHeroBlockHealth(placement) {
        if (!placement || !placement.boundBlocks)
            return;
        var health = placement.cardData ? Math.max(0, placement.cardData.heroCurrentHealth) : 0;
        for (var i = 0; i < placement.boundBlocks.length; ++i) {
            var record = placement.boundBlocks[i];
            if (!record || !record.wrapper || !record.wrapper.entry)
                continue;
            record.wrapper.entry.health = health;
        }
    }

    function handleHeroDefeat(placement, context) {
        if (!placement)
            return;
        var key = placement.key;
        var cardData = placement.cardData || null;
        if (placement.boundBlocks) {
            for (var i = 0; i < placement.boundBlocks.length; ++i) {
                var record = placement.boundBlocks[i];
                if (!record || !record.wrapper || !record.wrapper.entry)
                    continue;
                record.wrapper.entry.health = 0;
                record.wrapper.entry.blockState = "waitAndExplode";
            }
        }
        if (placement.heroItem && typeof placement.heroItem.destroy === "function") {
            placement.heroItem.visible = false;
            placement.heroItem.destroy();
            placement.heroItem = null;
        }

        var cardUuid = placement.metadata && placement.metadata.cardUuid ? placement.metadata.cardUuid : key;
        releaseHeroPlacement(cardUuid, { preserveCardState: true });
        if (cardData) {
            cardData.heroCurrentHealth = 0;
            cardData.resetAfterHeroRemoval();
        }
    }

    function applyHeroHealingAt(row, column, amount, context) {
        var placement = heroPlacementForCell(row, column);
        if (!placement || !placement.cardData)
            return { applied: 0, destroyed: false, key: null };
        var heal = Math.max(0, Math.floor(amount));
        if (heal <= 0)
            return { applied: 0, destroyed: false, key: placement.key };
        var previous = placement.cardData.heroCurrentHealth;
        placement.cardData.applyHeroHealing(heal);
        var applied = Math.max(0, placement.cardData.heroCurrentHealth - previous);
        refreshHeroBlockHealth(placement);
        return { applied: applied, destroyed: false, key: placement.key };
    }

    function applyDamageToHeroCell(row, column, amount, context) {
        var placement = heroPlacementForCell(row, column);
        if (!placement || !placement.cardData)
            return { applied: 0, destroyed: false, key: null };
        var dmg = Math.max(0, Math.floor(amount));
        if (dmg <= 0)
            return { applied: 0, destroyed: false, key: placement.key };
        var previous = placement.cardData.heroCurrentHealth;
        placement.cardData.applyHeroDamage(dmg);
        var applied = Math.max(0, previous - placement.cardData.heroCurrentHealth);
        var defeated = !placement.cardData.heroAlive;
        if (defeated)
            handleHeroDefeat(placement, Object.assign({ reason: "damage" }, context || {}));
        else
            refreshHeroBlockHealth(placement);
        return { applied: applied, destroyed: defeated, key: placement.key };
    }

    function applyBlockDelta(row, column, amount, operation, context) {
        var entry = getBlockEntryAt(row, column);
        if (!entry)
            return { affected: false };
        var delta = Math.max(0, Math.floor(amount));
        if (delta <= 0)
            return { affected: false };
        var placement = heroPlacementForCell(row, column);
        if (placement && placement.cardData) {
            if (operation && operation.toString().toLowerCase() === "increase")
                return Object.assign({ affected: true, hero: true }, applyHeroHealingAt(row, column, delta, context));
            return Object.assign({ affected: true, hero: true }, applyDamageToHeroCell(row, column, delta, context));
        }

        if (entry.health === undefined || entry.health === null)
            entry.health = 100;
        var op = operation && operation.toString().toLowerCase() === "increase" ? "increase" : "decrease";
        if (op === "increase") {
            entry.health = entry.health + delta;
            return { affected: true, destroyed: false, hero: false, health: entry.health };
        }

        entry.health = entry.health - delta;
        if (entry.health <= 0) {
            entry.health = 0;
            entry.blockState = "waitAndExplode";
            return { affected: true, destroyed: true, hero: false, health: 0 };
        }
        return { affected: true, destroyed: false, hero: false, health: entry.health };
    }

    function applyBlockDeltaList(cells, amount, operation, context) {
        var results = [];
        if (!Array.isArray(cells))
            return results;
        for (var i = 0; i < cells.length; ++i) {
            var cell = cells[i];
            if (!cell)
                continue;
            var row = cell.row !== undefined ? cell.row : cell.r;
            var column = cell.column !== undefined ? cell.column : cell.c;
            if (row === undefined || column === undefined)
                continue;
            results.push(Object.assign({ row: row, column: column }, applyBlockDelta(row, column, amount, operation, context)));
        }
        return results;
    }

    function applyHeroDeltaByColor(color, amount, operation, context) {
        if (!color)
            return [];
        var keyColor = color.toString().toLowerCase();
        var op = operation && operation.toString().toLowerCase() === "increase" ? "increase" : "decrease";
        var delta = Math.max(0, Math.floor(amount));
        if (delta <= 0)
            return [];
        var impacts = [];
        for (var key in heroPlacements) {
            if (!heroPlacements.hasOwnProperty(key))
                continue;
            var placement = heroPlacements[key];
            if (!placement || !placement.cardData)
                continue;
            var cardColor = (placement.cardData.powerupCardColor || "").toLowerCase();
            if (cardColor !== keyColor)
                continue;
            var result = op === "increase"
                    ? applyHeroHealingAt(placement.row, placement.column, delta, context)
                    : applyDamageToHeroCell(placement.row, placement.column, delta, context);
            impacts.push(Object.assign({ key: key, row: placement.row, column: placement.column }, result));
        }
        return impacts;
    }

    function attemptHeroShift(placement, deltaRow, deltaCol) {
        if (!placement)
            return false;
        if ((Math.abs(deltaRow) + Math.abs(deltaCol)) !== 1)
            return false;
        var newRow = placement.row + deltaRow;
        var newCol = placement.column + deltaCol;
        if (!heroAreaWithinBounds(newRow, newCol, placement.rowSpan, placement.colSpan))
            return false;

        var currentCells = heroCellsForArea(placement.row, placement.column, placement.rowSpan, placement.colSpan);
        var newCells = heroCellsForArea(newRow, newCol, placement.rowSpan, placement.colSpan);
        var currentMap = {};
        for (var i = 0; i < currentCells.length; ++i) {
            var key = currentCells[i].row + ":" + currentCells[i].column;
            currentMap[key] = true;
        }
        var newMap = {};
        for (var n = 0; n < newCells.length; ++n) {
            var nKey = newCells[n].row + ":" + newCells[n].column;
            newMap[nKey] = true;
        }

        var leaving = [];
        for (var c = 0; c < currentCells.length; ++c) {
            var cell = currentCells[c];
            if (!newMap[cell.row + ":" + cell.column])
                leaving.push(cell);
        }

        var entering = [];
        for (var m = 0; m < newCells.length; ++m) {
            var cellNew = newCells[m];
            if (!currentMap[cellNew.row + ":" + cellNew.column])
                entering.push(cellNew);
        }

        if (entering.length !== leaving.length)
            return false;

        var incomingWrappers = [];
        for (var e = 0; e < entering.length; ++e) {
            var enteringCell = entering[e];
            var incomingWrapper = getBlockWrapper(enteringCell.row, enteringCell.column);
            if (!incomingWrapper)
                return false;
            var otherPlacement = heroPlacementForWrapper(incomingWrapper);
            if (otherPlacement && otherPlacement.key !== placement.key)
                return false;
            incomingWrappers.push({ cell: enteringCell, wrapper: incomingWrapper });
        }

        var previousBlocks = placement.boundBlocks ? placement.boundBlocks.slice() : [];
        clearHeroPlacementCells(placement);

        for (var iw = 0; iw < incomingWrappers.length; ++iw) {
            var incoming = incomingWrappers[iw];
            clearWrapperAt(incoming.cell.row, incoming.cell.column);
        }

        var heroWrappers = [];
        for (var hb = 0; hb < previousBlocks.length; ++hb) {
            var blockRecord = previousBlocks[hb];
            if (!blockRecord || !blockRecord.wrapper)
                continue;
            heroWrappers.push({
                                  wrapper: blockRecord.wrapper,
                                  relRow: blockRecord.row - placement.row,
                                  relCol: blockRecord.column - placement.column
                              });
            clearWrapperAt(blockRecord.row, blockRecord.column);
        }

        for (var hw = 0; hw < heroWrappers.length; ++hw) {
            var heroRecord = heroWrappers[hw];
            var targetRow = newRow + heroRecord.relRow;
            var targetColumn = newCol + heroRecord.relCol;
            setWrapperAt(targetRow, targetColumn, heroRecord.wrapper);
        }

        leaving.sort(function(a, b) {
            if (a.row !== b.row)
                return a.row - b.row;
            return a.column - b.column;
        });
        incomingWrappers.sort(function(a, b) {
            if (a.cell.row !== b.cell.row)
                return a.cell.row - b.cell.row;
            return a.cell.column - b.cell.column;
        });

        for (var li = 0; li < incomingWrappers.length; ++li) {
            var leaveCell = leaving[li];
            var moveWrapper = incomingWrappers[li].wrapper;
            setWrapperAt(leaveCell.row, leaveCell.column, moveWrapper);
        }

        placement.row = newRow;
        placement.column = newCol;
        bindHeroPlacement(placement);
        refreshHeroBlockHealth(placement);
        if (placement.heroItem) {
            var heroPos = cellPosition(newRow, newCol);
            placement.heroItem.x = heroPos.x;
            placement.heroItem.y = heroPos.y;
            placement.heroItem.anchoredRow = newRow;
            placement.heroItem.anchoredColumn = newCol;
        }
        return true;
    }

    function requestSwapWrappers(row1, column1, row2, column2) {
        ensureMatrix();
        if (row1 === row2 && column1 === column2)
            return false;
        if ((Math.abs(row1 - row2) + Math.abs(column1 - column2)) !== 1)
            return false;

        var wrapperA = getBlockWrapper(row1, column1);
        var wrapperB = getBlockWrapper(row2, column2);
        if (!wrapperA || !wrapperB)
            return false;

        var placementA = heroPlacementForWrapper(wrapperA);
        var placementB = heroPlacementForWrapper(wrapperB);
        var deltaRow = row2 - row1;
        var deltaCol = column2 - column1;

        if (placementA && placementB && placementA.key !== placementB.key)
            return false;

        if (placementA) {
            if (attemptHeroShift(placementA, deltaRow, deltaCol))
                return true;
            return false;
        }

        if (placementB) {
            if (attemptHeroShift(placementB, -deltaRow, -deltaCol))
                return true;
            return false;
        }

        setWrapperAt(row1, column1, wrapperB);
        setWrapperAt(row2, column2, wrapperA);
        return true;
    }

    function registerHeroPlacement(cardUuid, heroItem, row, column, rowSpan, colSpan, metadata) {
        var key = heroPlacementKey(cardUuid);
        var meta = metadata || {};
        var cardData = meta.cardData || (heroItem && heroItem.cardData) || null;
        if (!meta.cardUuid)
            meta.cardUuid = cardUuid;
        var placement = {
            key: key,
            heroItem: heroItem || null,
            cardData: cardData || null,
            row: row,
            column: column,
            rowSpan: rowSpan,
            colSpan: colSpan,
            metadata: meta,
            boundBlocks: []
        };
        heroPlacements[key] = placement;
        if (cardData) {
            cardData.battleGrid = root;
            cardData.markHeroPlacedState(true);
        }
        bindHeroPlacement(placement);
        refreshHeroBlockHealth(placement);
    }

    function releaseHeroPlacement(cardUuid, options) {
        var key = heroPlacementKey(cardUuid);
        if (!heroPlacements.hasOwnProperty(key))
            return;
        var placement = heroPlacements[key];
        clearHeroPlacementCells(placement);
        if (placement && placement.cardData && (!options || !options.preserveCardState))
            placement.cardData.resetAfterHeroRemoval();
        delete heroPlacements[key];
    }

    function clearWrapperAt(row, column) {
        ensureMatrix();
        if (row < 0 || row >= gridRows || column < 0 || column >= gridCols)
            return;
        blockMatrix[row][column] = null;
    }

    function teardownWrapper(wrapper, location) {
        if (!wrapper)
            return false;

        const resolved = (location && location.row !== undefined && location.column !== undefined)
                ? location
                : findWrapperPosition(wrapper);
        if (resolved.row >= 0 && resolved.column >= 0)
            clearWrapperAt(resolved.row, resolved.column);

        const instanceIdx = instances.indexOf(wrapper);
        if (instanceIdx !== -1)
            instances.splice(instanceIdx, 1);

        const blockEntry = wrapper.entry || null;
        wrapper.entry = null;
        if (blockEntry && typeof blockEntry.destroy === "function")
            blockEntry.destroy();

        if (typeof wrapper.destroy === "function")
            wrapper.destroy();

        return true;
    }

    function purgeDestroyedBlocks() {
        ensureMatrix();
        var destroyedWrappers = [];
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                const wrapper = blockMatrix[row][column];
                if (!wrapper)
                    continue;

                const blockEntry = wrapper.entry || null;
                const state = blockEntry && blockEntry.blockState ? normalizeStateName(blockEntry.blockState) : "";
                if (state === "destroyed")
                    destroyedWrappers.push({ wrapper: wrapper, row: row, column: column });
            }
        }

        for (var idx = 0; idx < destroyedWrappers.length; ++idx) {
            const record = destroyedWrappers[idx];
            teardownWrapper(record.wrapper, { row: record.row, column: record.column });
        }

        return destroyedWrappers.length;
    }

    function getBlockWrapper(row, column) {
        ensureMatrix();
        if (row < 0 || row >= gridRows || column < 0 || column >= gridCols)
            return null;
        return blockMatrix[row][column] || null;
    }

    function getBlockEntryAt(row, column) {
        const wrapper = getBlockWrapper(row, column);
        return wrapper ? wrapper.entry : null;
    }

    function getEntryAt(row, column) {
        return getBlockEntryAt(row, column);
    }

    function distributePostSwapCascadeStatus() {
        if (!uuid)
            return;
        const payload = {
            battleGrid: uuid,
            postSwapCascade: postSwapCascading
        };
        informPostSwapCascadeStatus(payload);
    }

    function informOpponentPostSwapCascadeStatus(payload) {
        if (!payload)
            return;
        const state = normalizeStateName(currentState);
        if (state !== "wait")
            return;
        if (payload.postSwapCascade === false)
            requestState("compact");
    }

    function moveWrapper(wrapper, targetRow, targetColumn) {
        if (!wrapper)
            return;

        const currentPos = findWrapperPosition(wrapper);
        if (currentPos.row >= 0 && currentPos.column >= 0)
            clearWrapperAt(currentPos.row, currentPos.column);

        setWrapperAt(targetRow, targetColumn, wrapper);
    }

    function findWrapperPosition(wrapper) {
        ensureMatrix();
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                if (blockMatrix[row][column] === wrapper)
                    return { row: row, column: column };
            }
        }
        return { row: -1, column: -1 };
    }

    function fillGrid() {
        ensureMatrix();
        const fillDescending = normalizeStateName(launchDirection) === "up";
        const rowStart = fillDescending ? gridRows - 1 : 0;
        const rowEnd = fillDescending ? -1 : gridRows;
        const rowStep = fillDescending ? -1 : 1;

        const direction = normalizeStateName(launchDirection);
        const spawnOffset = direction === "down" ? -(cellH * 5)
                           : direction === "up" ? (cellH * 5)
                           : -(cellH * 6);

        for (var row = rowStart; row !== rowEnd; row += rowStep) {
            for (var column = 0; column < gridCols; ++column) {
                if (getBlockWrapper(row, column))
                    continue;

                const pos = cellPosition(row, column);
                const dragItem = Factory.createBlock(
                            blockComp,
                            dragComp,
                            root,
                            gameScene || root,
                            {
                                width: cellW,
                                height: cellH,
                                x: pos.x,
                                y: pos.y,
                                spawnOffset: spawnOffset,
                                blockProps: {
                                    row: row,
                                    column: column,
                                    maxRows: gridRows,
                                    blockColor: blockPalette[(row + column) % blockPalette.length]
                                }
                            });

                if (!dragItem)
                    continue;

                instances.push(dragItem);

                setWrapperAt(row, column, dragItem);
                dragItem.startedMoving.connect(dragItem.entry.startedMoving)
                dragItem.stoppedMoving.connect(dragItem.entry.stoppedMoving)
                dragItem.y = pos.y;
                dragItem.sceneX = root.mapToGlobal(pos.x, pos.y).x
                dragItem.sceneY = root.mapToGlobal(pos.x, pos.y).y
                dragItem.entry.battleGrid = root;
            }
        }
    }

    function compactColumns() {
        ensureMatrix();
        purgeDestroyedBlocks();
        const gravityDown = normalizeStateName(launchDirection) === "up";
        for (var column = 0; column < gridCols; ++column) {
            var survivors = [];
            if (gravityDown) {
                for (var row = 0; row < gridRows; ++row) {
                    const wrapperDown = getBlockWrapper(row, column);
                    if (wrapperDown)
                        survivors.push(wrapperDown);
                }

                var targetRowDown = 0;
                for (var idxDown = 0; idxDown < survivors.length; ++idxDown) {
                    moveWrapper(survivors[idxDown], targetRowDown, column);
                    targetRowDown += 1;
                }

                while (targetRowDown < gridRows) {
                    clearWrapperAt(targetRowDown, column);
                    targetRowDown += 1;
                }
            } else {
                for (var rowUp = gridRows - 1; rowUp >= 0; --rowUp) {
                    const wrapperUp = getBlockWrapper(rowUp, column);
                    if (wrapperUp)
                        survivors.push(wrapperUp);
                }

                var targetRowUp = gridRows - 1;
                for (var idxUp = 0; idxUp < survivors.length; ++idxUp) {
                    moveWrapper(survivors[idxUp], targetRowUp, column);
                    targetRowUp -= 1;
                }

                while (targetRowUp >= 0) {
                    clearWrapperAt(targetRowUp, column);
                    targetRowUp -= 1;
                }
            }
        }
    }

    function spawnMissingBlocks() {
        fillGrid();
    }
    function updateBlockScenePositions() {
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                var wrapper = getBlockWrapper(row, column)
                if (!wrapper) {
                    continue;
                }
                var globX = wrapper.mapToGlobal(wrapper.x, wrapper.y).x
                var globY = wrapper.mapToGlobal(wrapper.x, wrapper.y).y
                wrapper.sceneX = globX
                wrapper.sceneY = globY

            }
        }
    }

    function fillMissingBlocks() {
        fillGrid();
    }

    function markMatchedBlocks() {
        ensureMatrix();

        const matchedWrappers = [];
        const registerMatch = function(wrapper) {
            if (!wrapper)
                return;
            if (matchedWrappers.indexOf(wrapper) === -1)
                matchedWrappers.push(wrapper);
        };

        // Horizontal runs
        for (var row = 0; row < gridRows; ++row) {
            var runColor = null;
            var runWrappers = [];
            for (var column = 0; column <= gridCols; ++column) {
                const wrapper = column < gridCols ? blockMatrix[row][column] : null;
                const entry = wrapper && wrapper.entry ? wrapper.entry : null;
                const color = entry ? entry.blockColor : null;

                if (color && color === runColor) {
                    runWrappers.push(wrapper);
                } else {
                    if (runColor && runWrappers.length >= 3) {
                        for (var idx = 0; idx < runWrappers.length; ++idx)
                            registerMatch(runWrappers[idx]);
                    }
                    runColor = color;
                    runWrappers = color ? [wrapper] : [];
                }
            }
        }

        // Vertical runs
        for (var column = 0; column < gridCols; ++column) {
            var vRunColor = null;
            var vRunWrappers = [];
            for (var row = 0; row <= gridRows; ++row) {
                const wrapper = row < gridRows ? blockMatrix[row][column] : null;
                const entry = wrapper && wrapper.entry ? wrapper.entry : null;
                const color = entry ? entry.blockColor : null;

                if (color && color === vRunColor) {
                    vRunWrappers.push(wrapper);
                } else {
                    if (vRunColor && vRunWrappers.length >= 3) {
                        for (var idx = 0; idx < vRunWrappers.length; ++idx)
                            registerMatch(vRunWrappers[idx]);
                    }
                    vRunColor = color;
                    vRunWrappers = color ? [wrapper] : [];
                }
            }
        }

        // Apply states: only wrappers in matchedWrappers should flip to matched.
        for (var applyRow = 0; applyRow < gridRows; ++applyRow) {
            for (var applyColumn = 0; applyColumn < gridCols; ++applyColumn) {
                const applyWrapper = blockMatrix[applyRow][applyColumn];
                if (!applyWrapper || !applyWrapper.entry)
                    continue;

                if (matchedWrappers.indexOf(applyWrapper) !== -1)
                    applyWrapper.entry.blockState = "matched";
                else if (applyWrapper.entry.blockState === "matched")
                    applyWrapper.entry.blockState = "idle";
            }
        }

        const matches = [];
        for (var idx = 0; idx < matchedWrappers.length; ++idx) {
            const entry = matchedWrappers[idx] && matchedWrappers[idx].entry;
            if (entry && entry.itemName)
                matches.push(entry.itemName);
        }

        return { matches: matches };
    }

    function receiveLocalBlockLaunchPayload(payload) {
        if (!payload)
            return null;
        const enriched = Object.assign({}, payload, {
            battleGrid: root.uuid,
            uuid: uuid,
            launchDirection: launchDirection
        });
        distributedBlockLaunchPayload(enriched);
        return enriched;
    }

    function hasMissingOrDestroyedBlocks() {
        ensureMatrix();
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                const entry = getBlockEntryAt(row, column);
                if (!entry)
                    return true;
                const state = normalizeStateName(entry.blockState);
                if (state === "destroyed")
                    return true;
            }
        }
        return false;
    }

    function hasActiveNonIdleBlocks() {
        ensureMatrix();
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                const entry = getBlockEntryAt(row, column);
                if (!entry)
                    continue;
                const state = normalizeStateName(entry.blockState);
                if (state === "launch" || state === "match" || state === "explode")
                    return true;
            }
        }
        return false;
    }

    function handlePostSwapCascadeResolution() {
        if (!postSwapCascading)
            return false;
        if (hasMissingOrDestroyedBlocks())
            return false;
        if (hasActiveNonIdleBlocks())
            return false;
        postSwapCascading = false;
        requestState("idle");
        return true;
    }

    function allEntriesIdleAllowMissing() {
        ensureMatrix();
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                const entry = getBlockEntryAt(row, column);
                if (!entry)
                    continue;
                if (normalizeStateName(entry.blockState) !== "idle")
                    return false;
            }
        }
        return true;
    }

    function allEntriesIdleNoMissing() {
        ensureMatrix();
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                const entry = getBlockEntryAt(row, column);
                if (!entry)
                    return false;
                if (normalizeStateName(entry.blockState) !== "idle")
                    return false;
            }
        }
        return true;
    }

    function allEntriesIdleDestroyedOrMissing() {
        ensureMatrix();
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                const entry = getBlockEntryAt(row, column);
                if (!entry)
                    continue;
                const state = normalizeStateName(entry.blockState);
                if (state !== "idle" && state !== "destroyed")
                    return false;
            }
        }
        return true;
    }

    function hasMatchedBlocks() {
        ensureMatrix();
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                const entry = getBlockEntryAt(row, column);
                if (!entry)
                    continue;
                if (normalizeStateName(entry.blockState) === "matched")
                    return true;
            }
        }
        return false;
    }

    function buildLaunchSequence() {
        var sequence = [];
        for (var row = gridRows - 1; row >= 0; --row) {
            if (row % 2 === 1) {
                for (var columnDesc = gridCols - 1; columnDesc >= 0; --columnDesc)
                    sequence.push({ row: row, column: columnDesc });
            } else {
                for (var columnAsc = 0; columnAsc < gridCols; ++columnAsc)
                    sequence.push({ row: row, column: columnAsc });
            }
        }
        return sequence;
    }

    function prepareLaunchSequence() {
        launchSequence = buildLaunchSequence();
        launchSequenceIndex = 0;
    }

    function triggerLaunchForEntry(entry, row, column) {
        if (!entry)
            return false;
        if (normalizeStateName(entry.blockState) !== "matched")
            return false;

        const wrapper = getBlockWrapper(row, column);
        entry.blockState = "launch";
        if (entry.health === undefined || entry.health === null)
            entry.health = 5;

        var globalPoint = { x: 0, y: 0 };
        if (wrapper && typeof wrapper.mapToGlobal === "function")
            globalPoint = wrapper.mapToGlobal(0, 0);
        else {
            const cellPos = cellPosition(row, column);
            globalPoint = root.mapToGlobal(cellPos.x, cellPos.y);
        }

        const payload = {
            blockName: entry.itemName,
            row: entry.row,
            column: entry.column,
            health: entry.health,
            blockColor: entry.blockColor || "",
            x: globalPoint.x,
            y: globalPoint.y,
            action: "launch",
            battleGrid: root.uuid
        };
        distributeBlockLaunchPayload(payload);
        if (wrapper)
            wrapperLaunched(wrapper);
        return true;
    }

    function launchNextMatchedBlock() {
        ensureMatrix();
        while (launchSequenceIndex < launchSequence.length) {
            const coord = launchSequence[launchSequenceIndex++];
            const entry = getBlockEntryAt(coord.row, coord.column);
            if (!entry)
                continue;
            if (!triggerLaunchForEntry(entry, coord.row, coord.column))
                continue;
            return true;
        }
        return false;
    }

    function stopAllStateTimers() {
        if (compactStateCheckTimer.running)
            compactStateCheckTimer.stop();
        if (fillStateCheckTimer.running)
            fillStateCheckTimer.stop();
        if (matchStateCheckTimer.running)
            matchStateCheckTimer.stop();
        if (launchBlocksTimer.running)
            launchBlocksTimer.stop();
        if (launchStateCheckTimer.running)
            launchStateCheckTimer.stop();
    }

    function checkCompactStateCompletion() {
        if (!allEntriesIdleAllowMissing())
            return;
        compactStateCheckTimer.stop();
        requestState("fill");
    }

    function checkFillStateCompletion() {
        if (!allEntriesIdleNoMissing())
            return;
        fillStateCheckTimer.stop();
        requestState("match");
    }

    function evaluateMatchState() {
        matchStateCheckTimer.stop();
        if (hasMatchedBlocks())
            requestState("launch");
        else {
            postSwapCascading = false;
            requestState("idle");
        }
    }

    function checkLaunchStateCompletion() {
        if (!allEntriesIdleDestroyedOrMissing())
            return;
        launchStateCheckTimer.stop();
        requestState("compact");
    }

    function calculateLaunchDamage(payload) {
        if (!payload)
            return { remainingHealth: 0, blocksDamaged: [], directDamage: 0 };

        const column = payload.column;
        if (column === undefined || column === null || column < 0 || column >= gridCols)
            return { remainingHealth: payload.health || 0, blocksDamaged: [], directDamage: 0 };

        var remaining = payload.health !== undefined && payload.health !== null ? payload.health : 0;
        if (remaining <= 0)
            return { remainingHealth: remaining, blocksDamaged: [], directDamage: 0 };

        ensureMatrix();
        const damagedBlocks = [];
        var lastImpact = null;
        const damageAscending = normalizeStateName(launchDirection) === "up";
        const rowStart = damageAscending ? 0 : gridRows - 1;
        const rowEnd = damageAscending ? gridRows : -1;
        const rowStep = damageAscending ? 1 : -1;

        var columnClearedBeforeImpact = true;
        for (var scanRow = 0; scanRow < gridRows; ++scanRow) {
            const scanEntry = getBlockEntryAt(scanRow, column);
            if (!scanEntry)
                continue;
            const scanState = normalizeStateName(scanEntry.blockState);
            const scanHealth = scanEntry.health;
            const healthActive = (scanHealth === undefined || scanHealth === null || scanHealth > 0);
            if (healthActive && scanState !== "destroyed" && scanState !== "waitandexplode") {
                columnClearedBeforeImpact = false;
                break;
            }
        }

        for (var row = rowStart; row !== rowEnd && remaining > 0; row += rowStep) {
            const entry = getBlockEntryAt(row, column);
            if (!entry)
                continue;
            const state = normalizeStateName(entry.blockState);
            if (state && state !== "idle")
                continue;

            var blockColor = entry.blockColor || (entry.entry && entry.entry.blockColor) || "";
            var heroPlacement = heroPlacementForCell(row, column);
            if (heroPlacement && heroPlacement.cardData) {
                var heroHealthBefore = heroPlacement.cardData.heroCurrentHealth;
                var heroDamageResult = applyDamageToHeroCell(row, column, remaining, { reason: "launch", payload: payload });
                if (heroDamageResult.applied > 0) {
                    remaining -= heroDamageResult.applied;
                    damagedBlocks.push({
                                            row: row,
                                            column: column,
                                            destroyed: heroDamageResult.destroyed,
                                            color: blockColor,
                                            energyReward: heroDamageResult.destroyed ? heroHealthBefore : 0,
                                            hero: true
                                        });
                    if (shakeEffector)
                        shakeEffector.triggerImpact();
                    lastImpact = { row: row, column: column };
                }
                continue;
            }

            if (entry.health === undefined || entry.health === null)
                entry.health = 100;

            if (entry.health <= 0)
                continue;

            const targetHealth = entry.health;
            if (remaining >= targetHealth) {
                remaining -= targetHealth;
                entry.health = 0;
                entry.blockState = "waitAndExplode";
                damagedBlocks.push({
                                        row: row,
                                        column: column,
                                        destroyed: true,
                                        color: blockColor,
                                        energyReward: targetHealth
                                    });
                if (shakeEffector)
                    shakeEffector.triggerImpact();
                lastImpact = { row: row, column: column };
            } else {
                entry.health = targetHealth - remaining;
                damagedBlocks.push({
                                        row: row,
                                        column: column,
                                        destroyed: false,
                                        color: blockColor,
                                        energyReward: 0
                                    });
                remaining = 0;
                lastImpact = { row: row, column: column };
            }
        }

        const breachHealth = remaining;
        const breachOccurred = columnClearedBeforeImpact && breachHealth > 0;
        if (breachOccurred && shakeEffector)
            shakeEffector.triggerBreach();

        var directDamage = 0;
        if (remaining > 0) {
            const overflow = Math.min(remaining, mainHealth);
            if (overflow > 0) {
                mainHealth -= overflow;
                directDamage = overflow;
                remaining -= overflow;
            }
        }

        const endpointPayload = Object.assign({}, payload, {
            damagedBlocks: damagedBlocks.slice(),
            remainingHealth: remaining,
            directDamage: directDamage
        });

        var endpointRow;
        if (lastImpact)
            endpointRow = lastImpact.row;
        else
            endpointRow = damageAscending ? 0 : gridRows - 1;
        if (endpointRow < 0)
            endpointRow = 0;
        else if (endpointRow >= gridRows)
            endpointRow = gridRows - 1;
        const endpointCell = cellPosition(endpointRow, column);
        const endpointGlobal = root.mapToGlobal(endpointCell.x, endpointCell.y);
        informBlockLaunchEndPoint(endpointPayload, endpointGlobal.x, endpointGlobal.y);

        return {
            remainingHealth: remaining,
            blocksDamaged: damagedBlocks,
            directDamage: directDamage,
            breachHealth: breachHealth,
            breachOccurred: breachOccurred,
            columnCleared: columnClearedBeforeImpact,
            sourceBlockColor: payload.blockColor || ""
        };
    }

    function launchMatchedBlocks() {
        ensureMatrix();
        const launched = [];
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                const entry = getBlockEntryAt(row, column);
                if (!entry)
                    continue;
                if (triggerLaunchForEntry(entry, row, column) && entry.itemName)
                    launched.push(entry.itemName);
            }
        }
        return { launched: launched };
    }

    function findWrapperByItemName(blockId) {
        ensureMatrix();
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                const wrapper = blockMatrix[row][column];
                if (wrapper && wrapper.itemName === blockId)
                    return wrapper;
            }
        }
        return null;
    }

    Component { id: dragComp; Engine.GameDragItem { } }
    Component { id: blockComp; UI.Block { } }

    Timer {
        id: compactStateCheckTimer
        interval: 120
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: checkCompactStateCompletion()
    }

    Timer {
        id: fillStateCheckTimer
        interval: 120
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: checkFillStateCompletion()
    }

    Timer {
        id: matchStateCheckTimer
        interval: 150
        repeat: false
        running: false
        triggeredOnStart: false
        onTriggered: evaluateMatchState()
    }

    Timer {
        id: launchBlocksTimer
        interval: 90
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: {
            if (!launchNextMatchedBlock()) {
                launchBlocksTimer.stop();
                launchStateCheckTimer.start();
            }

        }
    }

    Timer {
        id: launchStateCheckTimer
        interval: 120
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: checkLaunchStateCompletion()
    }

    Component.onCompleted: {
        Factory.registerBattleGrid(root);
        requestState("init");
    }
}
