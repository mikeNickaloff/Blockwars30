# Main.qml
## File details
Top-level Window that loads the main menu and toggles the DebugScene per README's debug workflow.

## Functions/methods/routines
### (none)

## Properties/members
### debugScene -- Hidden DebugScene instance made visible when the main menu emits `debugChosen`.

## signals/events
### (none)

# main.cpp
## File details
Qt application entry point that registers the image resource bundle, exposes the Pool type, and loads the Blockwars30 QML module.

## Functions/methods/routines
### main(int argc, char *argv[]) -- Boots the QGuiApplication, registers assets/types, and starts the event loop.

## Properties/members
### (none)

## signals/events
### (none)

# engine/AbstractGameItem.qml
## File details
Reusable base item that auto-registers with a GameScene and hosts child content via a Loader.

## Functions/methods/routines
### deriveParent() -- Chooses the visual parent, preferring `gameScene` or `itemParent` when available.
### isUndefined(object) -- Helper that returns true when a value is strictly `undefined`.
### loadComponent(componentObject) -- Assigns a new source component to the internal loader.

## Properties/members
### gameScene -- Scene reference used for registration and parent derivation.
### sceneX -- Cached scene-space x coordinate for helpers.
### sceneY -- Cached scene-space y coordinate for helpers.
### itemParent -- Optional override for the loaded item's parent Item.
### itemWidth -- Stored width for layout tools and metadata syncing.
### itemHeight -- Stored height for layout tools and metadata syncing.
### itemInstance -- Slot for the instantiated child content.
### itemName -- Scene registration key for this item.
### itemComponent -- Alias to the Loader sourceComponent so callers can swap content.
### pendingOffsetX -- Reserved horizontal offset for delayed layout adjustments.
### pendingOffsetY -- Reserved vertical offset for delayed layout adjustments.

## signals/events
### (none)

# engine/GameContainer.qml
## File details
Placeholder Item that currently exists as a convenience hook for future container-specific logic.

## Functions/methods/routines
### (none)

## Properties/members
### (none)

## signals/events
### (none)

# engine/GameDragAndSwapItem.qml
## File details
Specialized drag item that tracks match-3 grid positions to support swap logic layered on GameDragItem.

## Functions/methods/routines
### (none)

## Properties/members
### visualIndex -- Visual ordering hint when animating drag swaps.
### isAlreadyDisplaced -- Flag indicating the block has been moved from its original slot.
### targetIndex -- Target linear index to land on after a swap completes.
### sourceIndex -- Original linear index prior to a swap.
### columnIndex -- Column coordinate inside the owning grid.
### rowIndex -- Row coordinate inside the owning grid.
### startColumn -- Column at drag start for rollback or analytics.
### startRow -- Row at drag start for rollback or analytics.
### entry -- Reference to the visual block instance bound to this drag item.

## signals/events
### (none)

# engine/GameDragItem.qml
## File details
Primary draggable wrapper that synchronizes loaded content with drag gestures and reports lifecycle through signals.

## Functions/methods/routines
### destroySceneItem() -- Emits `entryDestroyed` so the scene can clean up when the drag item is torn down.

## Properties/members
### gameScene -- Required scene reference for registration and drag callbacks.
### itemName -- Required scene identifier for this drag item.
### entry -- Required visual/logic payload that mirrors the drag item's geometry.
### content -- Default property alias used to provide the draggable visuals.
### contentItem -- Alias exposing the wrapper Item for manual positioning.
### dragStartX -- Local x coordinate recorded at the start of a drag.
### dragStartY -- Local y coordinate recorded at the start of a drag.
### dragCurrentX -- Placeholder for tracking the latest drag x coordinate.
### dragCurrentY -- Placeholder for tracking the latest drag y coordinate.
### dragActive -- True while the pointer is actively dragging this item.
### payload -- Array of extra drag metadata shared with drop targets.
### animationDurationX -- Duration in milliseconds for the x-axis easing when repositioning.
### animationDurationY -- Duration in milliseconds for the y-axis easing when repositioning.
### animationEnabledX -- Enables or disables the x-axis easing Behavior.
### animationEnabledY -- Enables or disables the y-axis easing Behavior.

