import QtQuick 2.15
import "../../engine" as Engine
import "../../lib" as Lib
import "." as UI
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
        move: Transition {
            NumberAnimation { properties: "x,y"; duration: 1000
            }
        }
        Repeater {
            id: blockRepeater
            model: blocksModel

             Engine.GameDragItem {
                required property var model
                required property var index
                property var rootObject: root
                property var blocksModel: root.blocksModel
                id: delegate

                gameScene: debugScene
                itemName: "block_dragItem_" + index
                width: 64
                height: 64
                x: 0
                y: 0
                z: 4

                entry:  redBlock
                payload: ["itemName"]
                property var myIndex: index

                UI.Block {
                           id: redBlock
                           blockColor: model.color
                           itemName: "block_" + index
                           gameScene: root.gameScene
                           width: 64
                           height: 64
                           onBlockStateChanged: {
                               if (blockState == "destroyed") {
                                delegate.entry.blockDestroyed(itemName);
                               }
                           }
                       }


                function transmitDestroyEntry(entryItemName) {
                    rootObject.blocksModel.remove(delegate.myIndex, 1)
                    rootObject.gameScene.removeSceneItem(delegate.itemName)
                }
                Component.onCompleted: {
                    delegate.rootObject.gameScene.addSceneDragItem(delegate.itemName, delegate);
                    delegate.entry.blockDestroyed.connect(delegate.transmitDestroyEntry)


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
        const colors = ["red","blue","green","yellow"];
        while (blocksModel.count < 36) {
            var i = blocksModel.count;
            blocksModel.append({ color: colors[i % colors.length] });
    }
    }

}
