# engine/AbstractGameItem.qml
## File details
Base item wrapper that registers scene items and loads child components via an internal loader.

## Functions/methods/routines
### deriveParent() -- chooses the visual parent, preferring `gameScene` or `itemParent` when set.
### isUndefined(object) -- helper that returns true when a value is the JavaScript undefined type.
### loadComponent(componentObject) -- assigns the provided component to the internal loader.

## Properties/members
### gameScene -- reference to the owning `GameScene`.
### sceneX -- stored scene-space x coordinate.
### sceneY -- stored scene-space y coordinate.
### itemParent -- overrides the default parent for the loaded item.
### itemWidth -- cached width value for layout tools.
### itemHeight -- cached height value for layout tools.
### itemInstance -- reference slot for the loaded instance.
### itemName -- key used when registering with the scene.
### itemComponent -- alias exposing the loader's `sourceComponent`.

# engine/GameDragItem.qml
## File details
Draggable game item that exposes a `DragHandler` so wrapped visuals can be moved around the scene while notifying a drag parent of lifecycle events.

## Functions/methods/routines
### (none) -- interaction is driven by the embedded `DragHandler` handlers.

## Properties/members
### dragParent -- object that receives `beginDrag`/`endDrag` callbacks.
### gameScene -- reference to the owning scene (used for registration and callbacks).
### itemName -- identifier for the draggable item.
### entry -- required content instance used to mirror geometry.
### content -- default property alias; add visuals here to make them draggable.
### contentItem -- alias exposing the internal wrapper item for advanced positioning.
### dragStartX / dragStartY -- global coordinates when the drag starts.
### dragCurrentX / dragCurrentY -- placeholders for live drag position tracking.
### animationDurationX / animationDurationY -- durations for x/y easing.
### animationEnabledX / animationEnabledY -- toggles for the axis animations.
### handler -- alias exposing the internal `DragHandler` instance.
### dragHandler -- the actual `DragHandler` controlling pointer interaction.

# engine/GameDropItem.qml
## File details
Drop zone wrapper that raises signals as `GameDragItem` elements hover and drop, optionally snapping them to the zone’s center.

## Functions/methods/routines
### isGameDragItem(item) -- helper that checks whether a dragged object exposes the expected GameDragItem API.
### snapItemToCenter(dragItem) -- recenters a dropped GameDragItem within the zone when `autoSnap` is true.

## Properties/members
### content -- default property alias to populate the drop zone visuals.
### contentItem -- direct access to the wrapper Item that hosts content.
### containsDrag -- true while an accepted drag hovers over the zone.
### autoSnap -- controls whether dropped items reposition to the zone center.

## signals/events
### dragEntered(var dragItem) -- emitted when a compatible draggable enters the zone.
### dragExited(var dragItem) -- emitted when a compatible draggable leaves without dropping.
### dropReceived(var dragItem) -- emitted when a compatible draggable is dropped inside.

# engine/GameScene.qml
## File details
Scene graph container that tracks named items and coordinates drag payload data.

## Functions/methods/routines
### getSceneItem(itemName) -- returns a previously registered scene item or logs an error.
### addSceneItem(itemName, itemObject) -- registers an item and ensures it knows its scene name/reference.
### setSceneItemProperties(itemName, propsObject) -- convenience helper for mutating stored scene item metadata.
### beginDrag(dragItem, _dragPayload = []) -- initializes the active drag payload for the scene.

## Properties/members
### sceneWidth / sceneHeight -- dimensions of the scene when defined.
### parentScene -- optional parent scene reference.
### sceneName -- identifier for the scene instance.
### sceneItems -- dictionary of registered items keyed by name.

## signals/events
### itemDragStarted(string itemName, var dragItem, real x, real y) -- emitted when a named drag item starts being dragged with the local pointer position.
### itemDragMoved(string itemName, var dragItem, real x, real y, var offsets) -- emitted on drag movement updates, including the latest offsets from the drag start.
### itemDroppedInDropArea(string dragItemName, var dragItem, string dropItemName, var dropItem, real startX, real startY, real endX, real endY) -- emitted when a drag item lands on a registered drop area, providing the items and start/end coordinates.
