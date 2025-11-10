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
    readonly property real cardMargin: cardHeight * 0.08
    readonly property real sectionSpacing: cardHeight * 0.08
    readonly property real iconHeight: cardHeight * 0.45
    readonly property real energyFont: Math.min(8, cardHeight * 0.42)

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
        radius: cardMinDim * 0.12
        color: powerup.powerupIsCustom ? "#1f2f46" : "#241a33"
        border.width: Math.max(1, cardMinDim * 0.02)
        border.color: cardColorHex()
        antialiasing: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: cardMargin
            spacing: sectionSpacing
            Layout.alignment: Qt.AlignHCenter

            Item {
                id: iconArea
                Layout.fillWidth: true
                Layout.preferredHeight: iconHeight

                Loader {
                    anchors.fill: parent
                    sourceComponent: powerup.powerupTargetSpec === powerup.targetSpecs.Blocks ? blocksIcon
                                        : powerup.powerupTargetSpec === powerup.targetSpecs.PlayerPowerupInGameCards ? cardIcon
                                        : playerIcon
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("%1 ⚡").arg(powerup.powerupCardEnergyRequired)
                font.pixelSize: 4
                font.bold: true
                color: "#64ffda"
                horizontalAlignment: Text.AlignHCenter
            }
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

    Rectangle {
        id: energyFill
        anchors.left: cardFace.left
        anchors.bottom: cardFace.bottom
        height: Math.max(2, cardHeight * 0.085)
        width: cardFace.width * runtimeEnergyProgress
        radius: height * 0.6
        color: cardColorHex()
        opacity: 0.95
    }

    Component {
        id: playerIcon
        Rectangle {
            anchors.centerIn: parent
            readonly property real iconDim: Math.min(parent.width, parent.height) * 0.35
            width: iconDim
            height: iconDim
            radius: iconDim / 2
            color: "#2f3a4f"
            border.width: Math.max(1, iconDim * 0.12)
            border.color: cardColorHex()
            Text {
                anchors.centerIn: parent
                text: "👤"
                font.pixelSize: iconDim * 0.55
            }
        }
    }

    Component {
        id: blocksIcon
        Item {
            anchors.top: parent.top
            readonly property real iconDim: Math.min(parent.width, parent.height) * 0.45
            width: iconDim
            height: iconDim

            Grid {
                id: blockGrid
                anchors.centerIn: parent
                width: iconDim
                height: iconDim
                rows: 6
                columns: 6
                rowSpacing: iconDim * 0.015
                columnSpacing: iconDim * 0.015
                Repeater {
                    model: 36
                    delegate: Rectangle {
                        readonly property real cellSize: (iconDim - (blockGrid.columns - 1) * blockGrid.columnSpacing) / blockGrid.columns
                        width: cellSize
                        height: cellSize
                        color: targetedBlocksContains(Math.floor(index / 6), index % 6) ? cardColorHex() : unselectedBlockColor()
                        border.width: targetedBlocksContains(Math.floor(index / 6), index % 6) ? 0 : Math.max(1, cellSize * 0.05)
                        border.color: "#24364d"
                        radius: cellSize * 0.2
                    }
                }
            }
        }
    }

    Component {
        id: cardIcon
        Item {
            anchors.fill: parent
            readonly property real iconDim: Math.min(width, height) * 0.6
            Rectangle {
                anchors.centerIn: parent
                width: iconDim * 1.1
                height: iconDim * 1.1
                radius: width * 0.2
                color: "#101622"
                border.width: Math.max(1, width * 0.08)
                border.color: cardColorHex()
            }
            UI.PowerupIconSprite {
                anchors.centerIn: parent
                width: iconDim
                height: iconDim
                iconIndex: powerup.powerupIcon
            }
        }
    }
}
