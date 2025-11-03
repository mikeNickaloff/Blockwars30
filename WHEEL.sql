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
COMMIT;
