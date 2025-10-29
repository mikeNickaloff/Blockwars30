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
            const colors = ["red","blue","green","yellow"];
            for (let i = 0; i < 36; ++i)
                append({ color: colors[i % colors.length] });
        }
    }
    GridLayout {
        anchors.fill: parent
        rows: 6
        flow: GridLayout.TopToBottom
        Repeater {
            model: blocksModel
            delegate:    Engine.GameDragItem {
                required property var model
                required property var index
                id: test_rect

                gameScene: debugScene
                itemName: "block_dragItem_" + index
                width: 64
                height: 64
                x: 0
                y: 0
                z: 4
                entry:  redBlock
                payload: ["itemName"]
                UI.Block {
                           id: redBlock
                           blockColor: model.color
                           itemName: "block_" + index
                           gameScene: root.gameScene
                           width: 64
                           height: 64
                       }


                Component.onCompleted: {
                    root.gameScene.addSceneDragItem(test_rect.itemName, test_rect);
                }
            }
        }
    }

    function getBlockEntryAt(row, column) {
        /* find the block located in the GridLayout at row, column pair and return that Item.entry */
    }

}