## signals/events
### itemDragging(string itemName, real x, real y) -- Fired when the mouse press begins to drag this item.
### itemDropped(string itemName, real x, real y, real startX, real startY) -- Fired when the pointer releases the drag item.
### itemDraggedTo(string itemName, real x, real y, var offsets) -- Fired on mouse movement with offset data relative to drag start.
### entryDestroyed(string itemName) -- Emitted prior to teardown so the owning scene can release references.

# engine/GameDropItem.qml
## File details
DropArea wrapper that exposes drag enter/exit signals and can auto-center compatible GameDragItem payloads.

## Functions/methods/routines
### isGameDragItem(item) -- Validates that the dragged object exposes the GameDragItem API.
### snapItemToCenter(dragItem) -- Recenters a dropped GameDragItem and mirrors coordinates back to its entry.

## Properties/members
### gameScene -- Scene reference used for registration and callbacks.
### itemName -- Scene identifier for the drop surface.
### content -- Default property alias to populate the visible drop target.
### contentItem -- Alias exposing the wrapper Item for manual tweaks.
### containsDrag -- Mirrors DropArea.containsDrag so layouts can react visually.
### autoSnap -- Toggles whether dropped GameDragItem payloads are recentered automatically.
### entry -- Reference to the visual content bound to this drop zone.

## signals/events
### dragItemEntered(var itemName, var dragEvent) -- Raised when an accepted drag hovers over the drop zone.
### dragItemExited(var itemName, var dragEvent) -- Raised when the hovering drag leaves without dropping.

# engine/GameDynamicItem.qml
## File details
Convenience subclass of AbstractGameItem that enforces the presence of scene and item name metadata.

## Functions/methods/routines
### (none)

## Properties/members
### gameScene -- Required scene reference for dynamic items.
### itemName -- Required scene identifier.

## signals/events
### (none)

# engine/GameLayout.qml
## File details
GridLayout alias used for arranging menu components with potential future custom behavior.

## Functions/methods/routines
### (none)

## Properties/members
### (none beyond GridLayout defaults)

## signals/events
### (none)

# engine/GameScene.qml
## File details
Central scene coordinator that tracks named items, wires drag/drop lifecycles, and emits gameplay events.

## Functions/methods/routines
### getSceneItem(itemName) -- Fetches a previously registered scene item or logs an error when missing.
### removeSceneItem(itemName) -- Destroys and removes a stored scene item entry.
### addSceneItem(itemName, itemObject) -- Registers a scene item and stamps scene metadata onto it.
### addSceneDragItem(itemName, itemObject) -- Registers a drag item and hooks drag lifecycle signals for scene relays.
### addSceneDropItem(itemName, itemObject) -- Registers a drop zone and hooks enter/exit signals.
### handleDropItemEntered(_itemName, _dragEvent) -- Updates `activeDrag` when a drag enters a drop area.
### handleDropItemExited(_itemName, _dragEvent) -- Flags the active drag as exiting so later moves clear the target.
### handleDragItemStartDrag(itemName, _x, _y) -- Captures the drag source and emits `itemDragStarted`.
### handleDragItemMoved(itemName, _x, _y, offsets) -- Relays drag motion via `itemDragMoved`, resetting target when exiting.
### handleDragItemDropped(itemName, _x, _y, _startx, _starty) -- Emits `itemDroppedInDropArea` with source and target context.
### setSceneItemProperties(itemName, propsObject) -- Attempts to update cached metadata on a registered item.

