import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts

import "../data" as Data

Item {
    id: card

    readonly property var colorPalette: ({
        blue: "#448aff",
        red: "#ef5350",
        green: "#81c784",
        yellow: "#ffeb3b"
    })

    implicitWidth: 180
    implicitHeight: 260

    readonly property real cardWidth: width > 0 ? width : implicitWidth
    readonly property real cardHeight: height > 0 ? height : implicitHeight
    readonly property real cardMinDim: Math.min(cardWidth, cardHeight)
    readonly property real cardMargin: cardHeight * 0.06
    readonly property real sectionSpacing: cardHeight * 0.04
    readonly property real nameFont: Math.max(12, cardHeight * 0.1)
    readonly property real infoFont: Math.max(10, cardHeight * 0.055)
    readonly property real labelFont: Math.max(10, cardHeight * 0.05)
    readonly property real energyFont: Math.max(11, cardHeight * 0.08)

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

    signal activated(string powerupUuid)

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

            Text {
                Layout.fillWidth: true
                text: powerup.powerupName.length ? powerup.powerupName : qsTr("Unnamed Powerup")
                font.pixelSize: nameFont
                font.bold: true
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                text: powerup.powerupIsCustom ? qsTr("Custom Powerup") : qsTr("Built-in Powerup")
                font.pixelSize: infoFont
                color: powerup.powerupIsCustom ? "#64b5f6" : "#ffcc80"
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                id: iconArea
                Layout.fillWidth: true
                Layout.preferredHeight: cardHeight * 0.45

                Loader {
                    anchors.fill: parent
                    sourceComponent: powerup.powerupTargetSpec === powerup.targetSpecs.Blocks ? blocksIcon
                                        : powerup.powerupTargetSpec === powerup.targetSpecs.PlayerPowerupInGameCards ? cardIcon
                                        : playerIcon
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: cardHeight * 0.025

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Powerup Amount: %1").arg(formattedAmount())
                    font.pixelSize: labelFont
                    color: "#e8eaf6"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Energy Cost: %1").arg(powerup.powerupCardEnergyRequired)
                    font.pixelSize: energyFont
                    color: "#64ffda"
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: activated(powerup.powerupUuid)
        cursorShape: Qt.PointingHandCursor
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
        Rectangle {
            anchors.top: parent.top
            readonly property real iconDim: Math.min(parent.width, parent.height) * 0.25
            width: iconDim
            height: iconDim * 1.3
            radius: iconDim * 0.18
            color: "#101622"
            border.width: Math.max(1, iconDim * 0.1)
            border.color: cardColorHex()
            Column {
                anchors.centerIn: parent
                spacing: iconDim * 0.1
                Rectangle {
                    width: iconDim * 0.65
                    height: iconDim
                    radius: iconDim * 0.15
                    border.width: Math.max(1, iconDim * 0.08)
                    border.color: cardColorHex()
                    color: "transparent"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Card")
                    font.pixelSize: Math.max(8, iconDim * 0.3)
                    color: "#e0e0e0"
                }
            }
        }
    }
}
