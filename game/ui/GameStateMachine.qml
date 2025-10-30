import QtQml 2.15
import "../engine" as Engine

Engine.GameStateMachine {
    id: coordinator

    property var battleGrid: null

    readonly property var managedStates: ["init", "initializing", "initialized"]

    property bool topologyRegistered: false
    property bool initializationTransitionRequested: false
    property bool initializedTransitionDispatched: false
    property bool bootstrapCompleted: false
    property var pendingInitializationSummary: null
    property var attachedGrid: null

    function attachGrid(newGrid) {
        if (attachedGrid === newGrid)
            return;

        if (attachedGrid) {
            attachedGrid.stateMachineManagedInitialization = false;
        }

        attachedGrid = newGrid;

        if (!attachedGrid)
            return;

        attachedGrid.stateMachineManagedInitialization = true;
        bindContext(attachedGrid, "currentState");
        ensureTopology();
        resetRuntimeFlags();
    }

    function resetRuntimeFlags() {
        initializationTransitionRequested = false;
        initializedTransitionDispatched = false;
        bootstrapCompleted = false;
        pendingInitializationSummary = null;
    }

    function ensureTopology() {
        if (topologyRegistered)
            return;

        for (var idx = 0; idx < managedStates.length; ++idx)
            addState(managedStates[idx]);

        addStateTransition("init", evaluateInitializationRequest, "initializing");
        addStateTransition("initializing", evaluateInitializationCompletion, "initialized");

        topologyRegistered = true;
    }

    function evaluateInitializationRequest(contextInstance) {
        if (!attachedGrid)
            return false;
        if (initializationTransitionRequested)
            return false;
        if (contextInstance.stateTransitionInProgress)
            return false;

        initializationTransitionRequested = true;
        return true;
    }

    function evaluateInitializationCompletion(contextInstance) {
        if (!attachedGrid)
            return false;
        if (!pendingInitializationSummary)
            return false;
        if (initializedTransitionDispatched)
            return false;
        if (contextInstance.stateTransitionInProgress)
            return false;

        return true;
    }

    function evaluateTransitions() {
        if (!attachedGrid || !bootstrapCompleted)
            return;
        checkTransitions();
    }

    onBattleGridChanged: attachGrid(battleGrid)

    onTransitionToNewState: handleTransition(previousState, nextState)

    function handleTransition(previousState, nextState) {
        if (!attachedGrid)
            return;

        switch (nextState) {
        case "initializing":
            attachedGrid.enqueueInitializationTransition();
            break;
        case "initialized":
            initializedTransitionDispatched = true;
            var initializationPayload = pendingInitializationSummary || {};
            pendingInitializationSummary = null;
            attachedGrid.enqueueInitializedState(initializationPayload);
            break;
        }
    }

    function handleQueueItemCompletion(queueItem, completionContext) {
        if (!attachedGrid)
            return;

        var contextState = completionContext ? completionContext.state : "";
        if (contextState === "init") {
            bootstrapCompleted = true;
            initializationTransitionRequested = false;
            evaluateTransitions();
        } else if (contextState === "initializing_complete") {
            pendingInitializationSummary = completionContext.payload || completionContext.result || {};
            initializedTransitionDispatched = false;
            evaluateTransitions();
        }
    }

    function handleStateTransitionFinished(fromState, toState) {
        if (!attachedGrid)
            return;

        if (toState === "init") {
            initializationTransitionRequested = false;
            initializedTransitionDispatched = false;
        }

        evaluateTransitions();
    }

    Connections {
        target: battleGrid
        ignoreUnknownSignals: true
        onStateTransitionFinished: handleStateTransitionFinished(fromState, toState)
        onQueueItemCompleted: handleQueueItemCompletion(item, context)
    }

    Component.onDestruction: {
        if (attachedGrid) {
            attachedGrid.stateMachineManagedInitialization = false;
        }
    }
}