## Properties/members
### sceneWidth -- Optional scene width metadata for layout consumers.
### sceneHeight -- Optional scene height metadata for layout consumers.
### parentScene -- Reference to a parent GameScene when scenes are nested.
### sceneName -- Logical identifier for this scene instance.
### sceneItems -- Dictionary mapping item names to registered objects.
### activeDrag -- Struct tracking the current drag source, target, and exit state.

## signals/events
### itemDragStarted(string itemName, var dragItem, real x, real y) -- Notifies listeners that a drag began.
### itemDragMoved(string itemName, var dragItem, real x, real y, var offsets) -- Broadcasts drag motion with offset data.
### itemDroppedInDropArea(string dragItemName, var dragItem, string dropItemName, var dropItem, real startX, real startY, real endX, real endY) -- Reports successful drops to interested systems.

# engine/GameSpriteSheetItem.qml
## File details
Sprite-driven dynamic item that proxies AnimatedSprite settings and emits start/end callbacks for effects.

## Functions/methods/routines
### startAnimation() -- Starts the internal AnimatedSprite playback.

## Properties/members
### spriteSheetFile -- Alias to the AnimatedSprite source.
### frameCount -- Alias controlling how many frames the sprite uses.
### loops -- Alias specifying how many loops to play.
### frameDuration -- Alias controlling per-frame duration in milliseconds.
### frameWidth -- Alias assigning frame width for the sprite sheet.
### frameHeight -- Alias assigning frame height for the sprite sheet.

## signals/events
### animationEndCallback(var itemName) -- Emitted when the animation finishes.
### animationBeginCallback(var itemName) -- Emitted when the animation starts running.

# engine/GameStaticItem.qml
## File details
Static variant of AbstractGameItem kept for parity with dynamic items when no extra behavior is needed.

## Functions/methods/routines
### (none)

## Properties/members
### (none beyond AbstractGameItem defaults)

## signals/events
### (none)

# game/DebugScene.qml
## File details
Development scene embedding draggable blocks, a drop zone, and demo timers to exercise engine behaviors.

## Functions/methods/routines
### createBlock(color) -- Uses Factory.createBlock to spawn a draggable block with the requested color.

## Properties/members
### blocks -- Array tracking the currently instantiated draggable block items.
### launchIndex -- Incrementing counter used by the timer-driven launch sequence.

## signals/events
### (none beyond GameScene)

# game/factory.js
## File details
Factory helpers for constructing UI blocks wrapped in Engine.GameDragItem instances with unique names.

## Functions/methods/routines
### uid(prefix) -- Generates a quasi-unique identifier using time and an incrementing sequence.
### createBlock(blockComp, dragComp, parent, gameScene, opts) -- Creates a UI.Block, wraps it in a GameDragItem, registers it with the scene, and returns the drag item.

## Properties/members
### (module-scope `_seq`) -- Internal counter feeding uid generation.

## signals/events
### (none)

# game/layouts.js
## File details
Layout utilities used by BattleGrid and other grid-based views to translate linear indexes to coordinates.

## Functions/methods/routines
### gridPos(index, o) -- Returns `{x, y, row, col}` coordinates inside a configurable grid footprint.

## Properties/members
### (none)

## signals/events
### (none)

# game/MainMenuScene.qml
## File details
Main menu scene exposing navigation signals and using GameLayout to stack MenuButtons.

## Functions/methods/routines
### (none)

## Properties/members
### (none)

## signals/events
### singlePlayerChosen() -- Triggered when the Single Player button is pressed.
### multiPlayerChosen() -- Triggered when the Multiplayer button is pressed.
### powerupEditorChosen() -- Triggered when the Powerup Editor button is pressed.
### optionsChosen() -- Triggered when the Options button is pressed.
### debugChosen() -- Triggered when the Debug button is pressed.
### exitChosen() -- Triggered when the Exit button is pressed.

# game/SinglePlayerScene.qml
## File details
Placeholder GameScene reserved for single-player gameplay layout.

## Functions/methods/routines
### (none)

## Properties/members
### (none)

## signals/events
### (none)

