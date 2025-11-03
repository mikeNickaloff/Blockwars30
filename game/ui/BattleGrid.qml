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

    property string currentState: "init"
    property string previousState: ""
    property bool suppressStateHandler: false
    property string deferredStateRequest: ""

    readonly property var stateList: [
        "init", "initializing", "initialized",
        "compact", "compacting", "compacted",
        "fill", "filling", "filled",
        "match", "matching", "matched",
        "launch", "launching", "launched"
    ]

    // Compact representation of the grid.
    property var blockMatrix: []

    // Queue used to serialize lifecycle work.
    property bool stateMachineManagedInitialization: false

    property alias battleQueue: battleQueueController.queue
    property alias queueProcessing: battleQueueController.processing
    property alias activeQueueItem: battleQueueController.activeItem

    property var stateActions: ({
        init: {
            main: function(target) {
                target.fillGrid();
                return { initialized: true };
            }
        },
        compact: {
            main: function(target) {
                target.compactColumns();
                target.spawnMissingBlocks();
                return { compacted: true };
            }
        },
        fill: {
            main: function(target) {
                target.fillMissingBlocks();
                return { filled: true };
            }
        },
        match: {
            main: function(target) {
                return target.markMatchedBlocks();
            }
        },
        launch: {
            main: function(target) {
                return target.launchMatchedBlocks();
            }
        }
    });

    property var __launchRelayRegistered: false

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

    function hasActiveLaunchOrExplodeBlocks() {
        ensureMatrix();
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                const entry = getBlockEntryAt(row, column);
                if (!entry)
                    continue;
                const blockState = normalizeStateName(entry.blockState);
                if (blockState === "launch" || blockState === "explode" || blockState === "moving")
                    return true;


            }
        }
        return false;
    }

    function deferStateTransition(baseState) {
        const normalized = normalizeStateName(baseState);
        if (!normalized)
            return;
        deferredStateRequest = normalized;
        if (!deferredStateRetryTimer.running)
            deferredStateRetryTimer.start();
    }

    function attemptDeferredStateTransition() {
        if (!deferredStateRequest) {
            if (deferredStateRetryTimer.running)
                deferredStateRetryTimer.stop();
            return;
        }

        if (hasActiveLaunchOrExplodeBlocks())
            return;

        const targetState = deferredStateRequest;
        deferredStateRequest = "";
        if (deferredStateRetryTimer.running)
            deferredStateRetryTimer.stop();
        requestState(targetState);
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
        const forms = stateFormsFor(baseState);
        if (!forms)
            return false;
        if (hasActiveLaunchOrExplodeBlocks()) {
            deferStateTransition(forms.base);
            return true;
        }
        if (deferredStateRequest === forms.base)
            deferredStateRequest = "";
        if (deferredStateRetryTimer.running && !deferredStateRequest)
            deferredStateRetryTimer.stop();
        const changed = setGridStateInternal(forms.base, false);
        if (!changed && currentState === forms.base)
            enqueueLifecycleForState(forms.base);
        return true;
    }

    onCurrentStateChanged: handleStateChange(currentState, previousState)

    function handleStateChange(newState, oldState) {
        console.log("state changed from",root, "from", oldState,"to", newState)
        if (suppressStateHandler)
            return;
        previousState = oldState || "";
        const forms = stateFormsFor(newState);
        if (!forms)
            return;

        if (forms.base === normalizeStateName(newState)) {
            enqueueLifecycleForState(forms.base);
        }
    }

    function enqueueLifecycleForState(baseState) {
        if (isLifecycleQueued(baseState))
            return;

        const forms = stateFormsFor(baseState);
        if (!forms)
            return;

        const stateAction = stateActions[forms.base] || {};
        const queueItem = {
            name: "lifecycle-" + forms.base,
            forms: forms,
            action: stateAction,
            start_function: function(target) {
                if (forms.base === "compact" && typeof target.purgeDestroyedBlocks === "function")
                    target.purgeDestroyedBlocks();
                target.setGridStateInternal(forms.active);
                if (typeof stateAction.start === "function")
                    stateAction.start(target, forms);
            },
            main_function: function(target) {
                if (typeof stateAction.main === "function")
                    return stateAction.main(target, forms);
                return {};
            },
            end_function: function(target, item, context) {
                target.setGridStateInternal(forms.completed);
                if (typeof stateAction.end === "function")
                    stateAction.end(target, context, forms);
                target.handleLifecycleCompleted(forms, context);
            }
        };

        enqueueBattleEvent(queueItem);
    }

    function isLifecycleQueued(baseState) {
        const target = normalizeStateName(baseState);
        if (!target)
            return false;

        if (activeQueueItem && activeQueueItem.forms && activeQueueItem.forms.base === target)
            return true;

        for (var idx = 0; idx < battleQueue.length; ++idx) {
            const item = battleQueue[idx];
            if (item && item.forms && item.forms.base === target)
                return true;
        }
        return false;
    }

    function enqueueBattleEvent(eventObject) {
        console.log("Enqueued battle event",JSON.stringify(eventObject))
        if (!eventObject)
            return;
        battleQueueController.enqueue(eventObject);
    }

    function deferActiveQueueItem() {
        return battleQueueController.deferActiveItem();
    }

    function finishActiveQueueItem(context) {
        battleQueueController.finishActiveItem(context);
    }

    function handleLifecycleCompleted(forms, context) {
        const baseState = forms.base;
        const summary = context && context.result ? context.result : context;

        switch (baseState) {
        case "init":
            requestState("compact");
            break;
        case "compact":
            requestState("fill");
            break;
        case "fill":
            requestState("match");
            break;
        case "match": {
            const matches = summary && summary.matches ? summary.matches : [];
           // updateBlockScenePositions();
            if (matches.length)
                requestState("launch");
            if (!matches.length)
                requestState("idle")
            break;
        }
        case "launch":
            requestState("compact");
            break;
        case "idle": {
            updateBlockScenePositions()
            break;
        }
        case "matched": {
            requestState("launch");
            break;
        }
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
                                blockProps: {
                                    row: row,
                                    column: column,
                                    maxRows: gridRows,
                                    blockColor: blockPalette[(row + column) % blockPalette.length]
                                },
                                rowHeight: cellH,
                                spawnOffsetRows: 5
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
            battleGrid: uuid,
            uuid: uuid,
            launchDirection: launchDirection
        });
        distributedBlockLaunchPayload(enriched);
        return enriched;
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
            if (remaining >= targetHealth) {
                remaining -= targetHealth;
                entry.health = 0;
                entry.blockState = "explode";
                damagedBlocks.push({ row: row, column: column, destroyed: true });
                lastImpact = { row: row, column: column };
            } else {
                entry.health = targetHealth - remaining;
                damagedBlocks.push({ row: row, column: column, destroyed: false });
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
                const wrapper = blockMatrix[row][column];
                if (!wrapper || !wrapper.entry)
                    continue;
                const entry = wrapper.entry;
                if (entry.blockState === "matched") {
                    entry.blockState = "launch";
                    if (entry.health === undefined || entry.health === null)
                        entry.health = 100;
                    const globalPoint = wrapper.mapToGlobal(0, 0);
                    const payload = {
                        blockName: entry.itemName,
                        row: entry.row,
                        column: entry.column,
                        health: entry.health,
                        x: globalPoint.x,
                        y: globalPoint.y,
                        action: "launch"
                    };
                    distributeBlockLaunchPayload(payload);
                    if (entry.itemName)
                        launched.push(entry.itemName);
                    wrapperLaunched(wrapper);
                }
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

    UI.BattleQueueOrchestrator {
        id: battleQueueController
        owner: root
        tickInterval: 5
        onQueueItemStarted: function(item) {
            root.queueItemStarted(item);
        }
        onQueueItemCompleted: function(item, context) {
            root.queueItemCompleted(item, context);
        }
    }

    Timer {
        id: deferredStateRetryTimer
        interval: 325
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: attemptDeferredStateTransition()
    }

    Component.onCompleted: {
        Factory.registerBattleGrid(root);
        requestState("init");
    }
}
