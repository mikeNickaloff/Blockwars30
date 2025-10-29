import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts

import "../data" as Data
import "." as UI

Item {
    id: matchSetup
    anchors.fill: parent

    signal closeRequested()
    signal proceedRequested(var loadout)

    Data.PowerupDatabase {
        id: database
    }

    onVisibleChanged: if (visible) refreshLoadout()

    property var loadoutData: []
    property int selectedSlot: -1
    property bool catalogVisible: false

    readonly property var slotCount: 4

    ListModel {
        id: loadoutModel
    }

    function refreshLoadout() {
        loadoutData = database.fetchLoadout()
        loadoutModel.clear()
        for (var slot = 0; slot < slotCount; ++slot) {
            var entry = loadoutData[slot] || { slot: slot, powerup: null }
            var record = entry.powerup || null
            loadoutModel.append({
                slot: slot,
                hasPowerup: record !== null,
                powerupUuid: record ? record.powerupUuid : "",
                powerupName: record ? record.powerupName : "",
                powerupTarget: record ? record.powerupTarget : "Self",
                powerupTargetSpec: record ? record.powerupTargetSpec : "PlayerHealth",
                powerupTargetSpecData: record ? record.powerupTargetSpecData : [],
                powerupCardHealth: record ? record.powerupCardHealth : 0,
                powerupActualAmount: record ? record.powerupActualAmount : 0,
                powerupOperation: record ? record.powerupOperation : "increase",
                powerupIsCustom: record ? record.powerupIsCustom : false,
                powerupCardEnergyRequired: record ? (record.powerupCardEnergyRequired || 0) : 0,
                powerupCardColor: record ? record.powerupCardColor : "blue"
            })
        }
    }

    function openCatalog(slot) {
        selectedSlot = slot
        catalogVisible = true
        overlayCatalog.refresh()
    }

    function closeCatalog() {
        catalogVisible = false
        selectedSlot = -1
    }

    function assignPowerupToSlot(slot, powerupUuid) {
        var updated = database.setLoadoutSlot(slot, powerupUuid)
        if (updated)
            refreshLoadout()
    }

    function handlePowerupChosen(record) {
        if (selectedSlot < 0)
            return
        if (!record || !record.powerupUuid) {
            closeCatalog()
            return
        }
        assignPowerupToSlot(selectedSlot, record.powerupUuid)
        closeCatalog()
    }

    Component.onCompleted: refreshLoadout()

    Rectangle {
        anchors.fill: parent
        color: "#0b1628"
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24

        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: qsTr("Match Setup")
                font.pixelSize: 28
                font.bold: true
                color: "#ffffff"
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Select up to four powerups to bring into battle. Powerups may only occupy one slot at a time.")
                wrapMode: Text.WordWrap
                color: "#cfd8dc"
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                spacing: 12
                Button {
                    text: qsTr("Close")
                    onClicked: closeRequested()
                }
                Button {
                    text: qsTr("Proceed")
                    enabled: true
                    onClicked: proceedRequested(loadoutData)
                }
            }
        }

        ColumnLayout {
            id: slotsColumn
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            spacing: 16

            Repeater {
                model: loadoutModel
                delegate: Item {
                    readonly property real slotHeight: (slotsColumn.height - (slotsColumn.spacing * (matchSetup.slotCount - 1))) / matchSetup.slotCount
                    Layout.fillWidth: true
                    Layout.preferredHeight: slotHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: hasPowerup ? "#182539" : "#131e2d"
                        border.width: 2
                        border.color: hasPowerup ? "#64ffda" : "#2a3b52"

                        UI.PowerupCard {
                            visible: hasPowerup
                            anchors.centerIn: parent
                            width: parent.width * 0.85
                            height: parent.height * 0.9
                            powerupUuid: powerupUuid
                            powerupName: powerupName
                            powerupTarget: powerupTarget
                            powerupTargetSpec: powerupTargetSpec
                            powerupTargetSpecData: powerupTargetSpecData
                            powerupCardHealth: powerupCardHealth
                            powerupActualAmount: powerupActualAmount
                            powerupOperation: powerupOperation
                            powerupIsCustom: powerupIsCustom
                            powerupCardEnergyRequired: powerupCardEnergyRequired
                            powerupCardColor: powerupCardColor
                        }

                        Column {
                            visible: !hasPowerup
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: qsTr("Slot %1").arg(slot + 1)
                                font.pixelSize: 16
                                color: "#78909c"
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                            }
                            Text {
                                text: qsTr("Tap to select a powerup")
                                font.pixelSize: 12
                                color: "#455a64"
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: openCatalog(slot)
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: catalogOverlay
        visible: catalogVisible
        anchors.fill: parent
        color: "#AA000000"
        z: 10

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: {
                var local = catalogDialog.mapFromItem(catalogOverlay, mouse.x, mouse.y)
                if (local.x < 0 || local.y < 0 || local.x > catalogDialog.width || local.y > catalogDialog.height)
                    closeCatalog()
            }
        }

        Rectangle {
            id: catalogDialog
            width: Math.min(parent.width * 0.8, 900)
            height: Math.min(parent.height * 0.8, 600)
            color: "#142134"
            radius: 12
            anchors.centerIn: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: qsTr("Choose Powerup")
                        font.pixelSize: 22
                        font.bold: true
                        color: "#ffffff"
                    }
                    Item { Layout.fillWidth: true }
                    Button {
                        text: qsTr("Cancel")
                        onClicked: closeCatalog()
                    }
                }

                UI.PowerupCatalog {
                    id: overlayCatalog
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onPowerupChosen: handlePowerupChosen(record)
                }
            }
        }
    }
}
