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
    readonly property real iconHeight: cardHeight * 0.6
    readonly property real energyIconSize: Math.min(cardMinDim * 0.4, cardHeight * 0.28)
    readonly property int maxEnergyCost: 100
    readonly property real energyCostRatio: maxEnergyCost > 0
            ? Math.min(1, powerup.powerupCardEnergyRequired / maxEnergyCost)
            : 0

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

            Rectangle {
                id: iconPanel
                Layout.fillWidth: true
                Layout.preferredHeight: iconHeight
                radius: cardMinDim * 0.12
                color: "#0d1524"
                border.width: Math.max(1, cardMinDim * 0.015)
                border.color: cardColorHex()
                antialiasing: true

                UI.PowerupIconSprite {
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: width
                    iconIndex: powerup.powerupIcon
                }
            }

            Rectangle {
                id: detailPanel
                Layout.fillWidth: true
                Layout.preferredHeight: cardHeight * 0.28
                radius: cardMinDim * 0.08
                color: "#101a2b"
                border.width: Math.max(1, cardMinDim * 0.015)
                border.color: "#0f1725"
                antialiasing: true

                Loader {
                    anchors.fill: parent
                    sourceComponent: powerup.powerupTargetSpec === powerup.targetSpecs.Blocks ? blocksIcon : detailPattern
                }
            }

            Item {
                id: energyBar
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(6, cardHeight * 0.13)

                Rectangle {
                    id: energyBarBackground
                    anchors.fill: parent
                    radius: height / 2
                    color: "#0b1019"
                    border.width: Math.max(1, height * 0.1)
                    border.color: "#04070c"
                    opacity: 0.9
                }

                Rectangle {
                    id: energyCapacityFill
                    anchors {
                        left: energyBarBackground.left
                        top: energyBarBackground.top
                        bottom: energyBarBackground.bottom
                    }
                    width: energyBarBackground.width * energyCostRatio
                    radius: energyBarBackground.radius
                    color: Qt.rgba(0.4, 0.58, 0.76, 0.35)
                    visible: energyCostRatio > 0
                }

                Rectangle {
                    id: energyRuntimeFill
                    anchors {
                        left: energyBarBackground.left
                        top: energyBarBackground.top
                        bottom: energyBarBackground.bottom
                    }
                    width: energyBarBackground.width * energyCostRatio * runtimeEnergyProgress
                    radius: energyBarBackground.radius
                    color: cardColorHex()
                    opacity: 0.9
                    visible: energyCostRatio > 0
                }

                Text {
                    anchors.centerIn: energyBarBackground
                    text: "\u26A1"
                    font.pixelSize: Math.max(8, energyIconSize * 0.6)
                    color: "#e0f7fa"
                }
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

    Component {
        id: blocksIcon
        Item {
            anchors.fill: parent
            readonly property real gridPadding: Math.min(width, height) * 0.08
            Grid {
                id: blockGrid
                anchors.fill: parent
                anchors.margins: gridPadding
                rows: 6
                columns: 6
                rowSpacing: gridPadding * 0.3
                columnSpacing: gridPadding * 0.3
                Repeater {
                    model: 36
                    delegate: Rectangle {
                        readonly property real cellSize: (blockGrid.width - (blockGrid.columns - 1) * blockGrid.columnSpacing) / blockGrid.columns
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
        id: detailPattern
        Item {
            anchors.fill: parent

            Repeater {
                model: 5
                delegate: Rectangle {
                    width: parent.width * 1.5
                    height: parent.height * 0.12
                    x: -parent.width * 0.25
                    y: index * parent.height * 0.18
                    rotation: 18
                    radius: height / 2
                    color: Qt.rgba(0.3, 0.38, 0.52, 0.2)
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0.22, 0.32, 0.48, 0.4)
                radius: height * 0.2
            }
        }
    }
}
