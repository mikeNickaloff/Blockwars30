# wheel.sh Usage Examples

The `wheel.sh` helper wraps SQLite automation around the `WHEEL.db` project database.  It lazily bootstraps the database (and `WHEEL.sql` dump) when needed and exposes a dense set of subcommands for querying, editing, and summarizing change/todo data.  This document captures concrete, copy/paste-ready examples for every syntactical helper and flag exposed by the script.

> **Tip:** All examples assume you run them from the project root (`/home/mike/build/Blockwars30`).  Prepend `./` when invoking from that directory.

## Global options

- Pick a different database file with `--database` (auto-refresh still works on the alternate file):
  ```bash
  ./wheel.sh --database Release/WHEEL.db query files id relpath --limit 5
  ```
- Force sqlite parameter bindings with `--force-params` when you want deterministic prepared statements:
  ```bash
  ./wheel.sh --force-params query defs id signature --limit 3
  ```
- Disable bound parameters with `--no-params` so literal SQL is emitted (useful when debugging triggers):
  ```bash
  ./wheel.sh --no-params query files --columns "relpath, description" --limit 2
  ```
- Emit verbose debug logging for every sqlite call using `--verbose`:
  ```bash
  ./wheel.sh --verbose query defs --limit 1
  ```
- Show the global usage summary with `-h/--help`:
  ```bash
  ./wheel.sh --help
  ```
- Run without subcommands to fall back to `query --limit 50` against the `defs` table:
  ```bash
  ./wheel.sh
  ```

## Core `query` helpers

- Basic select against the default `defs` table, inferring the table name from the first positional argument:
  ```bash
  ./wheel.sh query defs id signature --limit 5
  ```
- Explicitly target another table with `--table` (multiple `--table` flags are allowed when paired with `--merge`):
  ```bash
  ./wheel.sh query --table files id relpath description --limit 5
  ```
- Join multiple tables by pairing `--table` with `--merge` (one column reference per table; the first column drives the join key):
  ```bash
  ./wheel.sh query \
    --table change_files --table files \
    --merge change_files.file_id,files.id \
    change_files.id change_files.change_id files.relpath \
    --order-by change_files.id
  ```
- Supply a raw `SELECT` column list via `--columns` (this overrides any positional column tokens):
  ```bash
  ./wheel.sh query --table defs --columns "files.relpath, defs.signature, defs.type" --limit 3
  ```
- Override ordering with `--order-by` to change how results are sorted:
  ```bash
  ./wheel.sh query defs id signature --order-by "defs.id DESC" --limit 4
  ```
- Shrink or expand the result count using `--limit`:
  ```bash
  ./wheel.sh query defs id signature --limit 2
  ```
- Inject custom SQL predicates with `--where`:
  ```bash
  ./wheel.sh query defs id signature --where "files.relpath LIKE 'game/ui/%'" --limit 5
  ```
- Apply LIKE filters without writing SQL using repeated `--filter column=value` clauses:
  ```bash
  ./wheel.sh query --table files --filter "files.relpath=game/ui%" --filter "files.description=Battle%"
  ```
- Add textual search terms (per-table AND search) with `--search`:
  ```bash
  ./wheel.sh query --table defs --search launch --search payload --limit 5
  ```
- Pinpoint a single primary-key row with `--id`:
  ```bash
  ./wheel.sh query defs id signature type --id 4
  ```
- Return row counts instead of data using `--count`:
  ```bash
  ./wheel.sh query defs --count --where "files.relpath LIKE 'game/ui/%'"
  ```
- Enforce unique rows with `--distinct` (pairs well with `--columns`):
  ```bash
  ./wheel.sh query defs --columns "defs.type" --distinct
  ```
- Print the generated SQL before execution with `--raw-sql`:
  ```bash
  ./wheel.sh query defs id signature --limit 1 --raw-sql
  ```
- Filter by definition type via `--type` (only valid for `defs`):
  ```bash
  ./wheel.sh query defs signature --type function --limit 5
  ```
- Filter by joined file paths using `--relpath`:
  ```bash
  ./wheel.sh query defs signature --relpath "game/ui/%"
  ```
- Filter by signature text using `--signature` (defs/change_defs/refs aware):
  ```bash
  ./wheel.sh query defs --signature "calculate%"
  ```
- Filter by parameter text with `--parameters`:
  ```bash
  ./wheel.sh query defs --parameters payload
  ```
- Filter by description text via `--description` (works for defs/files/change_defs/todo/changes depending on the table):
  ```bash
  ./wheel.sh query files --description battle
  ```
- Filter by the joined file description with `--file-desc` (tables that include `files` only):
  ```bash
  ./wheel.sh query change_defs --file-desc sidebar
  ```
- Scope a query to a particular change id via `--change` (supported for defs/change_files/change_defs/todo/changes):
  ```bash
  ./wheel.sh query defs signature description --change 2
  ```
- Show definitions that reference another definition with `--refers-to DEF_ID`:
  ```bash
  ./wheel.sh query defs signature --refers-to 4
  ```
