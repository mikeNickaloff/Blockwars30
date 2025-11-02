// GameFactory.js
.pragma library

let _seq = 0;
function uid(prefix) {
    // Stable-enough unique-ish token for this process
    const t = Date.now().toString(36);
    const s = (_seq++ & 0xFFFF).toString(36).padStart(3, "0");
    return `${prefix}_${t}_${s}`;
}

/**
 * createBlock
 * Create UI.Block, then Engine.GameDragItem with that block as 'entry'.
 *
 * @param {Component} blockComp       Component for UI.Block
 * @param {Component} dragComp        Component for Engine.GameDragItem
 * @param {Item}      parent          Parent for the created drag item (final visual parent)
 * @param {QtObject}  gameScene       Scene object exposing addSceneDragItem(name, item)
 * @param {Object}    opts            { color, width, height, x, y, z, namePrefix, blockProps, dragProps }
 * @return {Item}     The Engine.GameDragItem instance
 */
function createBlock(blockComp, dragComp, parent, gameScene, opts) {
    opts = opts || {};
    const width  = opts.width  || 64;
    const height = opts.height || 64;
    const x      = (opts.x !== undefined) ? opts.x : Math.random() * 300;
    const y      = (opts.y !== undefined) ? opts.y : 0 -  Math.random() * 300;
    const z      = (opts.z !== undefined) ? opts.z : 4;
    const color  = opts.color || "red";
    const namePrefix = opts.namePrefix || "block";
    const spawnFromAbove = !!opts.spawnFromAbove;
    const dropOffsetY = spawnFromAbove
        ? (opts.dropOffsetY !== undefined ? opts.dropOffsetY : height)
        : 0;
    const targetX = x;
    const targetY = y;
    const spawnY = spawnFromAbove ? (targetY - dropOffsetY) : targetY;

    // Generate unique runtime names. QML 'id' is compile-time; use objectName/itemName.
    const blockName = uid(`${namePrefix}_core`);
    const dragName  = uid(`${namePrefix}_drag`);

    // 1) Create the block FIRST, so we can feed it into the required 'entry' property.
    const block = blockComp.createObject(parent, Object.assign({
        objectName: blockName,
        itemName: blockName,
        gameScene: gameScene,
        width: width,
        height: height,
        // your UI.Block API
        blockColor: color
    }, opts.blockProps || {}));

    if (!block) throw new Error("Failed to create UI.Block");

    // 2) Create the drag item with required props set at creation time.
    const dragItem = dragComp.createObject(parent, Object.assign({
                                                                     objectName: dragName,
                                                                     itemName: dragName,
                                                                     gameScene: gameScene,
                                                                     entry: block,    // required
                                                                     width: width,
                                                                     height: height,

                                                                     x: targetX,
                                                                     y: spawnY,
                                                                     z: z
                                                                 }, opts.dragProps || {}));

    block.blockDestroyed.connect(dragItem.destroy)

    if (!dragItem) {
        block.destroy();
        throw new Error("Failed to create Engine.GameDragItem");
    }

    // 3) Reparent the block under the drag item so visuals move together.
    block.parent = dragItem;

    if (spawnFromAbove && dropOffsetY !== 0) {
        let dropFinalized = false;
        const finalizeDrop = function() {
            if (dropFinalized) return;
            dropFinalized = true;
            dragItem.visible = true;
            dragItem.opacity = 1;
            dragItem.y = targetY;
            dragItem.dropInProgress = false;
            if (block && Object.prototype.hasOwnProperty.call(block, "blockState") && block.blockState === "animating") {
                block.blockState = "idle";
            }
        };

        dragItem.visible = false;
        dragItem.opacity = 0;
        dragItem.dropInProgress = true;
        dragItem.dropOffsetY = dropOffsetY;
        dragItem.targetY = targetY;
        if (block && Object.prototype.hasOwnProperty.call(block, "blockState")) {
            block.blockState = "animating";
        }

        Qt.callLater(function() {
            if (!dragItem || dropFinalized) return;
            dragItem.visible = true;
            dragItem.opacity = 1;
            dragItem.y = targetY;
        });

        dragItem.yChanged.connect(function(newValue) {
            if (dropFinalized) return;
            if (Math.abs(newValue - targetY) < 0.5) {
                finalizeDrop();
            }
        });

        if (block && block.blockStateChanged && typeof block.blockStateChanged.connect === "function") {
            block.blockStateChanged.connect(function(newState) {
                if (dropFinalized) return;
                if (newState !== "animating") {
                    finalizeDrop();
                }
            });
        }
        if (block && block.modifiedBlockGridCell) {
            block.modifiedBlockGridCell.connect(function() {
                console.log("Detected block modified row/column signal")
                var cellPos = parent.cellPosition(block.row, block.column)
                block.x = cellPos.x
                block.y = cellPos.y
            });
        }
        const dropDuration = (opts.dropDurationY !== undefined)
            ? Math.max(1, opts.dropDurationY)
            : Math.max(1, dragItem.animationDurationY || 200);

        const dropTimer = Qt.createQmlObject(
            'import QtQuick 2.15; Timer { interval: ' + dropDuration + '; repeat: false; running: true }',
            dragItem,
            'BlockDropFinalizeTimer'
        );

        dropTimer.triggered.connect(function() {
            finalizeDrop();
            if (dropTimer) dropTimer.destroy();
        });
    }

    // Optional convenience string if some legacy code references names
    //dragItem.entryName = block.objectName;

    // 4) Register with the scene
    if (gameScene && typeof gameScene.addSceneDragItem === "function") {
        gameScene.addSceneDragItem(dragItem.itemName, dragItem);
    }

    return dragItem;
}
