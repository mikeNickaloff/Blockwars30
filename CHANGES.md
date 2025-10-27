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
