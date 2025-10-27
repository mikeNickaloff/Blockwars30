import QtQuick 2.15

Item {
    id: sceneRoot
    property var sceneWidth
    property var sceneHeight
    property var parentScene
    property var sceneName
    property var sceneItems: ({})
    property var activeDrag: ({})

    function getSceneItem(itemName) {
        try {
            return sceneItems[itemName]
        } catch (evt) {
            console.log("ERROR: FROM:[ " + sceneName + " ] GameScene::getSceneItem(" + itemName + ") >> itemName is not an item in GameScene, use GameScene::addSceneItem(name, object) to add to GameScene")
            return null
        }
    }

    function addSceneItem(itemName, itemObject) {

        sceneItems[itemName] = itemObject
        itemObject.gameScene = sceneRoot
        itemObject.itemName = itemName
        console.log("Added",itemName,"to scene", sceneRoot)
    }
    function addSceneDragItem(itemName, itemObject) {
        sceneItems[itemName] = itemObject
        itemObject.gameScene = sceneRoot
        itemObject.itemName = itemName
        itemObject.itemDragging.connect(handleDragItemStartDrag)
        console.log("Added",itemName,"to scene", sceneRoot)
    }

    function handleDragItemStartDrag(itemName,_x, _y) {
        console.log("Game Scene detected drag start", itemName, _x, _y)
    }
    function setSceneItemProperties(itemName, propsObject) {
        var itm = getScceneItem(itemName);
        if (propsObject.x) { itm.sceneX = propsObject.x }
        if (propsObject.y) { itm.sceneY = propsObject.y }
        if (propsObject.width) { itm.itemWidth = propsObject.width }
        if (propsObject.height) { itm.itemHeight = propsObject.height }
        if (propsObject.parent) { itm.itemParent = propsObject.parent }
        if (propsObject.name) { itm.itemName = propsObject.name }

    }

    function beginDrag(dragItem, _dragPayload = []) {
        if (!dragItem || !dragItem.entry)
            return;
        activeDrag = ({})
        var dragPayload = [];
        if (_dragPayload) {
            dragPayload = dragPayload.concat(_dragPayload)
        }
        Drag.start()
        console.log("Started dragging with payload",dragPayload);

        for (var u=0; u<dragPayload.length; u++) {
            var prop = dragPayload[u];
            activeDrag[prop] = dragItem[prop]
        }
        activeDrag.dragItem = dragItem;

    }
}
