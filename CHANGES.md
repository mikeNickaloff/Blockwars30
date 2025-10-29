# Change 7 - Rebuild WHEEL Reference
## Status
- Complete
## Context
- WHEEL.md needs to capture an up-to-date inventory of every callable in the project.
- Project guidelines require WHEEL.md to be the quick reference for available functions, properties, and signals per file.
- Current WHEEL.md predates recent work and may omit newly added files or APIs.

## Proposed Changes
- Catalogue all project files to identify exposed functions, properties, members, and signals.
- Rewrite WHEEL.md using the prescribed format with one section per file and concise descriptions.
- Cross-check against README.md goals to ensure terminology and context stay aligned.

## Questions / Comments
- None.

# Change 6 - Finalize GridCell Drop Target
## Status
- Complete
## Context
- BattleGrid relies on GridCell delegates to expose drop behavior and state.
- Current GridCell stub offers no item tracking or visual feedback.
- Need cell-level API to report assigned items and notify BattleGrid about drops.

## Proposed Changes
- Implement GridCell as a GameDropItem with sizing helpers and assigned-item tracking.
- Emit signals for assignment changes and offer helper methods for centering items.
- Expose styling hooks (colors/borders) for future UI polish while keeping defaults subdued.

## Questions / Comments
- None.

# Change 5 - Implement BattleGrid Component
## Status
- Complete
## Context
- Need a 6x6 battle grid that integrates with existing drag/drop infrastructure.
- Blocks must queue above the grid per column and drop into cells on demand.
- Swapping occupied cells during drops should be handled within the grid component.

## Proposed Changes
- Lay out BattleGrid as a Row hosting six explicit ListView columns using a shared delegate.
- Track cell and block assignments to enable findCell(row, col) and swap-on-drop behavior.
- Implement buffered block creation per column with timed drop execution into visible cells.

## Questions / Comments
- Clarify expected timing for buffer drop intervals (using a default until gameplay tuning).

# Change 4 - Emit Drag Lifecycle Signals
## Status
- Complete
## Context
- Need generic drag lifecycle hooks so scenes can react to GameDragItem events.
- Expose drop target data for other QML consumers per in-game wiring needs.

## Proposed Changes
- Declare itemDragStarted, itemDragMoved, and itemDroppedInDropArea signals in engine/GameScene.qml.
- Emit the new signals from the respective drag handlers with the requested payloads.
- Update WHEEL.md to document the new GameScene signals for future reuse.

## Questions / Comments
- None.

# Change 3 - Harden GameDropItem Drop Handling
## Status
- Complete
## Context
- DropArea drops in DebugScene can emit without an event object, causing runtime errors when accessing event.source.
- Need to guard against undefined drop events while keeping existing snapping behavior.

## Proposed Changes
- Update GameDropItem's onDropped handler to fall back to DropArea.drag.source when the event is missing or lacks a source.
- Ensure the handler still accepts the drop proposal and emits dropReceived with a valid drag item.

## Questions / Comments
- None.

# Change 2 - Make GameDropItem Accept GameDragItem Drops
## Status
- Complete
## Context
- DebugScene needs a way to drop dragged items into specific zones.
- GameDropItem currently provides no drop handling or feedback for GameDragItem instances.

## Proposed Changes
- Convert GameDropItem into an Item hosting a DropArea that accepts drags from GameDragItem sources.
- Expose signals/properties so scenes can react to enter, leave, and drop events with payload references.
- Ensure dragged GameDragItem snaps into the drop zone by coordinating with the scene/drag parent when a drop occurs.

## Questions / Comments
- Dropped items now auto-snap to the zone center by default; toggle `autoSnap` to disable.

# Change 1 - Enable Dragging in GameDragItem
## Status
- Complete
## Context
- DebugScene content cannot be dragged because the wrapper anchors to its parent and ignores position updates.
- Need scene-independent drag behavior for any children inside GameDragItem instances.

## Proposed Changes
- Remove the forced anchors.fill on GameDragItem and size it from loaded content so x/y can update.
- Introduce a content wrapper that tracks childrenRect and houses the loader output.
- Bind the DragHandler to the wrapper so pointer drags move the entire child bundle while preserving existing drag callbacks.

## Questions / Comments
- None.