# game/ui/BattleGrid.qml
## File details
Runtime-instantiated battle grid that spawns draggable blocks via Factory helpers and reflows them into a grid.

## Functions/methods/routines
### arrangeAll() -- Iterates current instances, applying Layout.gridPos to keep blocks aligned with grid parameters.

## Properties/members
### gameScene -- Scene reference required when registering new drag items.
### gridCols -- Number of columns in the grid.
### gridRows -- Number of rows in the grid.
### cellW -- Width of each grid cell in pixels.
### cellH -- Height of each grid cell in pixels.
### gapX -- Horizontal spacing between cells.
### gapY -- Vertical spacing between cells.
### originX -- Horizontal offset applied to the entire grid footprint.
### originY -- Vertical offset applied to the entire grid footprint.
### instances -- Array tracking created GameDragItem instances for later reflow or cleanup.

## signals/events
### (none)

# game/ui/BlockExplodeParticles.qml
## File details
Particle effect container that bursts multiple emitters to simulate a block explosion.

## Functions/methods/routines
### burstAt(xpos, ypos) -- Triggers each emitter at the given coordinate to play the explosion sequence.

## Properties/members
### system -- Exposes the internal ParticleSystem for advanced tuning.

## signals/events
### (none)

# game/ui/Block.qml
## File details
Visual block component that swaps between idle, launch, and explode states while coordinating drop registration.

## Functions/methods/routines
### blockLaunchSpriteSheet() -- Produces the expected sprite sheet URL for the current block color.

## Properties/members
### blockColor -- Logical color for sprite selection and styling.
### source -- Alias to the Loader source for direct component swapping.
### gameScene -- Scene reference used for registering the internal drop item.
### itemName -- Scene identifier shared with the drop item.
### blockState -- High-level state driving which visual component is loaded.
### launchComponent -- Component definition used when the block launches.
### idleComponent -- Component definition used during idle state.
### explodeComponent -- Component definition used during explosion.

## signals/events
### blockDestroyed() -- Emitted when the post-launch timer completes and the block should be removed.

# game/ui/GridCell.qml
## File details
Drop-enabled grid cell that tracks the assigned drag item and updates visuals based on occupancy.

## Functions/methods/routines
### hasItem() -- Returns true when a drag item is currently assigned to the cell.
### clearAssignment() -- Clears the recorded drag item assignment.
### centerItem(dragItem) -- Reuses snapItemToCenter to align a drag item with the cell center.

## Properties/members
### rowIndex -- Row coordinate within the parent grid.
### columnIndex -- Column coordinate within the parent grid.
### battleGrid -- Back-reference to the owning BattleGrid Item.
### assignedItem -- Currently assigned drag item, if any.
### __gridRegistered -- Internal flag indicating registration with the grid.
### idleColor -- Fill color when the cell is empty.
### hoverColor -- Fill color while an accepted drag hovers over the cell.
### occupiedColor -- Fill color when the cell holds a block.
### borderColor -- Border color used when debug borders are enabled.
### showDebugBorder -- Toggles whether the border is drawn for debugging.

## signals/events
### assignmentChanged(var item) -- Emitted whenever `assignedItem` updates.

# game/ui/GridColumn.qml
## File details
Column ListView template that spawns placeholder GameDragItems for prototype grid column experiments.

## Functions/methods/routines
### (none)

## Properties/members
### cellModel -- Backing data model used to populate the column (defaults to 6 rows).
### rowCount -- Row count hint for external configuration.
### root -- Optional reference to the owning grid container.
### columnIndex -- Column coordinate for this ListView.
### gameScene -- Scene reference passed to delegate GameDragItems.

## signals/events
### (none)

# game/ui/Hud.qml
## File details
HUD placeholder Item reserved for future overlays.

## Functions/methods/routines
### (none)

## Properties/members
### (none)

## signals/events
### (none)

