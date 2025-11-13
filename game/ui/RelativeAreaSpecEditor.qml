import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ColumnLayout {
    id: editor
    spacing: 6
    property var specData: ({ rows: 1, columns: 1, distance: 6 })
    property bool targetIsEnemy: false
    property bool __syncing: false
    property int rowsValue: 1
    property int columnsValue: 1
    property int distanceValue: 6

    signal specChanged(var spec)

    function clampDistance(value) {
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

    function clampDimension(value) {
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

    function syncFromSpec(source) {
        var payload = source && typeof source === "object" ? source : {}
        __syncing = true
        rowsValue = clampDimension(payload.rows !== undefined ? payload.rows : payload.rowCount)
        columnsValue = clampDimension(payload.columns !== undefined ? payload.columns : payload.colCount)
        distanceValue = clampDistance(payload.distance !== undefined ? payload.distance : payload.rowOffset)
        __syncing = false
    }

    function emitSpecChange() {
        if (__syncing)
            return
        specChanged({
                        rows: rowsValue,
                        columns: columnsValue,
                        distance: distanceValue
                    })
    }

    function summaryText() {
        var magnitude = Math.abs(distanceValue)
        if (distanceValue === 0)
            return qsTr("The area stays aligned with the hero.")
        if (distanceValue > 0) {
            if (targetIsEnemy)
                return qsTr("Targets the mirrored board %1 rows ahead, wrapping across the gap.").arg(magnitude)
            return qsTr("Targets %1 rows ahead of the hero.").arg(magnitude)
        }
        return qsTr("Targets %1 rows behind the hero.").arg(magnitude)
    }

    Component.onCompleted: syncFromSpec(specData)
    onSpecDataChanged: syncFromSpec(specData)

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Label {
            text: qsTr("Area Rows")
            color: "#e8eaf6"
            Layout.preferredWidth: 120
        }
        SpinBox {
            from: 1
            to: 5
            value: rowsValue
            onValueChanged: {
                rowsValue = clampDimension(value)
                emitSpecChange()
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Label {
            text: qsTr("Area Columns")
            color: "#e8eaf6"
            Layout.preferredWidth: 120
        }
        SpinBox {
            from: 1
            to: 5
            value: columnsValue
            onValueChanged: {
                columnsValue = clampDimension(value)
                emitSpecChange()
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Label {
            text: qsTr("Row Offset")
            color: "#e8eaf6"
            Layout.preferredWidth: 120
        }
        SpinBox {
            from: -6
            to: 6
            value: distanceValue
            onValueChanged: {
                distanceValue = clampDistance(value)
                emitSpecChange()
            }
        }
    }

    Text {
        Layout.fillWidth: true
        color: "#b0bec5"
        wrapMode: Text.WordWrap
        text: summaryText()
    }
}
