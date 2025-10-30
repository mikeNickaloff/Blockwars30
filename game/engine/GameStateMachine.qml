import QtQml 2.15

QtObject {
    id: machine

    signal transitionToNewState(string previousState, string nextState)

    property alias contextObject: binding.contextObject
    property alias contextStateProperty: binding.stateProperty

    function bindContext(contextInstance, statePropertyName) {
        binding.bindContext(contextInstance, statePropertyName)
    }

    function addState(stateName) {
        return registry.defineState(stateName)
    }

    function addStateTransition(startState, evaluationHandler, destinationState) {
        return registry.registerTransition(startState, evaluationHandler, destinationState)
    }

    function removeStateTransition(startState, transitionId) {
        return registry.removeTransition(startState, transitionId)
    }

    function listStateTransitions(startState) {
        return registry.describeTransitions(startState)
    }

    function checkTransitions() {
        if (!binding.isReady())
            return false

        var activeState = binding.currentState()
        if (!registry.hasState(activeState))
            return false

        return registry.evaluateTransitions(activeState, binding.contextObject, function(targetState) {
            machine.transitionToNewState(activeState, targetState)
        })
    }

    QtObject {
        id: binding

        property var contextObject: null
        property string stateProperty: ""

        readonly property string errorMessageMissingProperty: "GameStateMachine binding requires a state property name"
        readonly property string errorMessageMissingContext: "GameStateMachine binding requires a context object"

        function bindContext(contextInstance, statePropertyName) {
            if (!contextInstance)
                throw new Error(errorMessageMissingContext)

            if (!statePropertyName || typeof statePropertyName !== "string")
                throw new Error(errorMessageMissingProperty)

            contextObject = contextInstance
            stateProperty = statePropertyName
        }

        function currentState() {
            if (!contextObject || !stateProperty)
                return ""

            var value = contextObject[stateProperty]
            return value === undefined || value === null ? "" : value
        }

        function isReady() {
            return !!contextObject && !!stateProperty
        }
    }

    QtObject {
        id: registry

        property var stateStore: ({})
        property int transitionCounter: 0

        readonly property string errorMessageStateName: "State names must be non-empty strings"
        readonly property string errorMessageTransitionHandler: "Transition predicate must be a function"

        function hasState(stateName) {
            return !!stateStore[stateName]
        }

        function defineState(stateName) {
            if (!stateName || typeof stateName !== "string")
                throw new Error(errorMessageStateName)

            if (!stateStore[stateName])
                stateStore[stateName] = []

            return true
        }

        function registerTransition(startState, evaluationHandler, destinationState) {
            defineState(startState)
            defineState(destinationState)

            if (typeof evaluationHandler !== "function")
                throw new Error(errorMessageTransitionHandler)

            var transitionId = ++transitionCounter
            var transition = transitionComponent.createObject(machine, {
                identifier: transitionId,
                predicate: evaluationHandler,
                targetState: destinationState
            })

            stateStore[startState].push(transition)
            return transitionId
        }

        function removeTransition(startState, transitionId) {
            var transitions = stateStore[startState]
            if (!transitions)
                return false

            for (var idx = transitions.length - 1; idx >= 0; --idx) {
                var candidate = transitions[idx]
                if (candidate.identifier === transitionId) {
                    transitions.splice(idx, 1)
                    candidate.destroy()
                    return true
                }
            }
            return false
        }

        function describeTransitions(startState) {
            var transitions = stateStore[startState]
            if (!transitions)
                return []

            var descriptions = []
            for (var idx = 0; idx < transitions.length; ++idx) {
                var transition = transitions[idx]
                descriptions.push({
                    id: transition.identifier,
                    newState: transition.targetState,
                    hasPredicate: typeof transition.predicate === "function"
                })
            }
            return descriptions
        }

        function evaluateTransitions(startState, contextInstance, transitionCallback) {
            var transitions = stateStore[startState]
            if (!transitions || transitions.length === 0)
                return false

            for (var idx = 0; idx < transitions.length; ++idx) {
                var transition = transitions[idx]
                if (transition.evaluate(contextInstance, startState)) {
                    transitionCallback(transition.targetState, transition.identifier)
                    return true
                }
            }
            return false
        }
    }

    Component {
        id: transitionComponent
        QtObject {
            property int identifier: -1
            property var predicate: null
            property string targetState: ""

            readonly property string errorMessageEvaluation: "GameStateMachine transition predicate threw an error"

            function evaluate(contextInstance, sourceStateName) {
                if (typeof predicate !== "function")
                    return false

                try {
                    return !!predicate.call(contextInstance, contextInstance, sourceStateName)
                } catch (evaluationError) {
                    console.error(errorMessageEvaluation, evaluationError)
                    return false
                }
            }
        }
    }
}
