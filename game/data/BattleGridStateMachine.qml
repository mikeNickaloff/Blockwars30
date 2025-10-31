import QtQml 2.15
import "../../engine" as Engine

Engine.GameStateMachine {
    id: battleGridStateMachineTemplate

    property var battleGrid: null
    property bool autoAttach: true

    function configureMachine(machine) {
        machine.battleGrid = machine.battleGrid || battleGrid || null
        machine.managedStates = []
        machine.topologyRegistered = false
        machine.initializationTransitionRequested = false
        machine.initializedTransitionDispatched = false
        machine.bootstrapCompleted = false
        machine.pendingInitializationSummary = null
        machine.stateConnections = machine.stateConnections || null
        machine.initializationTransitionId = -1
        machine.initializationCompletionTransitionId = -1

        machine.collectManagedStates = function() {
            var states = []
            var grid = machine.battleGrid
            if (grid && grid.stateList && typeof grid.stateList.length === "number") {
                for (var idx = 0; idx < grid.stateList.length; ++idx)
                    states.push(grid.stateList[idx])
            }
            if (states.indexOf("init") === -1)
                states.push("init")
            if (states.indexOf("initializing") === -1)
                states.push("initializing")
            if (states.indexOf("initialized") === -1)
                states.push("initialized")
            return states
        }

        machine.resetRuntimeFlags = function() {
            machine.initializationTransitionRequested = false
            machine.initializedTransitionDispatched = false
            machine.bootstrapCompleted = false
            machine.pendingInitializationSummary = null
        }

        machine.ensureConnections = function() {
            if (!machine.battleGrid)
                return

            if (!machine.stateConnections) {
                machine.stateConnections = Qt.createQmlObject(
                            'import QtQml 2.15; Connections { id: stateConnections; ignoreUnknownSignals: true }',
                            machine,
                            "BattleGridStateMachineConnections")
                machine.stateConnections.onStateTransitionFinished = function(fromState, toState, metadata) {
                    machine.handleStateTransitionFinished(fromState, toState, metadata)
                }
                machine.stateConnections.onQueueItemCompleted = function(item, context) {
                    machine.handleQueueItemCompletion(item, context)
                }
            }

            machine.stateConnections.target = machine.battleGrid
        }

        machine.detachGrid = function() {
            if (machine.stateConnections) {
                machine.stateConnections.target = null
                machine.stateConnections.destroy()
                machine.stateConnections = null
            }

            if (machine.battleGrid) {
                try {
                    machine.battleGrid.stateMachineManagedInitialization = false
                } catch (err) {
                }
            }

            machine.reset()
            machine.battleGrid = null
            machine.managedStates = []
            machine.resetRuntimeFlags()
            machine.topologyRegistered = false
        }

        machine.registerDefaultTransitions = function() {
            if (!machine.managedStates.length)
                machine.managedStates = machine.collectManagedStates()

            machine.addStates(machine.managedStates)
            machine.clearStateTransitions("init")
            machine.clearStateTransitions("initializing")

            machine.initializationTransitionId = machine.addStateTransition(
                        "init",
                        machine.evaluateInitializationRequest,
                        "initializing",
                        { metadata: { reason: "bootstrap" } })

            machine.initializationCompletionTransitionId = machine.addStateTransition(
                        "initializing",
                        machine.evaluateInitializationCompletion,
                        "initialized",
                        { metadata: { reason: "initialization" } })

            machine.topologyRegistered = true
        }

        machine.attachGrid = function(newGrid) {
            if (machine.battleGrid === newGrid)
                return

            machine.detachGrid()

            if (!newGrid)
                return

            machine.battleGrid = newGrid
            machine.reset()
            machine.bindContext(newGrid, "currentState")
            machine.managedStates = machine.collectManagedStates()
            machine.registerDefaultTransitions()
            machine.resetRuntimeFlags()
            machine.ensureConnections()
            machine.battleGrid.stateMachineManagedInitialization = true
            machine.enqueueInitialStateBootstrap()
        }

        machine.evaluateInitializationRequest = function(contextInstance) {
            if (!machine.battleGrid)
                return false
            if (machine.initializationTransitionRequested)
                return false
            if (contextInstance.stateTransitionInProgress)
                return false

            machine.initializationTransitionRequested = true
            return true
        }

        machine.evaluateInitializationCompletion = function(contextInstance) {
            if (!machine.battleGrid)
                return false
            if (!machine.pendingInitializationSummary)
                return false
            if (machine.initializedTransitionDispatched)
                return false
            if (contextInstance.stateTransitionInProgress)
                return false

            return true
        }

        machine.evaluateTransitions = function() {
            if (!machine.battleGrid || !machine.bootstrapCompleted)
                return
            machine.checkTransitions()
        }

        machine.enqueueInitialStateBootstrap = function() {
            var grid = machine.battleGrid
            if (!grid)
                return

            grid.enqueueBattleEvent({
                name: "state-init",
                start_function: function(target, item) {
                    target.setState("init", { source: item.name })
                },
                end_function: function(target) {
                    target.finishActiveQueueItem({ state: "init" })
                }
            })
        }

        machine.enqueueInitializationTransition = function() {
            var grid = machine.battleGrid
            if (!grid)
                return

            grid.enqueueBattleEvent({
                name: "state-initializing",
                start_function: function(target, item) {
                    target.setState("initializing", { source: item.name })
                },
                main_function: function(target) {
                    var initPromise = target.createInitializationPromise()
                    if (!initPromise)
                        return null

                    // Hook resolution to store payload for completion handler.
                    initPromise.then(function(value) {
                        machine.pendingInitializationSummary = value
                    }, function(reason) {
                        machine.pendingInitializationSummary = reason
                    })

                    if (typeof initPromise.resolve === "function")
                        initPromise.resolve({ powerups: [] })

                    return initPromise
                },
                end_function: function(target, item, context) {
                    var payload = context && context.result ? context.result : context
                    target.resetInitializationPromise()
                    if (!target.stateMachineManagedInitialization)
                        machine.enqueueInitializedState(payload)
                    machine.pendingInitializationSummary = payload
                    target.finishActiveQueueItem({ state: "initializing_complete", payload: payload })
                }
            })
        }

        machine.enqueueInitializedState = function(payload) {
            var grid = machine.battleGrid
            if (!grid)
                return

            grid.enqueueBattleEvent({
                name: "state-initialized",
                payload: payload,
                start_function: function(target, item) {
                    target.setState("initialized", { source: item.name, payload: item.payload })
                },
                main_function: function(target, item) {
                    return item.payload || {}
                },
                end_function: function(target, item, context) {
                    var summary = context && context.result ? context.result : context
                    target.finishActiveQueueItem({ state: "initialized", payload: summary })
                }
            })
        }

        machine.handleTransition = function(previousState, nextState) {
            if (!machine.battleGrid)
                return

            switch (nextState) {
            case "initializing":
                machine.enqueueInitializationTransition()
                break
            case "initialized":
                machine.initializedTransitionDispatched = true
                var initializationPayload = machine.pendingInitializationSummary || {}
                machine.pendingInitializationSummary = null
                machine.enqueueInitializedState(initializationPayload)
                break
            default:
                break
            }
        }

        machine.handleQueueItemCompletion = function(queueItem, completionContext) {
            if (!machine.battleGrid)
                return

            var contextState = completionContext ? completionContext.state : ""
            if (contextState === "init") {
                machine.bootstrapCompleted = true
                machine.initializationTransitionRequested = false
                machine.evaluateTransitions()
            } else if (contextState === "initializing_complete") {
                machine.pendingInitializationSummary = completionContext.payload || completionContext.result || {}
                machine.initializedTransitionDispatched = false
                machine.evaluateTransitions()
            }
        }

        machine.handleStateTransitionFinished = function(fromState, toState, metadata) {
            if (!machine.battleGrid)
                return

            if (toState === "init") {
                machine.initializationTransitionRequested = false
                machine.initializedTransitionDispatched = false
            }

            machine.evaluateTransitions()
        }

        machine.destroyed.connect(function() {
            machine.detachGrid()
        })

        try {
            machine.transitionToNewState.disconnect(machine.handleTransition)
        } catch (err) {
        }
        machine.transitionToNewState.connect(machine.handleTransition)

        if (machine.battleGrid && autoAttach)
            machine.attachGrid(machine.battleGrid)
    }

    Component.onCompleted: function(object) {
        if (!object)
            return

        configureMachine(object)
    }
}
