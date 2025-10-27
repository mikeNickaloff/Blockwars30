import QtQuick 2.15

Item {
    id: sceneRoot
    property var sceneWidth
    property var sceneHeight
    property var parentScene
    property var sceneName
    property var sceneItems: ({})
    property var activeDrag: ({ source: null, target: null, exiting: false })


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
        itemObject.itemDraggedTo.connect(handleDragItemMoved)
        itemObject.itemDropped.connect(handleDragItemDropped)
        console.log("Added",itemName,"to scene", sceneRoot)
    }
    function addSceneDropItem(itemName, itemObject) {
        sceneItems[itemName] = itemObject
        itemObject.gameScene = sceneRoot
        itemObject.dragItemEntered.connect(handleDropItemEntered)
        itemObject.dragItemExited.connect(handleDropItemExited)
    }
    function handleDropItemEntered(_itemName, _dragEvent) {
        activeDrag.target = getSceneItem(_itemName)
        activeDrag.exiting = false;
    }
    function handleDropItemExited(_itemName, _dragEvent) {
        activeDrag.exiting = true;
    }
    function handleDragItemStartDrag(itemName,_x, _y) {
        console.log("Game Scene detected drag start", itemName, _x, _y)
        activeDrag.source = getSceneItem(itemName)
        activeDrag.target = null
    }
    function handleDragItemMoved(itemName, _x, _y, offsets) {
        if (activeDrag.exiting) {
            activeDrag.target = null
            activeDrag.exiting = false
            console.log("Game Scene detected drag exit from Drop Item")
        }
        //console.log("Game Scene detected drag move",itemName, _x, _y, JSON.stringify(offsets));
    }
    function handleDragItemDropped(itemName, _x, _y, _startx, _starty) {
        if (activeDrag.target == null) {
            console.log("Game Scene detected drop on non-drop item. Fail.");
        } else {
            console.log("Game Scene detected item drop",itemName, "at", _x, _y, "started at", _startx, _starty, getSceneItem(itemName), "Drop target:",activeDrag.target);
        }
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


}