# game/ui/MenuButton.qml
## File details
Wrapper around Qt Quick Controls Button preconfigured for menu layout usage.

## Functions/methods/routines
### (none)

## Properties/members
### parentItem -- Optional reference to the scene item that owns the button.
### buttonText -- Alias to the button text for quick assignment.

## signals/events
### (none beyond Button defaults)

# game/ui/PowerupCard.qml
## File details
GameDragItem-based card shell used for drag-and-drop placement of powerup cards.

## Functions/methods/routines
### (none)

## Properties/members
### gameScene -- Required scene reference inherited from GameDragItem.
### itemName -- Required identifier used when registering the card.

## signals/events
### (none beyond GameDragItem)

# lib/promise.js
## File details
Promise library port that mirrors JavaScript Promise semantics for QML, including combinators and timers.

## Functions/methods/routines
### clearTimeout(timerId) -- Stops and destroys a previously scheduled PromiseTimer.
### setTimeout(callback, timeout) -- Schedules a PromiseTimer to invoke the callback after the timeout and returns its id.
### QPromise(executor) -- Constructor implementing a Promise-like object with fulfillment/rejection handlers.
### instanceOfPromiseJS(object) -- Detects promises created by this JS library.
### instanceOfPromiseItem(object) -- Detects QML Promise objects exposed by Promise.qml.
### instanceOfPromise(object) -- Returns true for either JS or QML promise variants.
### _instanceOfSignal(object) -- Checks whether the argument behaves like a Qt signal (has connect/disconnect).
### QPromise.prototype.then(onFulfilled, onRejected) -- Chains fulfillment and rejection handlers, returning a new QPromise.
### QPromise.prototype.resolve(value) -- Resolves the promise, assimilating other promises or signals when provided.
### QPromise.prototype._resolveInTick(value) -- Defers resolution to the next event loop tick.
### QPromise.prototype._resolveUnsafe(value) -- Resolves immediately without additional checks.
### QPromise.prototype.reject(reason) -- Rejects the promise, optionally wiring Qt signals to propagate rejection.
### QPromise.prototype._rejectUnsafe(reason) -- Rejects immediately without additional checks.
### QPromise.prototype._emit(arr, value) -- Runs stored callbacks in order, passing along the result.
### QPromise.prototype._executeThen() -- Executes queued fulfillment or rejection handlers based on state.
### QPromise.prototype._setState(state) -- Updates the state flags for fulfilled/rejected/settled tracking.
### promise(executor) -- Convenience creator returning a new pending QPromise.
### resolve(result) -- Returns a resolved QPromise with the provided result.
### resolved(result) -- Alias of resolve for compatibility.
### reject(reason) -- Returns a rejected QPromise with the provided reason.
### rejected(reason) -- Alias of reject for compatibility.
### Combinator(promises, allSettled) -- Aggregator responsible for resolving once a set of promises complete.
### Combinator.prototype.add(promises) -- Adds one or more promises to the combinator pool.
### Combinator.prototype._addPromises(promises) -- Internal helper to append an array-like collection of promises.
### Combinator.prototype._addPromise(promise) -- Adds a single promise, wrapping signals when encountered.
### Combinator.prototype._addCheckedPromise(promise) -- Hooks fulfillment/rejection callbacks to track progress.
### Combinator.prototype._reject(reason) -- Handles rejection depending on the allSettled mode.
### Combinator.prototype._settle() -- Resolves or rejects the combined promise when all inputs complete.
### combinator(promises, allSettled) -- Factory that returns a new Combinator instance.
### all(promises) -- Returns a promise fulfilled when all input promises resolve, or rejects on the first failure.
### allSettled(promises) -- Returns a promise that resolves after all inputs settle, collecting their results.

## Properties/members
### QPromise.all -- Assigned to the `all` helper to mirror native Promise.all.
### QPromise.resolve -- Assigned to the `resolve` helper for parity with native Promise.resolve.
### QPromise.reject -- Assigned to the `reject` helper for parity with native Promise.reject.

