import QtQuick 2.15

GameDynamicItem {
    id: itemRoot
    property alias spriteSheetFile: spriteRoot.source
    property alias frameCount: spriteRoot.frameCount
    property var frameDuration: spriteRoot.frameDuration
    property var frameWidth: spriteRoot.frameWidth
    property var frameHeight: spriteRoot.frameHeight
    property var animationEndCallback
    property var animationBeginCallback

    function startAnimation() {

        spriteRoot.start()
    }
    AnimatedSprite {
        id: spriteRoot
        interpolate: true
        onRunningChanged: {
            if (spriteRoot.running) {

                itemRoot.animationBeginCallback(itemRoot.itemName)
            }
        }
        onFinished: {
            itemRoot.animationEndCallback(itemRoot.itemName)
        }

    }
}
