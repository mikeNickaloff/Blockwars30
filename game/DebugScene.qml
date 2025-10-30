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
        /*addSceneDragItem("test_rect", test_rect)
        addSceneDragItem("test_rect2", test_rect2)
        addSceneDropItem("drop_item", dropItem);
        for (var i=0; i<36; i++) {
            var blk = createBlock("green");
            blk.x = i % 6 * 64
            blk.animationDurationX = 60
            blk.animationDurationY = 60
            blk.entryDestroyed.connect(removeSceneItem)
            debugScene.blocks.push(blk);
        } */

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
        interval: 4000
        repeat: false
        triggeredOnStart: false
        running: false
        onTriggered: {
            battleGrid.fillGrid();
        }
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
                     checkRefillTimer.running = true;
                     checkRefillTimer.restart();
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

                for (var i=0; i<8; i++) {
                    var blk = battleGrid.getBlockEntryAt(((i * 2) % 6), Math.floor((i * 2) / 6))
                    var wrapper = battleGrid.getBlockWrapper(((i * 2) % 6), Math.floor((i * 2) / 6))
                    wrapper.animationDurationX = 60
                    wrapper.animationDurationY = 360

                    debugScene.blocks.push(wrapper);
                }
            }
        }
    }

    UI.BattleGrid {
        id:battleGrid
        width: 300
        height: 300
        x: 100
        y: 200
        gameScene: debugScene


        Component.onCompleted: {

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
