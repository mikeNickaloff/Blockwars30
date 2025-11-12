import QtQuick 2.15
import "./" as UI

Item {
    id: hero

    property string powerupName: ""
    property string powerupCardColor: "blue"
    property int powerupHeroRowSpan: 1
    property int powerupHeroColSpan: 1
    property int powerupIcon: 0
    property int cellWidth: 50
    property int cellHeight: 50
    property real cellSpacing: 2
    property bool previewMode: true
    property alias label: heroLabel.text
    property var cardData: null
    property var anchoredRow
    property var anchoredColumn
    property string heroState: "idle"

    readonly property var colorPalette: ({
                                           blue: "#448aff",
                                           red: "#ef5350",
                                           green: "#81c784",
                                           yellow: "#ffeb3b",
                                           purple: "#b388ff"
                                       })
    readonly property int heroIconIndex: cardData && cardData.powerupIcon !== undefined
            ? cardData.powerupIcon
            : powerupIcon

    readonly property real spanWidth: Math.max(1, powerupHeroColSpan) * cellWidth + Math.max(0, powerupHeroColSpan - 1) * cellSpacing
    readonly property real spanHeight: Math.max(1, powerupHeroRowSpan) * cellHeight + Math.max(0, powerupHeroRowSpan - 1) * cellSpacing
    readonly property color heroFillColor: {
        if (heroState === "explode" || heroState === "destroyed")
            return Qt.rgba(0.45, 0.12, 0.12, previewMode ? 0.6 : 0.9)
        if (heroState === "gain")
            return Qt.rgba(0.16, 0.24, 0.32, previewMode ? 0.65 : 0.92)
        return previewMode ? Qt.rgba(0.12, 0.16, 0.24, 0.6) : Qt.rgba(0.1, 0.12, 0.18, 0.85)
    }

    width: spanWidth
    height: spanHeight
    opacity: previewMode ? 0.7 : 1.0
    visible: false

    function heroColor() {
        var key = (powerupCardColor || "blue").toLowerCase()
        return colorPalette[key] || colorPalette.blue
    }

    function applyCard(record) {
        if (!record)
            return
        powerupName = record.powerupName || ""
        powerupCardColor = record.powerupCardColor || "blue"
        powerupHeroRowSpan = record.powerupHeroRowSpan || 1
        powerupHeroColSpan = record.powerupHeroColSpan || 1
        powerupIcon = record.powerupIcon !== undefined ? record.powerupIcon : 0
    }

    Rectangle {
        id: heroHealthBackdrop
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(3, hero.spanHeight * 0.08)
        radius: height / 2
        opacity: previewMode ? 0 : 0.75
        color: Qt.rgba(0.05, 0.08, 0.12, 0.85)
        visible: cardData && !previewMode && heroState !== "destroyed"
        z: 5

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: parent.width * (cardData ? cardData.heroHealthProgress : 0)
            radius: parent.radius
            color: hero.heroColor()
            opacity: cardData && cardData.heroAlive ? 0.95 : 0.35
        }
    }

    Rectangle {
        id: heroBody
        anchors.fill: parent
        radius: Math.min(width, height) * 0.15
        color: hero.heroFillColor
        border.color: hero.heroColor()
        border.width: Math.max(2, Math.min(width, height) * 0.05)
        antialiasing: true
        z: 1

        UI.PowerupIconSprite {
            id: heroIconGraphic
            anchors.centerIn: parent
            width: Math.min(hero.width, hero.height) * 0.65
            height: width
            iconIndex: heroIconIndex
            visible: heroIconIndex >= 0
        }

        Text {
            id: heroLabel
            anchors.centerIn: parent
            visible: false
            opacity: 0
            text: powerupName.length ? powerupName : qsTr("Hero")
        }
    }
}
