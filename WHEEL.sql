PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE files (
  id INTEGER PRIMARY KEY,
  relpath TEXT UNIQUE NOT NULL,
  description TEXT
);
INSERT INTO files VALUES(1,'game/ui/BattleGrid.qml','Battle grid UI component for block management and states');
INSERT INTO files VALUES(2,'game/DebugScene.qml','Debug scene orchestrating game state visualization and testing');
INSERT INTO files VALUES(3,'game/factory.js','Factory layer linking game scenes and wiring signals');
INSERT INTO files VALUES(4,'game/data/PowerupItem.qml','Powerup item data model and energy calculations');
INSERT INTO files VALUES(5,'game/data/PowerupDatabase.qml','Local storage wrapper storing powerup definitions and loadouts');
INSERT INTO files VALUES(6,'game/ui/PowerupCard.qml','Visual card for displaying individual powerup stats and energy');
INSERT INTO files VALUES(7,'game/ui/PowerupCatalog.qml','Catalog grid for browsing and selecting powerups');
INSERT INTO files VALUES(8,'game/PowerupEditor.qml','Editor scene for creating and modifying powerups');
INSERT INTO files VALUES(9,'game/ui/MatchSetup.qml','Match setup screen for customizing loadouts before fights');
INSERT INTO files VALUES(10,'game/ui/BattleCardSidebar.qml','Sidebar UI for pre-match selected powerup cards with drag support');
INSERT INTO files VALUES(11,'game/ui/PowerupHero.qml','Visual placeholder representing a powerup hero placed on the grid');
INSERT INTO files VALUES(12,'game/data/PowerupCardModel.qml,description=Runtime Powerup card data helper storing energy/hero state','Shared data bridge between cards and hero instances');
INSERT INTO files VALUES(13,'game/MainMenuScene.qml','Main menu scene UI wiring');
INSERT INTO files VALUES(14,'Main.qml','Top-level window wiring');
INSERT INTO files VALUES(15,'wheel.sh','CLI helper for WHEEL database');
CREATE TABLE defs (
  id INTEGER PRIMARY KEY,
  file_id INTEGER NOT NULL,
  type TEXT NOT NULL,
  signature TEXT,
  parameters TEXT,
  description TEXT,
  FOREIGN KEY(file_id) REFERENCES files(id)
);
INSERT INTO defs VALUES(1,1,'signal','distributeBlockLaunchPayload(payload)','payload','Emitted when a block launch payload is generated within this grid before augmentation.');
INSERT INTO defs VALUES(2,1,'signal','distributedBlockLaunchPayload(payload)','payload','Broadcast payload describing a launch event including grid context for scene listeners.');
INSERT INTO defs VALUES(3,1,'function','receiveLocalBlockLaunchPayload(payload)','payload','Augments a locally generated launch payload with this grid''s UUID before rebroadcasting.');
INSERT INTO defs VALUES(4,1,'function','calculateLaunchDamage(payload)','payload','Applies launch payload damage to column blocks starting from the bottom row and cascades remaining damage upward.');
INSERT INTO defs VALUES(5,1,'function','launchMatchedBlocks()','','Transitions matched blocks into launch state and emits launch events for each.');
INSERT INTO defs VALUES(6,1,'property','property string uuid','','Unique identifier assigned to each battle grid instance for payload attribution.');
INSERT INTO defs VALUES(7,1,'property','property int mainHealth','','Tracks the player''s primary health pool to receive direct launch damage overflow.');
INSERT INTO defs VALUES(8,3,'function','createBlock(blockComp, dragComp, parent, gameScene, opts)','blockComp, dragComp, parent, gameScene, opts','Constructs a block with paired drag item and registers the pair with the scene.');
INSERT INTO defs VALUES(9,3,'function','registerBattleGrid(battleGrid)','battleGrid','Attaches battle-grid specific signal wiring such as launch payload relay hooks.');
INSERT INTO defs VALUES(10,2,'function','receiveBattleGridLaunchPayload(payload)','payload','Routes launch payloads between battle grids and triggers damage calculations.');
INSERT INTO defs VALUES(11,1,'signal','informBlockLaunchEndPoint(payload, endX, endY)','payload, endX, endY','Notifies listeners of the resolved launch endpoint position with damage summary.');
INSERT INTO defs VALUES(12,1,'function','getEntryAt(row, column)','row, column','Convenience wrapper returning the block entry at the specified grid coordinates.');
INSERT INTO defs VALUES(13,2,'function','forwardBlockLaunchEndPoint(payload, endX, endY)','payload, endX, endY','Relays resolved launch endpoints back to the originating grid to update visuals.');
INSERT INTO defs VALUES(14,1,'property','property var __launchRelayRegistered','','Internal guard flag ensuring signal wiring is only registered once per grid instance.');
INSERT INTO defs VALUES(15,1,'signal','informPostSwapCascadeStatus(payload)','payload','Broadcasts the grid''s post-swap cascade status to peer grids.');
INSERT INTO defs VALUES(16,1,'property','property bool postSwapCascading','','Flags when the grid is processing match cascades triggered by a swap.');
INSERT INTO defs VALUES(17,1,'function','distributePostSwapCascadeStatus()','','Emits the current post-swap cascade status payload to listeners.');
INSERT INTO defs VALUES(18,1,'function','informOpponentPostSwapCascadeStatus(payload)','payload','Responds to an opponent''s cascade status; resumes compaction if the peer has finished cascading.');
INSERT INTO defs VALUES(19,1,'function','hasMissingOrDestroyedBlocks()','','Scans the grid for empty or destroyed entries to determine if cascading should continue.');
INSERT INTO defs VALUES(20,1,'function','hasActiveNonIdleBlocks()','','Checks for blocks engaged in active states such as launch, match, or explode.');
INSERT INTO defs VALUES(21,1,'function','handlePostSwapCascadeResolution()','','Finalizes post-swap cascade flow by transitioning back to idle when no further cascades remain.');
INSERT INTO defs VALUES(22,2,'property','property var turnCoordinator','','Tracks offense/defense grids awaiting turn state synchronization.');
INSERT INTO defs VALUES(23,2,'function','normalizeState(value)','value','Utility converting a state value into its lowercase form for comparisons.');
INSERT INTO defs VALUES(24,2,'function','finalizeTurnStateSync()','','Sets offense grid idle and defense grid waiting once the previous turn finishes.');
INSERT INTO defs VALUES(25,2,'function','synchronizeTurnStateIfReady()','','Timer callback ensuring the defending grid reaches idle before handing control to the attacker.');
INSERT INTO defs VALUES(26,2,'function','handleTurnSwitch()','','Initiates turn state synchronization when the active player flips.');
INSERT INTO defs VALUES(27,2,'function','distributePostSwapCascade(payload)','payload','Forwards post-swap cascade status to the opposing grid.');
INSERT INTO defs VALUES(28,1,'property','property var launchSequence','','Sequence of grid coordinates used to launch matched blocks in snake order.');
INSERT INTO defs VALUES(29,1,'property','property int launchSequenceIndex','','Index into the launch sequence indicating the next coordinate to process.');
INSERT INTO defs VALUES(30,1,'function','allEntriesIdleAllowMissing()','','Checks whether every populated grid entry is idle while allowing empty slots.');
INSERT INTO defs VALUES(31,1,'function','allEntriesIdleNoMissing()','','Verifies the grid is fully populated and every block is idle.');
INSERT INTO defs VALUES(32,1,'function','allEntriesIdleDestroyedOrMissing()','','Ensures remaining blocks are either idle, destroyed, or absent before compacting again.');
INSERT INTO defs VALUES(33,1,'function','hasMatchedBlocks()','','Returns true if any grid entry is currently marked as matched.');
INSERT INTO defs VALUES(34,1,'function','buildLaunchSequence()','','Constructs the snake-order traversal used for sequential block launches.');
INSERT INTO defs VALUES(35,1,'function','prepareLaunchSequence()','','Initializes the launch sequence and resets iteration state before launching blocks.');
INSERT INTO defs VALUES(36,1,'function','triggerLaunchForEntry(entry, row, column)','entry, row, column','Switches a matched entry into launch state and emits its payload.');
INSERT INTO defs VALUES(37,1,'function','stopAllStateTimers()','','Stops all automation timers before transitioning to a new state.');
INSERT INTO defs VALUES(38,1,'function','checkCompactStateCompletion()','','Advances to fill once compaction settles and only idle or empty slots remain.');
INSERT INTO defs VALUES(39,1,'function','checkFillStateCompletion()','','Moves the grid into match state once every cell is populated and idle.');
INSERT INTO defs VALUES(40,1,'function','evaluateMatchState()','','Determines whether to launch matched blocks or return to idle after matching.');
INSERT INTO defs VALUES(41,1,'function','checkLaunchStateCompletion()','','Waits for launched blocks to resolve before returning to compact.');
INSERT INTO defs VALUES(42,1,'function','launchNextMatchedBlock()','','Launches the next matched block in the precomputed snake pattern.');
INSERT INTO defs VALUES(43,4,'function','normalizedHeroSpan(value)','value:number','Clamp hero row/column span inputs between 1 and 6 for downstream sizing logic.');
INSERT INTO defs VALUES(44,4,'function','ensureHeroSpanDefaults()',NULL,'Normalizes both hero span properties so drag and placement math always receives valid bounds.');
INSERT INTO defs VALUES(45,5,'function','normalizeHeroSpan(value)','value:number','Utility used by the database layer to coerce persisted hero dimensions into the valid 1-6 range.');
INSERT INTO defs VALUES(46,12,'function','ensureEnergyWithinBounds()',NULL,'Clamps accumulated energy to the current requirement and emits energy + activation updates for the runtime card state.');
INSERT INTO defs VALUES(47,12,'function','updateActivationState()',NULL,'Recomputes the activationReady flag whenever energy requirements change.');
INSERT INTO defs VALUES(48,12,'function','gainEnergy(amount)','amount:number','Adds rewarded energy to the card, respecting clamps and re-evaluating activation readiness.');
INSERT INTO defs VALUES(49,12,'function','resetRuntimeState()',NULL,'Clears accumulated energy, hero flags, and drag locks so the card behaves like a fresh selection.');
INSERT INTO defs VALUES(50,12,'function','applyRecord(record)','record:var','Loads database/loadout records into the runtime card, syncing hero spans, energy requirement, and color.');
INSERT INTO defs VALUES(51,12,'function','cloneRecord()',NULL,'Returns a lightweight JS object snapshot of the card state for signaling or hero preview needs.');
INSERT INTO defs VALUES(52,11,'function','heroColor()',NULL,'Derives the hex color used for the hero border based on the assigned card color palette.');
INSERT INTO defs VALUES(53,11,'function','applyCard(record)','record:var','Convenience helper to push a powerup record into the hero for consistent name, color, and span sizing.');
INSERT INTO defs VALUES(54,10,'function','repositionCards()',NULL,'Recomputes card home positions when the sidebar resizes and snaps existing drag items back into place.');
INSERT INTO defs VALUES(55,10,'function','homeXForSlot()',NULL,'Calculates the right-aligned X position for a sidebar card.');
INSERT INTO defs VALUES(56,10,'function','homeYForSlot(slotIndex)','slotIndex:int','Returns the vertical anchor for a given slot index using the configured spacing.');
INSERT INTO defs VALUES(57,10,'function','destroyCards()',NULL,'Destroys all drag items, heroes, and runtime card data before rebuilding the sidebar.');
INSERT INTO defs VALUES(58,10,'function','rebuildCards()',NULL,'Re-creates sidebar cards from the current loadout array, wiring drag + hero handling.');
INSERT INTO defs VALUES(59,10,'function','createCardSlot(slotIndex, record)','slotIndex:int, record:var','Creates the drag wrapper, hero preview, and runtime data object for a specific loadout slot.');
INSERT INTO defs VALUES(60,10,'function','updateDragEnabled(slot)','slot:var','Enables or disables a drag item based on activation state, lock flags, and placement status.');
INSERT INTO defs VALUES(61,10,'function','snapCardHome(slot)','slot:var','Resets a drag item to its resting coordinates and clears any active drag state.');
INSERT INTO defs VALUES(62,10,'function','handleCardDragStart(slot)','slot:var','Entry point for drag gestures that enforces activation gating and kicks off hero previews.');
INSERT INTO defs VALUES(63,10,'function','handleCardDragMove(slot)','slot:var','Updates hero previews while a sidebar card is being dragged.');
INSERT INTO defs VALUES(64,10,'function','handleCardDragEnd(slot)','slot:var','Closes previews, snaps cards home, and emits placement requests whenever a drag completes.');
INSERT INTO defs VALUES(65,10,'function','beginHeroPreview(slot)','slot:var','Makes the associated PowerupHero visible and notifies listeners that previewing has begun.');
INSERT INTO defs VALUES(66,10,'function','updateHeroPreview(slot)','slot:var','Moves the hero preview so it tracks the user drag path.');
INSERT INTO defs VALUES(67,10,'function','endHeroPreview(slot, wasDragging)','slot:var, wasDragging:bool','Hides the hero preview and notifies observers that the preview phase finished.');
INSERT INTO defs VALUES(68,10,'function','positionHero(slot)','slot:var','Aligns the hero overlay with the current drag position to mimic placement on the grid.');
INSERT INTO defs VALUES(69,10,'function','distributeEnergy(blockColor, amount)','blockColor:string, amount:number','Routes earned energy to every sidebar card that matches the supplied color, advancing activation progress.');
INSERT INTO defs VALUES(70,3,'function','createBattleCardSidebarCard(cardComp, dragComp, heroComp, parent, gameScene, opts)','cardComp:Component, dragComp:Component, heroComp:Component, parent:Item, gameScene:var, opts:var','Constructs a drag-ready PowerupCard wrapper plus optional hero preview for the sidebar selection UI.');
INSERT INTO defs VALUES(71,2,'function','refreshPlayerLoadout()',NULL,'Loads the current PlayerLoadout rows from the powerup DB so the sidebar stays in sync with Match Setup selections.');
INSERT INTO defs VALUES(72,2,'function','registerSidebarForGrid(grid, sidebar)','grid:Item, sidebar:Item','Caches a sidebar reference by battle grid UUID so reward logic can route energy to the right card set.');
INSERT INTO defs VALUES(73,2,'function','sidebarForGrid(grid)','grid:Item','Looks up a registered BattleCardSidebar for the provided grid UUID.');
INSERT INTO defs VALUES(74,2,'function','handleHeroPlacementRequest(cardData, heroItem, sceneX, sceneY)',NULL,'Validates drag drops from the sidebar and finalizes hero placement if the drop is fully over the owning battle grid.');
INSERT INTO defs VALUES(75,2,'function','heroPlacementBoundsValid(grid, cardData, sceneX, sceneY)',NULL,'Checks whether the projected hero footprint fits entirely within the grid surface before allowing placement.');
INSERT INTO defs VALUES(76,2,'function','finalizeHeroPlacement(cardData, heroItem, placedHero)',NULL,'Locks a powerup card after spawning its hero and hides the preview overlay.');
INSERT INTO defs VALUES(77,2,'function','processLaunchDamageRewards(sourceGrid, damageResult)',NULL,'Walks the BattleGrid damage summary and routes energy rewards to the launching grid’s sidebar.');
INSERT INTO defs VALUES(78,2,'function','refreshOpponentLoadout()',NULL,'Builds a fallback set of powerup cards for the opponent using whatever schema data is available, even if catalog entries are missing.');
INSERT INTO defs VALUES(79,2,'function','safeString(value, fallback)',NULL,'Utility ensuring attacker-provided data always resolves to a non-empty string.');
INSERT INTO defs VALUES(80,2,'function','normalizedPowerupRecord(sourceRecord, slotIndex, prefix)',NULL,'Sanitizes an arbitrary powerup payload into the minimal card structure expected by loadouts and sidebars.');
INSERT INTO defs VALUES(81,2,'function','recordForSlot(records, slotIndex)',NULL,'Picks the best matching record for a slot regardless of whether the source array stores {slot,powerup} tuples or plain objects.');
INSERT INTO defs VALUES(82,2,'function','normalizeLoadout(records, prefix, fillMissingSlots)',NULL,'Produces a four-slot loadout array, optionally filling missing entries with sanitized defaults for remote opponents.');
INSERT INTO defs VALUES(83,2,'function','heroPlacementInfo(grid, cardData, sceneX, sceneY)',NULL,'Computes whether a hero drop is valid plus the snapped row/column and pixel coordinates for placement.');
INSERT INTO defs VALUES(84,2,'function','spawnHeroOnGrid(grid, cardData, placement)',NULL,'Instantiates a PowerupHero inside the given grid using the snapped placement info and returns the Item reference.');
INSERT INTO defs VALUES(85,1,'function','heroPlacementKey(cardUuid)',NULL,'Normalizes the UUID key used to track hero placements on the grid.');
INSERT INTO defs VALUES(86,1,'function','hasHeroForCard(cardUuid)',NULL,'Returns true when a powerup card already has an active hero on this grid.');
INSERT INTO defs VALUES(87,1,'function','heroAreaWithinBounds(row, column, rowSpan, colSpan)',NULL,'Ensures a hero footprint would stay inside the grid before placement.');
INSERT INTO defs VALUES(88,1,'function','heroCellsForArea(row, column, rowSpan, colSpan)',NULL,'Enumerates every grid cell a hero footprint would cover for binding purposes.');
INSERT INTO defs VALUES(89,1,'function','heroAreasOverlap(a, b)',NULL,'Lightweight rectangle intersection helper for comparing hero footprints.');
INSERT INTO defs VALUES(90,1,'function','canPlaceHero(cardUuid, row, column, rowSpan, colSpan)',NULL,'Determines whether a hero can be spawned at the requested footprint without overlapping existing heroes or leaving the grid.');
INSERT INTO defs VALUES(91,1,'function','collectBoundBlocks(row, column, rowSpan, colSpan)',NULL,'Returns the current block wrappers that sit beneath a given hero footprint for later binding logic.');
INSERT INTO defs VALUES(92,1,'function','registerHeroPlacement(cardUuid, heroItem, row, column, rowSpan, colSpan, metadata)',NULL,'Adds the placed hero to the grid registry and records its footprint, metadata, and bound blocks.');
INSERT INTO defs VALUES(93,1,'function','releaseHeroPlacement(cardUuid)',NULL,'Removes a hero placement entry when the associated card is defeated or despawned.');
INSERT INTO defs VALUES(94,13,'property','property var pendingDebugLoadout','','Stores the selected loadout so DebugScene can be spawned with the latest MatchSetup choices.');
INSERT INTO defs VALUES(95,13,'function','openMatchSetup()','','Activates the MatchSetup loader unless it is already open or a debug scene is running.');
INSERT INTO defs VALUES(96,13,'function','closeMatchSetup(preserveSelection)','preserveSelection','Destroys the MatchSetup overlay and optionally resets pending loadout data when the dialog is dismissed.');
INSERT INTO defs VALUES(97,13,'function','beginDebugScene(loadout)','loadout','Closes MatchSetup, preserves the provided loadout, and spins up a DebugScene instance.');
INSERT INTO defs VALUES(98,2,'property','property var providedLoadout','','Holds MatchSetup-selected cards supplied by MainMenuScene before normalization.');
INSERT INTO defs VALUES(99,2,'function','applyProvidedLoadout(entries)','entries','Normalizes externally provided loadout entries and stores them in playerLoadout for the sidebar.');
INSERT INTO defs VALUES(100,6,'property','property bool interactive','','Toggles the card''s internal click area so parents like BattleCardSidebar can intercept drags.');
INSERT INTO defs VALUES(101,15,'function','require_integer(value, label=''value'')','value,label','Validate that provided value contains only digits; emits fatal error with label when not.');
INSERT INTO defs VALUES(102,15,'function','sql_collect(out_ref, sql)','out_ref,sql','Helper using sqlite3 to populate an array via nameref with query results.');
INSERT INTO defs VALUES(103,15,'function','resolve_file_id(provided_id, relpath, allow_empty=0)','provided_id,relpath,allow_empty','Locate a files.id by explicit id or fuzzy relpath, optionally tolerating missing input when allow_empty=1.');
INSERT INTO defs VALUES(104,15,'function','resolve_def_id(provided_id, signature, file_id='''', allow_empty=0)','provided_id,signature,file_id,allow_empty','Resolve a defs.id using exact or fuzzy signature matching, optionally scoped to a file and tolerant of missing inputs.');
INSERT INTO defs VALUES(105,15,'function','resolve_change_defs_link(def_id, change_id='''', file_id='''')','def_id,change_id,file_id','Return change_defs id + change id pair for a definition, enforcing single match or prompting for explicit identifiers.');
INSERT INTO defs VALUES(106,15,'function','resolve_change_files_link(file_id, change_id='''')','file_id,change_id','Return change_files id + change id pair for a file, requiring explicit selection when multiple rows match.');
INSERT INTO defs VALUES(107,15,'function','sql_nullable_int(value)','value','Format an integer id for SQL insertion, yielding NULL when the value is blank.');
INSERT INTO defs VALUES(108,15,'function','sql_nullable_text(value)','value','Return quoted text for SQL or NULL when the provided string is empty.');
INSERT INTO defs VALUES(109,15,'function','todo_list()',NULL,'List todo table entries joined to change/file/definition metadata in column mode.');
INSERT INTO defs VALUES(110,15,'function','todo_add([args...])','flags','Parse todo add flags, resolve linked ids, and insert a todo row while keeping the SQL dump fresh.');
INSERT INTO defs VALUES(111,15,'function','todo_del(todo_id)','todo_id','Delete a todo entry by id and report the number of rows removed.');
INSERT INTO defs VALUES(112,15,'function','todo_search([args...])','flags','Search todo rows with optional file/definition/change filters and ANDed keyword matching.');
INSERT INTO defs VALUES(113,15,'function','command_todo(args...)','args','Dispatch todo subcommands (list/add/del/search) and validate requested operation.');
INSERT INTO defs VALUES(114,15,'function','changes_list()',NULL,'Emit all change rows with ids, titles, status, and context.');
INSERT INTO defs VALUES(115,15,'function','changes_add([args...])','flags','Parse change metadata flags and insert a new changes row.');
INSERT INTO defs VALUES(116,15,'function','changes_update(change_id, [args...])','change_id,flags','Update title/context/status for an existing change row based on provided flags.');
INSERT INTO defs VALUES(117,15,'function','command_changes(args...)','args','Route changes subcommands (list/add/update) after ensuring a subcommand was provided.');
INSERT INTO defs VALUES(118,15,'function','files_list()',NULL,'List all file records ordered by relpath.');
INSERT INTO defs VALUES(119,15,'function','files_search([args...])','flags','Execute keyword search across file relpaths and descriptions.');
INSERT INTO defs VALUES(120,15,'function','files_add([args...])','flags','Insert a new files row using provided relpath and optional description.');
INSERT INTO defs VALUES(121,15,'function','files_del([args...])','flags','Delete a file record identified by id or relpath.');
INSERT INTO defs VALUES(122,15,'function','files_update([args...])','flags','Update relpath and/or description for a files row, resolving the target by id or relpath.');
INSERT INTO defs VALUES(123,15,'function','command_files(args...)','args','Dispatch files subcommands (list/search/add/del/update) with validation.');
INSERT INTO defs VALUES(124,15,'function','defs_list([args...])','flags','List definition rows joined to files with optional file filters.');
INSERT INTO defs VALUES(125,15,'function','defs_add([args...])','flags','Insert a definition for a given file using supplied type/signature metadata.');
INSERT INTO defs VALUES(126,15,'function','defs_del([args...])','flags','Remove a definition by id or signature (optionally scoped by file).');
INSERT INTO defs VALUES(127,15,'function','defs_update([args...])','flags','Update definition metadata and optionally move the definition to a different file.');
INSERT INTO defs VALUES(128,15,'function','command_defs(args...)','args','Dispatch defs subcommands (list/add/del/update) after verifying input.');
CREATE TABLE refs (
  id INTEGER PRIMARY KEY,
  def_id INTEGER NOT NULL,
  reference_def_id INTEGER NOT NULL,
  FOREIGN KEY(def_id) REFERENCES defs(id),
  FOREIGN KEY(reference_def_id) REFERENCES defs(id)
);
CREATE TABLE changes (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  context TEXT,
  status TEXT NOT NULL
);
INSERT INTO changes VALUES(1,'Wheel.sh integration test','Testing change addition via Codex agent','pending');
INSERT INTO changes VALUES(2,'BattleGrid launch payload framework','Add launch payload flow between BattleGrid, Factory, DebugScene','in_progress');
INSERT INTO changes VALUES(3,'Powerup hero sidebar groundwork','Add hero span data, editor fields, and sidebar hero drag scaffolding','in_progress');
INSERT INTO changes VALUES(4,'Gate debug scene behind match setup','Main menu should open MatchSetup before DebugScene','completed');
INSERT INTO changes VALUES(5,'Pass MatchSetup loadout to DebugScene','Debug flow should use player-selected powerups','completed');
INSERT INTO changes VALUES(6,'Fix BattleCardSidebar loadout wiring','Ensure sidebar cards display MatchSetup selections','completed');
INSERT INTO changes VALUES(7,'Restore sidebar drag interactions','Disable card click handlers so Engine.GameDragItem can drag','completed');
INSERT INTO changes VALUES(8,'Expand wheel CLI for metadata','Add todo/changes/files/defs shortcuts','complete');
CREATE TABLE change_files (
  id INTEGER PRIMARY KEY,
  change_id INTEGER NOT NULL,
  file_id INTEGER NOT NULL,
  FOREIGN KEY(change_id) REFERENCES changes(id),
  FOREIGN KEY(file_id) REFERENCES files(id)
);
INSERT INTO change_files VALUES(1,2,1);
INSERT INTO change_files VALUES(2,2,2);
INSERT INTO change_files VALUES(3,2,3);
INSERT INTO change_files VALUES(4,3,4);
INSERT INTO change_files VALUES(5,3,5);
INSERT INTO change_files VALUES(6,3,6);
INSERT INTO change_files VALUES(7,3,7);
INSERT INTO change_files VALUES(8,3,8);
INSERT INTO change_files VALUES(9,3,9);
INSERT INTO change_files VALUES(10,3,10);
INSERT INTO change_files VALUES(11,3,11);
INSERT INTO change_files VALUES(12,3,12);
INSERT INTO change_files VALUES(13,3,3);
INSERT INTO change_files VALUES(14,4,13);
INSERT INTO change_files VALUES(15,4,14);
INSERT INTO change_files VALUES(16,5,13);
INSERT INTO change_files VALUES(17,5,2);
INSERT INTO change_files VALUES(18,6,10);
INSERT INTO change_files VALUES(19,6,3);
INSERT INTO change_files VALUES(20,7,3);
INSERT INTO change_files VALUES(21,7,10);
INSERT INTO change_files VALUES(22,7,6);
INSERT INTO change_files VALUES(23,8,15);
CREATE TABLE change_defs (
  id INTEGER PRIMARY KEY,
  change_id INTEGER NOT NULL,
  file_id INTEGER NOT NULL,
  def_id INTEGER,
  description TEXT,
  FOREIGN KEY(change_id) REFERENCES changes(id),
  FOREIGN KEY(file_id) REFERENCES files(id),
  FOREIGN KEY(def_id) REFERENCES defs(id)
);
INSERT INTO change_defs VALUES(1,2,1,1,NULL);
INSERT INTO change_defs VALUES(2,2,1,2,NULL);
INSERT INTO change_defs VALUES(3,2,1,3,NULL);
INSERT INTO change_defs VALUES(4,2,1,4,NULL);
INSERT INTO change_defs VALUES(5,2,1,5,NULL);
INSERT INTO change_defs VALUES(6,2,1,6,NULL);
INSERT INTO change_defs VALUES(7,2,1,7,NULL);
INSERT INTO change_defs VALUES(8,2,3,8,NULL);
INSERT INTO change_defs VALUES(9,2,3,9,NULL);
INSERT INTO change_defs VALUES(10,2,2,10,NULL);
INSERT INTO change_defs VALUES(11,2,1,11,NULL);
INSERT INTO change_defs VALUES(12,2,1,12,NULL);
INSERT INTO change_defs VALUES(13,2,2,13,NULL);
INSERT INTO change_defs VALUES(14,2,1,14,NULL);
INSERT INTO change_defs VALUES(15,2,1,15,NULL);
INSERT INTO change_defs VALUES(16,2,1,16,NULL);
INSERT INTO change_defs VALUES(17,2,1,17,NULL);
INSERT INTO change_defs VALUES(18,2,1,18,NULL);
INSERT INTO change_defs VALUES(19,2,1,19,NULL);
INSERT INTO change_defs VALUES(20,2,1,20,NULL);
INSERT INTO change_defs VALUES(21,2,1,21,NULL);
INSERT INTO change_defs VALUES(22,2,2,22,NULL);
INSERT INTO change_defs VALUES(23,2,2,23,NULL);
INSERT INTO change_defs VALUES(24,2,2,24,NULL);
INSERT INTO change_defs VALUES(25,2,2,25,NULL);
INSERT INTO change_defs VALUES(26,2,2,26,NULL);
INSERT INTO change_defs VALUES(27,2,2,27,NULL);
INSERT INTO change_defs VALUES(28,2,1,28,NULL);
INSERT INTO change_defs VALUES(29,2,1,29,NULL);
INSERT INTO change_defs VALUES(30,2,1,30,NULL);
INSERT INTO change_defs VALUES(31,2,1,31,NULL);
INSERT INTO change_defs VALUES(32,2,1,32,NULL);
INSERT INTO change_defs VALUES(33,2,1,33,NULL);
INSERT INTO change_defs VALUES(34,2,1,34,NULL);
INSERT INTO change_defs VALUES(35,2,1,35,NULL);
INSERT INTO change_defs VALUES(36,2,1,36,NULL);
INSERT INTO change_defs VALUES(37,2,1,37,NULL);
INSERT INTO change_defs VALUES(38,2,1,38,NULL);
INSERT INTO change_defs VALUES(39,2,1,39,NULL);
INSERT INTO change_defs VALUES(40,2,1,40,NULL);
INSERT INTO change_defs VALUES(41,2,1,41,NULL);
INSERT INTO change_defs VALUES(42,2,1,42,NULL);
INSERT INTO change_defs VALUES(43,3,4,NULL,'Add hero span properties and persistence hooks to PowerupItem');
INSERT INTO change_defs VALUES(44,3,5,NULL,'Extend database schema and serialization for hero spans');
INSERT INTO change_defs VALUES(45,3,6,NULL,'Expose hero metadata on PowerupCard visuals');
INSERT INTO change_defs VALUES(46,3,7,NULL,'Carry hero span data through catalog selections');
INSERT INTO change_defs VALUES(47,3,8,NULL,'Allow editing hero dimensions in powerup editor');
INSERT INTO change_defs VALUES(48,3,9,NULL,'Store hero span data in match setup loadouts');
INSERT INTO change_defs VALUES(49,3,10,NULL,'Implement battle card sidebar UI and drag scaffolding');
INSERT INTO change_defs VALUES(50,3,11,NULL,'Add PowerupHero visual component for drag feedback');
INSERT INTO change_defs VALUES(51,3,12,NULL,'Provide shared powerup card data object');
INSERT INTO change_defs VALUES(52,3,3,NULL,'Add factory helper for battle card sidebar cards');
INSERT INTO change_defs VALUES(53,4,13,NULL,'Wire Debug button through MatchSetup overlay');
INSERT INTO change_defs VALUES(54,4,14,NULL,'Update Main.qml to rely on MainMenuScene debug flow');
INSERT INTO change_defs VALUES(55,4,13,94,'Track pending loadout between MatchSetup and DebugScene.');
INSERT INTO change_defs VALUES(56,4,13,95,'Expose helper to open MatchSetup while suppressing duplicates.');
INSERT INTO change_defs VALUES(57,4,13,96,'Allow callers to close MatchSetup and optionally clear pending data.');
INSERT INTO change_defs VALUES(58,4,13,97,'Handle Proceed by destroying MatchSetup and launching DebugScene.');
INSERT INTO change_defs VALUES(59,5,2,98,'Expose providedLoadout property to accept MatchSetup data.');
INSERT INTO change_defs VALUES(60,5,2,99,'Normalize and apply provided loadouts before falling back to database records.');
INSERT INTO change_defs VALUES(61,7,6,100,'Expose interactive property to disable MouseArea for drag contexts.');
INSERT INTO change_defs VALUES(62,8,15,NULL,'Add todo/changes/files/defs command handlers');
INSERT INTO change_defs VALUES(63,8,15,101,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(64,8,15,102,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(65,8,15,103,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(66,8,15,104,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(67,8,15,105,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(68,8,15,106,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(69,8,15,107,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(70,8,15,108,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(71,8,15,109,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(72,8,15,110,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(73,8,15,111,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(74,8,15,112,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(75,8,15,113,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(76,8,15,114,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(77,8,15,115,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(78,8,15,116,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(79,8,15,117,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(80,8,15,118,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(81,8,15,119,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(82,8,15,120,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(83,8,15,121,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(84,8,15,122,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(85,8,15,123,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(86,8,15,124,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(87,8,15,125,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(88,8,15,126,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(89,8,15,127,'Change 8: wheel.sh CLI shortcut');
INSERT INTO change_defs VALUES(90,8,15,128,'Change 8: wheel.sh CLI shortcut');
CREATE TABLE todo (
  id INTEGER PRIMARY KEY,
  change_id INTEGER NOT NULL,
  change_defs_id INTEGER,
  change_files_id INTEGER,
  description TEXT NOT NULL,
  FOREIGN KEY(change_id) REFERENCES changes(id),
  FOREIGN KEY(change_defs_id) REFERENCES change_defs(id),
  FOREIGN KEY(change_files_id) REFERENCES change_files(id)
);
INSERT INTO todo VALUES(1,2,1,1,'Add signal for raw launch payload emission.');
INSERT INTO todo VALUES(2,2,2,1,'Expose outward-facing launch payload signal.');
INSERT INTO todo VALUES(3,2,3,1,'Implement payload augmentation handler on BattleGrid.');
INSERT INTO todo VALUES(4,2,4,1,'Create damage resolution routine for incoming launch payloads.');
INSERT INTO todo VALUES(5,2,5,1,'Extend launchMatchedBlocks to emit payload data.');
INSERT INTO todo VALUES(6,2,6,1,'Add UUID property for identifying grids in payloads.');
INSERT INTO todo VALUES(7,2,7,1,'Introduce mainHealth property for overflow damage tracking.');
INSERT INTO todo VALUES(8,2,8,3,'Update createBlock wiring for launch payload relay.');
INSERT INTO todo VALUES(9,2,9,3,'Add helper to register battle grid signal connections.');
INSERT INTO todo VALUES(10,2,10,2,'Handle distributed launch payloads and forward to target grid.');
INSERT INTO todo VALUES(11,2,11,1,'Emit launch endpoint notification with position data.');
INSERT INTO todo VALUES(12,2,12,1,'Expose getEntryAt convenience accessor for launch tracking.');
INSERT INTO todo VALUES(13,2,13,2,'Forward launch endpoint updates to originating grid for animation.');
INSERT INTO todo VALUES(14,2,14,1,'Track internal registration guard for launch relay wiring.');
INSERT INTO todo VALUES(15,2,15,1,'Emit post-swap cascade status signal from BattleGrid.');
INSERT INTO todo VALUES(16,2,16,1,'Track BattleGrid postSwapCascading flag.');
INSERT INTO todo VALUES(17,2,17,1,'Provide helper to broadcast post-swap cascade payload.');
INSERT INTO todo VALUES(18,2,18,1,'Handle opponent post-swap cascade notifications.');
INSERT INTO todo VALUES(19,2,19,1,'Detect missing or destroyed blocks during cascade resolution.');
INSERT INTO todo VALUES(20,2,20,1,'Check for active non-idle blocks before ending cascade.');
INSERT INTO todo VALUES(21,2,21,1,'Reset grid to idle when post-swap cascading concludes.');
INSERT INTO todo VALUES(22,2,22,2,'Track turn coordination state references in DebugScene.');
INSERT INTO todo VALUES(23,2,23,2,'Normalize state helper for turn synchronization.');
INSERT INTO todo VALUES(24,2,24,2,'Finalize turn-state swap when defender is idle.');
INSERT INTO todo VALUES(25,2,25,2,'Timer-driven check for defender readiness.');
INSERT INTO todo VALUES(26,2,26,2,'Kick off wait/idle sequencing on turn change.');
INSERT INTO todo VALUES(27,2,27,2,'Forward post-swap cascade notifications between grids.');
INSERT INTO todo VALUES(28,2,28,1,'Store launch sequence coordinates for snake-pattern launches.');
INSERT INTO todo VALUES(29,2,29,1,'Track current index into launch sequence.');
INSERT INTO todo VALUES(30,2,30,1,'Check for idle entries allowing gaps after compact.');
INSERT INTO todo VALUES(31,2,31,1,'Verify grid fully populated and idle post-fill.');
INSERT INTO todo VALUES(32,2,32,1,'Confirm launch cleanup leaves only idle/destroyed blocks.');
INSERT INTO todo VALUES(33,2,33,1,'Detect presence of matched blocks before launching.');
INSERT INTO todo VALUES(34,2,34,1,'Generate snake-order launch traversal.');
INSERT INTO todo VALUES(35,2,35,1,'Reset launch sequence before processing matched blocks.');
INSERT INTO todo VALUES(36,2,36,1,'Emit launch payload for matched entry when triggered.');
INSERT INTO todo VALUES(37,2,37,1,'Provide helper to stop all state timers during transitions.');
INSERT INTO todo VALUES(38,2,38,1,'Gate transition from compact to fill using idle/missing check.');
INSERT INTO todo VALUES(39,2,39,1,'Transition from fill to match once the board is fully idle.');
INSERT INTO todo VALUES(40,2,40,1,'Evaluate match results to choose between launch or idle.');
INSERT INTO todo VALUES(41,2,41,1,'Only advance from launch once all blocks settle to idle/destroyed.');
INSERT INTO todo VALUES(42,2,42,1,'Iterate snake-pattern launch sequence one block at a time.');
INSERT INTO todo VALUES(43,3,43,NULL,'Add hero span properties to PowerupItem plus defaults and watchers');
INSERT INTO todo VALUES(44,3,44,NULL,'Expand PowerupDatabase schema/migrations/inserts to persist hero spans');
INSERT INTO todo VALUES(45,3,45,NULL,'Expose hero span bindings on PowerupCard and record application');
INSERT INTO todo VALUES(46,3,46,NULL,'Include hero spans in catalog model + selection payloads');
INSERT INTO todo VALUES(47,3,47,NULL,'Add UI controls to edit hero row/col spans and persist to DB');
INSERT INTO todo VALUES(48,3,48,NULL,'Carry hero spans through loadout slots and updatedSlotData events');
INSERT INTO todo VALUES(49,3,49,NULL,'Build BattleCardSidebar component with drag + hero hook-ups');
INSERT INTO todo VALUES(50,3,50,NULL,'Create PowerupHero component w/ dynamic sizing and state');
INSERT INTO todo VALUES(51,3,51,NULL,'Implement PowerupCard data helper bridging UI + DB schema');
INSERT INTO todo VALUES(52,3,52,NULL,'Add createBattleCardSidebarCard factory helper using drag wrapper');
INSERT INTO todo VALUES(53,4,53,14,'Create MatchSetup loader, connect proceed to spawn DebugScene, remove old direct signal usage.');
INSERT INTO todo VALUES(54,4,54,15,'Drop static DebugScene instance and obsolete handler in Main.qml.');
INSERT INTO todo VALUES(55,4,55,14,'Document pendingDebugLoadout property usage for debug gating.');
INSERT INTO todo VALUES(56,4,56,14,'Implement openMatchSetup guard logic.');
INSERT INTO todo VALUES(57,4,57,14,'Support closeMatchSetup tear-down semantics.');
INSERT INTO todo VALUES(58,4,58,14,'Connect MatchSetup proceed flow to DebugScene creation.');
INSERT INTO todo VALUES(59,5,NULL,16,'Ensure MatchSetup loadout passed via Loader to DebugScene without binding reset.');
INSERT INTO todo VALUES(60,5,NULL,17,'Handle provided loadout inside DebugScene and populate player sidebar accordingly.');
INSERT INTO todo VALUES(61,6,NULL,18,'Ensure BattleCardSidebar uses hero entry reference and applies records to cards so loadout shows.');
INSERT INTO todo VALUES(62,6,NULL,19,'Keep dragItem.entry bound to PowerupCard and expose hero separately in factory helper.');
INSERT INTO todo VALUES(63,7,NULL,20,'Have factory return both drag item and hero while keeping entry accessible for drag events.');
INSERT INTO todo VALUES(64,7,NULL,21,'Update BattleCardSidebar to use new factory return type and disable card click handling for drag operations.');
INSERT INTO todo VALUES(65,7,NULL,22,'Make PowerupCard expose a toggle to disable its internal MouseArea for draggable contexts.');
COMMIT;
