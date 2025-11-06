import QtQuick 2.15

Item {
    id: root

    property Item battleGrid: null
    property color backgroundColor: "#1a1f29"
    property color borderColor: "#2e3a4a"
    property color highHealthColor: "#2ecc71"
    property color mediumHealthColor: "#f1c40f"
    property color lowHealthColor: "#e74c3c"
    property int barPadding: 2
    property int barHeight: 18

    readonly property int maxHealth: battleGrid && battleGrid.mainHealthMax !== undefined
                                      ? battleGrid.mainHealthMax
                                      : (battleGrid ? battleGrid.mainHealth : 100)
    readonly property int currentHealth: battleGrid ? Math.max(0, battleGrid.mainHealth) : 0
    readonly property real progress: maxHealth > 0
                                     ? Math.max(0, Math.min(1, currentHealth / maxHealth))
                                     : 0
    readonly property color fillColor: currentHealth >= maxHealth * 0.5
                                       ? highHealthColor
                                       : (currentHealth >= maxHealth * 0.25
                                          ? mediumHealthColor
                                          : lowHealthColor)

    width: battleGrid ? battleGrid.width : 220
    height: barHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: backgroundColor
        border.width: 1
        border.color: borderColor
    }

    Rectangle {
        id: fillRect
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: barPadding
        height: Math.max(0, parent.height - barPadding * 2)
        width: Math.max(0, (parent.width - barPadding * 2) * root.progress)
        radius: height / 2
        color: fillColor

        Behavior on width {
            NumberAnimation {
                duration: 180
                easing.type: Easing.InOutQuad
            }
        }
    }

    Text {
        anchors.centerIn: parent
        color: "#d5deff"
        text: qsTr("%1 / %2").arg(currentHealth).arg(maxHealth)
        font.pixelSize: 12
    }
}
