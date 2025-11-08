import QtQuick 2.15
import "../../engine" as Engine
import "../../lib" as Lib
import "." as UI
import "../data" as Data
import "../factory.js" as Factory
import "../layouts.js" as Layout
import "../scripts/battlegrid.js" as BattleGridLogic
import QtQuick.Layouts
import com.blockwars 1.0
Item {
    id: root
    width: 400
    height: 400

    // Scene reference supplied by the parent view.
    property var gameScene

    signal queueItemStarted(var item)
    signal queueItemCompleted(var item, var context)
    signal wrapperLaunched(var wrapperItem)
    signal distributeBlockLaunchPayload(var payload)
    signal distributedBlockLaunchPayload(var payload)
    signal informBlockLaunchEndPoint(var payload, var endX, var endY)
    signal informPostSwapCascadeStatus(var payload)

    // Grid configuration.
    property int gridCols: 6
    property int gridRows: 6
    property int cellW: 40
    property int cellH: 40
    property int gapX: 1
    property int gapY: 1
    property int originX: 40
    property int originY: 40
    readonly property int gridHeight: (gridRows * cellH) + Math.max(0, gridRows - 1) * gapY

    property var instances: []
    property int blockSequence: 0
    property string launchDirection: "down"
    readonly property var blockPalette: ["red", "blue", "green", "yellow"]
    readonly property string blockIdPrefix: "grid_block"

    property string uuid: Factory.uid("battleGrid")
    property int mainHealthMax: 100
    property int mainHealth: mainHealthMax
    property bool postSwapCascading: false
    property var launchSequence: []
    property int launchSequenceIndex: 0
    property bool playerControlled: false

    property string currentState: "init"
    property string previousState: ""
    property bool suppressStateHandler: false
    readonly property var stateList: [
        "init", "initializing", "initialized",
        "compact", "compacting", "compacted",
        "fill", "filling", "filled",
        "match", "matching", "matched",
        "launch", "launching", "launched",
        "idle", "idling", "idled",
        "wait", "waiting", "waited"
    ]

    // Compact representation of the grid.
    property var blockMatrix: []

    property var __launchRelayRegistered: false
    property var heroPlacements: ({})
    property var heroCellMap: []

    onPlayerControlledChanged: {
        for (var idx = 0; idx < instances.length; ++idx) {
            var wrapper = instances[idx];
            if (wrapper && wrapper.enabled !== undefined)
                wrapper.enabled = playerControlled;
        }
    }

    onMainHealthChanged: {
        if (mainHealth < 0) {
            mainHealth = 0;
            return;
        }
        if (mainHealthMax > 0 && mainHealth > mainHealthMax)
            mainHealth = mainHealthMax;
    }

    onMainHealthMaxChanged: {
        if (mainHealthMax < 0)
            mainHealthMax = 0;
        if (mainHealth > mainHealthMax)
            mainHealth = mainHealthMax;
    }

    UI.GridShakeEffector {
        id: shakeEffector
        impactAmplitude: Math.max(2, cellW * 0.05)
        impactDuration: 120
        breachAmplitude: Math.max(impactAmplitude * 1.8, cellW * 0.1)
        breachDuration: 200
    }

    transform: [
        Translate {
            x: shakeEffector.offsetX
            y: shakeEffector.offsetY
        }
    ]

    onPostSwapCascadingChanged: distributePostSwapCascadeStatus()

    property var pools: []

    Component {

        id: poolComp
        Pool {
            property var colorsPool: []
            property var usedPool: [];
            currentIndex: Math.max(Math.floor(Math.random() * 1000), 100)
            function getNextBlockColor() {
                if (colorsPool.length > 0) {
                    var _color = colorsPool.shift();
                    colorsPool.push(_color);
                    return _color;
                }
            }

            Component.onCompleted: {
                for (var i=0; i<currentIndex; i++) {
                    colorsPool.push(colorAt(currentIndex - i));
                }
            }

        }
    }
    function normalizeStateName(value) {
        if (value === null || value === undefined)
            return "";
        return value.toString().trim().toLowerCase();
    }

    function stateFormsFor(stateValue) {
        const normalized = normalizeStateName(stateValue);
        const index = stateList.indexOf(normalized);
        if (index === -1)
            return null;

        const baseIndex = index - (index % 3);
        return {
            base: stateList[baseIndex],
            active: stateList[baseIndex + 1] || stateList[baseIndex],
            completed: stateList[baseIndex + 2] || stateList[baseIndex + 1] || stateList[baseIndex]
        };
    }

    function setGridStateInternal(stateName, suppressHandler) {
        const normalized = normalizeStateName(stateName);
        if (!normalized || currentState === normalized)
            return false;

        const previous = currentState;
        const suppress = suppressHandler !== undefined ? suppressHandler : true;
        if (suppress)
            suppressStateHandler = true;
        currentState = normalized;
        previousState = previous;
        if (suppress)
            suppressStateHandler = false;
        return true;
    }

    function requestState(baseState) {
        if (currentState == "wait") {
            if (gameScene.getBattleGridOffense() !== root) {
                if (baseState == "compact") { return false; }

                if (baseState == "match") { return false; }
                if (baseState == "launch") { return false; }

            }
        }
        const forms = stateFormsFor(baseState);
        if (!forms)
            return false;
        setGridStateInternal(forms.base, false);
        return true;
    }

    onCurrentStateChanged: handleStateChange(currentState, previousState)

    function handleStateChange(newState, oldState) {
        console.log("state changed from", root, "from", oldState, "to", newState);
        if (suppressStateHandler)
            return;

        previousState = oldState || "";
        stopAllStateTimers();

        const normalized = normalizeStateName(newState);

        switch (normalized) {
        case "wait":
            break;
        case "compact":
            compactColumns();
            compactStateCheckTimer.start();
            break;
        case "fill":
            fillMissingBlocks();
            fillStateCheckTimer.start();
            break;
        case "match":
            BattleGridLogic.markMatchedBlocks(root);
            matchStateCheckTimer.start();
          //  Qt.callLater(function() { evaluateMatchState(); });
            break;
        case "launch":
            prepareLaunchSequence();
            launchBlocksTimer.start();
            break;
        case "idle":
            postSwapCascading = false;
            updateBlockScenePositions();
            break;
        case "init":
            fillGrid();
            requestState("compact");
            break;
        default:
            break;
        }
    }

    function ensureMatrix() {
        if (!blockMatrix || blockMatrix.length !== gridRows) {
            var newMatrix = [];
            for (var r = 0; r < gridRows; ++r)
                newMatrix.push(new Array(gridCols));
            blockMatrix = newMatrix;
            return;
        }

        for (var idx = 0; idx < gridRows; ++idx) {
            if (!blockMatrix[idx] || blockMatrix[idx].length !== gridCols)
                blockMatrix[idx] = new Array(gridCols);
        }
    }

    function cellPosition(row, column) {
        return {
            x: originX + column * (cellW + gapX),
            y: originY + row * (cellH + gapY)
        };
    }

    function handleBlockDestroyed(event) {
        var payload = (event && typeof event === "object") ? event : { itemName: event };
        if (!payload || !payload.itemName)
            return;

        var wrapper = findWrapperByItemName(payload.itemName);
        if (!wrapper || !wrapper.entry)
            return;

        var entry = wrapper.entry;
        var reward = payload.energyAmount !== undefined && payload.energyAmount !== null
                ? payload.energyAmount
                : (entry.energyAmount !== undefined ? entry.energyAmount : 0);
        if (!reward || reward <= 0)
            return;

        var scene = gameScene;
        if (!scene) {
            entry.energyAmount = 0;
            return;
        }

        var offenseGrid = scene.getBattleGridOffense ? scene.getBattleGridOffense() : null;
        if (!offenseGrid) {
            entry.energyAmount = 0;
            return;
        }

        var sidebar = scene.sidebarForGrid ? scene.sidebarForGrid(offenseGrid) : null;
        if (!sidebar || typeof sidebar.distributeEnergy !== "function") {
            entry.energyAmount = 0;
            return;
        }

        var color = entry.blockColor || payload.blockColor || "";
        if (color)
            sidebar.distributeEnergy(color, reward);

        var placement = entry.heroBindingKey ? heroPlacementForKey(entry.heroBindingKey) : null;
        if (placement && placement.boundBlocks) {
            for (var i = 0; i < placement.boundBlocks.length; ++i) {
                var record = placement.boundBlocks[i];
                if (!record || !record.wrapper || !record.wrapper.entry)
                    continue;
                record.wrapper.entry.energyAmount = 0;
            }
            if (placement.heroItem)
                placement.heroItem.heroState = "destroyed";
        }
        entry.energyAmount = 0;
    }

    function registerBlockEntry(item) {
        if (!item)
            return;
        var entry = item.entry ? item.entry : item;
        if (!entry || entry.__battleGridSignalRegistered)
            return;

        entry.__battleGridWrapper = item.entry ? item : entry.__battleGridWrapper || null;

        var hasDestroyedSignal = entry.blockDestroyed && typeof entry.blockDestroyed.connect === "function";
        var hasStateSignal = entry.blockStateChanged && typeof entry.blockStateChanged.connect === "function";
        var hasHealthSignal = entry.healthChanged && typeof entry.healthChanged.connect === "function";
        var hasRowSignal = entry.rowChanged && typeof entry.rowChanged.connect === "function";
        var hasColumnSignal = entry.columnChanged && typeof entry.columnChanged.connect === "function";

        if (!hasDestroyedSignal && !hasStateSignal && !hasHealthSignal && !hasRowSignal && !hasColumnSignal)
            return;

        entry.__battleGridSignalRegistered = true;

        if (hasDestroyedSignal)
            entry.blockDestroyed.connect(handleBlockDestroyed);

        if (hasStateSignal) {
            entry.blockStateChanged.connect(function(newState) {
                synchronizeHeroBlockState(entry, newState);
            });
        }

        if (hasHealthSignal) {
            entry.healthChanged.connect(function() {
                synchronizeHeroBlockHealth(entry);
            });
        }

        if (hasRowSignal) {
            entry.rowChanged.connect(function() {
                synchronizeHeroBlockPosition(entry, true);
            });
        }

        if (hasColumnSignal) {
            entry.columnChanged.connect(function() {
                synchronizeHeroBlockPosition(entry, false);
            });
        }

        entry.__previousGridRow = entry.row;
        entry.__previousGridColumn = entry.column;
    }

    function synchronizeHeroBlockState(entry, newState) {
        if (!entry || !entry.heroBindingKey) {
         //   console.log("Hero gating [synchronizeHeroBlockState]: entry missing or not linked to a hero", {
//                hasEntry: !!entry,
  //              heroBindingKey: entry && entry.heroBindingKey
  //          });
            return;
        }
        var placement = heroPlacementForKey(entry.heroBindingKey);
        if (!placement || placement.__stateSync) {
            console.log("Hero gating [synchronizeHeroBlockState]: placement unavailable or state sync active", {
                hasPlacement: !!placement,
                stateSync: placement && placement.__stateSync
            });
            return;
        }
        placement.__stateSync = true;
        var normalizedState = normalizeStateName(newState);
        var records = placement.boundBlocks || [];
        for (var i = 0; i < records.length; ++i) {
            var record = records[i];
            if (!record || !record.wrapper || !record.wrapper.entry)
                continue;
            var linkedEntry = record.wrapper.entry;
            if (linkedEntry === entry)
                continue;
            var currentState = normalizeStateName(linkedEntry.blockState);
            if (currentState !== normalizedState)
                linkedEntry.blockState = newState;
        }
        if (placement.heroItem) {
            var stateValue = newState;
            if (stateValue === undefined || stateValue === null)
                stateValue = normalizedState || "idle";
            placement.heroItem.heroState = stateValue;
        }
        placement.__stateSync = false;
    }

    function synchronizeHeroBlockHealth(entry) {
        if (!entry) {
            console.log("Hero gating [synchronizeHeroBlockHealth]: entry missing");
            return;
        }
        if (entry.__heroHealthSyncGuard) {
            var guardKey = entry.heroBindingKey || entry.powerupHeroUuid || null;
            console.log("Hero gating [synchronizeHeroBlockHealth]: guard active, skipping sync", guardKey);
            return;
        }
        var bindingKey = entry.heroBindingKey || entry.powerupHeroUuid || null;
        if (!bindingKey) {
            console.log("Hero gating [synchronizeHeroBlockHealth]: entry lacks binding key");
            return;
        }
        var placement = heroPlacementForKey(bindingKey);
        if (!placement || (placement.__healthSyncCount && placement.__healthSyncCount > 0)) {
            console.log("Hero gating [synchronizeHeroBlockHealth]: placement missing or health sync busy", {
                hasPlacement: !!placement,
                healthSyncCount: placement && placement.__healthSyncCount
            });
            return;
        }
        if (!placement.cardData) {
            console.log("Hero gating [synchronizeHeroBlockHealth]: placement missing card data", bindingKey);
            return;
        }

        var heroHealth = Math.max(0, placement.cardData.heroCurrentHealth || 0);
        var blockHealth = Math.max(0, entry.health || 0);
        if (blockHealth === heroHealth) {
            console.log("Hero gating [synchronizeHeroBlockHealth]: block health already aligned", {
                key: bindingKey,
                heroHealth: heroHealth
            });
            return;
        }

        entry.__heroHealthSyncGuard = true;
        placement.__healthSyncCount = (placement.__healthSyncCount || 0) + 1;

        if (blockHealth < heroHealth)
            applyDamageToHeroCell(entry.row, entry.column, heroHealth - blockHealth, { source: "linkedBlock" });
        else
            applyHeroHealingAt(entry.row, entry.column, blockHealth - heroHealth, { source: "linkedBlock" });

        placement.__healthSyncCount = Math.max(0, (placement.__healthSyncCount || 1) - 1);
        entry.__heroHealthSyncGuard = false;
    }

    function synchronizeHeroBlockPosition(entry, isRowMutation) {
        if (!entry || entry.__heroPositionGuard) {
            console.log("Hero gating [synchronizeHeroBlockPosition]: entry missing or guard active", {
                hasEntry: !!entry,
                guard: entry && entry.__heroPositionGuard
            });
            return;
        }
        var bindingKey = entry.heroBindingKey || entry.powerupHeroUuid || null;
        if (!bindingKey) {
            console.log("Hero gating [synchronizeHeroBlockPosition]: missing binding key for entry");
            return;
        }
        var placement = heroPlacementForKey(bindingKey);
        if (!placement) {
            console.log("Hero gating [synchronizeHeroBlockPosition]: placement not found for binding key", bindingKey);
            return;
        }

        if (placement.__positionSyncCount && placement.__positionSyncCount > 0) {
            if (isRowMutation)
                entry.__previousGridRow = entry.row;
            else
                entry.__previousGridColumn = entry.column;
            console.log("Hero gating [synchronizeHeroBlockPosition]: position sync already running", {
                key: bindingKey,
                syncCount: placement.__positionSyncCount
            });
            return;
        }

        var previousRow = entry.__previousGridRow !== undefined ? entry.__previousGridRow : entry.row;
        var previousColumn = entry.__previousGridColumn !== undefined ? entry.__previousGridColumn : entry.column;

        var deltaRow = 0;
        var deltaColumn = 0;
        if (isRowMutation) {
            deltaRow = entry.row - previousRow;
            entry.__previousGridRow = entry.row;
        } else {
            deltaColumn = entry.column - previousColumn;
            entry.__previousGridColumn = entry.column;
        }

        if (deltaRow === 0 && deltaColumn === 0) {
            console.log("Hero gating [synchronizeHeroBlockPosition]: no delta detected");
            return;
        }

        entry.__heroPositionGuard = true;
        placement.__positionSyncCount = (placement.__positionSyncCount || 0) + 1;
        var success = applyHeroPlacementOffset(placement, deltaRow, deltaColumn);
        placement.__positionSyncCount = Math.max(0, (placement.__positionSyncCount || 1) - 1);
        entry.__heroPositionGuard = false;

        if (!success) {
            entry.__heroPositionGuard = true;
            if (isRowMutation)
                entry.row = previousRow;
            else
                entry.column = previousColumn;
            entry.__heroPositionGuard = false;
            entry.__previousGridRow = entry.row;
            entry.__previousGridColumn = entry.column;
        }
    }

    function applyHeroPlacementOffset(placement, deltaRow, deltaColumn) {
        if (!placement) {
            console.log("Hero gating [applyHeroPlacementOffset]: placement missing");
            return false;
        }

        var steps = [];
        if (deltaRow !== 0) {
            var stepRow = deltaRow > 0 ? 1 : -1;
            for (var r = 0; r < Math.abs(deltaRow); ++r)
                steps.push({ dr: stepRow, dc: 0 });
        }
        if (deltaColumn !== 0) {
            var stepCol = deltaColumn > 0 ? 1 : -1;
            for (var c = 0; c < Math.abs(deltaColumn); ++c)
                steps.push({ dr: 0, dc: stepCol });
        }

        if (steps.length === 0)
            return true;

        var executed = [];
        for (var i = 0; i < steps.length; ++i) {
            var step = steps[i];
            if (!attemptHeroShift(placement, step.dr, step.dc)) {
                console.log("Hero gating [applyHeroPlacementOffset]: attemptHeroShift blocked", {
                    stepRow: step.dr,
                    stepCol: step.dc
                });
                for (var ri = executed.length - 1; ri >= 0; --ri) {
                    var revert = executed[ri];
                    attemptHeroShift(placement, -revert.dr, -revert.dc);
                }
                return false;
            }
            executed.push(step);
        }
        return true;
    }

    function setWrapperAt(row, column, wrapper) {
        ensureMatrix();
        if (row < 0 || row >= gridRows || column < 0 || column >= gridCols)
            return;

        blockMatrix[row][column] = wrapper;
        if (!wrapper)
            return;

        if (wrapper.entry) {
            wrapper.entry.row = row;
            wrapper.entry.column = column;
            if (!wrapper.entry.blockState)
                wrapper.entry.blockState = "idle";
            registerBlockEntry(wrapper);
        }

        wrapper.width = cellW;
        wrapper.height = cellH;
        const pos = cellPosition(row, column);
        wrapper.x = pos.x;
        wrapper.y = pos.y;

        var heroKey = heroKeyAt(row, column);
        if (heroKey) {
            var placement = heroPlacementForKey(heroKey);
            if (placement) {
                attachWrapperToHeroCell(placement, row, column, wrapper);
                refreshHeroBlockHealth(placement);
            }
        }
    }

    function heroPlacementKey(cardUuid) {
        return cardUuid || "";
    }

    function hasHeroForCard(cardUuid) {
        var key = heroPlacementKey(cardUuid);
        return !!heroPlacements[key];
    }

    function heroAreaWithinBounds(row, column, rowSpan, colSpan) {
        if (row < 0 || column < 0) {
            console.log("Hero gating [heroAreaWithinBounds]: negative coordinates", {
                row: row,
                column: column
            });
            return false;
        }
        if ((row + rowSpan) > gridRows) {
            console.log("Hero gating [heroAreaWithinBounds]: row span exceeds grid", {
                row: row,
                rowSpan: rowSpan,
                gridRows: gridRows
            });
            return false;
        }
        if ((column + colSpan) > gridCols) {
            console.log("Hero gating [heroAreaWithinBounds]: column span exceeds grid", {
                column: column,
                colSpan: colSpan,
                gridCols: gridCols
            });
            return false;
        }
        return true;
    }

    function heroCellsForArea(row, column, rowSpan, colSpan) {
        var cells = [];
        for (var r = row; r < row + rowSpan; ++r) {
            for (var c = column; c < column + colSpan; ++c) {
                cells.push({ row: r, column: c });
            }
        }
        return cells;
    }

    function heroAreasOverlap(a, b) {
        if (!a || !b) {
            console.log("Hero gating [heroAreasOverlap]: missing area data", {
                hasA: !!a,
                hasB: !!b
            });
            return false;
        }
        var aBottom = a.row + a.rowSpan - 1;
        var aRight = a.column + a.colSpan - 1;
        var bBottom = b.row + b.rowSpan - 1;
        var bRight = b.column + b.colSpan - 1;
        var horizontal = !(a.column > bRight || b.column > aRight);
        var vertical = !(a.row > bBottom || b.row > aBottom);
        return horizontal && vertical;
    }

    function canPlaceHero(cardUuid, row, column, rowSpan, colSpan) {
        if (!heroAreaWithinBounds(row, column, rowSpan, colSpan)) {
            console.log("Hero gating [canPlaceHero]: requested area out of bounds", {
                row: row,
                column: column,
                rowSpan: rowSpan,
                colSpan: colSpan
            });
            return false;
        }
        if (hasHeroForCard(cardUuid)) {
            console.log("Hero gating [canPlaceHero]: hero already placed for card", cardUuid);
            return false;
        }
        var placement = { row: row, column: column, rowSpan: rowSpan, colSpan: colSpan };
        for (var key in heroPlacements) {
            if (!heroPlacements.hasOwnProperty(key))
                continue;
            var existing = heroPlacements[key];
            if (!existing)
                continue;
            if (heroAreasOverlap(existing, placement)) {
                console.log("Hero gating [canPlaceHero]: requested area overlaps existing hero", {
                    existingKey: key,
                    row: existing.row,
                    column: existing.column
                });
                return false;
            }
        }
        return true;
    }

    function collectBoundBlocks(row, column, rowSpan, colSpan) {
        var cells = heroCellsForArea(row, column, rowSpan, colSpan);
        var bound = [];
        for (var i = 0; i < cells.length; ++i) {
            var cell = cells[i];
            var wrapper = getBlockWrapper(cell.row, cell.column);
            if (wrapper)
                bound.push({ row: cell.row, column: cell.column, wrapper: wrapper });
        }
        return bound;
    }

    function ensureHeroCellMap() {
        if (!heroCellMap || heroCellMap.length !== gridRows) {
            var map = [];
            for (var r = 0; r < gridRows; ++r)
                map.push(new Array(gridCols));
            heroCellMap = map;
            return;
        }
        for (var r = 0; r < gridRows; ++r) {
            if (!heroCellMap[r] || heroCellMap[r].length !== gridCols)
                heroCellMap[r] = new Array(gridCols);
        }
    }

    function setHeroCellKey(row, column, key) {
        ensureHeroCellMap();
        if (row < 0 || row >= gridRows || column < 0 || column >= gridCols) {
            console.log("Hero gating [setHeroCellKey]: coordinates out of bounds", {
                row: row,
                column: column,
                gridRows: gridRows,
                gridCols: gridCols
            });
            return;
        }
        heroCellMap[row][column] = key || null;
    }

    function heroKeyAt(row, column) {
        ensureHeroCellMap();
        if (row < 0 || row >= gridRows || column < 0 || column >= gridCols) {
            console.log("Hero gating [heroKeyAt]: lookup out of bounds", {
                row: row,
                column: column
            });
            return null;
        }
        return heroCellMap[row][column] || null;
    }

    function heroPlacementForKey(key) {
        if (!key) {
            console.log("Hero gating [heroPlacementForKey]: key missing");
            return null;
        }
        var placement = heroPlacements[key] || null;
        if (!placement)
            console.log("Hero gating [heroPlacementForKey]: placement not found", key);
        return placement;
    }

    function heroPlacementForWrapper(wrapper) {
        if (!wrapper) {
            console.log("Hero gating [heroPlacementForWrapper]: wrapper missing");
            return null;
        }
        var key = null;
        if (wrapper.entry && wrapper.entry.heroBindingKey)
            key = wrapper.entry.heroBindingKey;
        if (!key && typeof wrapper.property === "function")
            key = wrapper.property("heroBindingKey");
        if (!key && wrapper.heroBindingKey !== undefined)
            key = wrapper.heroBindingKey;
        if (!key)
            console.log("Hero gating [heroPlacementForWrapper]: unable to resolve hero binding key");
        return heroPlacementForKey(key);
    }

    function heroPlacementForCell(row, column) {
        var key = heroKeyAt(row, column);
        return heroPlacementForKey(key);
    }

    function isHeroOccupiedCell(row, column) {
        return heroKeyAt(row, column) !== null;
    }

    function unlinkWrapperFromHero(wrapper) {
        if (!wrapper) {
            console.log("Hero gating [unlinkWrapperFromHero]: wrapper missing");
            return;
        }
        if (wrapper.entry) {
            wrapper.entry.heroBindingKey = null;
            wrapper.entry.heroLinked = false;
            wrapper.entry.powerupHeroLinked = false;
            wrapper.entry.powerupHeroUuid = "";
            wrapper.entry.powerupHeroItem = null;
            wrapper.entry.powerupHeroRowOffset = 0;
            wrapper.entry.powerupHeroColOffset = 0;
            wrapper.entry.__heroHealthSyncGuard = false;
            wrapper.entry.__heroPositionGuard = false;
            wrapper.entry.__previousGridRow = wrapper.entry.row;
            wrapper.entry.__previousGridColumn = wrapper.entry.column;
        }
        if (typeof wrapper.setProperty === "function") {
            wrapper.setProperty("heroBindingKey", null);
            wrapper.setProperty("powerupHeroLinked", false);
            wrapper.setProperty("powerupHeroUuid", "");
            wrapper.setProperty("powerupHeroItem", null);
            wrapper.setProperty("powerupHeroRowOffset", 0);
            wrapper.setProperty("powerupHeroColOffset", 0);
            wrapper.setProperty("heroAnchorRow", undefined);
            wrapper.setProperty("heroAnchorColumn", undefined);
        }
    }

    function linkWrapperToHero(wrapper, placement, row, column) {
        if (!wrapper || !placement) {
            console.log("Hero gating [linkWrapperToHero]: wrapper or placement missing", {
                hasWrapper: !!wrapper,
                hasPlacement: !!placement
            });
            return;
        }
        var heroKey = placement.key;
        var relRow = row - placement.row;
        var relCol = column - placement.column;
        if (typeof wrapper.setProperty === "function") {
            wrapper.setProperty("heroBindingKey", heroKey);
            wrapper.setProperty("powerupHeroLinked", true);
            wrapper.setProperty("powerupHeroUuid", heroKey);
            wrapper.setProperty("powerupHeroItem", placement.heroItem || null);
            wrapper.setProperty("powerupHeroRowOffset", relRow);
            wrapper.setProperty("powerupHeroColOffset", relCol);
            wrapper.setProperty("heroAnchorRow", placement.row);
            wrapper.setProperty("heroAnchorColumn", placement.column);
        }
        if (wrapper.entry) {
            wrapper.entry.heroBindingKey = heroKey;
            wrapper.entry.heroLinked = true;
            wrapper.entry.powerupHeroLinked = true;
            wrapper.entry.powerupHeroUuid = heroKey;
            wrapper.entry.powerupHeroItem = placement.heroItem || null;
            wrapper.entry.powerupHeroRowOffset = relRow;
            wrapper.entry.powerupHeroColOffset = relCol;
            wrapper.entry.__previousGridRow = row;
            wrapper.entry.__previousGridColumn = column;
            wrapper.entry.__heroHealthSyncGuard = false;
            wrapper.entry.__heroPositionGuard = false;
        }
        console.log("Hero placement flow: wrapper linked to hero", {
            heroKey: heroKey,
            row: row,
            column: column,
            wrapperId: wrapper.objectName || wrapper
        });
    }

    function attachWrapperToHeroCell(placement, row, column, wrapper) {
        if (!placement || !wrapper) {
            console.log("Hero gating [attachWrapperToHeroCell]: placement or wrapper missing", {
                hasPlacement: !!placement,
                hasWrapper: !!wrapper
            });
            return;
        }
        linkWrapperToHero(wrapper, placement, row, column);
        if (!placement.boundBlocks)
            placement.boundBlocks = [];
        var target = null;
        for (var i = 0; i < placement.boundBlocks.length; ++i) {
            var record = placement.boundBlocks[i];
            if (!record)
                continue;
            if (record.row === row && record.column === column) {
                target = record;
                break;
            }
            if (!target && record.wrapper === wrapper)
                target = record;
        }
        if (!target) {
            target = {
                row: row,
                column: column,
                wrapper: wrapper,
                relRow: row - placement.row,
                relCol: column - placement.column
            };
            placement.boundBlocks.push(target);
        } else {
            target.row = row;
            target.column = column;
            target.wrapper = wrapper;
            target.relRow = row - placement.row;
            target.relCol = column - placement.column;
        }
        for (var j = placement.boundBlocks.length - 1; j >= 0; --j) {
            var other = placement.boundBlocks[j];
            if (!other || other === target)
                continue;
            if (other.wrapper === wrapper)
                placement.boundBlocks.splice(j, 1);
        }
    }

    function detachWrapperFromHeroCell(placement, row, column, wrapper) {
        if (!placement) {
            console.log("Hero gating [detachWrapperFromHeroCell]: placement missing");
            return;
        }
        if (wrapper)
            unlinkWrapperFromHero(wrapper);
        if (!placement.boundBlocks || !placement.boundBlocks.length) {
            console.log("Hero gating [detachWrapperFromHeroCell]: no bound blocks to update", placement.key);
            return;
        }
        for (var i = placement.boundBlocks.length - 1; i >= 0; --i) {
            var record = placement.boundBlocks[i];
            if (!record)
                continue;
            if ((wrapper && record.wrapper === wrapper) || (record.row === row && record.column === column)) {
                placement.boundBlocks.splice(i, 1);
                break;
            }
        }
    }

    function clearHeroPlacementCells(placement) {
        if (!placement) {
            console.log("Hero gating [clearHeroPlacementCells]: placement missing");
            return;
        }
        ensureHeroCellMap();
        if (placement.coverageCells && placement.coverageCells.length) {
            for (var c = 0; c < placement.coverageCells.length; ++c) {
                var coverageCell = placement.coverageCells[c];
                if (!coverageCell)
                    continue;
                if (coverageCell.row === undefined || coverageCell.column === undefined)
                    continue;
                setHeroCellKey(coverageCell.row, coverageCell.column, null);
            }
        }
        if (placement.boundBlocks) {
            for (var i = 0; i < placement.boundBlocks.length; ++i) {
                var record = placement.boundBlocks[i];
                if (!record)
                    continue;
                var wrap = record.wrapper;
                if (!wrap)
                    continue;
                unlinkWrapperFromHero(wrap);
            }
        }
        if (placement.heroItem)
            placement.heroItem.heroState = "idle";
        placement.__stateSync = false;
        placement.boundBlocks = [];
        placement.coverageCells = [];
    }

    function bindHeroPlacement(placement) {
        if (!placement) {
            console.log("Hero gating [bindHeroPlacement]: placement missing");
            return;
        }
        console.log("Hero placement flow: bindHeroPlacement start", {
            key: placement.key,
            row: placement.row,
            column: placement.column,
            rowSpan: placement.rowSpan,
            colSpan: placement.colSpan
        });
        clearHeroPlacementCells(placement);
        var areaCells = heroCellsForArea(placement.row, placement.column, placement.rowSpan, placement.colSpan);
        placement.coverageCells = [];
        for (var ac = 0; ac < areaCells.length; ++ac) {
            var coverage = areaCells[ac];
            if (!coverage)
                continue;
            placement.coverageCells.push({ row: coverage.row, column: coverage.column });
            setHeroCellKey(coverage.row, coverage.column, placement.key);
        }

        var bound = collectBoundBlocks(placement.row, placement.column, placement.rowSpan, placement.colSpan);
        placement.boundBlocks = [];
        for (var i = 0; i < bound.length; ++i) {
            var record = bound[i];
            if (!record || !record.wrapper)
                continue;
            attachWrapperToHeroCell(placement, record.row, record.column, record.wrapper);
        }
        if (placement.heroItem) {
            placement.heroItem.anchoredRow = placement.row;
            placement.heroItem.anchoredColumn = placement.column;
            placement.heroItem.heroState = "idle";
        }
        console.log("Hero placement flow: bindHeroPlacement complete", {
            key: placement.key,
            coverageCount: placement.coverageCells.length,
            boundBlocks: placement.boundBlocks.length
        });
    }

    function refreshHeroBlockHealth(placement) {
        if (!placement || !placement.boundBlocks) {
            console.log("Hero gating [refreshHeroBlockHealth]: placement missing or no bound blocks", {
                hasPlacement: !!placement,
                hasBoundBlocks: placement && placement.boundBlocks
            });
            return;
        }
        var health = placement.cardData ? Math.max(0, placement.cardData.heroCurrentHealth) : 0;
        for (var i = 0; i < placement.boundBlocks.length; ++i) {
            var record = placement.boundBlocks[i];
            if (!record || !record.wrapper || !record.wrapper.entry)
                continue;
            var linkedEntry = record.wrapper.entry;
            var previousGuard = linkedEntry.__heroHealthSyncGuard;
            linkedEntry.__heroHealthSyncGuard = true;
            linkedEntry.health = health;
            if (linkedEntry.cachedHealth !== undefined)
                linkedEntry.cachedHealth = health;
            linkedEntry.__heroHealthSyncGuard = previousGuard;
        }
    }

    function handleHeroDefeat(placement, context) {
        if (!placement) {
            console.log("Hero gating [handleHeroDefeat]: placement missing");
            return;
        }
        var key = placement.key;
        var cardData = placement.cardData || null;
        var previousHealth = cardData ? Math.max(0, cardData.heroCurrentHealth) : 0;
        if (placement.boundBlocks) {
            for (var i = 0; i < placement.boundBlocks.length; ++i) {
                var record = placement.boundBlocks[i];
                if (!record || !record.wrapper || !record.wrapper.entry)
                    continue;
                record.wrapper.entry.health = 0;
                record.wrapper.entry.energyAmount = Math.max(record.wrapper.entry.energyAmount || 0, previousHealth);
                record.wrapper.entry.blockState = "waitAndExplode";
            }
        }
        if (placement.heroItem && typeof placement.heroItem.destroy === "function") {
            placement.heroItem.heroState = "destroyed";
            placement.heroItem.visible = false;
            placement.heroItem.destroy();
            placement.heroItem = null;
        }

        var cardUuid = placement.metadata && placement.metadata.cardUuid ? placement.metadata.cardUuid : key;
        releaseHeroPlacement(cardUuid, { preserveCardState: true });
        if (cardData) {
            cardData.heroCurrentHealth = 0;
            if (typeof cardData.markHeroDefeated === "function")
                cardData.markHeroDefeated();
            else
                cardData.resetAfterHeroRemoval();
        }
    }

    function applyHeroHealingAt(row, column, amount, context) {
        var placement = heroPlacementForCell(row, column);
        if (!placement || !placement.cardData) {
            console.log("Hero gating [applyHeroHealingAt]: placement or card data missing", {
                row: row,
                column: column
            });
            return { applied: 0, destroyed: false, key: null };
        }
        var heal = Math.max(0, Math.floor(amount));
        if (heal <= 0) {
            console.log("Hero gating [applyHeroHealingAt]: heal amount non-positive", {
                amount: amount
            });
            return { applied: 0, destroyed: false, key: placement.key };
        }
        var previous = placement.cardData.heroCurrentHealth;
        placement.cardData.applyHeroHealing(heal);
        var applied = Math.max(0, placement.cardData.heroCurrentHealth - previous);
        refreshHeroBlockHealth(placement);
        return { applied: applied, destroyed: false, key: placement.key };
    }

    function applyDamageToHeroCell(row, column, amount, context) {
        var placement = heroPlacementForCell(row, column);
        if (!placement || !placement.cardData) {
            console.log("Hero gating [applyDamageToHeroCell]: placement or card data missing", {
                row: row,
                column: column
            });
            return { applied: 0, destroyed: false, key: null };
        }
        var dmg = Math.max(0, Math.floor(amount));
        if (dmg <= 0) {
            console.log("Hero gating [applyDamageToHeroCell]: damage amount non-positive", {
                amount: amount
            });
            return { applied: 0, destroyed: false, key: placement.key };
        }
        var previous = placement.cardData.heroCurrentHealth;
        placement.cardData.applyHeroDamage(dmg);
        var applied = Math.max(0, previous - placement.cardData.heroCurrentHealth);
        var defeated = !placement.cardData.heroAlive;
        if (defeated)
            handleHeroDefeat(placement, Object.assign({ reason: "damage" }, context || {}));
        else
            refreshHeroBlockHealth(placement);
        return { applied: applied, destroyed: defeated, key: placement.key };
    }

    function applyBlockDelta(row, column, amount, operation, context) {
        var entry = getBlockEntryAt(row, column);
        if (!entry) {
            console.log("Powerup grid effect: applyBlockDelta skipped, no entry at cell", JSON.stringify({
                row: row,
                column: column
            }));
            return { affected: false };
        }
        var delta = Math.max(0, Math.floor(amount));
        if (delta <= 0) {
            console.log("Powerup grid effect: applyBlockDelta delta non-positive", JSON.stringify({
                row: row,
                column: column,
                amount: amount
            }));
            return { affected: false };
        }
        var placement = heroPlacementForCell(row, column);
        if (placement && placement.cardData) {
            if (operation && operation.toString().toLowerCase() === "increase")
                return Object.assign({ affected: true, hero: true }, applyHeroHealingAt(row, column, delta, context));
            return Object.assign({ affected: true, hero: true }, applyDamageToHeroCell(row, column, delta, context));
        }

        if (entry.health === undefined || entry.health === null)
            entry.health = 100;
        var op = operation && operation.toString().toLowerCase() === "increase" ? "increase" : "decrease";
        if (op === "increase") {
            entry.health = entry.health + delta;
            return { affected: true, destroyed: false, hero: false, health: entry.health };
        }

        var previousHealth = entry.health;
        entry.health = entry.health - delta;
        if (entry.health <= 0) {
            entry.health = 0;
            entry.energyAmount = Math.max(entry.energyAmount || 0, previousHealth);
            entry.blockState = "waitAndExplode";
            var result = { affected: true, destroyed: true, hero: false, health: 0, energyAmount: entry.energyAmount };
            console.log("Powerup grid effect: block destroyed", JSON.stringify(Object.assign({ row: row, column: column }, result)));
            return result;
        }
        var resultAlive = { affected: true, destroyed: false, hero: false, health: entry.health };
        console.log("Powerup grid effect: block health updated", JSON.stringify(Object.assign({ row: row, column: column }, resultAlive)));
        return resultAlive;
    }

    function applyBlockDeltaList(cells, amount, operation, context) {
        var results = [];
        if (!Array.isArray(cells)) {
            console.log("Powerup grid effect: applyBlockDeltaList called with invalid cells payload", JSON.stringify(cells));
            return results;
        }
        console.log("Powerup grid effect: applying deltas to cells", JSON.stringify({
            count: cells.length,
            amount: amount,
            operation: operation
        }));
        for (var i = 0; i < cells.length; ++i) {
            var cell = cells[i];
            if (!cell)
                continue;
            var row = cell.row !== undefined ? cell.row : cell.r;
            var column = cell.column !== undefined ? cell.column : cell.c;
            if (row === undefined || column === undefined) {
                console.log("Powerup grid effect: skipped cell missing row/column", JSON.stringify(cell));
                continue;
            }
            results.push(Object.assign({ row: row, column: column }, applyBlockDelta(row, column, amount, operation, context)));
        }
        console.log("Powerup grid effect: delta list results", JSON.stringify(results));
        return results;
    }

    function applyHeroDeltaByColor(color, amount, operation, context) {
        if (!color) {
            console.log("Hero gating [applyHeroDeltaByColor]: color filter missing");
            return [];
        }
        var keyColor = color.toString().toLowerCase();
        var op = operation && operation.toString().toLowerCase() === "increase" ? "increase" : "decrease";
        var delta = Math.max(0, Math.floor(amount));
        if (delta <= 0) {
            console.log("Hero gating [applyHeroDeltaByColor]: delta non-positive", {
                amount: amount
            });
            return [];
        }
        var impacts = [];
        for (var key in heroPlacements) {
            if (!heroPlacements.hasOwnProperty(key))
                continue;
            var placement = heroPlacements[key];
            if (!placement || !placement.cardData)
                continue;
            var cardColor = (placement.cardData.powerupCardColor || "").toLowerCase();
            if (cardColor !== keyColor)
                continue;
            var result = op === "increase"
                    ? applyHeroHealingAt(placement.row, placement.column, delta, context)
                    : applyDamageToHeroCell(placement.row, placement.column, delta, context);
            impacts.push(Object.assign({ key: key, row: placement.row, column: placement.column }, result));
        }
        return impacts;
    }

    function attemptHeroShift(placement, deltaRow, deltaCol) {
        if (!placement) {
            console.log("Hero gating [attemptHeroShift]: placement missing");
            return false;
        }
        placement.__positionSyncCount = (placement.__positionSyncCount || 0) + 1;
        try {
            if ((Math.abs(deltaRow) + Math.abs(deltaCol)) !== 1) {
                console.log("Hero gating [attemptHeroShift]: move delta invalid", {
                    deltaRow: deltaRow,
                    deltaCol: deltaCol
                });
                return false;
            }
            var newRow = placement.row + deltaRow;
            var newCol = placement.column + deltaCol;
            if (!heroAreaWithinBounds(newRow, newCol, placement.rowSpan, placement.colSpan)) {
                console.log("Hero gating [attemptHeroShift]: new area out of bounds", {
                    newRow: newRow,
                    newCol: newCol
                });
                return false;
            }

            var currentCells = heroCellsForArea(placement.row, placement.column, placement.rowSpan, placement.colSpan);
            var newCells = heroCellsForArea(newRow, newCol, placement.rowSpan, placement.colSpan);
            var currentMap = {};
            for (var i = 0; i < currentCells.length; ++i) {
                var key = currentCells[i].row + ":" + currentCells[i].column;
                currentMap[key] = true;
            }
            var newMap = {};
            for (var n = 0; n < newCells.length; ++n) {
                var nKey = newCells[n].row + ":" + newCells[n].column;
                newMap[nKey] = true;
            }

            var leaving = [];
            for (var c = 0; c < currentCells.length; ++c) {
                var cell = currentCells[c];
                if (!newMap[cell.row + ":" + cell.column])
                    leaving.push(cell);
            }

            var entering = [];
            for (var m = 0; m < newCells.length; ++m) {
                var cellNew = newCells[m];
                if (!currentMap[cellNew.row + ":" + cellNew.column])
                    entering.push(cellNew);
            }

            if (entering.length !== leaving.length) {
                console.log("Hero gating [attemptHeroShift]: mismatch between entering and leaving cells");
                return false;
            }

            var incomingWrappers = [];
            for (var e = 0; e < entering.length; ++e) {
                var enteringCell = entering[e];
                var incomingWrapper = getBlockWrapper(enteringCell.row, enteringCell.column);
                if (incomingWrapper) {
                    var otherPlacement = heroPlacementForWrapper(incomingWrapper);
                    if (otherPlacement && otherPlacement.key !== placement.key) {
                        console.log("Hero gating [attemptHeroShift]: incoming wrapper belongs to another hero", {
                            otherKey: otherPlacement && otherPlacement.key
                        });
                        return false;
                    }
                } else {
                    var occupyingKey = heroKeyAt(enteringCell.row, enteringCell.column);
                    if (occupyingKey && occupyingKey !== placement.key) {
                        console.log("Hero gating [attemptHeroShift]: target cell occupied by another hero", {
                            occupyingKey: occupyingKey
                        });
                        return false;
                    }
                }
                incomingWrappers.push({ cell: enteringCell, wrapper: incomingWrapper });
            }

            var previousBlocks = placement.boundBlocks ? placement.boundBlocks.slice() : [];
            clearHeroPlacementCells(placement);

            for (var iw = 0; iw < incomingWrappers.length; ++iw) {
                var incoming = incomingWrappers[iw];
                clearWrapperAt(incoming.cell.row, incoming.cell.column);
            }

            var heroWrappers = [];
            for (var hb = 0; hb < previousBlocks.length; ++hb) {
                var blockRecord = previousBlocks[hb];
                if (!blockRecord || !blockRecord.wrapper)
                    continue;
                heroWrappers.push({
                                      wrapper: blockRecord.wrapper,
                                      relRow: blockRecord.row - placement.row,
                                      relCol: blockRecord.column - placement.column
                                  });
                clearWrapperAt(blockRecord.row, blockRecord.column);
            }

            for (var hw = 0; hw < heroWrappers.length; ++hw) {
                var heroRecord = heroWrappers[hw];
                var targetRow = newRow + heroRecord.relRow;
                var targetColumn = newCol + heroRecord.relCol;
                setWrapperAt(targetRow, targetColumn, heroRecord.wrapper);
            }

            leaving.sort(function(a, b) {
                if (a.row !== b.row)
                    return a.row - b.row;
                return a.column - b.column;
            });
            incomingWrappers.sort(function(a, b) {
                if (a.cell.row !== b.cell.row)
                    return a.cell.row - b.cell.row;
                return a.cell.column - b.cell.column;
            });

            for (var li = 0; li < incomingWrappers.length; ++li) {
                var leaveCell = leaving[li];
                var moveWrapper = incomingWrappers[li].wrapper;
                if (moveWrapper)
                    setWrapperAt(leaveCell.row, leaveCell.column, moveWrapper);
                else
                    clearWrapperAt(leaveCell.row, leaveCell.column);
            }

            placement.row = newRow;
            placement.column = newCol;
            bindHeroPlacement(placement);
            refreshHeroBlockHealth(placement);
            if (placement.heroItem) {
                var heroPos = cellPosition(newRow, newCol);
                placement.heroItem.x = heroPos.x;
                placement.heroItem.y = heroPos.y;
                placement.heroItem.anchoredRow = newRow;
                placement.heroItem.anchoredColumn = newCol;
            }
            return true;
        } finally {
            placement.__positionSyncCount = Math.max(0, (placement.__positionSyncCount || 1) - 1);
        }
    }

    function requestSwapWrappers(row1, column1, row2, column2) {
        ensureMatrix();
        if (row1 === row2 && column1 === column2)
            return false;
        if ((Math.abs(row1 - row2) + Math.abs(column1 - column2)) !== 1)
            return false;

        var wrapperA = getBlockWrapper(row1, column1);
        var wrapperB = getBlockWrapper(row2, column2);
        if (!wrapperA || !wrapperB)
            return false;

        var placementA = heroPlacementForWrapper(wrapperA);
        var placementB = heroPlacementForWrapper(wrapperB);
        var deltaRow = row2 - row1;
        var deltaCol = column2 - column1;

        if ((placementA || placementB) && normalizeStateName(currentState) !== "idle")
            return false;
        if ((placementA || placementB) && !BattleGridLogic.allEntriesIdleNoMissing(root))
            return false;

        if (placementA && placementB && placementA.key !== placementB.key)
            return false;

        if (placementA) {
            if (attemptHeroShift(placementA, deltaRow, deltaCol))
                return true;
            return false;
        }

        if (placementB) {
            if (attemptHeroShift(placementB, -deltaRow, -deltaCol))
                return true;
            return false;
        }

        setWrapperAt(row1, column1, wrapperB);
        setWrapperAt(row2, column2, wrapperA);
        return true;
    }

    function registerHeroPlacement(cardUuid, heroItem, row, column, rowSpan, colSpan, metadata) {
        console.log("Hero placement flow: registerHeroPlacement called", {
            cardUuid: cardUuid,
            row: row,
            column: column,
            rowSpan: rowSpan,
            colSpan: colSpan
        });
        var key = heroPlacementKey(cardUuid);
        var meta = metadata || {};
        var cardData = meta.cardData || (heroItem && heroItem.cardData) || null;
        if (!meta.cardUuid)
            meta.cardUuid = cardUuid;
        var placement = {
            key: key,
            heroItem: heroItem || null,
            cardData: cardData || null,
            row: row,
            column: column,
            rowSpan: rowSpan,
            colSpan: colSpan,
            metadata: meta,
            boundBlocks: [],
            coverageCells: [],
            __stateSync: false,
            __positionSyncCount: 0,
            __healthSyncCount: 0
        };
        heroPlacements[key] = placement;
        if (cardData) {
            cardData.battleGrid = root;
            cardData.markHeroPlacedState(true);
        }
        console.log("Hero placement flow: placement stored and card state updated", {
            key: key,
            hasCardData: !!cardData,
            battleGridUuid: cardData && cardData.battleGrid ? cardData.battleGrid.uuid : null,
            heroPlaced: cardData && cardData.heroPlaced
        });
        bindHeroPlacement(placement);
        refreshHeroBlockHealth(placement);
        console.log("Hero placement flow: registerHeroPlacement finished", key);
    }

    function releaseHeroPlacement(cardUuid, options) {
        var key = heroPlacementKey(cardUuid);
        if (!heroPlacements.hasOwnProperty(key)) {
            console.log("Hero gating [releaseHeroPlacement]: no placement exists for key", key);
            return;
        }
        var placement = heroPlacements[key];
        clearHeroPlacementCells(placement);
        if (placement && placement.cardData && (!options || !options.preserveCardState))
            placement.cardData.resetAfterHeroRemoval();
        delete heroPlacements[key];
    }

    function clearWrapperAt(row, column) {
        ensureMatrix();
        if (row < 0 || row >= gridRows || column < 0 || column >= gridCols)
            return;
        var existing = blockMatrix[row][column];
        blockMatrix[row][column] = null;
        if (!existing)
            return;
        var heroKey = heroKeyAt(row, column);
        var placement = heroKey ? heroPlacementForKey(heroKey) : heroPlacementForWrapper(existing);
        if (!placement)
            return;
        detachWrapperFromHeroCell(placement, row, column, existing);
    }

    function teardownWrapper(wrapper, location) {
        if (!wrapper)
            return false;

        const resolved = (location && location.row !== undefined && location.column !== undefined)
                ? location
                : findWrapperPosition(wrapper);
        if (resolved.row >= 0 && resolved.column >= 0)
            clearWrapperAt(resolved.row, resolved.column);

        const instanceIdx = instances.indexOf(wrapper);
        if (instanceIdx !== -1)
            instances.splice(instanceIdx, 1);

        const blockEntry = wrapper.entry || null;
        wrapper.entry = null;
        if (blockEntry && typeof blockEntry.destroy === "function")
            blockEntry.destroy();

        if (typeof wrapper.destroy === "function")
            wrapper.destroy();

        return true;
    }

    function purgeDestroyedBlocks() {
        ensureMatrix();
        var destroyedWrappers = [];
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                const wrapper = blockMatrix[row][column];
                if (!wrapper)
                    continue;

                const blockEntry = wrapper.entry || null;
                const state = blockEntry && blockEntry.blockState ? normalizeStateName(blockEntry.blockState) : "";
                if (state === "destroyed")
                    destroyedWrappers.push({ wrapper: wrapper, row: row, column: column });
            }
        }

        for (var idx = 0; idx < destroyedWrappers.length; ++idx) {
            const record = destroyedWrappers[idx];
            teardownWrapper(record.wrapper, { row: record.row, column: record.column });
        }

        return destroyedWrappers.length;
    }

    function getBlockWrapper(row, column) {
        ensureMatrix();
        if (row < 0 || row >= gridRows || column < 0 || column >= gridCols)
            return null;
        return blockMatrix[row][column] || null;
    }

    function getBlockEntryAt(row, column) {
        const wrapper = getBlockWrapper(row, column);
        return wrapper ? wrapper.entry : null;
    }

    function getEntryAt(row, column) {
        return getBlockEntryAt(row, column);
    }

    function distributePostSwapCascadeStatus() {
        if (!uuid)
            return;
        const payload = {
            battleGrid: uuid,
            postSwapCascade: postSwapCascading
        };
        informPostSwapCascadeStatus(payload);
    }

    function informOpponentPostSwapCascadeStatus(payload) {
        if (!payload)
            return;
        const state = normalizeStateName(currentState);
        if (state !== "wait")
            return;
        if (payload.postSwapCascade === false)
            requestState("compact");
    }

    function moveWrapper(wrapper, targetRow, targetColumn) {
        if (!wrapper)
            return false;

        if (heroPlacementForWrapper(wrapper))
            return false;

        const currentPos = findWrapperPosition(wrapper);
        if (currentPos.row === targetRow && currentPos.column === targetColumn)
            return true;
        if (currentPos.row >= 0 && currentPos.column >= 0)
            clearWrapperAt(currentPos.row, currentPos.column);

        setWrapperAt(targetRow, targetColumn, wrapper);
        return true;
    }

    function findWrapperPosition(wrapper) {
        ensureMatrix();
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                if (blockMatrix[row][column] === wrapper)
                    return { row: row, column: column };
            }
        }
        return { row: -1, column: -1 };
    }

    function fillGrid() {

        ensureMatrix();
        const fillDescending = normalizeStateName(launchDirection) === "up";
        const rowStart = fillDescending ? gridRows - 1 : 0;
        const rowEnd = fillDescending ? -1 : gridRows;
        const rowStep = fillDescending ? -1 : 1;

        const direction = normalizeStateName(launchDirection);
        const spawnOffset = direction === "down" ? -(cellH * 5)
                           : direction === "up" ? (cellH * 5)
                           : -(cellH * 6);

        for (var row = rowStart; row !== rowEnd; row += rowStep) {
            for (var column = 0; column < gridCols; ++column) {
                if (isHeroOccupiedCell(row, column))
                    continue;
                if (getBlockWrapper(row, column))
                    continue;
                var nextBlockColor = pools[column].getNextBlockColor()

                const pos = cellPosition(row, column);
                const dragItem = Factory.createBlock(
                            blockComp,
                            dragComp,
                            root,
                            gameScene || root,
                            {
                                width: cellW,
                                height: cellH,
                                x: pos.x,
                                y: pos.y,
                                spawnOffset: spawnOffset,
                                blockProps: {
                                    row: row,
                                    column: column,
                                    maxRows: gridRows,
                                    blockColor: nextBlockColor
                                }
                            });

                if (!dragItem)
                    continue;

                instances.push(dragItem);
                dragItem.enabled = playerControlled;

                setWrapperAt(row, column, dragItem);
                dragItem.startedMoving.connect(dragItem.entry.startedMoving)
                dragItem.stoppedMoving.connect(dragItem.entry.stoppedMoving)
                dragItem.y = pos.y;
                dragItem.sceneX = root.mapToGlobal(pos.x, pos.y).x
                dragItem.sceneY = root.mapToGlobal(pos.x, pos.y).y
                dragItem.entry.battleGrid = root;
            }
        }
    }

    function compactColumns() {
        ensureMatrix();
        purgeDestroyedBlocks();
        const gravityDown = normalizeStateName(launchDirection) === "up";
        for (var column = 0; column < gridCols; ++column) {
            if (gravityDown) {
                var survivorsDown = [];
                for (var rowDown = 0; rowDown < gridRows; ++rowDown) {
                    if (isHeroOccupiedCell(rowDown, column))
                        continue;
                    const wrapperDown = getBlockWrapper(rowDown, column);
                    if (wrapperDown && !heroPlacementForWrapper(wrapperDown))
                        survivorsDown.push(wrapperDown);
                }

                var availableRowsDown = [];
                for (var fillRowDown = 0; fillRowDown < gridRows; ++fillRowDown) {
                    if (!isHeroOccupiedCell(fillRowDown, column))
                        availableRowsDown.push(fillRowDown);
                }

                var survivorIdxDown = 0;
                for (var ar = 0; ar < availableRowsDown.length; ++ar) {
                    var targetRowDown = availableRowsDown[ar];
                    if (survivorIdxDown < survivorsDown.length) {
                        var movingWrapperDown = survivorsDown[survivorIdxDown++];
                        var currentPosDown = findWrapperPosition(movingWrapperDown);
                        if (currentPosDown.row !== targetRowDown)
                            moveWrapper(movingWrapperDown, targetRowDown, column);
                    } else {
                        clearWrapperAt(targetRowDown, column);
                    }
                }
            } else {
                var survivorsUp = [];
                for (var rowUp = gridRows - 1; rowUp >= 0; --rowUp) {
                    if (isHeroOccupiedCell(rowUp, column))
                        continue;
                    const wrapperUp = getBlockWrapper(rowUp, column);
                    if (wrapperUp && !heroPlacementForWrapper(wrapperUp))
                        survivorsUp.push(wrapperUp);
                }

                var availableRowsUp = [];
                for (var fillRowUp = gridRows - 1; fillRowUp >= 0; --fillRowUp) {
                    if (!isHeroOccupiedCell(fillRowUp, column))
                        availableRowsUp.push(fillRowUp);
                }

                var survivorIdxUp = 0;
                for (var aru = 0; aru < availableRowsUp.length; ++aru) {
                    var targetRowUp = availableRowsUp[aru];
                    if (survivorIdxUp < survivorsUp.length) {
                        var movingWrapperUp = survivorsUp[survivorIdxUp++];
                        var currentPosUp = findWrapperPosition(movingWrapperUp);
                        if (currentPosUp.row !== targetRowUp)
                            moveWrapper(movingWrapperUp, targetRowUp, column);
                    } else {
                        clearWrapperAt(targetRowUp, column);
                    }
                }
            }
        }
    }

    function spawnMissingBlocks() {
        fillGrid();
    }
    function updateBlockScenePositions() {
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                var wrapper = getBlockWrapper(row, column)
                if (!wrapper) {
                    continue;
                }
                var globX = wrapper.mapToGlobal(wrapper.x, wrapper.y).x
                var globY = wrapper.mapToGlobal(wrapper.x, wrapper.y).y
                wrapper.sceneX = globX
                wrapper.sceneY = globY

            }
        }
    }

    function fillMissingBlocks() {
        fillGrid();
    }

    function receiveLocalBlockLaunchPayload(payload) {
        if (!payload)
            return null;
        const enriched = Object.assign({}, payload, {
            battleGrid: root.uuid,
            uuid: uuid,
            launchDirection: launchDirection
        });
        distributedBlockLaunchPayload(enriched);
        return enriched;
    }


    function buildLaunchSequence() {
        var sequence = [];
        for (var row = gridRows - 1; row >= 0; --row) {
            if (row % 2 === 1) {
                for (var columnDesc = gridCols - 1; columnDesc >= 0; --columnDesc)
                    sequence.push({ row: row, column: columnDesc });
            } else {
                for (var columnAsc = 0; columnAsc < gridCols; ++columnAsc)
                    sequence.push({ row: row, column: columnAsc });
            }
        }
        return sequence;
    }

    function prepareLaunchSequence() {
        launchSequence = buildLaunchSequence();
        launchSequenceIndex = 0;
    }

    function triggerLaunchForEntry(entry, row, column) {
        if (!entry)
            return false;
        if (normalizeStateName(entry.blockState) !== "matched")
            return false;

        const wrapper = getBlockWrapper(row, column);
        entry.blockState = "launch";
        if (entry.health === undefined || entry.health === null)
            entry.health = 5;
        entry.energyAmount = Math.max(entry.energyAmount || 0, entry.health || 0);

        var globalPoint = { x: 0, y: 0 };
        if (wrapper && typeof wrapper.mapToGlobal === "function")
            globalPoint = wrapper.mapToGlobal(0, 0);
        else {
            const cellPos = cellPosition(row, column);
            globalPoint = root.mapToGlobal(cellPos.x, cellPos.y);
        }

        const payload = {
            blockName: entry.itemName,
            row: entry.row,
            column: entry.column,
            health: entry.health,
            blockColor: entry.blockColor || "",
            x: globalPoint.x,
            y: globalPoint.y,
            action: "launch",
            battleGrid: root.uuid
        };
        distributeBlockLaunchPayload(payload);
        if (wrapper)
            wrapperLaunched(wrapper);
        return true;
    }

    function launchNextMatchedBlock() {
        ensureMatrix();
        while (launchSequenceIndex < launchSequence.length) {
            const coord = launchSequence[launchSequenceIndex++];
            const entry = getBlockEntryAt(coord.row, coord.column);
            if (!entry)
                continue;
            if (!triggerLaunchForEntry(entry, coord.row, coord.column))
                continue;
            return true;
        }
        return false;
    }

    function stopAllStateTimers() {
        if (compactStateCheckTimer.running)
            compactStateCheckTimer.stop();
        if (fillStateCheckTimer.running)
            fillStateCheckTimer.stop();
        if (matchStateCheckTimer.running)
            matchStateCheckTimer.stop();
        if (launchBlocksTimer.running)
            launchBlocksTimer.stop();
        if (launchStateCheckTimer.running)
            launchStateCheckTimer.stop();
    }

    function checkCompactStateCompletion() {
        if (!BattleGridLogic.allEntriesIdleAllowMissing(root))
            return;
        compactStateCheckTimer.stop();
        requestState("fill");
    }

    function checkFillStateCompletion() {
        if (!BattleGridLogic.allEntriesIdleNoMissing(root))
            return;
        fillStateCheckTimer.stop();
        requestState("match");
    }

    function evaluateMatchState() {
        matchStateCheckTimer.stop();
        if (BattleGridLogic.hasMatchedBlocks(root))
            requestState("launch");
        else {
            postSwapCascading = false;
            requestState("idle");
        }
    }

    function checkLaunchStateCompletion() {
        if (!BattleGridLogic.allEntriesIdleDestroyedOrMissing(root))
            return;
        launchStateCheckTimer.stop();
        requestState("compact");
    }

    function calculateLaunchDamage(payload) {
        if (!payload)
            return { remainingHealth: 0, blocksDamaged: [], directDamage: 0 };

        const column = payload.column;
        if (column === undefined || column === null || column < 0 || column >= gridCols)
            return { remainingHealth: payload.health || 0, blocksDamaged: [], directDamage: 0 };

        var remaining = payload.health !== undefined && payload.health !== null ? payload.health : 0;
        if (remaining <= 0)
            return { remainingHealth: remaining, blocksDamaged: [], directDamage: 0 };

        ensureMatrix();
        const damagedBlocks = [];
        var lastImpact = null;
        const damageAscending = normalizeStateName(launchDirection) === "up";
        const rowStart = damageAscending ? 0 : gridRows - 1;
        const rowEnd = damageAscending ? gridRows : -1;
        const rowStep = damageAscending ? 1 : -1;

        var columnClearedBeforeImpact = true;
        for (var scanRow = 0; scanRow < gridRows; ++scanRow) {
            const scanEntry = getBlockEntryAt(scanRow, column);
            if (!scanEntry)
                continue;
            const scanState = normalizeStateName(scanEntry.blockState);
            const scanHealth = scanEntry.health;
            const healthActive = (scanHealth === undefined || scanHealth === null || scanHealth > 0);
            if (healthActive && scanState !== "destroyed" && scanState !== "waitandexplode") {
                columnClearedBeforeImpact = false;
                break;
            }
        }

        for (var row = rowStart; row !== rowEnd && remaining > 0; row += rowStep) {
            const entry = getBlockEntryAt(row, column);
            if (!entry)
                continue;
            const state = normalizeStateName(entry.blockState);
            if (state && state !== "idle")
                continue;

            var blockColor = entry.blockColor || (entry.entry && entry.entry.blockColor) || "";
            var heroPlacement = heroPlacementForCell(row, column);
            if (heroPlacement && heroPlacement.cardData) {
                var heroHealthBefore = heroPlacement.cardData.heroCurrentHealth;
                var heroDamageResult = applyDamageToHeroCell(row, column, remaining, { reason: "launch", payload: payload });
                if (heroDamageResult.applied > 0) {
                    remaining -= heroDamageResult.applied;
                    damagedBlocks.push({
                                            row: row,
                                            column: column,
                                            destroyed: heroDamageResult.destroyed,
                                            color: blockColor,
                                            energyReward: heroDamageResult.destroyed ? heroHealthBefore : 0,
                                            hero: true
                                        });
                    if (shakeEffector)
                        shakeEffector.triggerImpact();
                    lastImpact = { row: row, column: column };
                }
                continue;
            }

            if (entry.health === undefined || entry.health === null)
                entry.health = 100;

            if (entry.health <= 0)
                continue;

            const targetHealth = entry.health;
            if (remaining >= targetHealth) {
                remaining -= targetHealth;
                entry.energyAmount = Math.max(entry.energyAmount || 0, targetHealth);
                entry.health = 0;
                entry.blockState = "waitAndExplode";
                damagedBlocks.push({
                                        row: row,
                                        column: column,
                                        destroyed: true,
                                        color: blockColor,
                                        energyReward: targetHealth
                                    });
                if (shakeEffector)
                    shakeEffector.triggerImpact();
                lastImpact = { row: row, column: column };
            } else {
                entry.health = targetHealth - remaining;
                damagedBlocks.push({
                                        row: row,
                                        column: column,
                                        destroyed: false,
                                        color: blockColor,
                                        energyReward: 0
                                    });
                remaining = 0;
                lastImpact = { row: row, column: column };
            }
        }

        const breachHealth = remaining;
        const breachOccurred = columnClearedBeforeImpact && breachHealth > 0;
        if (breachOccurred && shakeEffector)
            shakeEffector.triggerBreach();

        var directDamage = 0;
        if (remaining > 0) {
            const overflow = Math.min(remaining, mainHealth);
            if (overflow > 0) {
                mainHealth -= overflow;
                directDamage = overflow;
                remaining -= overflow;
            }
        }

        const endpointPayload = Object.assign({}, payload, {
            damagedBlocks: damagedBlocks.slice(),
            remainingHealth: remaining,
            directDamage: directDamage
        });

        var endpointRow;
        if (lastImpact)
            endpointRow = lastImpact.row;
        else
            endpointRow = damageAscending ? 0 : gridRows - 1;
        if (endpointRow < 0)
            endpointRow = 0;
        else if (endpointRow >= gridRows)
            endpointRow = gridRows - 1;
        const endpointCell = cellPosition(endpointRow, column);
        const endpointGlobal = root.mapToGlobal(endpointCell.x, endpointCell.y);
        informBlockLaunchEndPoint(endpointPayload, endpointGlobal.x, endpointGlobal.y);

        return {
            remainingHealth: remaining,
            blocksDamaged: damagedBlocks,
            directDamage: directDamage,
            breachHealth: breachHealth,
            breachOccurred: breachOccurred,
            columnCleared: columnClearedBeforeImpact,
            sourceBlockColor: payload.blockColor || ""
        };
    }

    function launchMatchedBlocks() {
        ensureMatrix();
        const launched = [];
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                const entry = getBlockEntryAt(row, column);
                if (!entry)
                    continue;
                if (triggerLaunchForEntry(entry, row, column) && entry.itemName)
                    launched.push(entry.itemName);
            }
        }
        return { launched: launched };
    }

    function findWrapperByItemName(blockId) {
        ensureMatrix();
        for (var row = 0; row < gridRows; ++row) {
            for (var column = 0; column < gridCols; ++column) {
                const wrapper = blockMatrix[row][column];
                if (wrapper && wrapper.itemName === blockId)
                    return wrapper;
            }
        }
        return null;
    }

    Component { id: dragComp; Engine.GameDragItem { } }
    Component { id: blockComp; UI.Block { } }

    Timer {
        id: compactStateCheckTimer
        interval: 120
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: checkCompactStateCompletion()
    }

    Timer {
        id: fillStateCheckTimer
        interval: 120
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: checkFillStateCompletion()
    }

    Timer {
        id: matchStateCheckTimer
        interval: 150
        repeat: false
        running: false
        triggeredOnStart: false
        onTriggered: evaluateMatchState()
    }

    Timer {
        id: launchBlocksTimer
        interval: 90
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: {
            if (!launchNextMatchedBlock()) {
                launchBlocksTimer.stop();
                launchStateCheckTimer.start();
            }

        }
    }

    Timer {
        id: launchStateCheckTimer
        interval: 120
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: checkLaunchStateCompletion()
    }

    Component.onCompleted: {
        for (var i=0; i<6; i++) {
            var poolInst = poolComp.createObject(root);
            pools[i] = poolInst;
            pools[i].currentIndex = Math.floor(Math.random() * 1000)
        }
        Factory.registerBattleGrid(root);

        requestState("init");

    }
}
