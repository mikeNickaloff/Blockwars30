import QtQuick
import QtQuick.Layouts
import QtQml
import "../../engine" as Engine
import "../../lib" as Lib
import "." as UI
Item {
    id: blockRoot

    property var blockColor
    property alias source: blockLoader.source
    width: 92
    height: 92

    property var gameScene
    property var itemName
    property int row: -1
    property int column: -1
    property int maxRows: 0
    property var blockState: "init"

    property Component launchComponent: blockLaunchComponent
    property Component idleComponent: blockIdleComponent
    property Component explodeComponent: blockExplodeComponent
    property var lowerBlockRefs: []

    signal blockDestroyed(var itemName)


    Component.onCompleted: {
        blockRoot.blockState = "idle"
        console.log("block instance created")
    }
    onBlockStateChanged: {
        console.log("block state set to",blockState);
        if (blockState == "launch") {
            blockLoader.sourceComponent = launchComponent;
        }
        if (blockState == "explode") {
            blockLoader.sourceComponent = explodeComponent;
            postLaunchStateTimer.running = true;

        }

        if (blockState == "idle") {
            blockLoader.sourceComponent = idleComponent;
        }
    }

    Component {
        id: blockLaunchComponent
        Engine.GameSpriteSheetItem {
            spriteSheetFile: blockLaunchSpriteSheet()
            gameScene: blockRoot.gameScene
            itemName: blockRoot.itemName
            frameWidth: 64
            frameHeight: 64
            frameCount: 5
            frameDuration: 60
            loops: 1
            onAnimationEndCallback: function(itemName) {
                blockRoot.blockState = "explode"
            }
        }
    }

    Component {
        id: blockIdleComponent
        Rectangle {
            color: "black"
            border.color: "black"

            property var blockColor: blockRoot.blockColor
            Image {
                source: "qrc:///images/block_" + blockRoot.blockColor + ".png"
                height: {
                    return parent.height * 0.90
                }
                width: {
                    return parent.width * 0.90
                }

                id: blockImage
                asynchronous: true

                sourceSize.height: blockImage.height
                sourceSize.width: blockImage.width
                anchors.centerIn: parent
                visible: true
            }
        }
    }
    Component {
        id: blockExplodeComponent
        UI.BlockExplodeParticles {
            id: particles
            Component.onCompleted: {
                particles.burstAt(blockRoot.x + (blockRoot.width * 0.5), blockRoot.y + (blockRoot.height * 0.5))
            }
        }

    }



    function blockLaunchSpriteSheet() { return "qrc:///images/block_" + blockColor + "_ss.png" }

        Loader {
            id: blockLoader
            width: blockRoot.width
            height: blockRoot.height
            sourceComponent: blockIdleComponent

            onLoaded: {
                blockLoader.visible = true
            }

    }
        Timer {
            id: postLaunchStateTimer
            interval: 2840
            running: false
            repeat: false
            triggeredOnStart: false
            onTriggered: {
                blockRoot.blockState = "destroyed"
                //blockRoot.blockDestroyed()
            }
        }
        Engine.GameDropItem {
            id: blockRootDropItem
            anchors.fill: blockRoot
            gameScene: blockRoot.gameScene
            itemName: blockRoot.itemName
            entry: dropAreaRect
            width: 64
            height: 64
            Rectangle {
                id: dropAreaRect
              width: 64
              height: 64
              opacity: 0
            }
         /*   Component.onCompleted: {
                blockRoot.gameScene.addSceneDropItem(blockRoot.itemName + "_drop", blockRootDropItem);
            } (*/
        }

}
