#!/usr/bin/env bash
# merge_investigate.sh — PlasticSCM merge investigation bundle.
#
# Usage:   merge_investigate.sh <src-branch-spec> [--workspace <path>]
# Example: merge_investigate.sh /main/feature/foo --workspace C:/work/proj
#
# Runs the cm queries needed to brief a merge decision, in one Bash call.
# Output is raw data in labeled sections — interpretation is the caller's job.
# Read-only: does NOT invoke cm merge / checkin / undo / switch.

set -u

SRC_BRANCH=""
WORKSPACE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      WORKSPACE="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,8p' "$0"; exit 0 ;;
    *)
      if [[ -z "$SRC_BRANCH" ]]; then SRC_BRANCH="$1"; fi
      shift ;;
  esac
done

if [[ -z "$SRC_BRANCH" ]]; then
  echo "ERROR: <src-branch-spec> required. Example: /main/feature/foo" >&2
  exit 1
fi

# Accept "br:/main/x" or "/main/x"
SRC_BRANCH="${SRC_BRANCH#br:}"

if [[ -n "$WORKSPACE" ]]; then
  cd "$WORKSPACE" || { echo "ERROR: cannot cd to $WORKSPACE" >&2; exit 1; }
fi

# Derive leaf + parent from src branch path (Plastic stores name = leaf only)
SRC_LEAF="${SRC_BRANCH##*/}"
SRC_PARENT="${SRC_BRANCH%/*}"
[[ -z "$SRC_PARENT" ]] && SRC_PARENT="/"

echo "=== Workspace ==="
WI_OUT=$(cm wi 2>&1) || { echo "$WI_OUT"; echo "ERROR: cm wi failed (not a workspace?)" >&2; exit 1; }
echo "$WI_OUT"
# Query status once, up-front. Its header includes "cs:NNNN - head" for the current
# workspace revision — needed by Effective Merge Delta below. Reused in Destination
# Status section to avoid a second round-trip.
STATUS_OUT=$(cm status 2>&1)
CURRENT_BRANCH=$(echo "$WI_OUT" | grep -oE '/[^@[:space:]]+' | head -1)
CURRENT_TIP_CS=$(echo "$STATUS_OUT" | grep -oE 'cs:[0-9]+' | head -1 | cut -d: -f2)
echo "# current_branch=${CURRENT_BRANCH}"
echo "# current_tip_cs=cs:${CURRENT_TIP_CS}"
echo "# src_branch=${SRC_BRANCH}"
echo "# src_leaf=${SRC_LEAF}"
echo "# src_parent=${SRC_PARENT}"
echo

echo "=== Prior Merges (src -> dst) ==="
cm find merge "where srcbranch='${SRC_BRANCH}' and dstbranch='${CURRENT_BRANCH}'" \
  --format="{dstchangeset}|{srcchangeset}|{date}" --nototal 2>&1 \
  | sed '/^$/d'
echo

echo "=== Source Branch Info ==="
# name field in Plastic = leaf only. Filter by (leaf AND parent) to disambiguate.
cm find branch "where name='${SRC_LEAF}'" \
  --format="{name}|{parent}|{date}|{owner}" --nototal 2>&1 \
  | awk -F'|' -v par="$SRC_PARENT" 'NF>=4 && $2==par {
      print "name="$1" | parent="$2" | date="$3" | owner="$4
    }'
echo

echo "=== Source Branch Changesets ==="
# Drop comment from list format to avoid multiline-comment breakage; tip comment shown below.
SRC_CS_TABLE=$(cm find changeset "where branch='${SRC_BRANCH}'" \
  --format="{changesetid}|{date}|{owner}" --nototal 2>&1 \
  | grep -E '^[0-9]+\|' | sort -t'|' -k1,1n)
echo "$SRC_CS_TABLE"
SRC_CS_COUNT=$(echo "$SRC_CS_TABLE" | grep -cE '^[0-9]+\|')
SRC_CS_TIP=$(echo "$SRC_CS_TABLE" | tail -1 | cut -d'|' -f1)
SRC_CS_MIN=$(echo "$SRC_CS_TABLE" | head -1 | cut -d'|' -f1)
SRC_CS_BASE=""
if [[ -n "$SRC_CS_MIN" && "$SRC_CS_MIN" =~ ^[0-9]+$ ]]; then
  SRC_CS_BASE=$((SRC_CS_MIN - 1))
fi
echo "# changeset_count=${SRC_CS_COUNT}"
echo "# tip=cs:${SRC_CS_TIP}"
echo "# approx_base=cs:${SRC_CS_BASE} (heuristic: min_src_cs - 1; verify against parent branch if precision matters)"
echo

if [[ -n "$SRC_CS_TIP" ]]; then
  echo "=== Source Tip Comment (cs:${SRC_CS_TIP}) ==="
  cm find changeset "where changesetid=${SRC_CS_TIP}" \
    --format="{comment}" --nototal 2>&1
  echo
fi

