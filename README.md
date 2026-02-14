# Blockwars 8

## what is Block Wars?
- Block Wars is a cross-platform game that allows players to battle it out in a duel-style match-3 game where the matches you make turn into projectiles that damage the enemy's isolated match-3 game. 
- Players take turns alternating between being on offense and on defense.  
- Each player gets three moves on offense, then has to defend against three moves on defense.
- Offensive players make matches within their match-3 grid to attack the other player's blocks. 
- Also features Powerup Card system that lets players customize various types of Powerups by adjusting the damage, targets, colors, and more.
- Players can use their custom powerups to battle other players online against other player's Powerup Cards. 
- Each player gets 4 cards per game, and they must be charged up by destroying oppponent's blocks of the same color as the Powerup cards.
- Once cards are charged, you must place them somewhere on your game board where they will be exposed to attacks from blocks and powerup cards
- Depending on the amount of life your Powerup Card has and the amount of damage it does, activation energy is automatically calculated, so there are many variations of Cards that will be brought to battles.
- Single player mode vsersus A.I. is also available. 
- While on offense, player's blocks automatically fill in and cascade by launching matches at the opponent's board.
- Matches are only launched when the offensive player's board is totally filled.  
- Aside from the automatically launched matches, you have three moves on offense to move your blocks by swapping any single block one cell in any direction (up,down, left, or right). 
- After swapping, any matching row or column of three or more connected blocks of the same color will activate and launch at the opponent's match-3 grid.  
- Destroy an entire column of the opponent's blocks within 3 moves and any blocks that are fired at empty columns will deal direct damage to the enemy player's health. 
- First player to run out of health loses the game. 
- Winners gain more Total Powerup Energy available to them so that they can increase their Powerup Cards' attributes.

# Current Development Stats

## 📊 Project Metrics Summary

### 🗓 Timeline
- **First spec entry:** **2026-02-01 10:31:36**
- **Latest spec entry:** **2026-02-14 02:37:58**
- **Active span:** **12.67 days**

---

### 📝 Specification Activity
- **Total spec entries:** **131**
- **Recent planning activity (last 24h):** **22 entries**

**Spec focus areas:**
- Root scope — **blockwars (131)**
- Next level:
  - [none] — **109**
  - multiplayer — **14**
  - transport — **8**

---

### 📋 Requirements & Governance
- **Requirements (total):** **97**
  - Approved — **88**
  - Superseded — **9**

- **Decisions + Constraints (total):** **12**
  - Decisions — **4**
  - Constraints — **8**

---

### ❓ Question Handling
- **Total questions:** **17**
  - Approved — **17**
  - Closed — **0**
  - Open — **0**

- **Completion gate health:**  
  - Open questions — **0**  
  - Open requirement/decision/constraint rows — **0**

- **Spec notes:**  
  - Total notes — **5**  
  - Currently open — **2**

---

### 🚀 Delivery & Change Management
- **Total changes:** **21**
- **Strict completed rate:** **11 / 21 (52.38%)**

**Change status mix:**
- completed — **11**
- complete — **3**
- in_progress — **6**
- pending — **1**

**Throughput (active span):**
- **1.66 changes/day**
- **10.34 spec entries/day**

---

### 📚 Definition Catalog
- **Total definitions:** **941**
- **Files covered:** **58**
- **Average defs per file:** **16.22**

---

### 🔗 Change Impact & Coverage
- **Total change–definition links:** **915**
- **Average defs per change:** **43.57**
- **Unique defs touched:** **825**
  - Coverage of all defs — **87.67%**
- **Tracked changes (with change_defs entries):** **17 / 21 (80.95%)**
- **Files touched by tracked changes:** **55**

---

### 🔥 Hotspots & Concentration
- **Top 3 touched files account for:** **33.01%** of all touches

**Top touched files:**
- `game/ui/BattleGrid.qml` — **117**
- `BWTransport.h` — **101**
- `game/MultiplayerScene.qml` — **84**

**Most frequently touched definitions (tie — 4 touches each):**
- `BWTransport.h::sendCommand(const QString &type, const QJsonObject &payload = QJsonObject())`
- `game/DebugScene.qml::triggerPowerupActivation(cardData, options)`

---

### 📡 Process & Backlog Signals
- **refs table rows:** **8**
- **todo table rows:** **65**
