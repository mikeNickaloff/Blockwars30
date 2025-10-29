import QtQuick 2.15

GameDynamicItem {
    id: itemRoot
    property alias spriteSheetFile: spriteRoot.source
    property alias frameCount: spriteRoot.frameCount
    property alias loops: spriteRoot.loops
    property alias frameDuration: spriteRoot.frameDuration
    property alias frameWidth: spriteRoot.frameWidth
    property alias frameHeight: spriteRoot.frameHeight
    signal animationEndCallback(var itemName)
    signal animationBeginCallback(var itemName)

    function startAnimation() {

        spriteRoot.start()
    }
    AnimatedSprite {
        id: spriteRoot
        interpolate: true
        smooth: true
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
