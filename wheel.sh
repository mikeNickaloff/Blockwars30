#!/usr/bin/env bash
set -euo pipefail

# wheel_db.sh — dynamic query runner for WHEEL.db with robust parameter fallback
# Tables:
#   files(id, relpath, description)
#   defs(id, file_id, type, parameters, description)
#   refs(id, def_id, reference_def_id)
#   changes(id, title, context, status)
#   change_files(id, change_id, file_id)
#   change_defs(id, change_id, file_id, def_id, description)
#   todo(id, change_id, change_defs_id, change_files_id, change_defs_id, description)

usage() {
  cat <<'USAGE'
Usage:
  wheel_db.sh [--database PATH] [--type STR] [--relpath STR] [--signature STR] [--parameters STR] [--description STR]
              [--file-desc STR] [--order-by SQL] [--limit N]
              [--refers-to DEF_ID] [--referenced-by DEF_ID] [--change CHANGE_ID]
              [--raw-sql] [--count] [--distinct]
              [--force-params | --no-params] [--verbose]

Notes:
  • All string filters use LIKE. If you don't include % or _, they are wrapped as %...%.
  • Shortcuts add JOINs:
      --refers-to X      -> defs that reference def X (refs.def_id -> refs.reference_def_id)
      --referenced-by X  -> defs referenced by X (inverse)
      --change C         -> rows tied to change C (via change_files/change_defs)
  • --count returns COUNT(*) instead of detail columns.
  • --distinct makes SELECT DISTINCT.
  • --raw-sql prints final SQL (and param sets if used).
  • If your sqlite3 CLI trips over ".parameter", we fall back to literal-quoting safely.
USAGE
}

# Defaults
DB_PATH="WHEEL.db"
TYPE_FILTER=""; RELPATH_FILTER=""; SIGNATURE_FILTER=""; PARAMS_FILTER=""; DESC_FILTER=""; FILE_DESC_FILTER=""
ORDER_BY="files.relpath, defs.type, defs.signature"
LIMIT_VAL=""
REFERS_TO=""; REFERENCED_BY=""; CHANGE_ID=""
RAW_SQL=0; DO_COUNT=0; DO_DISTINCT=0; VERBOSE=0
FORCE_PARAMS=0; NO_PARAMS=0

# Arg parse
while [[ $# -gt 0 ]]; do
  case "$1" in
    --database)       DB_PATH="${2:?}"; shift 2;;
    --type)           TYPE_FILTER="${2:?}"; shift 2;;
    --relpath)        RELPATH_FILTER="${2:?}"; shift 2;;
    --signature)      SIGNATURE_FILTER="${2:?}"; shift 2;;
    --parameters)     PARAMS_FILTER="${2:?}"; shift 2;;
    --description)    DESC_FILTER="${2:?}"; shift 2;;
    --file-desc)      FILE_DESC_FILTER="${2:?}"; shift 2;;
    --order-by)       ORDER_BY="${2:?}"; shift 2;;
    --limit)          LIMIT_VAL="${2:?}"; shift 2;;
    --refers-to)      REFERS_TO="${2:?}"; shift 2;;
    --referenced-by)  REFERENCED_BY="${2:?}"; shift 2;;
    --change)         CHANGE_ID="${2:?}"; shift 2;;
    --raw-sql)        RAW_SQL=1; shift;;
    --count)          DO_COUNT=1; shift;;
    --distinct)       DO_DISTINCT=1; shift;;
    --force-params)   FORCE_PARAMS=1; shift;;
    --no-params)      NO_PARAMS=1; shift;;
    --verbose)        VERBOSE=1; shift;;
    -h|--help)        usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

[[ -f "$DB_PATH" ]] || { echo "Error: database not found: $DB_PATH" >&2; exit 1; }

# Helpers
like_wrap() {
  local v="$1"
  if [[ "$v" == *"%"* || "$v" == *"_"* ]]; then printf '%s' "$v"; else printf '%%%s%%' "$v"; fi
}
sql_quote() {
  # Safe single-quote for SQLite string literal
  local v="$1"
  printf "'%s'" "${v//\'/\'\'}"
}

# Probe whether .parameter actually works (unless overridden)
PARAM_MODE="auto"
if [[ $FORCE_PARAMS -eq 1 && $NO_PARAMS -eq 1 ]]; then
  echo "Error: choose either --force-params or --no-params, not both." >&2; exit 2
fi
if [[ $NO_PARAMS -eq 1 ]]; then
  PARAM_MODE="off"
elif [[ $FORCE_PARAMS -eq 1 ]]; then
  PARAM_MODE="on"
else
  # Try to run a tiny param query. If it prints "X", we’re good.
  if out="$(sqlite3 "$DB_PATH" ".parameter init\n.parameter set @p 'X'\nselect @p;" 2>/dev/null)" && [[ "$out" == "X" ]]; then
    PARAM_MODE="on"
  else
    PARAM_MODE="off"
  fi
fi
[[ $VERBOSE -eq 1 ]] && echo "[debug] parameter mode: $PARAM_MODE" >&2

# Build SELECT
SELECT_LIST="files.relpath, defs.type, defs.signature, defs.parameters, defs.description"
[[ "$DO_COUNT" -eq 1 ]] && SELECT_LIST="COUNT(*)"
[[ "$DO_DISTINCT" -eq 1 ]] && SELECT_LIST="DISTINCT $SELECT_LIST"

