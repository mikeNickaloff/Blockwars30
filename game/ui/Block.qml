import QtQuick
import QtQuick.Layouts
import "../../engine" as Engine
import "../../lib" as Lib
import "." as UI
Engine.GameDragItem {
    id: blockRoot
    required property var gameScene
    required property var itemName
    required property var blockColor
    property alias source: blockLoader.source
    Layout.fillWidth: true
    Layout.fillHeight: true
    Loader {
        anchors.fill: parent
        id: blockLoader

    }
    property var blockState: "idle"

    onBlockStateChanged: {
        if (blockState == "launch") {
            blockLoader.source = BlockLaunchComponent.createObject(blockRoot, { spriteSheetFile: blockLaunchSpriteSheet() })

        }
    }

    component BlockLaunchComponent: Engine.GameSpriteSheetItem {
        required property var spriteSheetFile
    }

    component BlockIdleComponent: Rectangle {
            color: "black"
            border.color: "black"
            anchors.fill: parent

            Image {
                source: "qrc:///images/block_" + block_color + ".png"
                height: {
                    return block.height * 0.90
                }
                width: {
                    return block.width * 0.90
                }

                id: blockImage
                asynchronous: true

                sourceSize.height: blockImage.height
                sourceSize.width: blockImage.width
                anchors.centerIn: parent
                visible: true
            }

    }
    component BlockExplodeComponent: UI.BlockExplodeParticles {

    }



    function blockLaunchSpriteSheet() { return "qrc:///images/block_" + blockColor + "_ss.png" }

}
