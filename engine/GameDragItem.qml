import QtQuick 2.15


AbstractGameItem {
    id: dragItemRoot
    required property var dragParent
    required property var gameScene

    property real dragStartX: 0
    property real dragStartY: 0
    property real dragCurrentX: 0
    property real dragCurrentY: 0
    z: dragHandler.active ? 10 : 1

    property var animationDurationX: 200
    property var animationDurationY: 200
    property bool animationEnabledX: true
    property bool animationEnabledY: true
    property var handler: dragItemRoot.dragHandler
    property var entry: null

  //  radius: 3


    Behavior on x {
        enabled: animationEnabledX
        NumberAnimation { duration: animationDurationX; easing.type: Easing.OutQuad }
    }

    Behavior on y {
        enabled: animationEnabledX
        NumberAnimation { duration: animationDurationY; easing.type: Easing.OutQuad }
    }



    DragHandler {
        id: dragHandler
        onActiveChanged: {
            //icon.isAlreadyDisplaced = false;
            if (dragHandler.active) {
                var centerPoint = mapToGlobal(dragItemRoot.implicitWidth / 2, dragItemRoot.implicitHeight / 2);
                dragItemRoot.dragStartX = centerPoint.x;
                dragItemRoot.dragStartY = centerPoint.y;
                // icon.sourceIndex = icon.visualIndex;
                // icon.targetIndex = icon.visualIndex;
                if (dragItemRoot.dragParent && dragItemRoot.dragParent.beginDrag)
                    dragItemRoot.dragParent.beginDrag(dragItemRoot);
            } else {
                if (dragItemRoot.entry && dragItemRoot.dragParent && dragItemRoot.dragParent.positionEntry)
                    dragItemRoot.dragParent.positionEntry(dragItemRoot.entry, true);
                if (dragItemRoot.dragParent && dragItemRoot.dragParent.endDrag)
                    dragItemRoot.dragParent.endDrag(dragItemRoot);
            }
        }
    }

    Drag.active: dragHandler.active
    Drag.source: dragItemRoot
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2
}