FROM_JOIN=$'FROM files\nJOIN defs ON files.id = defs.file_id\n'
WHERE_CLAUSES=()

# Optional joins based on shortcuts
if [[ -n "$REFERS_TO" && -n "$REFERENCED_BY" ]]; then
  echo "Error: use either --refers-to or --referenced-by, not both." >&2; exit 2
fi
if [[ -n "$REFERS_TO" ]]; then
  FROM_JOIN+=$'JOIN refs rft ON rft.def_id = defs.id\n'
fi
if [[ -n "$REFERENCED_BY" ]]; then
  FROM_JOIN+=$'JOIN refs rby ON rby.reference_def_id = defs.id\n'
fi
if [[ -n "$CHANGE_ID" ]]; then
  FROM_JOIN+=$'LEFT JOIN change_files cf ON cf.file_id = files.id\nLEFT JOIN change_defs cd ON cd.def_id = defs.id\n'
fi

# Assemble WHERE using either parameters or literal quoting
PARAM_PRELUDE=""
add_like() {
  # args: column value param_name
  local col="$1" raw="$2" pname="$3"
  local val; val="$(like_wrap "$raw")"
  if [[ "$PARAM_MODE" == "on" ]]; then
    PARAM_PRELUDE+=".$(printf "parameter set %s '%s'\n" "$pname" "${val//\'/\'\'}")"
    WHERE_CLAUSES+=("$col LIKE $pname")
  else
    WHERE_CLAUSES+=("$col LIKE $(sql_quote "$val")")
  fi
}

[[ -n "$TYPE_FILTER"      ]] && add_like "defs.type"        "$TYPE_FILTER"      "@p_type"
[[ -n "$RELPATH_FILTER"   ]] && add_like "files.relpath"    "$RELPATH_FILTER"   "@p_relpath"
[[ -n "$SIGNATURE_FILTER" ]] && add_like "defs.signature"   "$SIGNATURE_FILTER"   "@p_signature"
[[ -n "$PARAMS_FILTER"    ]] && add_like "defs.parameters"  "$PARAMS_FILTER"    "@p_params"
[[ -n "$DESC_FILTER"      ]] && add_like "defs.description" "$DESC_FILTER"      "@p_desc"
[[ -n "$FILE_DESC_FILTER" ]] && add_like "files.description" "$FILE_DESC_FILTER" "@p_fdesc"

# Add numeric equals for shortcuts
if [[ -n "$REFERS_TO" ]]; then
  if [[ "$PARAM_MODE" == "on" ]]; then
    PARAM_PRELUDE+=".$(printf "parameter set @p_refers_to %s\n" "$REFERS_TO")"
    WHERE_CLAUSES+=("rft.reference_def_id = @p_refers_to")
  else
    WHERE_CLAUSES+=("rft.reference_def_id = $REFERS_TO")
  fi
fi
if [[ -n "$REFERENCED_BY" ]]; then
  if [[ "$PARAM_MODE" == "on" ]]; then
    PARAM_PRELUDE+=".$(printf "parameter set @p_referenced_by %s\n" "$REFERENCED_BY")"
    WHERE_CLAUSES+=("rby.def_id = @p_referenced_by")
  else
    WHERE_CLAUSES+=("rby.def_id = $REFERENCED_BY")
  fi
fi
if [[ -n "$CHANGE_ID" ]]; then
  if [[ "$PARAM_MODE" == "on" ]]; then
    PARAM_PRELUDE+=".$(printf "parameter set @p_change %s\n" "$CHANGE_ID")"
    WHERE_CLAUSES+=("(cf.change_id = @p_change OR cd.change_id = @p_change)")
  else
    WHERE_CLAUSES+=("(cf.change_id = $CHANGE_ID OR cd.change_id = $CHANGE_ID)")
  fi
fi

WHERE_SQL="WHERE 1=1"
for clause in "${WHERE_CLAUSES[@]:-}"; do
  WHERE_SQL+=" AND $clause"
done

ORDER_SQL=""
if [[ "$DO_COUNT" -eq 0 && -n "$ORDER_BY" ]]; then
  ORDER_SQL="ORDER BY $ORDER_BY"
fi
LIMIT_SQL=""
if [[ -n "$LIMIT_VAL" ]]; then
  LIMIT_SQL="LIMIT $LIMIT_VAL"
fi

read -r -d '' SQL_BODY <<SQL || true
SELECT $SELECT_LIST
$FROM_JOIN
$WHERE_SQL
$ORDER_SQL
$LIMIT_SQL;
SQL

# Debug print
if [[ "$RAW_SQL" -eq 1 ]]; then
  if [[ "$PARAM_MODE" == "on" ]]; then
    echo "/* .parameter prelude */"
    printf ".parameter init\n%b" "$PARAM_PRELUDE"
  else
    echo "/* literal-quoted mode (no .parameter) */"
  fi
  echo "/* SQL */"
  echo "$SQL_BODY"
fi

# Execute
if [[ "$PARAM_MODE" == "on" ]]; then
  sqlite3 "$DB_PATH" <<EOF
.timer off
.headers on
.mode column
.parameter init
$PARAM_PRELUDE
$SQL_BODY
EOF
else
  sqlite3 "$DB_PATH" <<EOF
.timer off
.headers on
.mode column
$SQL_BODY
EOF
fi
