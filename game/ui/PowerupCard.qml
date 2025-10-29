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
        powerup.powerupTargetSpecData = record.powerupTargetSpecData !== undefined ? record.powerupTargetSpecData : []
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
        radius: 18
        color: powerup.powerupIsCustom ? "#1f2f46" : "#241a33"
        border.width: 3
        border.color: cardColorHex()
        antialiasing: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: powerup.powerupName.length ? powerup.powerupName : qsTr("Unnamed Powerup")
                font.pixelSize: 18
                font.bold: true
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                text: powerup.powerupIsCustom ? qsTr("Custom Powerup") : qsTr("Built-in Powerup")
                font.pixelSize: 12
                color: powerup.powerupIsCustom ? "#64b5f6" : "#ffcc80"
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                id: iconArea
                Layout.fillWidth: true
                Layout.preferredHeight: 140

                Loader {
                    anchors.fill: parent
                    sourceComponent: powerup.powerupTargetSpec === powerup.targetSpecs.Blocks ? blocksIcon
                                        : powerup.powerupTargetSpec === powerup.targetSpecs.PlayerPowerupInGameCards ? cardIcon
                                        : playerIcon
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Powerup Amount: %1").arg(formattedAmount())
                    font.pixelSize: 14
                    color: "#e8eaf6"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Energy Cost: %1").arg(powerup.powerupCardEnergyRequired)
                    font.pixelSize: 14
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
            width: parent.width * 0.6
            height: width
            radius: width / 2
            color: "#2f3a4f"
            border.width: 3
            border.color: cardColorHex()
            Text {
                anchors.centerIn: parent
                text: "👤"
                font.pixelSize: parent.width * 0.45
            }
        }
    }

    Component {
        id: blocksIcon
        Item {
            anchors.centerIn: parent
            width: parent.width * 0.9
            height: width

            Grid {
                id: blockGrid
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                rows: 6
                columns: 6
                rowSpacing: 2
                columnSpacing: 2
                Repeater {
                    model: 36
                    delegate: Rectangle {
                        width: (blockGrid.width - (blockGrid.columns - 1) * blockGrid.columnSpacing) / blockGrid.columns
                        height: (blockGrid.height - (blockGrid.rows - 1) * blockGrid.rowSpacing) / blockGrid.rows
                        color: targetedBlocksContains(Math.floor(index / 6), index % 6) ? cardColorHex() : unselectedBlockColor()
                        border.width: targetedBlocksContains(Math.floor(index / 6), index % 6) ? 0 : 1
                        border.color: "#24364d"
                        radius: 2
                    }
                }
            }
        }
    }

    Component {
        id: cardIcon
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.55
            height: parent.height * 0.85
            radius: 10
            color: "#101622"
            border.width: 4
            border.color: cardColorHex()
            Column {
                anchors.centerIn: parent
                spacing: 6
                Rectangle {
                    width: parent.width * 0.6
                    height: width * 1.2
                    radius: 6
                    border.width: 2
                    border.color: cardColorHex()
                    color: "transparent"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Card")
                    font.pixelSize: 12
                    color: "#e0e0e0"
                }
            }
        }
    }
}
