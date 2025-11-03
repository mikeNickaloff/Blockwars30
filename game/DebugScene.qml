import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import "../engine" as Engine
import "../lib" as Lib
import "ui" as UI
import "factory.js" as Factory
Engine.GameScene {
    id: debugScene
    anchors.fill: parent
    property var blocks: []
    property alias checkRefillTimer: checkRefillTimer
    property var currentTurn: "top"
    property var turnsLeft: 3
    property var turnCoordinator: ({ offense: null, defense: null })

   onCurrentTurnChanged: handleTurnSwitch()

    function getBattleGridOffense() {

        if (currentTurn == "top") { return battleGrid_top } else { return battleGrid_bottom }
    }
    function getBattleGridDefense() {
           if (currentTurn == "top") { return battleGrid_bottom } else { return battleGrid_top }
    }

    function receiveBattleGridLaunchPayload(payload) {
        if (!payload || !payload.battleGrid)
            return;
        console.log("received launch payload", JSON.stringify(payload))
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

        targetBattleGrid.calculateLaunchDamage(payload);
    }

    function forwardBlockLaunchEndPoint(payload, endX, endY) {
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
            console.log("launching to position", entry.y);
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
        if (battleGrid_top && typeof battleGrid_top.requestState === "function")
            battleGrid_top.requestState("compact");
        if (battleGrid_bottom && typeof battleGrid_bottom.requestState === "function")
            battleGrid_bottom.requestState("wait");
    }
    Engine.GameDropItem {
        id: dropItem
        itemName: "drop_item"
        gameScene: debugScene
        width: 200
        height: 200
        x: 100
        y: 100
        entry: blueRect


        Rectangle {
            id: blueRect
            color: "blue"
            width: 200
            height: 200
        }
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
    console.log("drag item dropped nowhere")
        var dragItem = getSceneItem(itemName);
    function snapItemToGrid(item, row, col) {
        var grid = getBattleGridOffense();
        item.x = grid.cellPosition(row, col).x
        item.y = grid.cellPosition(row, col).y

    }
    snapItemToGrid(dragItem, dragItem.entry.row, dragItem.entry.column)
}
    onItemDroppedInNonDropArea: function(dragItemName, dropItemName, startx, starty, endx, endy) {
        function snapItemToGrid(item, row, col) {
                var bg = getBattleGridOffense();
            item.x = bg.cellPosition(row, col).x
            item.y = bg.cellPosition(row, col).y


        }

        var dragItem = getSceneItem(dragItemName);
        var dropItem = getSceneItem(dropItemName)
        if (dragItem.entry.battleGrid !== getBattleGridOffense()) { snapItemToGrid(dragItem, dragItem.entry.row, dragItem.entry.col); return }
        if (dropItem.entry.battleGrid !== getBattleGridOffense()) { snapItemToGrid(dragItem, dragItem.entry.row, dragItem.entry.col); return }

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

            dragItem.entry.row = row2
            dragItem.entry.column = col2
            dropItem.entry.row = row1
            dropItem.entry.column = col1
            snapItemToGrid(dragItem, row2, col2)
            snapItemToGrid(dropItem, row1, col1)

            console.log("got valid swap  -- ",dragItemName, dropItemName, startx, starty, endx, endy)
            var bg = getBattleGridOffense();
            bg.blockMatrix[row1][col1] = dropItem
            bg.blockMatrix[row2][col2] = dragItem
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
                console.log("turn switched to",currentTurn);
                postSwapCascadeCheckTimer.running = false;
                if (newbg && typeof newbg.requestState === "function")
                    newbg.requestState("compact");
                if (bg && typeof bg.requestState === "function")
                    bg.requestState("wait");
            }
        }
    }

    onItemEnteredNonDropArea: {
        console.log("item dragged and entered non-drop area", dragItemName, dropItemName)
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
                    console.log("got last block launched, connecting destroyed state change to fill timer");
                    var grid = getBattleGridOffense();
                    if (grid && typeof grid.requestState === "function")
                        grid.requestState("compact");
                }

           }

        }
    }
    Engine.GameDynamicItem {
        itemName: "test_button"
        gameScene: debugScene
        Button {
            text: "click here"
            width: 200
            height: 200
            x: 300
            y: 300
            onClicked: function(evt) {
                console.log(debugScene.getSceneItem("test_button"), debugScene.getSceneItem("test_rect"))

                launchTimer.running = true
                var new_blocks = [];
                var activeGrid = getBattleGridOffense();
                console.log(activeGrid ? activeGrid.currentState : "unknown state")
                if (!activeGrid)
                    return;
                for (var i=0; i<17; i++) {
                    var r = Math.floor(Math.random() * 5);
                    var c = Math.floor(Math.random() * 5);
                    var blk = activeGrid.getBlockEntryAt(r,c)
                    var wrapper = activeGrid.getBlockWrapper(r, c)
                    wrapper.animationDurationX = 60
                    wrapper.animationDurationY = 360

                    debugScene.blocks.push(wrapper);
               // }
                }
            }
        }
    }

    UI.BattleGrid {
        id:battleGrid_top
        width: 300
        height: 300
        x: 200
        y: 0
        gameScene: debugScene

        launchDirection: "down"
        uuid: "top"
        Component.onCompleted: {

        }
    }

    UI.BattleGrid {
        id:battleGrid_bottom
        width: 300
        height: 300
        x: 200
        y: 400
        gameScene: debugScene
        uuid: "bottom"
        launchDirection: "up"

        Component.onCompleted: {

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
    }










    Component {
            id: dragComp
            Engine.GameDragItem { }   // has required: gameScene, itemName, entry
        }

        Component {
            id: blockComp
            UI.Block { }              // has blockColor, itemName, gameScene...
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
