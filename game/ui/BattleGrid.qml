import QtQuick 2.15
import "../../engine" as Engine
import "../../lib" as Lib
import "." as UI
import "../data" as Data
import "../factory.js" as Factory
import "../layouts.js" as Layout
import QtQuick.Layouts






Item {
    id: root
    width: 400; height: 400

    // Your scene (must expose addSceneDragItem(name, item))
    property var gameScene

    // Grid params. Tweak at runtime if you enjoy power.
    property int gridCols: 6
    property int gridRows: 6
    property int cellW: 50
    property int cellH: 50
    property int gapX: 2
    property int gapY: 2
    property int originX: 40
    property int originY: 40
    readonly property int gridHeight: (gridRows * cellH) + Math.max(0, gridRows - 1) * gapY
    property alias blocksModel: blocksModel
    // Keep references if you want to reflow or mutate later
    property var instances: []
    property int blockSequence: 0
    property string launchDirection: "down"
    readonly property var blockPalette: ["red", "blue", "green", "yellow"]
    readonly property string blockIdPrefix: "grid_block"

    readonly property var stateList: [
        "init", "initializing", "initialized",
        "precompact", "precompacting", "precompacted",
        "compact", "compacting", "compacted",
        "fill", "filling", "filled",
        "fastfill", "fastfilling", "fastfilled",
        "match", "matching", "matched",
        "launch", "launching", "launched",
        "fastlaunch", "fastlaunching", "fastlaunched",
        "powerup", "poweruping", "poweruped",
        "swap", "swapping", "swapped",
        "aimove", "aimoving", "aimoved",
        "ready", "wait", "waiting"
    ]
    property string currentState: "init"


    property var battleQueue: []
    property bool queueProcessing: false
    property var activeQueueItem: null





    // Components for factory injection
    Component { id: dragComp;  Engine.GameDragItem { } }
    Component { id: blockComp; UI.Block { } }



    // Your model. Could be ListModel, JS array, or C++ model.
    ListModel {
        id: blocksModel
        // 36 entries for 6x6, but do whatever
        Component.onCompleted: {
            fillGrid();
        }
    }
    Grid {
        anchors.fill: parent
        rows: 6
        columns: 6
        flow: Grid.TopToBottom
        layoutDirection: Qt.RightToLeft
        move: Transition {
            NumberAnimation { properties: "x,y"; duration: 1000
            }
        }
        Repeater {
            id: blockRepeater

            model: 36

            delegate: Engine.GameDragItem {
               required property var model
               required property var index
               property var rootObject: root


               id: delegate

               gameScene: root.gameScene
               itemName: "block_dragItem_" + index
               width: 64
               height: 64
               x: 0
               y: 0
               z: 4

               entry:  blockEntry
               payload: ["itemName"]
               property int myIndex: index






               UI.Block {
                   id: blockEntry
                   blockColor:"blue"
                   itemName: delegate.blockId
                   gameScene: root.gameScene
                   width: 64
                   height: 64
                   row: model.row
                   column: model.column
                   maxRows: root.gridRows
                   onBlockStateChanged: {
                       if (blockState === "destroyed") {
                           delegate.entry.blockDestroyed(itemName);
                       }
                   }
               }
               Component.onCompleted: {
                   delegate.rootObject.gameScene.addSceneDragItem(delegate.itemName, delegate);
               }
               Component.onDestruction: {
                   if (delegate.rootObject && delegate.rootObject.gameScene && typeof delegate.rootObject.gameScene.removeSceneItem === "function") {
                       delegate.rootObject.gameScene.removeSceneItem(delegate.itemName);
                       const dropName = delegate.entry && delegate.entry.itemName ? (delegate.entry.itemName + "_drop") : null;
                       if (dropName)
                           delegate.rootObject.gameScene.removeSceneItem(dropName);
                   }
               }




            }



        }
    }




    function getBlockEntryAt(row, column) {
        if (row < 0 || row >= gridRows || column < 0 || column >= gridCols)
            return null;

        const index = (column * gridRows) + row;
        const block = blockRepeater.itemAt(index);
        return block ? block.entry : null;
    }
    function getBlockWrapper(row, column) {
        if (row < 0 || row >= gridRows || column < 0 || column >= gridCols)
            return null;

        const index = (column * gridRows) + row;
        const block = blockRepeater.itemAt(index);
        return block ? block : null;
    }

    function fillGrid() {
        console.log("Filling Grid Model", blocksModel);
        for (var i=0; i<6; i++) {
            for (var u=0; u<6; u++) {
                if (!getBlockWrapper(i, u)) {
                    Factory.createBlock(blockComp, dragComp, gameScene, {row: i, column: u, gameScene: gameScene, blockColor: "green"})
                }
            }
        }
    }



    function indexFor(row, column) {
        if (row < 0 || column < 0)
            return -1;
        return (column * gridRows) + row;
    }

    function findModelIndexByItemName(blockId) {
        for (var i = 0; i < blocksModel.count; i++) {
            const element = blocksModel.get(i);
            if (element.blockId === blockId)
                return i;
        }
        return -1;
    }

    function findWrapperByItemName(blockId) {
        for (var i = 0; i < blockRepeater.count; i++) {
            const wrapper = blockRepeater.itemAt(i);
            if (wrapper && wrapper.entry && wrapper.entry.itemName === blockId)
                return wrapper;
        }
        return null;
    }

}