# Reusable helper: dump what a single changeset touched (Move/rename-aware)
dump_cs_items() {
  local cs="$1"
  local out
  out=$(cm log "cs:${cs}" --itemformat="{path}|{shortstatus}{newline}" 2>&1)
  if [[ $? -ne 0 ]] || echo "$out" | grep -qiE 'not recognized|예상치|unknown format'; then
    # itemformat placeholder unsupported here; fallback to XML dump
    echo "# (itemformat unavailable; falling back to --xml)"
    cm log "cs:${cs}" --xml 2>&1
  else
    echo "$out"
  fi
}

echo "=== Source Changes ==="
if [[ "$SRC_CS_COUNT" == "1" && -n "$SRC_CS_TIP" ]]; then
  echo "# mode=single-changeset (tip log only)"
  echo "# Move/rename operations are preserved here; a range-diff would report them as Added+Deleted."
  dump_cs_items "$SRC_CS_TIP"
elif [[ "$SRC_CS_COUNT" -gt 1 && -n "$SRC_CS_BASE" && -n "$SRC_CS_TIP" ]]; then
  echo "# mode=range-diff (cs:${SRC_CS_BASE} -> cs:${SRC_CS_TIP})"
  echo "# Range-diff shows the cumulative delta but collapses Move/rename into Added+Deleted."
  RANGE_DIFF=$(cm diff "cs:${SRC_CS_BASE}" "cs:${SRC_CS_TIP}" --format="{path}|{status}" 2>&1)
  RANGE_N=$(echo "$RANGE_DIFF" | grep -c .)
  echo "# range_diff_entries=${RANGE_N}"
  if [[ "$RANGE_N" -gt 300 ]]; then
    echo "# Output large — showing summary + head 100 + tail 30 entries."
    echo "# To re-run full: cm diff cs:${SRC_CS_BASE} cs:${SRC_CS_TIP} --format=\"{path}|{status}\""
    echo "# --- by status counts ---"
    echo "$RANGE_DIFF" | awk -F'|' 'NF>=2 {print $NF}' | sort | uniq -c | sort -rn
    echo "# --- by top-level path (count) ---"
    echo "$RANGE_DIFF" | sed 's|"||g; s|\\|/|g' \
      | awk -F'|' '{print $1}' \
      | awk -F'/' '{ if (NF>=2) print $1"/"$2; else print $1 }' \
      | sort | uniq -c | sort -rn | head -30
    echo "# --- first 100 entries ---"
    echo "$RANGE_DIFF" | head -100
    echo "# --- last 30 entries ---"
    echo "$RANGE_DIFF" | tail -30
  else
    echo "$RANGE_DIFF"
  fi
  echo
  echo "=== Source Tip-Only Changes (cs:${SRC_CS_TIP}) ==="
  echo "# What the tip commit alone touched (Move-aware view, useful for intent of the latest commit)."
  dump_cs_items "$SRC_CS_TIP"
else
  echo "# mode=unknown (count=${SRC_CS_COUNT}, tip='${SRC_CS_TIP}', base='${SRC_CS_BASE}')"
  echo "# Source branch may be empty or query failed. Inspect earlier sections."
fi
echo

# Reusable summary printer for large diff outputs.
summarize_diff() {
  local label="$1"
  local diff_out="$2"
  local n
  n=$(echo "$diff_out" | grep -c .)
  echo "# ${label}_entries=${n}"
  if [[ "$n" -gt 300 ]]; then
    echo "# Output large — showing summary + head 100 + tail 30."
    echo "# --- by status counts ---"
    echo "$diff_out" | awk -F'|' 'NF>=2 {print $NF}' | sort | uniq -c | sort -rn
    echo "# --- by top-level path (count, top 30) ---"
    echo "$diff_out" | sed 's|"||g; s|\\|/|g' \
      | awk -F'|' '{print $1}' \
      | awk -F'/' '{ if (NF>=2) print $1"/"$2; else print $1 }' \
      | sort | uniq -c | sort -rn | head -30
    echo "# --- first 100 entries ---"
    echo "$diff_out" | head -100
    echo "# --- last 30 entries ---"
    echo "$diff_out" | tail -30
  else
    echo "$diff_out"
  fi
}

echo "=== Effective Merge Delta (dst_tip -> src_tip) ==="
echo "# What would actually change in the workspace if src were merged into current."
echo "# Parent-branch evolution since src branched off is already accounted for here,"
echo "# so this is usually smaller than the src-internal range-diff above."
echo "# using current_tip_cs=cs:${CURRENT_TIP_CS}"
if [[ -n "$CURRENT_TIP_CS" && -n "$SRC_CS_TIP" ]]; then
  EFF_DIFF=$(cm diff "cs:${CURRENT_TIP_CS}" "cs:${SRC_CS_TIP}" --format="{path}|{status}" 2>&1)
  summarize_diff "effective_delta" "$EFF_DIFF"
  echo "# full list command if needed: cm diff cs:${CURRENT_TIP_CS} cs:${SRC_CS_TIP} --format=\"{path}|{status}\""
else
  echo "# could not resolve current_tip_cs or src_tip — skipping."
fi
echo

echo "=== Destination Status ==="
echo "$STATUS_OUT"
echo

echo "=== END ==="
