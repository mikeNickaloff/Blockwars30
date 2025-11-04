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

    function registerHeroPlacement(cardUuid, heroItem, row, column, rowSpan, colSpan, metadata) {
        var key = heroPlacementKey(cardUuid);
        heroPlacements[key] = {
            heroItem: heroItem,
            row: row,
            column: column,
            rowSpan: rowSpan,
            colSpan: colSpan,
            metadata: metadata || {},
            boundBlocks: collectBoundBlocks(row, column, rowSpan, colSpan)
        };
    }

    function releaseHeroPlacement(cardUuid) {
        var key = heroPlacementKey(cardUuid);
        if (!heroPlacements.hasOwnProperty(key))
            return;
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

        for (var row = rowStart; row !== rowEnd && remaining > 0; row += rowStep) {
            const entry = getBlockEntryAt(row, column);
            if (!entry)
                continue;
            const state = normalizeStateName(entry.blockState);
            if (state && state !== "idle")
                continue;

            if (entry.health === undefined || entry.health === null)
                entry.health = 100;

            if (entry.health <= 0)
                continue;

            const targetHealth = entry.health;
            var blockColor = entry.blockColor || (entry.entry && entry.entry.blockColor) || "";
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
            directDamage: directDamage
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
