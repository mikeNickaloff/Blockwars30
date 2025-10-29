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

    // The object pump
    Instantiator {
        id: pump
        active: true
        model: blocksModel

        // Delegate is a QtObject wrapper; creation happens in JS
        delegate: QtObject {
            // hold the created item
            property var itemRef: null

            Component.onCompleted: {
                const g = Layout.gridPos(index, {
                    cols: gridCols, cellW: cellW, cellH: cellH,
                    gapX: gapX, gapY: gapY, originX: originX, originY: originY
                });
                itemRef = Factory.createBlock(
                    blockComp,        // UI.Block
                    dragComp,         // Engine.GameDragItem
                    debugScene,       // parent directly under the scene
                    debugScene,       // scene for registration
                    {
                        color: model.color || modelData.color || "red",
                        x: g.x,
                        y: g.y,
                        width: cellW,
                        height: cellH,
                        namePrefix: "gridBlock"
                    }
                );
                instances.push(itemRef);
                     // debugScene.addSceneDragItem(itemRef.itemName, itemRef)

            }

            Component.onDestruction: {
                if (itemRef) {
                    if (itemRef.destroy) itemRef.destroy();
                    const idx = instances.indexOf(itemRef);
                    if (idx >= 0) instances.splice(idx, 1);
                }
            }
        }
    }

    // Reflow everything whenever you change layout params
    function arrangeAll() {
        for (let i = 0; i < instances.length; ++i) {
            const g = Layout.gridPos(i, {
                cols: gridCols, cellW: cellW, cellH: cellH,
                gapX: gapX, gapY: gapY, originX: originX, originY: originY
            });
            const it = instances[i];
            if (it) { it.x = g.x; it.y = g.y; it.width = cellW; it.height = cellH; }
        }
    }

    // Example: tweak columns at runtime and reflow, because why be boring
    Keys.onPressed: if (event.key === Qt.Key_Plus) { gridCols = Math.max(1, gridCols - 1); arrangeAll(); }
    Keys.onReleased: if (event.key === Qt.Key_Minus) { gridCols += 1; arrangeAll(); }

    // Initial layout sync in case something touches params after startup
    Component.onCompleted: arrangeAll()


}