- Show definitions that are referenced by another definition with `--referenced-by DEF_ID`:
  ```bash
  ./wheel.sh query defs signature --referenced-by 4
  ```

## `search` command helpers

- Basic multi-term AND search across the default `defs` table:
  ```bash
  ./wheel.sh search hero damage shield
  ```
- Target specific tables with `--table` / `-t` (each table prints in its own block):
  ```bash
  ./wheel.sh search payload --table defs --table files --limit 5
  ```
- Restrict matches per table with `--limit`:
  ```bash
  ./wheel.sh search launch column breach --limit 3 --table defs
  ```
- Control ordering of search results with `--order-by` (applied per-table):
  ```bash
  ./wheel.sh search powerup --table defs --order-by "files.relpath DESC" --limit 4
  ```
- Return custom column sets via `--columns` while searching:
  ```bash
  ./wheel.sh search timeline --table defs --columns "files.relpath, defs.signature" --limit 5
  ```
- Restrict matches to a specific change id with `--change`:
  ```bash
  ./wheel.sh search payload --table defs --change 2
  ```
- Apply quick LIKE matches in addition to the search terms using `--filter`:
  ```bash
  ./wheel.sh search idle --table files --filter "files.relpath=game/ui%"
  ```
- Apply arbitrary SQL to every searched table with `--where`:
  ```bash
  ./wheel.sh search hero --table defs --where "files.relpath LIKE 'game/%'"
  ```
- Reveal the generated SQL per table with `--raw-sql`:
  ```bash
  ./wheel.sh search launch --table defs --raw-sql
  ```
- Combine `--distinct` with search results to suppress duplicate rows:
  ```bash
  ./wheel.sh search block --table defs --distinct
  ```
- Use `--count` to convert each search into a row count per table:
  ```bash
  ./wheel.sh search grid --table files --count
  ```

## Data mutation helpers

- Insert rows with `insert TABLE key=value ...`:
  ```bash
  ./wheel.sh insert changes title="Doc example" status="draft" context="Created via documentation"
  ```
- Update by primary key using `--set` plus `--id`:
  ```bash
  ./wheel.sh update changes --set status=done --set context="Wrapped up" --id 1
  ```
- Update rows selected by a custom predicate using `--where` (you can omit `--set` and pass assignments positionally):
  ```bash
  ./wheel.sh update files description="Temporarily hidden" --where "relpath='game/ui/BattleGrid.qml'"
  ```
- Delete by id via `delete TABLE --id N`:
  ```bash
  ./wheel.sh delete todo --id 6
  ```
- Delete via a SQL predicate with `--where`:
  ```bash
  ./wheel.sh delete defs --where "signature='Temporary Example Definition'"
  ```

## Inspectors: `describe`, `plan`, and `raw`

- Describe a table (first 20 rows) by default:
  ```bash
  ./wheel.sh describe files
  ```
- Show only schema details with `--schema`:
  ```bash
  ./wheel.sh describe defs --schema
  ```
- Limit describe output to a specific row id via `--id`:
  ```bash
  ./wheel.sh describe defs --id 4
  ```
- Use `--where` on describe for ad-hoc filtering:
  ```bash
  ./wheel.sh describe todo --where "change_id = 2"
  ```
- Render a full change plan (change row + associated files/defs/todo entries):
  ```bash
  ./wheel.sh plan 2
  ```
- Run arbitrary SQL via `raw "SQL"`:
  ```bash
  ./wheel.sh raw "SELECT COUNT(*) AS def_count FROM defs;"
  ```
- Launch an interactive sqlite prompt bound to `WHEEL.db` by omitting SQL entirely:
  ```bash
  ./wheel.sh raw
  ```

## `todo` shortcuts

- List every todo item with joins to file/definition context:
  ```bash
  ./wheel.sh todo list
  ```
- Add a todo with just a description and change id (minimum viable flags):
  ```bash
  ./wheel.sh todo add --description "Document launch timing" --change-id 2
  ```
- Add while resolving files by path via `--file`:
  ```bash
  ./wheel.sh todo add --description "Note health sync" --file "game/ui/BattleGrid.qml" --change-id 2
  ```
- Add while resolving files by id via `--file_id`:
  ```bash
  ./wheel.sh todo add --description "Note sidebar tweak" --file_id 1 --change-id 2
  ```
- Link to a definition by signature using `--def`:
  ```bash
  ./wheel.sh todo add --description "Describe calculateLaunchDamage" --def "calculateLaunchDamage(payload)" --file "game/ui/BattleGrid.qml" --change-id 2
  ```
- Link to a definition by id via `--def_id`:
  ```bash
  ./wheel.sh todo add --description "Audit serialize" --def_id 618 --file "game/ui/Block.qml" --change-id 3
  ```
- Pass the owning change id explicitly with `--change-id` (aliases `--change` / `--change_id` also work):
  ```bash
  ./wheel.sh todo add --description "Sync hero placement" --change 3 --file "game/ui/BattleGrid.qml"
  ```
- Attach an existing `change_defs` row directly through `--change_def_id`:
  ```bash
  ./wheel.sh todo add --description "Document block launch signal" --change_def_id 4 --change-id 2
  ```
