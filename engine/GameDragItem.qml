import QtQuick 2.15
import "."

/* this is a class of QML item types which can be dragged around when added
  to a GameScene using GameScene.addSceneDragItem(itemName, itemInstance) */
AbstractGameItem {
    id: dragItemRoot

    required property var gameScene
    required property var itemName
    required property var entry

    default property alias content: dragContentWrapper.data
    property alias contentItem: dragContentWrapper
    property real dragStartX: 0
    property real dragStartY: 0
    property real dragCurrentX: 0
    property real dragCurrentY: 0
    property bool dragActive: false

    property var payload: []
    property var animationDurationX: 200
    property var animationDurationY: 200
    property bool animationEnabledX: true
    property bool animationEnabledY: true



    signal itemDragging(string itemName, real x, real y)
    signal itemDropped(string itemName, real x, real y, real startX, real startY)
    signal itemDraggedTo(string itemName, real x, real y, var offsets)
    signal entryDestroyed(string itemName)

    anchors.fill: undefined
    implicitWidth: dragContentWrapper.implicitWidth
    implicitHeight: dragContentWrapper.implicitHeight
    width: entry.width
    height: entry.height
    x: entry.x
    y: entry.y
    z: dragActive ? 10 : 1

    Drag.active: dragActive
    Drag.source: dragItemRoot
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2


    Item {
        id: dragContentWrapper
        x: 0
        y: 0
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: implicitWidth
        height: implicitHeight
    }

    Behavior on x {
        enabled: animationEnabledX
        ParallelAnimation {
            NumberAnimation { duration: animationDurationX; easing.type: Easing.OutQuad }
            ScriptAction {
                script: function() {
                    entry.x = dragItemRoot.x
                }
            }
        }
    }

    Behavior on y {
        enabled: animationEnabledX
        ParallelAnimation {
            NumberAnimation { duration: animationDurationY; easing.type: Easing.OutQuad }
            ScriptAction {
                script: function() {
                    entry.y = dragItemRoot.y
                }
            }
        }
    }






    MouseArea {
        property var dragAxis: "XAxis"
        drag.target: parent;
        drag.axis: Drag.XAndYAxis
       /* drag.minimumX: x - width * 2
        drag.maximumX: x + width * 2
        drag.minimumY: y - height * 2
        drag.maximumY: y + height * 2 */
        drag.filterChildren: true
        anchors.fill: parent
        onPressed: function(event) {
          //  drag.active = true
            dragStartX = event.x;
            dragStartY = event.y;
            dragActive = true;
            itemDragging(itemName, event.x, event.y)
        }
        onMouseXChanged: {
            var offsets = {x: Math.abs(mouseX - dragStartX), y: Math.abs(mouseY - dragStartY) }
            itemDraggedTo(itemName, mouseX, mouseY, offsets)

        }
        onMouseYChanged: {
            var offsets = {x: Math.abs(mouseX - dragStartX), y: Math.abs(mouseY - dragStartY) }
            itemDraggedTo(itemName, mouseX, mouseY, offsets)
        }
        onReleased: function(event) {
            parent = contentItem.Drag.target !== null ? contentItem.Drag.target : dragItemRoot
            dragActive = false;
            itemDropped(itemName, event.x, event.y, dragStartX, dragStartY)
        }
    }
    function destroySceneItem() {
        entryDestroyed(dragItemRoot.itemName)
    }

}
