import QtQuick 2.15

Item {
    id: sceneRoot
    property var sceneWidth
    property var sceneHeight
    property var parentScene
    property var sceneName
    property var sceneItems: ({})
    property var activeDrag: ({ source: null, target: null, exiting: false })

    signal itemDragStarted(string itemName, var dragItem, real x, real y)
    signal itemDragMoved(string itemName, var dragItem, real x, real y, var offsets)
    signal itemDroppedInDropArea(string dragItemName, var dragItem, string dropItemName, var dropItem, real startX, real startY, real endX, real endY)
    signal itemEnteredNonDropArea(string dragItemName, string dropItemName)
    signal itemDroppedInNonDropArea(string dragItemName, string dropItemName, real dragStartX, real dragStartY, real dragEndX, real dragEndY)
    signal itemDroppedNowhere(string dragItemName)

    function getSceneItem(itemName) {
        try {
            return sceneItems[itemName]
        } catch (evt) {
            console.log("ERROR: FROM:[ " + sceneName + " ] GameScene::getSceneItem(" + itemName + ") >> itemName is not an item in GameScene, use GameScene::addSceneItem(name, object) to add to GameScene")
            return null
        }
    }
    Timer {
     id: dragTimer
     interval: 30
     running: false
     repeat: true
     onTriggered: {
         var dragItem = activeDrag.source

         if (!dragItem) { dragTimer.running = false; return }
         var overlap = listOverlappingItems(dragItem.itemName, "")
         for (var i=0; i<overlap.legth; i++) {
  //           console.log("Item entered non-drop area", overlap[i].itemName)
             itemEnteredNonDropArea(dragItem.itemName, overlap[i].itemName)
             if (activeDrag.target !== overlap[i]) { activeDrag.target.opacity = 1.0;  overlap[i].opacity = 0.5; activeDrag.target = overlap[i] }


         }
     }
    }
    function removeSceneItem(itemName) {

        //console.log("Removing item", itemName)
        var itm = sceneItems[itemName];
      //  itm.destroy();
        sceneItems[itemName] = null
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
        var globalXY = itemObject.mapToGlobal(0, 0)
        itemObject.sceneX = globalXY.x
        itemObject.sceneY = globalXY.y
        itemObject.xChanged.connect(function() { itemObject.sceneX = itemObject.mapToGlobal(itemObject.x, itemObject.y).x })
        itemObject.yChanged.connect(function() { itemObject.sceneY = itemObject.mapToGlobal(itemObject.x, itemObject.y).y })
        console.log("Added",itemName,"to scene", sceneRoot)
    }
    function addSceneDropItem(itemName, itemObject) {
        sceneItems[itemName] = itemObject
        itemObject.gameScene = sceneRoot
        itemObject.dragItemEntered.connect(handleDropItemEntered)
        itemObject.dragItemExited.connect(handleDropItemExited)
        var globalXY = itemObject.mapToGlobal(0, 0)
        itemObject.sceneX = globalXY.x
        itemObject.sceneY = globalXY.y
        itemObject.xChanged.connect(function() { itemObject.sceneX = itemObject.mapToGlobal(itemObject.x, itemObject.y).x })
        itemObject.yChanged.connect(function() { itemObject.sceneY = itemObject.mapToGlobal(itemObject.x, itemObject.y).y })
           console.log("Added",itemName,"to scene", sceneRoot)
    }
    function listSceneDropItemsAt(_x = -1, _y = -1, matchString = "") {
      //  console.log("looking for items with boundaries containing", _x, _y);
        var results = []
        var requirePosition = _x !== -1 && _y !== -1
        var needle = matchString ? ("" + matchString).toLowerCase() : ""

        for (var key in sceneItems) {

            var item = sceneItems[key]
            if (!item)
                continue
         //   console.log("testing",item,"dimensions to see if it contains",_x,_y)
            var itemName = item && item.itemName !== undefined ? item.itemName : key
            if (needle !== "" && ("" + itemName).toLowerCase().indexOf(needle) === -1)
                continue

            if (requirePosition) {
                var _left = item.sceneX !== undefined ? item.sceneX : (item.x !== undefined ? item.x : -1)
                var _top = item.sceneY !== undefined ? item.sceneY : (item.y !== undefined ? item.y : -1)
                var globalXY = item.mapToGlobal(_left, _top)
                var left = globalXY.x
                var top = globalXY.y

                var width = item.itemWidth !== undefined ? item.itemWidth : (item.width !== undefined ? item.width : (item.implicitWidth !== undefined ? item.implicitWidth : 0))
                var height = item.itemHeight !== undefined ? item.itemHeight : (item.height !== undefined ? item.height : (item.implicitHeight !== undefined ? item.implicitHeight : 0))
              //  console.log("> cheking if ",left,top,"with dimensions",width,height, "contains",_x,_y)
                var right = left + width
                var bottom = top + height

                if (_x < left || _x > right || _y < top || _y > bottom)
                    continue
               // console.log(">> It does!");

            }
          //  console.log(">> PASS!");
            results.push(item)
        }

        return results
    }
    function listOverlappingItems(_itemName, matchstring = "") {
        var overlaps = []
        var primary = sceneItems[_itemName]
        if (!primary || !primary.mapToGlobal)
            return overlaps

        var targetName = primary.itemName !== undefined ? primary.itemName : _itemName
        var needle = matchstring ? ("" + matchstring).toLowerCase() : ""
        var primaryBounds = calculateBounds(primary)
        if (!primaryBounds)
            return overlaps

        for (var key in sceneItems) {
            var candidate = sceneItems[key]
            if (!candidate || candidate === primary || !candidate.mapToGlobal)
                continue

            var candidateName = candidate.itemName !== undefined ? candidate.itemName : key
            if (candidateName === _itemName || candidateName === targetName)
                continue
            if (needle !== "" && ("" + candidateName).toLowerCase().indexOf(needle) === -1)
                continue

            var candidateBounds = calculateBounds(candidate)
            if (!candidateBounds)
                continue

            if (rectsOverlap(primaryBounds, candidateBounds) || rectsOverlap(candidateBounds, primaryBounds))
                overlaps.push(candidate)
        }

        return overlaps

        function calculateBounds(item) {
            var baseX = item.sceneX
            var baseY = item.sceneY
            var globalPoint = ({x: baseX, y: baseY})
            if (!globalPoint)
                return null

            var width = item.itemWidth !== undefined ? item.itemWidth : (item.width !== undefined ? item.width : (item.implicitWidth !== undefined ? item.implicitWidth : 0))
            var height = item.itemHeight !== undefined ? item.itemHeight : (item.height !== undefined ? item.height : (item.implicitHeight !== undefined ? item.implicitHeight : 0))

            return {
                left: globalPoint.x,
                top: globalPoint.y,
                right: globalPoint.x + item.width,
                bottom: globalPoint.y + item.height
            }
        }

        function rectsOverlap(a, b) {
            if (!a || !b)
                return false

            var horizontalOverlap = (a.left < b.right) && (a.right > b.left)
            var verticalOverlap = (a.top < b.bottom) && (a.bottom > b.top)

            return horizontalOverlap && verticalOverlap
        }
    }
    function handleDropItemEntered(_itemName, _dragEvent) {
        activeDrag.target = getSceneItem(_itemName)
        activeDrag.exiting = false;
           console.log(_itemName,"entered")
    }
    function handleDropItemExited(_itemName, _dragEvent) {
        activeDrag.exiting = true;
    }
    function handleDragItemStartDrag(itemName, _x, _y) {
        //console.log("Game Scene detected drag start", itemName, _x, _y)
        var dragItem = getSceneItem(itemName)
        activeDrag.source = dragItem
        activeDrag.target = null
        itemDragStarted(itemName, dragItem, dragItem.sceneX, dragItem.sceneY)
//        dragTimer.running = true;

    }
    function handleDragItemMoved(itemName, _x, _y, offsets) {
        if (activeDrag.exiting) {
            activeDrag.target = null
            activeDrag.exiting = false
            //console.log("Game Scene detected drag exit from Drop Item")
        }
        var dragItem = activeDrag.source || getSceneItem(itemName)
        itemDragMoved(itemName, dragItem, _x, _y, offsets)
        var overlap = listOverlappingItems(itemName, "")
        for (var i=0; i<overlap.legth; i++) {

            itemEnteredNonDropArea(itemName, overlap[i].itemName)
        }

        //console.log("Game Scene detected drag move",itemName, _x, _y, JSON.stringify(offsets));
    }
    function handleDragItemDropped(itemName, _x, _y, _startx, _starty) {
        var dragItem = activeDrag.source || getSceneItem(itemName)
        var dropItem = activeDrag.target
        if (dropItem == null) {
    //        console.log("Game Scene detected drop on non-drop item. Fail.");

            var globalXY = dragItem.mapToGlobal(_x, _y);

            var dropTargets = listOverlappingItems(itemName)
            if (dropTargets.length == 0) {
                itemDroppedNowhere(itemName)
            }
            for (var i=0; i<dropTargets.length; i++) {

                itemDroppedInNonDropArea(itemName, dropTargets[i].itemName, _startx, _starty, _x, _y)
            }
        } else {

            //console.log("Game Scene detected item drop", itemName, "at", _x, _y, "started at", _startx, _starty, dragItem, "Drop target:", dropItem);
            var dropItemName = dropItem.itemName !== undefined ? dropItem.itemName : null;
            itemDroppedInDropArea(itemName, dragItem, dropItemName, dropItem, _startx, _starty, _x, _y);
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