## signals/events
### (none)

# lib/Promise.qml
## File details
QtObject wrapper around the JS Promise library that exposes QML-friendly resolve/reject hooks and signals.

## Functions/methods/routines
### setTimeout(callback, interval) -- Delegates to QPTimer to schedule a callback after the interval.
### then(onFulfilled, onRejected) -- Chains handlers onto the underlying JS promise.
### resolve(value) -- Resolves the internal promise, assimilating other promise-like objects when provided.
### reject(reason) -- Rejects the internal promise.
### all(promises) -- Returns a JS promise that resolves when all supplied promises fulfill.
### allSettled(promises) -- Returns a JS promise that resolves once all supplied promises settle.
### instanceOfPromise(object) -- Checks whether an object is an instance of this QML promise wrapper.
### _instanceOfSignal(object) -- Delegates to PromiseJS helper to test for Qt signals.
### _init() -- Lazily constructs the underlying JS promise and wires state signals.

## Properties/members
### data -- Default property alias enabling inline child objects.
### __data -- Backing list holding inline child objects.
### isFulfilled -- True when the promise has resolved.
### isRejected -- True when the promise has rejected.
### isSettled -- Computed flag indicating the promise has either resolved or rejected.
### resolveWhen -- Expression or promise that auto-resolves this object when it becomes truthy/completes.
### rejectWhen -- Expression or signal that auto-rejects this object when it becomes truthy.
### _promise -- Internal reference to the JS QPromise instance.
### ___promiseQmlSignature71237___ -- Marker used for type checking between JS and QML worlds.

## signals/events
### fulfilled(var value) -- Emitted when the promise resolves successfully.
### rejected(var reason) -- Emitted when the promise rejects.
### settled(var value) -- Emitted after fulfillment or rejection for generic observers.

# lib/PromiseTimer.qml
## File details
Thin Timer wrapper used by the promise utility to schedule callbacks.

## Functions/methods/routines
### (none)

## Properties/members
### (inherits QtQuick Timer defaults)

## signals/events
### (none)

# lib/qmldir
## File details
Module manifest exposing the Promise JS library and QML wrapper under `PromiseLib`.

## Functions/methods/routines
### (none)

## Properties/members
### module -- Declares the module name `PromiseLib`.
### Q 1.0 promise.js -- Maps the JavaScript library for import.
### Promise 1.0 Promise.qml -- Registers the QML Promise type.

## signals/events
### (none)

# pool.h
## File details
QObject-derived pool that serves deterministic random numbers and color names to QML consumers.

## Functions/methods/routines
### Pool(QObject *parent = nullptr) -- Constructor that initializes the pool.
### loadNumbers() -- Loads numeric data from the embedded random_numbers resource.
### randomNumber(int current_index = -1) -- Returns the next value from the number pool, optionally seeding the index.
### nextColor(int current_index = -1) -- Maps the next pooled number to a block color string.

## Properties/members
### m_numbers -- QHash storing loaded number entries keyed by index.
### pool_index -- Tracks the current index into the number pool.

## signals/events
### (none)

# pool.cpp
## File details
Implementation backing Pool that reads resource data and cycles through numeric and color outputs.

## Functions/methods/routines
### Pool::Pool(QObject *parent) -- Invokes loadNumbers during construction.
### Pool::loadNumbers() -- Reads random_numbers.txt from resources and seeds the number hash.
### Pool::randomNumber(int current_index) -- Steps through the stored numbers and returns the next entry.
### Pool::nextColor(int current_index) -- Converts the next numeric entry into a color name.

## Properties/members
### (relies on members declared in pool.h)

## signals/events
### (none)

# images.qrc
## File details
Qt resource collection listing sprite and UI assets bundled with the application.

## Functions/methods/routines
### (none)

## Properties/members
### (resource file entries define file paths for bundling)

## signals/events
### (none)
