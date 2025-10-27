import QtQuick
import QtQml.Models
import QtQml

DropArea {
    id: dropItemRoot
    required property var gameScene
    required property var itemName
    default property alias content: contentWrapper.data
    property alias contentItem: contentWrapper

    property bool containsDrag: dropItemRoot.containsDrag
    property bool autoSnap: true
    signal dragItemEntered(var itemName, var dragEvent)
    signal dragItemExited(var itemName, var dragEvent)

    property var entry
    Item {
        id: contentWrapper
        anchors.fill: parent

    }
    onEntered: function(drag) { dropItemRoot.dragItemEntered(itemName, drag) }
    onExited: function(drag) { dropItemRoot.dragItemExited(itemName, drag) }


    function isGameDragItem(item) {
        return item && item.dragParent !== undefined && item.gameScene !== undefined;
    }

    function snapItemToCenter(dragItem) {
        if (!dragItem || !dragItem.parent)
            return;
        var parentItem = dragItem.parent;
        var centerPoint = dropItemRoot.mapToItem(parentItem, dropItemRoot.width / 2, dropItemRoot.height / 2);
        var newX = centerPoint.x - dragItem.width / 2;
        var newY = centerPoint.y - dragItem.height / 2;
        dragItem.x = newX;
        dragItem.y = newY;
        if (dragItem.entry) {
            if (dragItem.entry.hasOwnProperty("x")) {
                dragItem.entry.x = newX;
            }
            if (dragItem.entry.hasOwnProperty("y")) {
                dragItem.entry.y = newY;
            }
        }
    }




}


