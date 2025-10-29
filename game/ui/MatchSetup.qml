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
    signal updatedSlotData(int slot, var record)

    Data.PowerupDatabase {
        id: database
    }

    onVisibleChanged: if (visible) refreshLoadout()

    property var loadoutData: []
    property int selectedSlot: -1
    property bool catalogVisible: false
    property var slots: []

    readonly property var slotCount: 4

    function populateLoadoutModel(entries) {
        loadoutData = entries || []
        for (var i = 0; i < slotCount; ++i) {
            var slotObj = slots[i]
            if (!slotObj)
                continue
            var entry = (loadoutData[i]) || { slot: i, powerup: null }
            loadoutData[i] = entry
            var record = entry.powerup || null
            slotObj.applyRecord(record)
        }
    }

    function refreshLoadout() {
        var entries = database.fetchLoadout() || []
        populateLoadoutModel(entries)
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
            populateLoadoutModel(updated)
    }

    function deserializeSpecData(value) {
        if (typeof value === "string") {
            try {
                var parsed = JSON.parse(value)
                return parsed === null ? null : parsed
            } catch (err) {
                return value
            }
        }
        return value
    }

    function destroySlots() {
        for (var i = 0; i < slots.length; ++i) {
            if (slots[i])
                slots[i].destroy()
        }
        slots = []
    }

    function createSlots() {
        destroySlots()
        for (var i = 0; i < slotCount; ++i) {
            var slotObj = slotAreaComponent.createObject(slotsColumn, {
                                                         slotIndex: i,
                                                         matchSetupRef: matchSetup,
                                                         slotHeight: Qt.binding(function() { return (slotsColumn.height - slotsColumn.spacing * (matchSetup.slotCount - 1)) / matchSetup.slotCount; })
                                                     })
            slots.push(slotObj)
        }
    }

    function handlePowerupChosen(record) {
        if (selectedSlot < 0)
            return
        if (!record || !record.powerupUuid) {
            closeCatalog()
            return
        }

        var normalized = {
            powerupUuid: record.powerupUuid || "",
            powerupName: record.powerupName || "",
            powerupTarget: record.powerupTarget || "Self",
            powerupTargetSpec: record.powerupTargetSpec || "PlayerHealth",
            powerupTargetSpecData: deserializeSpecData(record.powerupTargetSpecData),
            powerupCardHealth: record.powerupCardHealth || 0,
            powerupActualAmount: record.powerupActualAmount || 0,
            powerupOperation: record.powerupOperation || "increase",
            powerupIsCustom: !!record.powerupIsCustom,
            powerupCardEnergyRequired: record.powerupCardEnergyRequired || 0,
            powerupCardColor: record.powerupCardColor || "blue"
        }

        if (slots[selectedSlot])
            slots[selectedSlot].applyRecord(normalized)
        loadoutData[selectedSlot] = { slot: selectedSlot, powerup: normalized }

        updatedSlotData(selectedSlot, normalized)

        assignPowerupToSlot(selectedSlot, normalized.powerupUuid)
        closeCatalog()
    }

    Component.onCompleted: {
        createSlots()
        refreshLoadout()
    }

    Component.onDestruction: destroySlots()

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
        }
    }
    Component {
        id: slotAreaComponent
        Item {
            id: slotRoot
            property var matchSetupRef
            property int slotIndex: 0
            property real slotHeight: 200
            property bool hasPowerup: false
            property string powerupUuid: ""
            property string powerupName: ""
            property string powerupTarget: "Self"
            property string powerupTargetSpec: "PlayerHealth"
            property var powerupTargetSpecData: []
            property int powerupCardHealth: 0
            property int powerupActualAmount: 0
            property string powerupOperation: "increase"
            property bool powerupIsCustom: false
            property int powerupCardEnergyRequired: 0
            property string powerupCardColor: "blue"
            property alias card: slotCard
            property alias frame: slotFrame

            Layout.fillWidth: true
            Layout.preferredHeight: slotHeight > 0 ? slotHeight : (matchSetupRef ? matchSetupRef.height / matchSetupRef.slotCount : 200)

            function applyRecord(record) {
                if (!record || !record.powerupUuid) {
                    hasPowerup = false
                    powerupUuid = ""
                    powerupName = ""
                    powerupTarget = "Self"
                    powerupTargetSpec = "PlayerHealth"
                    powerupTargetSpecData = []
                    powerupCardHealth = 0
                    powerupActualAmount = 0
                    powerupOperation = "increase"
                    powerupIsCustom = false
                    powerupCardEnergyRequired = 0
                    powerupCardColor = "blue"
                    slotCard.applyRecord({
                        powerupUuid: "",
                        powerupName: "",
                        powerupTarget: "Self",
                        powerupTargetSpec: "PlayerHealth",
                        powerupTargetSpecData: [],
                        powerupCardHealth: 0,
                        powerupActualAmount: 0,
                        powerupOperation: "increase",
                        powerupIsCustom: false,
                        powerupCardEnergyRequired: 0,
                        powerupCardColor: "blue"
                    })
                } else {
                    hasPowerup = true
                    powerupUuid = record.powerupUuid || ""
                    powerupName = record.powerupName || ""
                    powerupTarget = record.powerupTarget || "Self"
                    powerupTargetSpec = record.powerupTargetSpec || "PlayerHealth"
                    powerupTargetSpecData = record.powerupTargetSpecData || []
                    powerupCardHealth = record.powerupCardHealth || 0
                    powerupActualAmount = record.powerupActualAmount || 0
                    powerupOperation = record.powerupOperation || "increase"
                    powerupIsCustom = record.powerupIsCustom ? true : false
                    powerupCardEnergyRequired = record.powerupCardEnergyRequired || 0
                    powerupCardColor = record.powerupCardColor || "blue"
                    slotCard.applyRecord(record)
                }
            }

            Rectangle {
                id: slotFrame
                anchors.fill: parent
                radius: 14
                color: hasPowerup ? "#182539" : "#131e2d"
                border.width: 2
                border.color: hasPowerup ? "#64ffda" : "#2a3b52"

                UI.PowerupCard {
                    id: slotCard
                    visible: hasPowerup
                    anchors.centerIn: parent
                    width: parent.width * 0.7
                    height: parent.height * 0.8
                    powerupUuid: slotRoot.powerupUuid
                    powerupName: slotRoot.powerupName
                    powerupTarget: slotRoot.powerupTarget
                    powerupTargetSpec: slotRoot.powerupTargetSpec
                    powerupTargetSpecData: slotRoot.powerupTargetSpecData
                    powerupCardHealth: slotRoot.powerupCardHealth
                    powerupActualAmount: slotRoot.powerupActualAmount
                    powerupOperation: slotRoot.powerupOperation
                    powerupIsCustom: slotRoot.powerupIsCustom
                    powerupCardEnergyRequired: slotRoot.powerupCardEnergyRequired
                    powerupCardColor: slotRoot.powerupCardColor
                }

                Column {
                    visible: !hasPowerup
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: qsTr("Slot %1").arg(slotIndex + 1)
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
                    cursorShape: Qt.PointingHandCursor
                    onClicked: matchSetupRef.openCatalog(slotIndex)
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
                    onPowerupChosen: function(record) { handlePowerupChosen(record); }
                }
            }
        }
    }
}
