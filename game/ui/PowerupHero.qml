import QtQuick 2.15

Item {
    id: hero

    property string powerupName: ""
    property string powerupCardColor: "blue"
    property int powerupHeroRowSpan: 1
    property int powerupHeroColSpan: 1
    property int cellWidth: 50
    property int cellHeight: 50
    property real cellSpacing: 2
    property bool previewMode: true
    property alias label: heroLabel.text
    property var cardData: null
    property var anchoredRow
    property var anchoredColumn

    readonly property var colorPalette: ({
                                           blue: "#448aff",
                                           red: "#ef5350",
                                           green: "#81c784",
                                           yellow: "#ffeb3b",
                                           purple: "#b388ff"
                                       })

    readonly property real spanWidth: Math.max(1, powerupHeroColSpan) * cellWidth + Math.max(0, powerupHeroColSpan - 1) * cellSpacing
    readonly property real spanHeight: Math.max(1, powerupHeroRowSpan) * cellHeight + Math.max(0, powerupHeroRowSpan - 1) * cellSpacing

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
    }

    Rectangle {
        id: heroBody
        anchors.fill: parent
        radius: Math.min(width, height) * 0.15
        color: previewMode ? Qt.rgba(0.12, 0.16, 0.24, 0.6) : Qt.rgba(0.1, 0.12, 0.18, 0.85)
        border.color: hero.heroColor()
        border.width: Math.max(2, Math.min(width, height) * 0.05)
        antialiasing: true

        Text {
            id: heroLabel
            anchors.centerIn: parent
            text: powerupName.length ? powerupName : qsTr("Hero")
            color: "#f5f5f5"
            font.pixelSize: Math.max(10, Math.min(hero.width, hero.height) * 0.18)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            wrapMode: Text.WordWrap
            width: parent.width * 0.8
        }
    }
}
