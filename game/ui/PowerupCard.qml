import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts

import "../data" as Data
import "." as UI

Item {
    id: card

    readonly property var colorPalette: ({
        blue: "#448aff",
        red: "#ef5350",
        green: "#81c784",
        yellow: "#ffeb3b"
    })

    implicitWidth: 38
    implicitHeight: 50

    readonly property real cardWidth: width > 0 ? width : implicitWidth
    readonly property real cardHeight: height > 0 ? height : implicitHeight
    readonly property real cardMinDim: Math.min(cardWidth, cardHeight)
    readonly property real iconOverlaySize: cardWidth * 0.5
    readonly property string normalizedTargetSpec: (powerup.powerupTargetSpec || "").toLowerCase()
    readonly property bool isBlocksTargetSpec: powerup.powerupTargetSpec === powerup.targetSpecs.Blocks || normalizedTargetSpec === "blocks"
    readonly property bool isCardsTargetSpec: powerup.powerupTargetSpec === powerup.targetSpecs.PlayerPowerupInGameCards || normalizedTargetSpec === "cards"
    readonly property bool isRelativeAreaTargetSpec: powerup.powerupTargetSpec === powerup.targetSpecs.RelativeGridArea || normalizedTargetSpec === "relativegridarea"
    readonly property color cardsTargetBorderColor: powerup.powerupTarget === powerup.targets.Enemy ? "#ff9800" : "#9e9e9e"

    property alias powerupData: powerup
    property alias powerupUuid: powerup.powerupUuid
    property alias powerupName: powerup.powerupName
    property alias powerupTarget: powerup.powerupTarget
    property alias powerupTargetSpec: powerup.powerupTargetSpec
    property alias powerupTargetSpecData: powerup.powerupTargetSpecData
    property alias powerupCardHealth: powerup.powerupCardHealth
    property alias powerupActualAmount: powerup.powerupActualAmount
    property alias powerupOperation: powerup.powerupOperation
    property alias powerupIsCustom: powerup.powerupIsCustom
    property alias powerupCardEnergyRequired: powerup.powerupCardEnergyRequired
    property alias powerupCardColor: powerup.powerupCardColor
    property alias powerupHeroRowSpan: powerup.powerupHeroRowSpan
    property alias powerupHeroColSpan: powerup.powerupHeroColSpan
    property alias powerupIcon: powerup.powerupIcon
    property bool interactive: true
    property var runtimeData: null
    readonly property real runtimeEnergyProgress: runtimeData && runtimeData.energyProgress !== undefined
            ? Math.max(0, Math.min(1, runtimeData.energyProgress))
            : 0

    signal activated(string powerupUuid)
    Layout.fillWidth: true

    function applyRecord(record) {
        if (!record)
            return
        powerup.powerupUuid = record.powerupUuid || ""
        powerup.powerupName = record.powerupName || ""
        powerup.powerupTarget = record.powerupTarget || powerup.targets.Self
        powerup.powerupTargetSpec = record.powerupTargetSpec || powerup.targetSpecs.PlayerHealth
        var specData = record.powerupTargetSpecData
        if (typeof specData === "string") {
            try {
                specData = JSON.parse(specData)
            } catch (err) {
                specData = specData
            }
        }
        powerup.powerupTargetSpecData = specData !== undefined ? specData : []
        powerup.powerupCardHealth = record.powerupCardHealth || 0
        powerup.powerupActualAmount = record.powerupActualAmount || 0
        powerup.powerupOperation = record.powerupOperation || powerup.operations.Increase
        powerup.powerupIsCustom = !!record.powerupIsCustom
        powerup.powerupCardColor = record.powerupCardColor || "blue"
        powerup.powerupHeroRowSpan = record.powerupHeroRowSpan || powerup.powerupHeroRowSpan
        powerup.powerupHeroColSpan = record.powerupHeroColSpan || powerup.powerupHeroColSpan
        powerup.powerupIcon = record.powerupIcon !== undefined ? record.powerupIcon : 0
        powerup.updateEnergyRequirement()
    }

    function formattedAmount() {
        var sign = powerup.powerupOperation === powerup.operations.Decrease ? "-" : "+"
        return sign + " " + powerup.powerupActualAmount
    }

    function targetedBlocksContains(row, col) {
        if (!Array.isArray(powerup.powerupTargetSpecData))
            return false
        for (var i = 0; i < powerup.powerupTargetSpecData.length; ++i) {
            var item = powerup.powerupTargetSpecData[i]
            if (item && item.row === row && item.col === col)
                return true
        }
        return false
    }

    function normalizedRelativeAreaDimension(value) {
        var dimension = Number(value)
        if (!isFinite(dimension))
            dimension = 1
        dimension = Math.floor(dimension)
        if (dimension < 1)
            dimension = 1
        if (dimension > 5)
            dimension = 5
        return dimension
    }

    function normalizedRelativeAreaDistance(value) {
        var distance = Number(value)
        if (!isFinite(distance))
            distance = 6
        distance = Math.floor(distance)
        if (distance < -6)
            distance = -6
        if (distance > 6)
            distance = 6
        return distance
    }

    function relativeAreaSpecData() {
        if (!isRelativeAreaTargetSpec)
            return null
        var data = powerup.powerupTargetSpecData || {}
        return {
            rows: normalizedRelativeAreaDimension(data.rows !== undefined ? data.rows : data.rowCount),
            columns: normalizedRelativeAreaDimension(data.columns !== undefined ? data.columns : data.colCount),
            distance: normalizedRelativeAreaDistance(data.distance !== undefined ? data.distance : data.rowOffset)
        }
    }

    function relativeAreaSummary() {
        var spec = relativeAreaSpecData()
        if (!spec)
            return ""
        var sizeText = qsTr("%1x%2 area").arg(spec.rows).arg(spec.columns)
        if (spec.distance === 0)
            return qsTr("%1 aligned with hero").arg(sizeText)
        var magnitude = Math.abs(spec.distance)
        if (spec.distance > 0)
            return qsTr("%1 %2 rows ahead").arg(sizeText).arg(magnitude)
        return qsTr("%1 %2 rows behind").arg(sizeText).arg(magnitude)
    }

    function cardColorHex() {
        var value = (powerup.powerupCardColor || "blue").toLowerCase()
        return colorPalette[value] || colorPalette.blue
    }

    function unselectedBlockColor() {
        return Qt.rgba(28 / 255, 40 / 255, 58 / 255, 1)
    }

    Data.PowerupItem {
        id: powerup
    }

    Rectangle {
        id: cardFace
        anchors.fill: parent
        radius: cardMinDim * 0.03
        color: powerup.powerupIsCustom ? "#1f2f46" : "#241a33"
        border.width: Math.max(1, cardMinDim * 0.02)
        border.color: cardColorHex()
        antialiasing: true

        Item {
            id: blockLayer
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: parent.height * 0.5
            visible: card.isBlocksTargetSpec
            opacity: 0.75
            clip: true
            z: 1

            readonly property real gridPadding: Math.min(width, height) * 0.08
            readonly property real availableWidth: Math.max(0, width - gridPadding * 2)
            readonly property real availableHeight: Math.max(0, height - gridPadding * 2)
            readonly property real gridSide: Math.min(availableWidth, availableHeight)

            Grid {
                id: blockGrid
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: blockLayer.gridPadding
                width: blockLayer.gridSide
                height: width
                rows: 6
                columns: 6
                rowSpacing: width * 0.02
                columnSpacing: width * 0.02

                Repeater {
                    model: blockGrid.rows * blockGrid.columns
                    delegate: Rectangle {
                        readonly property int row: Math.floor(index / blockGrid.columns)
                        readonly property int column: index % blockGrid.columns
                        readonly property bool isSelected: targetedBlocksContains(row, column)
                        readonly property real cellSize: (blockGrid.width - (blockGrid.columns - 1) * blockGrid.columnSpacing) / blockGrid.columns
                        width: cellSize
                        height: cellSize
                        radius: cellSize * 0.2
                        color: isSelected ? cardColorHex() : unselectedBlockColor()
                        border.width: isSelected ? 0 : Math.max(1, cellSize * 0.05)
                        border.color: "#24364d"
                    }
                }
            }
        }

        Item {
            id: iconContainer
            anchors.centerIn: parent
            width: iconOverlaySize
            height: width
            z: 2

            Rectangle {
                id: cardsTargetFrame
                anchors.centerIn: parent
                width: parent.width * 1.1
                height: parent.height * 1.1
                radius: width * 0.15
                color: Qt.rgba(15 / 255, 23 / 255, 37 / 255, 0.55)
                border.width: Math.max(1, width * 0.05)
                border.color: cardsTargetBorderColor
                visible: card.isCardsTargetSpec
                z: -1
            }

            UI.PowerupIconSprite {
                id: overlayIcon
                anchors.centerIn: parent
                width: parent.width
                height: width
                iconIndex: powerup.powerupIcon
                opacity: 1
            }
        }

        Text {
            id: relativeAreaLabel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: cardMinDim * 0.08
            visible: card.isRelativeAreaTargetSpec
            color: "#cfd8dc"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Math.max(10, cardMinDim * 0.18)
            text: relativeAreaSummary()
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: card.interactive
        enabled: card.interactive
        acceptedButtons: card.interactive ? Qt.LeftButton : Qt.NoButton
        onClicked: activated(powerup.powerupUuid)
        cursorShape: Qt.PointingHandCursor
    }

}
