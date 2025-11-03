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
COMMIT;
