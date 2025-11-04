import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts

import "ui" as UI
import "./data" as Data
import "../engine" as Engine

Engine.GameScene {
    id: powerupEditor
    anchors.fill: parent

    signal closeRequested()

    readonly property var cardColorOptions: [
        { label: qsTr("Blue"), value: "blue" },
        { label: qsTr("Red"), value: "red" },
        { label: qsTr("Green"), value: "green" },
        { label: qsTr("Yellow"), value: "yellow" }
    ]

    readonly property var targetOptions: [
        { label: qsTr("Self"), value: editingPowerup.targets.Self },
        { label: qsTr("Enemy"), value: editingPowerup.targets.Enemy }
    ]

    readonly property var targetSpecOptions: [
        { label: qsTr("Player Health"), value: editingPowerup.targetSpecs.PlayerHealth },
        { label: qsTr("Blocks"), value: editingPowerup.targetSpecs.Blocks },
        { label: qsTr("Powerup Cards"), value: editingPowerup.targetSpecs.PlayerPowerupInGameCards }
    ]

    readonly property var operationOptions: [
        { label: qsTr("Gain"), value: editingPowerup.operations.Increase },
        { label: qsTr("Damage"), value: editingPowerup.operations.Decrease }
    ]

    property bool editingActive: editingPowerup.powerupUuid.length > 0

    Data.PowerupItem {
        id: editingPowerup
    }

    Rectangle {
        anchors.fill: parent
        color: "#101b2c"
    }

    function indexForValue(list, value) {
        for (var i = 0; i < list.length; ++i) {
            if (list[i].value === value)
                return i
        }
        return 0
    }

    function cardColorHex(name) {
        var palette = {
            blue: "#448aff",
            red: "#ef5350",
            green: "#81c784",
            yellow: "#ffeb3b"
        }
        var key = (name || "blue").toLowerCase()
        return palette[key] || palette.blue
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

    function cloneBlockArray(items) {
        var clone = []
        if (!Array.isArray(items))
            return clone
        for (var i = 0; i < items.length; ++i) {
            var entry = items[i]
            if (entry && entry.row !== undefined && entry.col !== undefined)
                clone.push({ row: entry.row, col: entry.col })
        }
        return clone
    }

    function isBlockSelected(row, col) {
        if (editingPowerup.powerupTargetSpec !== editingPowerup.targetSpecs.Blocks)
            return false
        if (!Array.isArray(editingPowerup.powerupTargetSpecData))
            return false
        for (var i = 0; i < editingPowerup.powerupTargetSpecData.length; ++i) {
            var block = editingPowerup.powerupTargetSpecData[i]
            if (block && block.row === row && block.col === col)
                return true
        }
        return false
    }

    function toggleBlock(row, col) {
        if (editingPowerup.powerupTargetSpec !== editingPowerup.targetSpecs.Blocks)
            return
        var next = []
        var removed = false
        var existing = Array.isArray(editingPowerup.powerupTargetSpecData) ? editingPowerup.powerupTargetSpecData : []
        for (var i = 0; i < existing.length; ++i) {
            var block = existing[i]
            if (block && block.row === row && block.col === col)
                removed = true
            else
                next.push(block)
        }
        if (!removed)
            next.push({ row: row, col: col })
        editingPowerup.powerupTargetSpecData = next
    }

    function applyEditorRecord(record) {
        if (!record)
            return
        editingPowerup.powerupUuid = record.powerupUuid || ""
        editingPowerup.powerupName = record.powerupName || ""
        editingPowerup.powerupTarget = record.powerupTarget || editingPowerup.targets.Self
        var specData = deserializeSpecData(record.powerupTargetSpecData)
        editingPowerup.setTargetSpec(record.powerupTargetSpec || editingPowerup.targetSpecs.PlayerHealth,
                                     specData)
        editingPowerup.powerupCardHealth = record.powerupCardHealth || 0
        editingPowerup.powerupActualAmount = record.powerupActualAmount || 0
        editingPowerup.powerupOperation = record.powerupOperation || editingPowerup.powerupOperation
        editingPowerup.powerupIsCustom = record.powerupIsCustom !== undefined ? !!record.powerupIsCustom : true
        editingPowerup.powerupCardColor = record.powerupCardColor || "blue"
        editingPowerup.powerupHeroRowSpan = record.powerupHeroRowSpan || 1
        editingPowerup.powerupHeroColSpan = record.powerupHeroColSpan || 1
        editingPowerup.updateEnergyRequirement()
    }

    function loadPowerupFromDatabase(uuid) {
        if (!uuid)
            return
        var record = catalog.database.fetchPowerup(uuid)
        if (record)
            applyEditorRecord(record)
    }

    function clearEditor() {
        editingPowerup.powerupUuid = ""
        editingPowerup.powerupName = ""
        editingPowerup.powerupTarget = editingPowerup.targets.Self
        editingPowerup.setTargetSpec(editingPowerup.targetSpecs.PlayerHealth, null)
        editingPowerup.powerupCardHealth = 0
        editingPowerup.powerupActualAmount = 0
        editingPowerup.powerupIsCustom = true
        editingPowerup.powerupCardColor = "blue"
        editingPowerup.powerupHeroRowSpan = 1
        editingPowerup.powerupHeroColSpan = 1
        editingPowerup.updateEnergyRequirement()
    }

    function handleNewPowerup() {
        var record = catalog.database.createPowerup({ powerupIsCustom: true })
        catalog.refresh()
        applyEditorRecord(record)
    }

    function buildPayloadFromEditor() {
        return {
            powerupUuid: editingPowerup.powerupUuid,
            powerupName: editingPowerup.powerupName,
            powerupTarget: editingPowerup.powerupTarget,
            powerupTargetSpec: editingPowerup.powerupTargetSpec,
            powerupTargetSpecData: editingPowerup.powerupTargetSpec === editingPowerup.targetSpecs.Blocks
                    ? cloneBlockArray(editingPowerup.powerupTargetSpecData)
                    : editingPowerup.powerupTargetSpec === editingPowerup.targetSpecs.PlayerPowerupInGameCards
                        ? editingPowerup.powerupTargetSpecData
                        : null,
            powerupCardHealth: editingPowerup.powerupCardHealth,
            powerupActualAmount: editingPowerup.powerupActualAmount,
            powerupOperation: editingPowerup.powerupOperation,
            powerupIsCustom: editingPowerup.powerupIsCustom,
            powerupCardColor: editingPowerup.powerupCardColor,
            powerupHeroRowSpan: editingPowerup.powerupHeroRowSpan,
            powerupHeroColSpan: editingPowerup.powerupHeroColSpan
        }
    }

    function handleSavePowerup() {
        if (!editingActive)
            return
        var payload = buildPayloadFromEditor()
        var saved = catalog.database.savePowerup(payload)
        catalog.refresh()
        if (saved)
            applyEditorRecord(saved)
    }

    function handleDeletePowerup() {
        if (!editingActive)
            return
        var uuid = editingPowerup.powerupUuid
        if (!uuid)
            return
        catalog.database.deletePowerup(uuid)
        catalog.refresh()
        clearEditor()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Label {
                text: qsTr("Powerup Editor")
                font.pixelSize: 28
                font.bold: true
                color: "#ffffff"
            }

            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("Close")
                onClicked: powerupEditor.closeRequested()
            }
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("Browse predefined powerups and custom creations. Select one or create a new powerup to edit its configuration.")
            wrapMode: Text.WordWrap
            color: "#b0bec5"
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24

            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: 360
                spacing: 12

                Text {
                    text: qsTr("Powerup Catalog")
                    font.pixelSize: 18
                    font.bold: true
                    color: "#ffffff"
                }

                UI.PowerupCatalog {
                    id: catalog
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onPowerupChosen: function(record) {
                        if (record && record.powerupUuid)
                            loadPowerupFromDatabase(record.powerupUuid)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                RowLayout {
                    spacing: 8
                    Button {
                        text: qsTr("New Powerup")
                        onClicked: handleNewPowerup()
                    }
                    Button {
                        text: qsTr("Save Changes")
                        enabled: editingActive
                        onClicked: handleSavePowerup()
                    }
                    Button {
                        text: qsTr("Delete Powerup")
                        enabled: editingActive && editingPowerup.powerupIsCustom
                        onClicked: handleDeletePowerup()
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: editingActive ? editorComponent : placeholderComponent
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            Button {
                text: qsTr("Return to Menu")
                onClicked: powerupEditor.closeRequested()
            }
        }
    }

    Component {
        id: placeholderComponent
        Item {
            anchors.fill: parent
            Text {
                anchors.centerIn: parent
                width: parent.width * 0.6
                text: qsTr("Select a powerup from the catalog or create a new powerup to begin editing.")
                color: "#b0bec5"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Component {
        id: editorComponent
        ScrollView {
            clip: true
            ColumnLayout {
                id: editorForm
                width: parent.width
                spacing: 18


                RowLayout {
                    Layout.fillWidth: true
                    spacing: 24

                    UI.PowerupCard {
                        Layout.preferredWidth: 200
                        Layout.preferredHeight: 280
                        powerupUuid: editingPowerup.powerupUuid
                        powerupName: editingPowerup.powerupName
                        powerupTarget: editingPowerup.powerupTarget
                        powerupTargetSpec: editingPowerup.powerupTargetSpec
                        powerupTargetSpecData: editingPowerup.powerupTargetSpecData
                        powerupCardHealth: editingPowerup.powerupCardHealth
                        powerupActualAmount: editingPowerup.powerupActualAmount
                        powerupOperation: editingPowerup.powerupOperation
                        powerupIsCustom: editingPowerup.powerupIsCustom
                        powerupCardEnergyRequired: editingPowerup.powerupCardEnergyRequired
                        powerupCardColor: editingPowerup.powerupCardColor
                        powerupHeroRowSpan: editingPowerup.powerupHeroRowSpan
                        powerupHeroColSpan: editingPowerup.powerupHeroColSpan
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: qsTr("Editing: %1").arg(editingPowerup.powerupName.length ? editingPowerup.powerupName : editingPowerup.powerupUuid)
                            font.pixelSize: 18
                            color: "#ffffff"
                        }

                        Text {
                            text: qsTr("Energy Cost: %1").arg(editingPowerup.powerupCardEnergyRequired)
                            font.pixelSize: 14
                            color: "#64ffda"
                        }
                    }
                }

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true

                    Label { text: qsTr("UUID") }
                    TextField {
                        text: editingPowerup.powerupUuid
                        readOnly: true
                        selectByMouse: true
                    }

                    Label { text: qsTr("Name") }
                    TextField {
                        text: editingPowerup.powerupName
                        placeholderText: qsTr("Enter powerup name")
                        onTextChanged: editingPowerup.powerupName = text
                    }

                    Label { text: qsTr("Card Color") }
                    ComboBox {
                        model: cardColorOptions
                        textRole: "label"
                        valueRole: "value"
                        currentIndex: indexForValue(cardColorOptions, editingPowerup.powerupCardColor)
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < cardColorOptions.length)
                                editingPowerup.powerupCardColor = cardColorOptions[currentIndex].value
                        }
                    }

                    Label { text: qsTr("Hero Rows") }
                    SpinBox {
                        from: 1
                        to: 6
                        value: editingPowerup.powerupHeroRowSpan
                        onValueChanged: editingPowerup.powerupHeroRowSpan = Math.max(1, Math.min(6, value))
                    }

                    Label { text: qsTr("Hero Columns") }
                    SpinBox {
                        from: 1
                        to: 6
                        value: editingPowerup.powerupHeroColSpan
                        onValueChanged: editingPowerup.powerupHeroColSpan = Math.max(1, Math.min(6, value))
                    }

                    Label { text: qsTr("Target") }
                    ComboBox {
                        model: targetOptions
                        textRole: "label"
                        valueRole: "value"
                        currentIndex: indexForValue(targetOptions, editingPowerup.powerupTarget)
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < targetOptions.length)
                                editingPowerup.powerupTarget = targetOptions[currentIndex].value
                        }
                    }

                    Label { text: qsTr("Target Spec") }
                    ComboBox {
                        model: targetSpecOptions
                        textRole: "label"
                        valueRole: "value"
                        currentIndex: indexForValue(targetSpecOptions, editingPowerup.powerupTargetSpec)
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < targetSpecOptions.length)
                                editingPowerup.setTargetSpec(targetSpecOptions[currentIndex].value, editingPowerup.powerupTargetSpecData)
                        }
                    }

                    Label { text: qsTr("Operation") }
                    ComboBox {
                        model: operationOptions
                        textRole: "label"
                        valueRole: "value"
                        currentIndex: indexForValue(operationOptions, editingPowerup.powerupOperation)
                        enabled: editingPowerup.powerupTarget === editingPowerup.targets.Enemy
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < operationOptions.length)
                                editingPowerup.powerupOperation = operationOptions[currentIndex].value
                        }
                    }

                    Label { text: qsTr("Card Health") }
                    SpinBox {
                        from: 0
                        to: 200
                        value: editingPowerup.powerupCardHealth
                        onValueChanged: editingPowerup.powerupCardHealth = value
                    }

                    Label { text: qsTr("Custom") }
                    CheckBox {
                        checked: editingPowerup.powerupIsCustom
                        onToggled: editingPowerup.powerupIsCustom = checked
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: qsTr("Powerup Amount: %1").arg(editingPowerup.powerupActualAmount)
                        color: "#e8eaf6"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Slider {
                            from: 0
                            to: 200
                            stepSize: 1
                            value: editingPowerup.powerupActualAmount
                            Layout.fillWidth: true
                            onMoved: editingPowerup.powerupActualAmount = Math.round(value)
                            onValueChanged: {
                                if (!pressed)
                                    editingPowerup.powerupActualAmount = Math.round(value)
                            }
                        }
                        Label {
                            text: editingPowerup.powerupActualAmount
                            color: "#64ffda"
                        }
                    }
                }

                ColumnLayout {
                    visible: editingPowerup.powerupTargetSpec === editingPowerup.targetSpecs.PlayerPowerupInGameCards
                    spacing: 8

                    Text {
                        text: qsTr("Target Powerup Card Color")
                        color: "#ffffff"
                    }

                    ComboBox {
                        model: cardColorOptions
                        textRole: "label"
                        valueRole: "value"
                        Layout.preferredWidth: 200
                        currentIndex: indexForValue(cardColorOptions, typeof editingPowerup.powerupTargetSpecData === "string" ? editingPowerup.powerupTargetSpecData : "blue")
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < cardColorOptions.length)
                                editingPowerup.powerupTargetSpecData = cardColorOptions[currentIndex].value
                        }
                    }
                }

                ColumnLayout {
                    visible: editingPowerup.powerupTargetSpec === editingPowerup.targetSpecs.Blocks
                    spacing: 8

                    Text {
                        text: qsTr("Choose Blocks")
                        color: "#ffffff"
                    }

                    Grid {
                        id: blockSelectionGrid
                        rows: 6
                        columns: 6
                        rowSpacing: 2
                        columnSpacing: 2
                        Layout.preferredWidth: 240
                        Layout.preferredHeight: 240
                        Repeater {
                            model: 36
                            delegate: Rectangle {
                                readonly property int rowIndex: Math.floor(index / 6)
                                readonly property int colIndex: index % 6
                                width: (blockSelectionGrid.width - (blockSelectionGrid.columns - 1) * blockSelectionGrid.columnSpacing) / blockSelectionGrid.columns
                                height: (blockSelectionGrid.height - (blockSelectionGrid.rows - 1) * blockSelectionGrid.rowSpacing) / blockSelectionGrid.rows
                                color: isBlockSelected(rowIndex, colIndex) ? cardColorHex(editingPowerup.powerupCardColor) : "#2a3240"
                                border.width: 1
                                border.color: "#17202d"
                                radius: 2

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: toggleBlock(parent.rowIndex, parent.colIndex)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