- Attach an existing `change_files` row through `--change_file_id`:
  ```bash
  ./wheel.sh todo add --description "Track sidebar assets" --change_file_id 1 --change-id 2
  ```
- Delete a todo by id:
  ```bash
  ./wheel.sh todo del 5
  ```
- Search todos by terms only:
  ```bash
  ./wheel.sh todo search launch payload
  ```
- Search todos scoped to a file path via `--file`:
  ```bash
  ./wheel.sh todo search payload --file "game/ui/BattleGrid.qml"
  ```
- Search todos scoped to a file id via `--file_id`:
  ```bash
  ./wheel.sh todo search payload --file_id 1
  ```
- Search todos constrained to a definition signature via `--def`:
  ```bash
  ./wheel.sh todo search launch --def "calculateLaunchDamage(payload)"
  ```
- Search todos constrained to a definition id via `--def_id`:
  ```bash
  ./wheel.sh todo search launch --def_id 4
  ```
- Search todos limited to a particular change via `--change-id`:
  ```bash
  ./wheel.sh todo search hero --change-id 2
  ```

## `changes` shortcuts

- List all change rows:
  ```bash
  ./wheel.sh changes list
  ```
- Create a new change with `changes add --title --status --context`:
  ```bash
  ./wheel.sh changes add --title "Grid polish" --status pending --context "Notes for launch polish"
  ```
- Update only the title on an existing change:
  ```bash
  ./wheel.sh changes update 1 --title "Wheel integration baseline"
  ```
- Update only the context field:
  ```bash
  ./wheel.sh changes update 1 --context "Updated context for docs"
  ```
- Update only the status field:
  ```bash
  ./wheel.sh changes update 1 --status done
  ```

## `files` shortcuts

- List every file row (id + relpath + description):
  ```bash
  ./wheel.sh files list
  ```
- Search files by keywords:
  ```bash
  ./wheel.sh files search BattleGrid state machine
  ```
- Add a file by relpath using `--relpath`:
  ```bash
  ./wheel.sh files add --relpath "docs/mock.txt" --description "Placeholder for docs"
  ```
- Add a file using the alias `--file` (same as `--relpath`):
  ```bash
  ./wheel.sh files add --file "notes/scratch.md"
  ```
- Delete a file via `--file_id`:
  ```bash
  ./wheel.sh files del --file_id 1
  ```
- Delete by relpath via `--file`:
  ```bash
  ./wheel.sh files del --file "notes/scratch.md"
  ```
- Update metadata by targeting the file id:
  ```bash
  ./wheel.sh files update --file_id 1 --description "Main BattleGrid QML entry"
  ```
- Update metadata by targeting the file path:
  ```bash
  ./wheel.sh files update --file "game/ui/Block.qml" --relpath "game/ui/Block.qml" --description "Block UI component"
  ```

## `defs` shortcuts

- List definitions for every file:
  ```bash
  ./wheel.sh defs list
  ```
- List definitions scoped to a file path via `--file`:
  ```bash
  ./wheel.sh defs list --file "game/ui/BattleGrid.qml"
  ```
- List definitions scoped to a file id via `--file_id`:
  ```bash
  ./wheel.sh defs list --file_id 1
  ```
- Search definitions with keyword AND semantics:
  ```bash
  ./wheel.sh defs search launch payload --file "game/ui/BattleGrid.qml"
  ```
- Add a definition by resolving its file via `--file`:
  ```bash
  ./wheel.sh defs add --file "game/ui/menubar.qml" --type function --signature "toggleMenu()" --parameters "" --description "Shows or hides the menu"
  ```
- Add a definition resolving the file by id via `--file_id`:
  ```bash
  ./wheel.sh defs add --file_id 1 --type signal --signature "blockLaunched(var payload)" --description "Broadcasts launch payloads"
  ```
- Delete a definition directly via `--def_id`:
  ```bash
  ./wheel.sh defs del --def_id 618
  ```
- Delete by signature (optionally scoping to its file):
  ```bash
  ./wheel.sh defs del --def "calculateLaunchDamage(payload)" --file "game/ui/BattleGrid.qml"
  ```
- Update by id to modify type/signature/parameters/description:
  ```bash
  ./wheel.sh defs update --def_id 4 --type function --signature "calculateLaunchDamage(payload)" --parameters "payload" --description "Resolves launch damage with pending health"
  ```
- Update by signature scoped to a file:
  ```bash
  ./wheel.sh defs update --def "serialize()" --file "game/ui/Block.qml" --description "Snapshot block metadata"
  ```
- Move a definition to a new file path via `--new_file`:
  ```bash
  ./wheel.sh defs update --def_id 4 --new_file "game/ui/BattleGrid.qml"
  ```
- Move a definition to a new file id via `--new_file_id`:
  ```bash
  ./wheel.sh defs update --def_id 4 --new_file_id 1
  ```

---

These examples cover every wheel.sh flag and syntactic helper.  Combine them freely—the script will validate arguments, ensure the SQLite database exists, and refresh the text dump after any write so you always have an up-to-date project index.
