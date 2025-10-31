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
    width: 400; height: 400

    // Your scene (must expose addSceneDragItem(name, item))
    property var gameScene

    // Grid params. Tweak at runtime if you enjoy power.
    property int gridCols: 6
    property int gridRows: 6
    property int cellW: 50
    property int cellH: 50
    property int gapX: 2
    property int gapY: 2
    property int originX: 40
    property int originY: 40
    readonly property int gridHeight: (gridRows * cellH) + Math.max(0, gridRows - 1) * gapY
    property alias blocksModel: blocksModel
    // Keep references if you want to reflow or mutate later
    property var instances: []
    property int blockSequence: 0
    readonly property var blockPalette: ["red", "blue", "green", "yellow"]
    readonly property string blockIdPrefix: "grid_block"

    readonly property var stateList: [
        "init", "initializing", "initialized",
        "precompact", "precompacting", "precompacted",
        "compact", "compacting", "compacted",
        "fill", "filling", "filled",
        "fastfill", "fastfilling", "fastfilled",
        "match", "matching", "matched",
        "launch", "launching", "launched",
        "fastlaunch", "fastlaunching", "fastlaunched",
        "powerup", "poweruping", "poweruped",
        "swap", "swapping", "swapped",
        "aimove", "aimoving", "aimoved",
        "ready", "wait", "waiting"
    ]
    property string currentState: "init"
    property string previousState: ""
    property bool stateTransitionInProgress: false
    property bool stateMachineManagedInitialization: false

    signal stateTransitionStarted(string fromState, string toState, var metadata)
    signal stateTransitionFinished(string fromState, string toState, var metadata)
    signal stateTransitionRejected(string requestedState, string reason, var metadata)

    readonly property var stateHelper: ({
        name: currentState,
        equals: function(value) {
            return root.normalizeStateName(value) === root.currentState;
        },
        evaluateTransitions: function() {
            if (battleStateMachine)
                battleStateMachine.evaluateTransitions();
        },
        machine: battleStateMachine
    })

    function normalizeStateName(value) {
        if (value === null || value === undefined)
            return "";
        return value.toString().trim().toLowerCase();
    }

    function isValidState(value) {
        const normalized = normalizeStateName(value);
        return stateList.indexOf(normalized) !== -1;
    }

    function setState(nextState, metadata) {
        const normalized = normalizeStateName(nextState);
        const payload = metadata || {};

        if (!isValidState(normalized)) {
            stateTransitionRejected(normalized, "invalid", payload);
            console.warn("BattleGrid: Ignoring request to change to unknown state", nextState);
            return false;
        }

        if (stateTransitionInProgress) {
            stateTransitionRejected(normalized, "transition_in_progress", payload);
            console.warn("BattleGrid: State transition already in progress", currentState, "->", normalized);
            return false;
        }

        if (currentState === normalized) {
            return true;
        }

        stateTransitionInProgress = true;
        const fromState = currentState;
        stateTransitionStarted(fromState, normalized, payload);

        previousState = fromState;
        currentState = normalized;

        stateTransitionInProgress = false;
        stateTransitionFinished(fromState, normalized, payload);
        return true;
    }

    function ensureState(targetState, metadata) {
        if (currentState === normalizeStateName(targetState))
            return true;
        return setState(targetState, metadata);
    }

    property var battleQueue: []
    property bool queueProcessing: false
    property var activeQueueItem: null
    property QtObject activeQueuePromise: null
    property QtObject initializationPromise: null
    property QtObject battleStateMachine: null

    Component {
        id: battleStateMachineFactory
        Data.BattleGridStateMachine {
            battleGrid: root
        }
    }

    signal queueItemStarted(var item)
    signal queueItemCompleted(var item, var context)

    onCurrentStateChanged: handleCurrentStateChanged(currentState, previousState)

    Component.onCompleted: {
        battleStateMachine = battleStateMachineFactory.createObject(root);
        if (!battleStateMachine) {
            console.warn("BattleGrid: Failed to instantiate BattleGridStateMachine");
            return;
        }

        if (battleStateMachine.battleGrid !== root)
            battleStateMachine.attachGrid(root);
    }

    Component.onDestruction: {
        battleStateMachine = null;
    }

    Timer {
        id: nextQueueItemTimer
        interval: 50
        running: false
        repeat: false
        triggeredOnStart: false
        onTriggered: root.processNextQueueItem()
    }

    Component {
        id: queuePromiseFactory
        Lib.Promise { }
    }

    Component {
        id: initializationPromiseFactory
        Lib.Promise { }
    }

    function initializeQueuePromise() {
        disposeQueuePromise();
        activeQueuePromise = queuePromiseFactory.createObject(root);
        if (!activeQueuePromise) {
            console.warn("BattleGrid: Failed to create queue promise instance");
            return null;
        }

        activeQueuePromise.fulfilled.connect(handleQueuePromiseFulfilled);
        queueItemCompleted.connect(activeQueuePromise.resolve);
        return activeQueuePromise;
    }

    function disposeQueuePromise() {
        if (!activeQueuePromise)
            return;

        try {
            queueItemCompleted.disconnect(activeQueuePromise.resolve);
            activeQueuePromise.fulfilled.disconnect(handleQueuePromiseFulfilled);
        } catch (err) {
        }

        activeQueuePromise.destroy();
        activeQueuePromise = null;
    }

    function handleQueuePromiseFulfilled() {
        nextQueueItemTimer.running = false;
        nextQueueItemTimer.start();
    }

    function finishActiveQueueItem(context) {
        queueItemCompleted(activeQueueItem, context || {});
    }

    function resetInitializationPromise() {
        if (!initializationPromise)
            return;

        initializationPromise.destroy();
        initializationPromise = null;
    }

    function createInitializationPromise() {
        resetInitializationPromise();
        initializationPromise = initializationPromiseFactory.createObject(root);
        if (!initializationPromise) {
            console.warn("BattleGrid: Unable to create initialization promise instance");
            return null;
        }
        return initializationPromise;
    }

    function enqueueBattleEvent(eventObject) {
        if (!eventObject)
            return;
        battleQueue.push(eventObject);
        if (!queueProcessing) {
            queueProcessing = true;
            nextQueueItemTimer.start();
        }
    }

    function processNextQueueItem() {
        if (!battleQueue.length) {
            queueProcessing = false;
            disposeQueuePromise();
            return;
        }

        activeQueueItem = battleQueue.shift();
        queueItemStarted(activeQueueItem);
        const promiseInstance = initializeQueuePromise();
        if (!promiseInstance) {
            finishActiveQueueItem({ error: "promise_init_failed" });
            return;
        }

        if (activeQueueItem.start_function && typeof activeQueueItem.start_function === "function") {
            try {
                activeQueueItem.start_function(root, activeQueueItem);
            } catch (err) {
                console.warn("BattleGrid: start_function error", err);
            }
        }

        const runEnd = function(context) {
            const endContext = context === undefined ? {} : context;
            if (activeQueueItem && typeof activeQueueItem.end_function === "function") {
                try {
                    activeQueueItem.end_function(root, activeQueueItem, endContext);
                } catch (err) {
                    console.warn("BattleGrid: end_function error", err);
                }
            } else {
                finishActiveQueueItem(endContext);
            }
        };

        const handleMainCompletion = function(context) {
            runEnd(context);
        };

        const executeMain = function() {
            if (!activeQueueItem.main_function || typeof activeQueueItem.main_function !== "function") {
                handleMainCompletion({ warning: "no_main_function" });
                return;
            }

            let mainResult;
            try {
                mainResult = activeQueueItem.main_function(root, activeQueueItem);
            } catch (err) {
                console.warn("BattleGrid: main_function error", err);
                handleMainCompletion({ error: err });
                return;
            }

            if (isPromiseLike(mainResult)) {
                mainResult.then(function(value) {
                    handleMainCompletion({ result: value });
                }, function(reason) {
                    console.warn("BattleGrid: main_function promise rejected", reason);
                    handleMainCompletion({ error: reason });
                });
            } else {
                handleMainCompletion(mainResult);
            }
        };

        executeMain();
    }

    function handleCurrentStateChanged(newState, oldState) {
        switch (newState) {
        default:
            break;
        }
    }

    function enqueueInitialStateBootstrap() {
        if (battleStateMachine) {
            battleStateMachine.enqueueInitialStateBootstrap();
            return;
        }

        enqueueBattleEvent({
            name: "state-init",
            start_function: function(grid, item) {
                grid.setState("init", { source: item.name });
            },
            end_function: function(grid) {
                grid.enqueueInitializationTransition();
                grid.finishActiveQueueItem({ state: "init" });
            }
        });
    }

    function enqueueInitializationTransition() {
        if (battleStateMachine) {
            battleStateMachine.enqueueInitializationTransition();
            return;
        }

        enqueueBattleEvent({
            name: "state-initializing",
            start_function: function(grid, item) {
                grid.setState("initializing", { source: item.name });
            },
            main_function: function(grid) {
                const initPromise = grid.createInitializationPromise();
                if (!initPromise)
                    return null;

                // TODO: Replace stub resolution with real powerup data signal.
                initPromise.resolve({ powerups: [] });
                return initPromise;
            },
            end_function: function(grid, item, context) {
                const payload = context && context.result ? context.result : context;
                grid.resetInitializationPromise();
                if (!grid.stateMachineManagedInitialization)
                    grid.enqueueInitializedState(payload);
                grid.finishActiveQueueItem({ state: "initializing_complete", payload: payload });
            }
        });
    }

    function enqueueInitializedState(payload) {
        if (battleStateMachine) {
            battleStateMachine.enqueueInitializedState(payload);
            return;
        }

        enqueueBattleEvent({
            name: "state-initialized",
            payload: payload,
            start_function: function(grid, item) {
                grid.setState("initialized", { source: item.name, payload: item.payload });
            },
            main_function: function(grid, item) {
                return item.payload || {};
            },
            end_function: function(grid, item, context) {
                const summary = context && context.result ? context.result : context;
                grid.finishActiveQueueItem({ state: "initialized", payload: summary });
            }
        });
    }

    // NOTE: GameScene should connect its powerup data ready signal to this handler.
    function handleInitialPowerupDataLoaded(powerupData) {
        if (!initializationPromise)
            return;
        initializationPromise.resolve(powerupData);
    }

    function isPromiseLike(value) {
        return value && (typeof value.then === "function");
    }

    // Components for factory injection
    Component { id: dragComp;  Engine.GameDragItem { } }
    Component { id: blockComp; UI.Block { } }

    // Your model. Could be ListModel, JS array, or C++ model.
    ListModel {
        id: blocksModel
        // 36 entries for 6x6, but do whatever
        Component.onCompleted: {
            fillGrid();
        }
    }
    Grid {
        anchors.fill: parent
        rows: 6
        columns: 6
        flow: Grid.TopToBottom
        layoutDirection: Qt.RightToLeft
        move: Transition {
            NumberAnimation { properties: "x,y"; duration: 1000
            }
        }
        Repeater {
            id: blockRepeater
            model: blocksModel

             Engine.GameDragItem {
                required property var model
                required property var index
                property var rootObject: root
                property var blocksModel: root.blocksModel
                property string blockId: model.blockId
                id: delegate

                gameScene: root.gameScene
                itemName: "block_dragItem_" + blockId
                width: 64
                height: 64
                x: 0
                y: 0
                z: 4

                entry:  blockEntry
                payload: ["itemName"]
                property int myIndex: index






                UI.Block {
                    id: blockEntry
                    blockColor: model.color
                    itemName: delegate.blockId
                    gameScene: root.gameScene
                    width: 64
                    height: 64
                    row: model.row
                    column: model.column
                    maxRows: root.gridRows
                    onBlockStateChanged: {
                        if (blockState === "destroyed") {
                            delegate.entry.blockDestroyed(itemName);
                        }
                    }
                }

                Component.onCompleted: {
                    delegate.rootObject.gameScene.addSceneDragItem(delegate.itemName, delegate);
                }

                Text {


                    id: debugText
                    text: "" + index + ""
                }

            }
        }
    }


    function getBlockEntryAt(row, column) {
        if (row < 0 || row >= gridRows || column < 0 || column >= gridCols)
            return null;

        const index = (column * gridRows) + row;
        const block = blockRepeater.itemAt(index);
        return block ? block.entry : null;
    }
    function getBlockWrapper(row, column) {
        if (row < 0 || row >= gridRows || column < 0 || column >= gridCols)
            return null;

        const index = (column * gridRows) + row;
        const block = blockRepeater.itemAt(index);
        return block ? block : null;
    }
    function composeBlockDescriptor(row, column, targetIndex) {
        const palette = blockPalette || [];
        const paletteSize = palette.length;
        const fallbackColor = paletteSize > 0 ? palette[0] : "red";
        const paletteIndex = paletteSize > 0 ? Math.floor(Math.random() * paletteSize) : 0;
        const chosenColor = paletteSize > 0 ? palette[paletteIndex] : fallbackColor;

        blockSequence += 1;

        return {
            __index: targetIndex,
            blockId: blockIdPrefix + "_" + blockSequence,
            row: row,
            column: column,
            color: chosenColor
        };
    }

    function scheduleBlockForPosition(row, column, pendingDescriptors) {
        const targetIndex = indexFor(row, column);
        if (targetIndex < 0)
            return;

        if (getBlockWrapper(row, column))
            return;

        if (targetIndex < blocksModel.count) {
            const existingEntry = blocksModel.get(targetIndex);
            if (existingEntry && existingEntry.row === row && existingEntry.column === column)
                return;
        }

        const descriptor = composeBlockDescriptor(row, column, targetIndex);
        if (!descriptor)
            return;

        pendingDescriptors.push(descriptor);
    }

    function fillGrid() {
        console.log("Filling Grid Model", blocksModel);

        const pendingDescriptors = [];

        for (var row = gridRows - 1; row >= 0; --row) {
            for (var column = 0; column < gridCols; ++column) {
                scheduleBlockForPosition(row, column, pendingDescriptors);
            }
        }

        if (!pendingDescriptors.length)
            return;

        pendingDescriptors.sort(function(a, b) {
            return a.__index - b.__index;
        });

        for (var i = 0; i < pendingDescriptors.length; ++i) {
            const descriptor = pendingDescriptors[i];
            const insertionIndex = descriptor.__index <= blocksModel.count
                    ? descriptor.__index
                    : blocksModel.count;

            const payload = {
                blockId: descriptor.blockId,
                row: descriptor.row,
                column: descriptor.column,
                color: descriptor.color
            };

            if (insertionIndex === blocksModel.count) {
                blocksModel.append(payload);
            } else {
                blocksModel.insert(insertionIndex, payload);
            }
        }
    }



    function indexFor(row, column) {
        if (row < 0 || column < 0)
            return -1;
        return (column * gridRows) + row;
    }

    function findModelIndexByItemName(blockId) {
        for (var i = 0; i < blocksModel.count; i++) {
            const element = blocksModel.get(i);
            if (element.blockId === blockId)
                return i;
        }
        return -1;
    }

    function findWrapperByItemName(blockId) {
        for (var i = 0; i < blockRepeater.count; i++) {
            const wrapper = blockRepeater.itemAt(i);
            if (wrapper && wrapper.entry && wrapper.entry.itemName === blockId)
                return wrapper;
        }
        return null;
    }

}
