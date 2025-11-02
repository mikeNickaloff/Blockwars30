#!/usr/bin/env bash
set -euo pipefail

PROG="${0##*/}"
DB_PATH="WHEEL.db"
PARAM_PREF="auto"
PARAM_STATE=""
VERBOSE=0

usage() {
  cat <<'USAGE'
Usage:
  wheel.sh [GLOBAL OPTIONS] query    [QUERY OPTIONS]
  wheel.sh [GLOBAL OPTIONS] search   [TERMS...] [--table TABLE] [query opts]
  wheel.sh [GLOBAL OPTIONS] insert   TABLE key=value [...]
  wheel.sh [GLOBAL OPTIONS] update   TABLE --set col=value [--set col=value ...] [--id ID | --where SQL]
  wheel.sh [GLOBAL OPTIONS] delete   TABLE [--id ID | --where SQL]
  wheel.sh [GLOBAL OPTIONS] describe TABLE [--id ID] [--schema]
  wheel.sh [GLOBAL OPTIONS] plan     CHANGE_ID
  wheel.sh [GLOBAL OPTIONS] raw      [SQL]

Global options:
  --database PATH     Use the given SQLite database (default WHEEL.db)
  --force-params      Force use of sqlite3 .parameter bindings where supported
  --no-params         Disable use of sqlite3 .parameter bindings
  --verbose           Emit debug logging to stderr
  -h, --help          Show this message

Notes:
  • Invoking wheel.sh with only legacy query flags still works (query mode is default).
  • LIKE filters wrap values in %...% unless you provide %/_ yourself.
  • `search` spreads the terms across the most relevant columns for each table.
  • `raw` with no SQL launches an interactive sqlite3 shell.
USAGE
}

fatal() { echo "$PROG: $*" >&2; exit 1; }

debug() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "[$PROG] $*" >&2
  fi
}

ensure_db() {
  [[ -f "$DB_PATH" ]] || fatal "database not found: $DB_PATH"
}

sql_quote() {
  local v="$1"
  printf "'%s'" "${v//\'/\'\'}"
}

wrap_like() {
  local v="$1"
  if [[ "$v" == *%* || "$v" == *_* ]]; then
    printf '%s' "$v"
  else
    printf '%%%s%%' "$v"
  fi
}

sanitize_identifier() {
  local ident="$1"
  [[ "$ident" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || fatal "invalid identifier: $ident"
  printf '%s' "$ident"
}

sanitize_column_ref() {
  local ref="$1"
  if [[ "$ref" == *.* ]]; then
    local lhs="${ref%%.*}"
    local rhs="${ref#*.}"
    sanitize_identifier "$lhs" >/dev/null
    sanitize_identifier "$rhs" >/dev/null
    printf '%s' "$lhs.$rhs"
  else
    sanitize_identifier "$ref"
  fi
}

sanitize_select_expression() {
  local expr="$1"
  local default_tbl="${2:-}"
  expr="${expr//[[:space:]]/}"
  if [[ -z "$expr" ]]; then
    fatal "empty column name"
  fi
  if [[ "$expr" == "*" ]]; then
    printf '*'
    return
  fi
  if [[ "$expr" == *.* && "${expr##*.}" == "*" ]]; then
    local tbl="${expr%%.*}"
    sanitize_identifier "$tbl" >/dev/null
    printf '%s.*' "$tbl"
    return
  fi
  if [[ "$expr" == *.* ]]; then
    sanitize_column_ref "$expr"
    return
  fi
  if [[ -n "$default_tbl" ]]; then
    local tbl="$(sanitize_identifier "$default_tbl")"
    local col="$(sanitize_identifier "$expr")"
    printf '%s.%s' "$tbl" "$col"
    return
  fi
  sanitize_identifier "$expr"
}

init_param_mode() {
  if [[ -n "$PARAM_STATE" ]]; then
    return
  fi
  case "$PARAM_PREF" in
    off) PARAM_STATE="off"; return;;
    on)  PARAM_STATE="on"; return;;
  esac
  if out="$(sqlite3 "$DB_PATH" ".parameter init\n.parameter set @p 'X'\nselect @p;" 2>/dev/null)" && [[ "$out" == "X" ]]; then
    PARAM_STATE="on"
  else
    PARAM_STATE="off"
  fi
  debug "parameter mode: $PARAM_STATE"
}

