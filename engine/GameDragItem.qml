import QtQuick 2.15


Item {
    id: dragItemRoot
    required property var dragParent
    required property var gameScene
    required property var itemName
    anchors.fill: undefined
    implicitWidth: dragContentWrapper.implicitWidth
    implicitHeight: dragContentWrapper.implicitHeight
    width: entry.width
    height: entry.height
    x: entry.x
    y: entry.y


    default property alias content: dragContentWrapper.data
    property alias contentItem: dragContentWrapper
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
    required property var entry

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
                entry.y = dragItemRoot.y
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



    DragHandler {
        id: dragHandler
        target: dragItemRoot
        acceptedButtons: Qt.LeftButton
        xAxis.enabled: true
        yAxis.enabled: true
        onActiveChanged: {
            if (dragHandler.active) {
                var centerPoint = mapToGlobal(dragItemRoot.width / 2, dragItemRoot.height / 2);
                dragItemRoot.dragStartX = centerPoint.x;
                dragItemRoot.dragStartY = centerPoint.y;
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
