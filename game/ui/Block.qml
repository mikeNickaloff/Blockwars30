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
    property var battleGrid
    property var health: 5
    property var cachedHealth: 5
    property int energyAmount: 0

    property Component launchComponent: blockLaunchComponent
    property Component idleComponent: blockIdleComponent
    property Component explodeComponent: blockExplodeComponent
    property Component gainComponent: blockGainComponent
    property Component gainCooldownComponent: blockGainCooldownComponent
    property var heroBindingKey
    property var lowerBlockRefs: []
    property bool heroLinked: false
    property bool powerupHeroLinked: false
    property string powerupHeroUuid: ""
    property var powerupHeroItem: null
    property int powerupHeroRowOffset: 0
    property int powerupHeroColOffset: 0
    property bool __heroHealthSyncGuard: false
    property bool __heroPositionGuard: false
    property int __previousGridRow: -1
    property int __previousGridColumn: -1

    signal blockDestroyed(var itemName)
    signal modifiedBlockGridCell()
    signal blockKilled()

    onRowChanged: {

     modifiedBlockGridCell()
    }
    onColumnChanged: {
        modifiedBlockGridCell()
    }
    onHealthChanged: {
        if (blockRoot.__heroHealthSyncGuard) {
            cachedHealth = health
            return
        }
        if (health > cachedHealth) {
            if (blockRoot.blockState === "idle") {
                blockRoot.blockState = "gain"
                cachedHealth = health
            } else {
                cachedHealth = health
            }
        }
    }

    Component.onCompleted: {
        blockRoot.blockState = "idle"
        console.log("block instance created")
        blockRoot.__previousGridRow = blockRoot.row
        blockRoot.__previousGridColumn = blockRoot.column
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
        if (blockState == "explodeKilled") {
            blockRoot.blockKilled()
        }

        if (blockState == "waitAndExplode") {
            waitAndExplodeTimer.running = true
            waitAndExplodeTimer.restart()
        }
        if (blockState == "idle") {
            blockLoader.sourceComponent = idleComponent;
            energyAmount = 0;
        }
        if (blockState == "gain") {
            blockLoader.sourceComponent = gainComponent;
        }
        if (blockState == "gainCooldown") {
            blockLoader.sourceComponent = gainCooldownComponent;
        }
    }
    Timer {
        id: waitAndExplodeTimer
        running: false
        interval: 200
        triggeredOnStart: false
        repeat: false
        onTriggered:  {

            blockState = "explode"

        }
    }
    Timer {
        id: waitAndDestroyTimer
        running: false
        interval: 300
        triggeredOnStart: false
        repeat: false
        onTriggered: {
            blockRoot.opacity = 0
            blockState = "explode"
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
        id: blockGainComponent
        Engine.GameSpriteSheetItem {
            spriteSheetFile: blockLaunchSpriteSheet()
            gameScene: blockRoot.gameScene
            itemName: blockRoot.itemName
            frameWidth: 64
            frameHeight: 64
            frameCount: 3
            frameDuration: 125
            loops: 1
            reverse: false
            onAnimationEndCallback: function(itemName) {
                blockRoot.blockState = "gainCooldown"
            }
        }
    }

    Component {
        id: blockGainCooldownComponent
        Engine.GameSpriteSheetItem {
            spriteSheetFile: blockLaunchSpriteSheet()
            gameScene: blockRoot.gameScene
            itemName: blockRoot.itemName
            frameWidth: 64
            frameHeight: 64
            frameCount: 3
            frameDuration: 125
            loops: 1
            reverse: true
            onAnimationEndCallback: function(itemName) {
                blockRoot.blockState = "idle"
            }
        }
    }

    Component {
        id: blockIdleComponent


            Rectangle {
                color: "black"
                border.color: "black"
                id: blockRect
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
            interval: 1040
            running: false
            repeat: false
            triggeredOnStart: false
            onTriggered: {
                blockRoot.blockState = "destroyed"
                blockRoot.blockDestroyed({
                                             itemName: blockRoot.itemName,
                                             blockColor: blockRoot.blockColor,
                                             energyAmount: blockRoot.energyAmount,
                                             row: blockRoot.row,
                                             column: blockRoot.column,
                                             battleGrid: blockRoot.battleGrid
                                         })
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
        function startedMoving() {
            if (blockRoot.blockState === "idle") { blockRoot.blockState = "moving" }
        }
        function stoppedMoving() {
            if (blockRoot.blockState === "moving") { blockRoot.blockState = "idle" }
        }
}