join_with() {
  local delim="$1"; shift
  local out=""
  local first=1
  for part in "$@"; do
    [[ -n "$part" ]] || continue
    if [[ $first -eq 1 ]]; then
      out="$part"
      first=0
    else
      out+="$delim$part"
    fi
  done
  printf '%s' "$out"
}

build_search_clause() {
  local term="$1"; shift
  local like_term="$(wrap_like "$term")"
  like_term="$(sql_quote "$like_term")"
  local conditions=()
  for col in "$@"; do
    conditions+=("LOWER($col) LIKE LOWER($like_term)")
  done
  local joined="$(join_with ' OR ' "${conditions[@]}")"
  printf '( %s )' "$joined"
}

command_query() {
  local -a tables=()
  local positional_columns=()
  local merge_spec=""
  local table="defs"
  local order_sql=""
  local limit_sql=""
  local select_clause=""
  local from_clause=""
  local default_order=""
  local count_mode=0
  local distinct_mode=0
  local raw_sql=0
  local explicit_columns=""
  local explicit_where=""
  local id_filter=""
  local filters_cols=()
  local filters_vals=()
  local search_terms=()

  local type_filter=""
  local relpath_filter=""
  local signature_filter=""
  local params_filter=""
  local desc_filter=""
  local file_desc_filter=""
  local change_filter=""
  local refers_to=""
  local referenced_by=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --table)          tables+=("$2"); shift 2;;
      --merge)          merge_spec="$2"; shift 2;;
      --order-by)       order_sql="$2"; shift 2;;
      --limit)          limit_sql="$2"; shift 2;;
      --columns)        explicit_columns="$2"; shift 2;;
      --where)          explicit_where="$2"; shift 2;;
      --filter)         local kv="$2"; filters_cols+=("${kv%%=*}"); filters_vals+=("${kv#*=}"); shift 2;;
      --search)         search_terms+=("$2"); shift 2;;
      --id)             id_filter="$2"; shift 2;;
      --count)          count_mode=1; shift;;
      --distinct)       distinct_mode=1; shift;;
      --raw-sql)        raw_sql=1; shift;;
      --type)           type_filter="$2"; shift 2;;
      --relpath)        relpath_filter="$2"; shift 2;;
      --signature)      signature_filter="$2"; shift 2;;
      --parameters)     params_filter="$2"; shift 2;;
      --description)    desc_filter="$2"; shift 2;;
      --file-desc)      file_desc_filter="$2"; shift 2;;
      --change)         change_filter="$2"; shift 2;;
      --refers-to)      refers_to="$2"; shift 2;;
      --referenced-by)  referenced_by="$2"; shift 2;;
      --help|-h)        usage; exit 0;;
      --verbose)        VERBOSE=1; shift;;
      --database)       DB_PATH="$2"; PARAM_STATE=""; shift 2;;
      --force-params)   PARAM_PREF="on"; PARAM_STATE=""; shift;;
      --no-params)      PARAM_PREF="off"; PARAM_STATE=""; shift;;
      --)               shift; break;;
      -*)               fatal "unknown query option: $1";;
      *)                positional_columns+=("$1"); shift;;
    esac
  done

  while [[ $# -gt 0 ]]; do
    positional_columns+=("$1"); shift
  done

  if [[ ${#tables[@]} -eq 0 ]]; then
    tables=("defs")
  fi
  table="${tables[0]}"

  if [[ ${#tables[@]} -gt 1 && -z "$merge_spec" ]]; then
    fatal "multiple --table values require --merge to define join columns"
  fi
  if [[ -n "$merge_spec" && ${#tables[@]} -lt 2 ]]; then
    fatal "--merge requires at least two --table entries"
  fi

  ensure_db
  init_param_mode

  if [[ ${#tables[@]} -gt 1 ]]; then
    if [[ -n "$type_filter" || -n "$relpath_filter" || -n "$signature_filter" || -n "$params_filter" || -n "$desc_filter" || -n "$file_desc_filter" || -n "$change_filter" || -n "$refers_to" || -n "$referenced_by" || -n "$id_filter" ]]; then
      fatal "specialized filters like --type/--relpath are not supported with multi-table queries"
    fi
    if [[ ${#search_terms[@]} -gt 0 ]]; then
      fatal "--search terms are not supported with multi-table queries; run per-table instead"
    fi

    local sanitized_tables=()
    for tbl in "${tables[@]}"; do
      sanitized_tables+=("$(sanitize_identifier "$tbl")")
    done

    IFS=',' read -r -a merge_cols <<< "$merge_spec"
    if [[ ${#merge_cols[@]} -ne ${#tables[@]} ]]; then
      fatal "--merge must provide one column per --table entry"
    fi
    local sanitized_merge=()
    for col in "${merge_cols[@]}"; do
      col="${col//[[:space:]]/}"
      sanitized_merge+=("$(sanitize_column_ref "$col")")
    done

    local base_table="${sanitized_tables[0]}"
    local base_merge_col="${sanitized_merge[0]}"
    from_clause="$base_table"
    for idx in "${!sanitized_tables[@]}"; do
      if [[ $idx -eq 0 ]]; then
        continue
      fi
      from_clause+=" JOIN ${sanitized_tables[$idx]} ON ${sanitized_merge[$idx]} = $base_merge_col"
    done

    if [[ -n "$explicit_columns" ]]; then
      select_clause="$explicit_columns"
    elif [[ ${#positional_columns[@]} -gt 0 ]]; then
      local sanitized_cols=()
      for col in "${positional_columns[@]}"; do
        sanitized_cols+=("$(sanitize_select_expression "$col")")
      done
      select_clause="$(join_with ', ' "${sanitized_cols[@]}")"
    else
      select_clause="*"
    fi
    [[ $count_mode -eq 1 ]] && select_clause="COUNT(*)"
    [[ $distinct_mode -eq 1 && $count_mode -eq 0 ]] && select_clause="DISTINCT $select_clause"

    local where_clauses=("1=1")
    for i in "${!filters_cols[@]}"; do
      local col="${filters_cols[$i]}"
      local val="${filters_vals[$i]}"
      [[ -n "$col" ]] || continue
      local ref="$(sanitize_column_ref "$col")"
      where_clauses+=("$ref LIKE $(sql_quote "$(wrap_like "$val")")")
    done
    if [[ -n "$explicit_where" ]]; then
      where_clauses+=("($explicit_where)")
    fi

    local where_sql="WHERE $(join_with ' AND ' "${where_clauses[@]}")"
    local order_clause=""
    [[ $count_mode -eq 0 && -n "$order_sql" ]] && order_clause="ORDER BY $order_sql"
    local limit_clause=""
    [[ -n "$limit_sql" ]] && limit_clause="LIMIT $limit_sql"

    read -r -d '' SQL_BODY <<SQL || true
SELECT $select_clause
FROM $from_clause
$where_sql
$order_clause
$limit_clause;
SQL

    if [[ $raw_sql -eq 1 ]]; then
      echo "/* SQL */" >&2
      echo "$SQL_BODY" >&2
    fi

    sqlite3 "$DB_PATH" <<EOF
.timer off
.headers on
.mode column
$SQL_BODY
EOF
    return
  fi

  table="$(sanitize_identifier "$table")"

  local search_cols=()

  case "$table" in
    defs)
      select_clause="defs.id AS def_id, files.relpath, defs.type, defs.signature, defs.parameters, defs.description"
      from_clause=$'FROM defs\nJOIN files ON files.id = defs.file_id'
      default_order="files.relpath, defs.type, defs.signature"
      search_cols=("files.relpath" "defs.signature" "defs.description" "defs.parameters" "defs.type")
      ;;
    files)
      select_clause="files.id, files.relpath, files.description"
      from_clause="FROM files"
      default_order="files.relpath"
      search_cols=("files.relpath" "files.description")
      ;;
    changes)
      select_clause="changes.id, changes.title, changes.status, changes.context"
      from_clause="FROM changes"
      default_order="changes.id"
      search_cols=("changes.title" "changes.context" "changes.status")
      ;;
    change_files)
      select_clause="change_files.id, change_files.change_id, change_files.file_id, files.relpath"
      from_clause=$'FROM change_files\nLEFT JOIN files ON files.id = change_files.file_id'
      default_order="change_files.change_id, change_files.id"
      search_cols=("files.relpath")
      ;;
    change_defs)
      select_clause="change_defs.id, change_defs.change_id, change_defs.file_id, change_defs.def_id, change_defs.description, files.relpath AS file_relpath, defs.signature AS def_signature"
      from_clause=$'FROM change_defs\nLEFT JOIN files ON files.id = change_defs.file_id\nLEFT JOIN defs ON defs.id = change_defs.def_id'
      default_order="change_defs.change_id, change_defs.id"
      search_cols=("change_defs.description" "files.relpath" "defs.signature")
      ;;
    todo)
      select_clause="todo.id, todo.change_id, todo.change_defs_id, todo.change_files_id, todo.description"
      from_clause="FROM todo"
      default_order="todo.change_id, todo.id"
      search_cols=("todo.description")
      ;;
    refs)
      select_clause="refs.id, refs.def_id, d.signature AS def_signature, refs.reference_def_id, rd.signature AS reference_signature"
      from_clause=$'FROM refs\nLEFT JOIN defs d ON d.id = refs.def_id\nLEFT JOIN defs rd ON rd.id = refs.reference_def_id'
      default_order="refs.id"
      search_cols=("d.signature" "rd.signature")
      ;;
    *)
      fatal "unsupported table for query: $table"
      ;;
  esac

  if [[ -n "$explicit_columns" ]]; then
    select_clause="$explicit_columns"
  elif [[ ${#positional_columns[@]} -gt 0 ]]; then
    local sanitized_cols=()
    for col in "${positional_columns[@]}"; do
      sanitized_cols+=("$(sanitize_select_expression "$col" "$table")")
    done
    select_clause="$(join_with ', ' "${sanitized_cols[@]}")"
  fi
  [[ $count_mode -eq 1 ]] && select_clause="COUNT(*)"
  [[ $distinct_mode -eq 1 && $count_mode -eq 0 ]] && select_clause="DISTINCT $select_clause"

  [[ -z "$order_sql" ]] && order_sql="$default_order"

  local where_clauses=("1=1")

  if [[ -n "$id_filter" ]]; then
    where_clauses+=("$table.id = $id_filter")
  fi

  if [[ -n "$type_filter" ]]; then
    [[ "$table" == "defs" ]] || fatal "--type is only valid for defs"
    where_clauses+=("defs.type LIKE $(sql_quote "$(wrap_like "$type_filter")")")
  fi

  if [[ -n "$relpath_filter" ]]; then
    case "$table" in
      defs|change_files|change_defs)
        where_clauses+=("files.relpath LIKE $(sql_quote "$(wrap_like "$relpath_filter")")")
        ;;
      files)
        where_clauses+=("files.relpath LIKE $(sql_quote "$(wrap_like "$relpath_filter")")")
        ;;
      *)
        fatal "--relpath is not supported for table $table"
        ;;
    esac
  fi

  if [[ -n "$signature_filter" ]]; then
    case "$table" in
      defs)
        where_clauses+=("defs.signature LIKE $(sql_quote "$(wrap_like "$signature_filter")")")
        ;;
      change_defs)
        where_clauses+=("defs.signature LIKE $(sql_quote "$(wrap_like "$signature_filter")")")
        ;;
      refs)
        where_clauses+=("(d.signature LIKE $(sql_quote "$(wrap_like "$signature_filter")") OR rd.signature LIKE $(sql_quote "$(wrap_like "$signature_filter")"))")
        ;;
      *)
        fatal "--signature is not supported for table $table"
        ;;
    esac
  fi

  if [[ -n "$params_filter" ]]; then
    [[ "$table" == "defs" ]] || fatal "--parameters is only valid for defs"
    where_clauses+=("defs.parameters LIKE $(sql_quote "$(wrap_like "$params_filter")")")
  fi

  if [[ -n "$desc_filter" ]]; then
    case "$table" in
      defs) where_clauses+=("defs.description LIKE $(sql_quote "$(wrap_like "$desc_filter")")");;
      files) where_clauses+=("files.description LIKE $(sql_quote "$(wrap_like "$desc_filter")")");;
      change_defs) where_clauses+=("change_defs.description LIKE $(sql_quote "$(wrap_like "$desc_filter")")");;
      todo) where_clauses+=("todo.description LIKE $(sql_quote "$(wrap_like "$desc_filter")")");;
      changes) where_clauses+=("changes.context LIKE $(sql_quote "$(wrap_like "$desc_filter")")");;
      *) fatal "--description is not supported for table $table";;
    esac
  fi

  if [[ -n "$file_desc_filter" ]]; then
    case "$table" in
      defs|change_files|change_defs)
        where_clauses+=("files.description LIKE $(sql_quote "$(wrap_like "$file_desc_filter")")")
        ;;
      *)
        fatal "--file-desc is only valid when files.* is joined"
        ;;
    esac
  fi

  if [[ -n "$change_filter" ]]; then
    case "$table" in
      defs)
        from_clause+=$'\nLEFT JOIN change_files cf ON cf.file_id = files.id\nLEFT JOIN change_defs cd ON cd.def_id = defs.id'
        where_clauses+=("(cf.change_id = $change_filter OR cd.change_id = $change_filter)")
        ;;
      change_files)
        where_clauses+=("change_files.change_id = $change_filter")
        ;;
      change_defs)
        where_clauses+=("change_defs.change_id = $change_filter")
        ;;
      todo)
        where_clauses+=("todo.change_id = $change_filter")
        ;;
      changes)
        where_clauses+=("changes.id = $change_filter")
        ;;
      *)
        fatal "--change not supported for table $table"
        ;;
    esac
  fi

  if [[ -n "$refers_to" && -n "$referenced_by" ]]; then
    fatal "use either --refers-to or --referenced-by, not both"
  fi
  if [[ -n "$refers_to" ]]; then
    [[ "$table" == "defs" ]] || fatal "--refers-to only applies to defs"
    from_clause+=$'\nJOIN refs rft ON rft.def_id = defs.id'
    where_clauses+=("rft.reference_def_id = $refers_to")
  fi
  if [[ -n "$referenced_by" ]]; then
    [[ "$table" == "defs" ]] || fatal "--referenced-by only applies to defs"
    from_clause+=$'\nJOIN refs rby ON rby.reference_def_id = defs.id'
    where_clauses+=("rby.def_id = $referenced_by")
  fi

  for i in "${!filters_cols[@]}"; do
    local col="${filters_cols[$i]}"
    local val="${filters_vals[$i]}"
    [[ -n "$col" ]] || continue
    local ref="$(sanitize_column_ref "$col")"
    where_clauses+=("$ref LIKE $(sql_quote "$(wrap_like "$val")")")
  done

  for term in "${search_terms[@]}"; do
    [[ ${#search_cols[@]} -gt 0 ]] || fatal "search is not supported for table $table"
    local clause="$(build_search_clause "$term" "${search_cols[@]}")"
    where_clauses+=("$clause")
  done

  if [[ -n "$explicit_where" ]]; then
    where_clauses+=("($explicit_where)")
  fi

  local where_sql="WHERE $(join_with ' AND ' "${where_clauses[@]}")"
  local order_clause=""
  [[ $count_mode -eq 0 && -n "$order_sql" ]] && order_clause="ORDER BY $order_sql"
  local limit_clause=""
  [[ -n "$limit_sql" ]] && limit_clause="LIMIT $limit_sql"

  read -r -d '' SQL_BODY <<SQL || true
SELECT $select_clause
$from_clause
$where_sql
$order_clause
$limit_clause;
SQL

  if [[ $raw_sql -eq 1 ]]; then
    echo "/* SQL */" >&2
    echo "$SQL_BODY" >&2
  fi

  sqlite3 "$DB_PATH" <<EOF
.timer off
.headers on
.mode column
$SQL_BODY
EOF
}

command_search() {
  local -a tables=()
  local limit=20
  local passthrough=()
  local terms=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --table|-t)
        [[ $# -ge 2 ]] || fatal "--table expects a table name"
        tables+=("$2"); shift 2;;
      --limit)
        [[ $# -ge 2 ]] || fatal "--limit expects a value"
        limit="$2"; shift 2;;
      --order-by) passthrough+=("--order-by" "$2"); shift 2;;
      --columns)  passthrough+=("--columns" "$2"); shift 2;;
      --change)   passthrough+=("--change" "$2"); shift 2;;
      --filter)   passthrough+=("--filter" "$2"); shift 2;;
      --where)    passthrough+=("--where" "$2"); shift 2;;
      --raw-sql)  passthrough+=("--raw-sql"); shift;;
      --distinct) passthrough+=("--distinct"); shift;;
      --count)    passthrough+=("--count"); shift;;
      --help|-h)  usage; exit 0;;
      --)
        shift
        while [[ $# -gt 0 ]]; do
          terms+=("$1"); shift
        done
        break
        ;;
      -* ) fatal "unknown search option: $1";;
      *)
        terms+=("$1"); shift;;
    esac
  done

  [[ ${#tables[@]} -gt 0 ]] || tables=("defs")
  [[ ${#terms[@]} -gt 0 ]] || fatal "search requires at least one term"

  local first_table=1
  for table in "${tables[@]}"; do
    local args=("--table" "$table" "--limit" "$limit")
    args+=("${passthrough[@]}")
    for term in "${terms[@]}"; do
      args+=("--search" "$term")
    done
    if [[ ${#tables[@]} -gt 1 ]]; then
      if [[ $first_table -eq 0 ]]; then
        printf '\n'
      fi
      printf '%s\n' "-- $table --"
      first_table=0
    fi
    command_query "${args[@]}"
  done
}

parse_assignments() {
  local -n _names_ref="$1"
  local -n _values_ref="$2"
  shift 2
  while [[ $# -gt 0 ]]; do
    local pair="$1"
    if [[ "$pair" != *=* ]]; then
      fatal "expected key=value assignment, got '$pair'"
    fi
    local key="${pair%%=*}"
    local value="${pair#*=}"
    [[ -n "$key" ]] || fatal "empty column name in assignment"
    _names_ref+=("$(sanitize_identifier "$key")")
    _values_ref+=("$value")
    shift
  done
}

command_insert() {
  ensure_db
  [[ $# -ge 2 ]] || fatal "insert requires TABLE and at least one key=value"
  local table="$1"; shift
  table="$(sanitize_identifier "$table")"
  local cols=()
  local vals=()
  parse_assignments cols vals "$@"
  local col_list="$(join_with ', ' "${cols[@]}")"
  local val_list_parts=()
  for v in "${vals[@]}"; do
    val_list_parts+=("$(sql_quote "$v")")
  done
  local val_list="$(join_with ', ' "${val_list_parts[@]}")"
  sqlite3 "$DB_PATH" <<EOF
.timer off
.headers on
.mode column
BEGIN;
INSERT INTO $table ($col_list) VALUES ($val_list);
SELECT last_insert_rowid() AS last_insert_rowid;
COMMIT;
EOF
}

command_update() {
  ensure_db
  [[ $# -ge 1 ]] || fatal "update requires TABLE"
  local table="$1"; shift
  table="$(sanitize_identifier "$table")"
  local id_clause=""
  local where_clause=""
  local sets=()
  local values=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --set)
        [[ $# -ge 2 ]] || fatal "--set expects key=value"
        parse_assignments sets values "$2"
        shift 2
        ;;
      --id)
        id_clause="$2"; shift 2
        ;;
      --where)
        where_clause="$2"; shift 2
        ;;
      --) shift; break;;
      *)
        parse_assignments sets values "$1"
        shift
        ;;
    esac
  done
  [[ ${#sets[@]} -gt 0 ]] || fatal "update requires at least one --set column=value"
  if [[ -n "$id_clause" && -n "$where_clause" ]]; then
    fatal "provide either --id or --where, not both"
  fi
  if [[ -z "$where_clause" && -z "$id_clause" ]]; then
    fatal "update requires --id ID or --where SQL"
  fi
  [[ ${#sets[@]} -eq ${#values[@]} ]] || fatal "internal error: set/value mismatch"
  local set_fragments=()
  for i in "${!sets[@]}"; do
    set_fragments+=("${sets[$i]} = $(sql_quote "${values[$i]}")")
  done
  local set_clause="$(join_with ', ' "${set_fragments[@]}")"
  if [[ -n "$id_clause" ]]; then
    where_clause="$table.id = $id_clause"
  fi
  sqlite3 "$DB_PATH" <<EOF
.timer off
.headers on
.mode column
UPDATE $table
   SET $set_clause
 WHERE $where_clause;
SELECT changes() AS rows_changed;
EOF
}

command_delete() {
  ensure_db
  [[ $# -ge 1 ]] || fatal "delete requires TABLE"
  local table="$1"; shift
  table="$(sanitize_identifier "$table")"
  local where_clause=""
  local id_clause=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id_clause="$2"; shift 2;;
      --where) where_clause="$2"; shift 2;;
      --) shift; break;;
      *) fatal "unknown delete option: $1";;
    esac
  done
  if [[ -n "$id_clause" && -n "$where_clause" ]]; then
    fatal "provide either --id or --where"
  fi
  if [[ -z "$where_clause" ]]; then
    [[ -n "$id_clause" ]] || fatal "delete requires --id ID or --where SQL"
    where_clause="$table.id = $id_clause"
  fi
  sqlite3 "$DB_PATH" <<EOF
.timer off
.headers on
.mode column
DELETE FROM $table WHERE $where_clause;
SELECT changes() AS rows_deleted;
EOF
}

command_describe() {
  ensure_db
  [[ $# -ge 1 ]] || fatal "describe requires TABLE"
  local table="$1"; shift
  table="$(sanitize_identifier "$table")"
  local show_schema=0
  local row_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --schema) show_schema=1; shift;;
      --id)     row_id="$2"; shift 2;;
      --where)
        local where_clause="$2"; shift 2
        sqlite3 "$DB_PATH" <<EOF
.timer off
.headers on
.mode column
SELECT * FROM $table WHERE $where_clause;
EOF
        return
        ;;
      --) shift; break;;
      *) fatal "unknown describe option: $1";;
    esac
  done
  if [[ $show_schema -eq 1 ]]; then
    sqlite3 "$DB_PATH" "PRAGMA table_info($table);"
  fi
  if [[ -n "$row_id" ]]; then
    sqlite3 "$DB_PATH" <<EOF
.timer off
.headers on
.mode column
SELECT * FROM $table WHERE id = $row_id;
EOF
  elif [[ $show_schema -eq 0 ]]; then
    sqlite3 "$DB_PATH" <<EOF
.timer off
.headers on
.mode column
SELECT * FROM $table LIMIT 20;
EOF
  fi
}

command_plan() {
  ensure_db
  [[ $# -eq 1 ]] || fatal "plan requires CHANGE_ID"
  local change_id="$1"
  sqlite3 "$DB_PATH" <<EOF
.timer off
.headers on
.mode column
SELECT id, title, status, context FROM changes WHERE id = $change_id;

SELECT cf.id AS change_file_id, cf.file_id, f.relpath, f.description
  FROM change_files cf
  LEFT JOIN files f ON f.id = cf.file_id
 WHERE cf.change_id = $change_id
 ORDER BY cf.id;

SELECT cd.id AS change_def_id, cd.file_id, cd.def_id, cd.description, f.relpath, d.signature
  FROM change_defs cd
  LEFT JOIN files f ON f.id = cd.file_id
  LEFT JOIN defs d ON d.id = cd.def_id
 WHERE cd.change_id = $change_id
 ORDER BY cd.id;

SELECT t.id AS todo_id, t.description, t.change_defs_id, t.change_files_id
  FROM todo t
 WHERE t.change_id = $change_id
 ORDER BY t.id;
EOF
}

command_raw() {
  ensure_db
  if [[ $# -eq 0 ]]; then
    sqlite3 "$DB_PATH"
  else
    local sql="$*"
    sqlite3 "$DB_PATH" <<EOF
.timer off
.headers on
.mode column
$sql
EOF
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --database) DB_PATH="$2"; PARAM_STATE=""; shift 2;;
      --force-params) PARAM_PREF="on"; PARAM_STATE=""; shift;;
      --no-params) PARAM_PREF="off"; PARAM_STATE=""; shift;;
      --verbose) VERBOSE=1; shift;;
      -h|--help) usage; exit 0;;
      query|search|insert|update|delete|describe|plan|raw)
        local command="$1"; shift
        case "$command" in
          query)    command_query "$@"; return;;
          search)   command_search "$@"; return;;
          insert)   command_insert "$@"; return;;
          update)   command_update "$@"; return;;
          delete)   command_delete "$@"; return;;
          describe) command_describe "$@"; return;;
          plan)     command_plan "$@"; return;;
          raw)      command_raw "$@"; return;;
        esac
        ;;
      --*)
        command_query "$@"
        return
        ;;
      *)
        command_query "$@"
        return
        ;;
    esac
  done
  command_query --limit 50
}

main "$@"
