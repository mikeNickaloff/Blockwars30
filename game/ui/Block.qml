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
    property var pendingHealth: 5
    property int energyAmount: 0
    property int spriteAnimationDisplaySize: 40
    property bool explodeAfterLaunch: true
    property real blockScaleX: 1
    property real blockScaleY: 1

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
property var __battleGridWrapper
property bool __battleGridSignalRegistered: false
    property bool hasLaunched: false
    signal blockDestroyed(var itemName)
    signal modifiedBlockGridCell()
    signal blockKilled()

    Behavior on blockScaleX {
        enabled: !blockRoot.explodeAfterLaunch
        NumberAnimation {
            duration: 220
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on blockScaleY {
        enabled: !blockRoot.explodeAfterLaunch
        NumberAnimation {
            duration: 220
            easing.type: Easing.InOutQuad
        }
    }

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

        if (blockRoot.pendingHealth !== blockRoot.health)
            blockRoot.pendingHealth = blockRoot.health

    }

    onCachedHealthChanged: {
        blockHealthText.text = cachedHealth.toString()
    }

    onPendingHealthChanged: {
        if (blockRoot.pendingHealth === blockRoot.health)
            return;
        if (pendingHealthApplyTimer.running)
            pendingHealthApplyTimer.restart();
        else
            pendingHealthApplyTimer.start();
    }
    Component.onCompleted: {
        blockRoot.blockState = "idle"
        console.log("block instance created")
        blockRoot.__previousGridRow = blockRoot.row
        blockRoot.__previousGridColumn = blockRoot.column
    }
    onBlockStateChanged: {
        console.log("block state set to",blockState);
        if (!hasLaunched && (blockState === "launch" || blockState === "launchNoExplode")) {
            launchDelayTimer.running = true;
            launchDelayTimer.restart();
            hasLaunched = true;
        }

        if (blockState === "launch") {
            explodeAfterLaunch = true;
            resetLaunchScale();
        } else if (blockState === "launchNoExplode") {
            explodeAfterLaunch = false;
        }

        if (blockState == "explode") {
            blockLoader.sourceComponent = explodeComponent;
            postLaunchStateTimer.running = true;
        }
        if (blockState === "scaleDown") {
            blockLoader.sourceComponent = idleComponent;
            triggerScaleDownAnimation();
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
            explodeAfterLaunch = true;
            resetLaunchScale();
        }
        if (!hasLaunched) {
            if (blockState == "gain")
                blockLoader.sourceComponent = gainComponent;
            if (blockState == "gainCooldown")
                blockLoader.sourceComponent = gainCooldownComponent;
        }
    }
    Timer {
        id: pendingHealthApplyTimer
        running: false
        interval: 200
        triggeredOnStart: false
        repeat: false
        onTriggered: {
            if (blockRoot.pendingHealth === blockRoot.health)
                return;
            blockRoot.health = blockRoot.pendingHealth;
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
    Timer {
        id: launchDelayTimer
        running: false
        repeat: false
        interval: 50
        triggeredOnStart: false
        onTriggered: {

            blockLoader.sourceComponent = launchComponent;
        }
    }

    Component {
        id: blockLaunchComponent
        Engine.GameSpriteSheetItem {
            anchors.fill: undefined
            anchors.centerIn: parent
            transformOrigin: Item.Center
            spriteSheetFile: blockLaunchSpriteSheet()
            gameScene: blockRoot.gameScene
            itemName: blockRoot.itemName
            frameWidth: 64
            frameHeight: 64
            width: frameWidth
            height: frameHeight
            scale: blockRoot.spriteAnimationDisplaySize / frameWidth
            frameCount: 5
            frameDuration: 60
            loops: 1
            onAnimationEndCallback: function(itemName) {
                blockRoot.blockState = blockRoot.explodeAfterLaunch ? "explode" : "scaleDown"
            }
        }
    }

    Component {
        id: blockGainComponent
        Engine.GameSpriteSheetItem {
            anchors.fill: undefined
            anchors.centerIn: parent
            transformOrigin: Item.Center
            spriteSheetFile: blockLaunchSpriteSheet()
            gameScene: blockRoot.gameScene
            itemName: blockRoot.itemName
            frameWidth: 64
            frameHeight: 64
            width: frameWidth
            height: frameHeight
            scale: blockRoot.spriteAnimationDisplaySize / frameWidth
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
             scale: blockRoot.spriteAnimationDisplaySize / frameWidth
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
            transform: Scale {
                id: launchScaleTransform
                origin.x: blockLoader.width / 2
                origin.y: blockLoader.height / 2
                xScale: blockRoot.blockScaleX
                yScale: blockRoot.blockScaleY
            }

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
            onTriggered: finalizePostLaunchState()
        }

        Timer {
            id: scaleDownStateTimer
            interval: 260
            running: false
            repeat: false
            triggeredOnStart: false
            onTriggered: finalizePostLaunchState()
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
        function serialize() {
            return {
                blockColor: blockRoot.blockColor || "",
                row: blockRoot.row,
                column: blockRoot.column,
                health: blockRoot.health
            };
        }
        Text {
            id: blockHealthText
            text: health.toString()
            anchors.centerIn: parent
            color: "white"
        }

        function finalizePostLaunchState() {
            if (blockRoot.blockState === "destroyed")
                return;
            blockRoot.blockState = "destroyed";
            blockRoot.blockDestroyed({
                                         itemName: blockRoot.itemName,
                                         blockColor: blockRoot.blockColor,
                                         energyAmount: blockRoot.energyAmount,
                                         row: blockRoot.row,
                                         column: blockRoot.column,
                                         battleGrid: blockRoot.battleGrid
                                     })
        }

        function resetLaunchScale() {
            blockRoot.blockScaleX = 1
            blockRoot.blockScaleY = 1
        }

        function triggerScaleDownAnimation() {
            blockRoot.blockScaleX = 1.5
            blockRoot.blockScaleY = 0
            scaleDownStateTimer.restart()
        }
}
