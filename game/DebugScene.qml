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
    battleGrid.fillGrid()
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
        interval: 1000
        repeat: false
        triggeredOnStart: false
        running: false
        onTriggered: {
            if (battleGrid.currentState == "init") {
                battleGrid.currentState = "compact"
                return
            }

            if (battleGrid.currentState == "launched") {
                battleGrid.currentState = "compact"
                return
            }
            if (battleGrid.currentState == "compacted") {
                battleGrid.currentState = "fill"
                return
            }
            if (battleGrid.currentState == "filled") {
                battleGrid.currentState = "match"
                return
            }
            if (battleGrid.currentState == "matched") {
                battleGrid.currentState = "launch"
                return
            }



            //battleGrid.fillGrid();
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
                console.log(battleGrid.currentState)
                //if (battleGrid.currentState == "init") {
                for (var i=0; i<16; i++) {
                    var r = Math.floor(Math.random() * 5);
                    var c = Math.floor(Math.random() * 5);
                    var blk = battleGrid.getBlockEntryAt(r,c)
                    var wrapper = battleGrid.getBlockWrapper(r, c)
                    wrapper.animationDurationX = 60
                    wrapper.animationDurationY = 360

                    debugScene.blocks.push(wrapper);
               // }
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

        launchDirection: "up"

        Component.onCompleted: {

        }
        onWrapperLaunched: function(wrapperItem) {
               launchTimer.running = false
            wrapperItem.animationDurationX = 60
            wrapperItem.animationDurationY = 360
            wrapperItem.y += 400
        }
    }



    Item {
        width: 600
        height: 600

        Repeater {
            model: 15
            delegate: Rectangle {
                required property var index
                required property var model
                PathInterpolator {

                      id: motionPath
                      progress: index / 15



                      NumberAnimation on progress {

                          from: index / 15
                          to: 1.0
                          running: true
                          duration: 3000
                          loops: NumberAnimation.Infinite
                      }

                      path: Path {
                    startX: 100; startY: 100

                    PathArc {
                        x: 300; y: 300
                        radiusX: 200 - (10 * index); radiusY: 200 - (10 * index)
                        useLargeArc: true

                    }
                }
                }

                Component.onCompleted: {
                   // motionPath.progressChanged.connect(delegate.updateProgress)
                }
                function updateProgress(new_prog) {
                    /* motionPath.progress += 0.1
                    if (motionPath.progress >= 1.0)  { motionPath.progress = 0 }
                    delegate.x = motionPath.x
                    delegate.y =motionPath.y */

                }
                id: delegate

                color: Math.random() < 0.33 ? "red" : (Math.random() < 0.66) ? "blue" : "yellow"
                x: motionPath.x
                y: motionPath.y
                Behavior on x { NumberAnimation { duration: 3000 } }
                Behavior on y { NumberAnimation { duration: 3000 } }
                width: height
                height: 40
                z: 20
                transformOrigin: Item.Center

            }


            }


    }


    Item {
        id: colorRing
        width: 280
        height: 280
        anchors.centerIn: parent
        property var colorChoices: ["red", "blue", "green", "yellow"]
        property real angleOffset: 0
        readonly property int itemCount: 15
        readonly property real radius: Math.min(width, height) / 2 - 24

        NumberAnimation on angleOffset {
            from: 0
            to: 2 * Math.PI
            duration: 8000
            loops: Animation.Infinite
            easing.type: Easing.Linear
            running: true
        }

        Repeater {
            model: colorRing.itemCount
            delegate: Rectangle {
                readonly property real angle: (2 * Math.PI / colorRing.itemCount) * index + colorRing.angleOffset
                readonly property color rectColor: colorRing.colorChoices[Math.floor(Math.random() * colorRing.colorChoices.length)]
                width: 32
                height: 32
                color: rectColor
                radius: 6
                x: colorRing.width / 2 + colorRing.radius * Math.cos(angle) - width / 2
                y: colorRing.height / 2 + colorRing.radius * Math.sin(angle) - height / 2
            }
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
