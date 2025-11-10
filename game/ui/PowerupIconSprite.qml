import QtQuick 2.15

Item {
    id: spriteRoot

    property url spriteSheetSource: "qrc:///images/cardicons.png"
    property int iconIndex: 0
    property int frameSize: 64
    property int totalIcons: 25

    readonly property int normalizedIconIndex: {
        if (totalIcons <= 0)
            return 0
        var normalized = iconIndex % totalIcons
        if (normalized < 0)
            normalized += totalIcons
        return normalized
    }

    implicitWidth: frameSize
    implicitHeight: frameSize

    AnimatedSprite {
        id: spriteSheet
        anchors.fill: parent
        source: spriteRoot.spriteSheetSource
        frameCount: spriteRoot.totalIcons
        frameWidth: 64
        frameHeight: 64
        frameDuration: 0
        running: false
        loops: 1
        smooth: true
        interpolate: true

        currentFrame: spriteRoot.normalizedIconIndex
    }
}
