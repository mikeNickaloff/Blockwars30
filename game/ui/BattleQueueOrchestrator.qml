import QtQuick 2.15

Item {
    id: orchestrator

    property var owner: null
    property var queue: []
    property bool processing: false
    property var activeItem: null
    property var activeContext: ({ completed: false, deferred: false })
    property int tickInterval: 4

    signal queueItemStarted(var item)
    signal queueItemCompleted(var item, var context)

    Timer {
        id: queueTimer
        interval: Math.max(1, orchestrator.tickInterval)
        repeat: false
        running: false
        onTriggered: orchestrator.executeNext()
    }

    function enqueue(item) {
        if (!item)
            return
        queue.push(item)
        schedule()
    }

    function schedule() {
        if (processing)
            return
        if (!queue.length)
            return
        if (!queueTimer.running)
            queueTimer.start()
    }

    function executeNext() {
        if (processing)
            return
        if (!queue.length)
            return

        activeItem = queue.shift()
        processing = true
        activeContext = { completed: false, deferred: false }

        var target = owner ? owner : orchestrator
        var item = activeItem

        queueItemStarted(item)

        try {
            if (typeof item.start_function === "function")
                item.start_function(target, item)
        } catch (err) {
            console.warn("BattleQueueOrchestrator: start error", err)
        }

        var mainResult
        var mainErrored = false
        try {
            if (typeof item.main_function === "function")
                mainResult = item.main_function(target, item)
        } catch (err) {
            mainErrored = true
            console.warn("BattleQueueOrchestrator: main error", err)
            mainResult = { error: err }
        }

        if (mainErrored) {
            finishActiveItem(mainResult)
            return
        }

        if (item.deferCompletion || activeContext.deferred)
            return

        if (isPromiseLike(mainResult)) {
            mainResult.then(function(value) {
                finishActiveItem({ result: value })
            }, function(reason) {
                finishActiveItem({ error: reason })
            })
            return
        }

        finishActiveItem(mainResult)
    }

    function deferActiveItem() {
        if (!processing || !activeItem)
            return null
        if (!activeContext)
            activeContext = { completed: false, deferred: false }
        activeContext.deferred = true
        return activeItem
    }

    function finishActiveItem(context) {
        if (!processing || !activeItem)
            return
        if (activeContext && activeContext.completed)
            return

        activeContext.completed = true

        var target = owner ? owner : orchestrator
        var item = activeItem
        var payload = context === undefined ? {} : context

        try {
            if (typeof item.end_function === "function")
                item.end_function(target, item, payload)
        } catch (err) {
            console.warn("BattleQueueOrchestrator: end error", err)
        }

        queueItemCompleted(item, payload)

        activeItem = null
        processing = false

        if (queue.length)
            queueTimer.start()
    }

    function isPromiseLike(value) {
        return value && typeof value.then === "function"
    }
}
