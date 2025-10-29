import QtQuick 2.15
import "../../engine" as Engine

Engine.GameDropItem {
    id: cellRoot


    property int rowIndex: -1
    property int columnIndex: -1
    property Item battleGrid: null
    property var assignedItem: null
    property bool __gridRegistered: false
    property color idleColor: "transparent"
    property color hoverColor: "#33FFFFFF"
    property color occupiedColor: "#3340FF80"
    property color borderColor: "#335D6C7C"
    property bool showDebugBorder: false

    signal assignmentChanged(var item)

    implicitWidth: 64
    implicitHeight: 64

    onAssignedItemChanged: assignmentChanged(assignedItem)

    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        radius: 6
        border.width: showDebugBorder ? 1 : 0
        border.color: showDebugBorder ? borderColor : "transparent"
        color: cellRoot.containsDrag ? hoverColor : (assignedItem ? occupiedColor : idleColor)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    function hasItem() {
        return assignedItem !== null && assignedItem !== undefined;
    }

    function clearAssignment() {
        assignedItem = null;
    }

    function centerItem(dragItem) {
        if (!dragItem)
            return;
        snapItemToCenter(dragItem);
    }
}
