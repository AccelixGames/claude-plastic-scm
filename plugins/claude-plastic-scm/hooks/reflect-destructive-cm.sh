#!/usr/bin/env bash
# reflect-destructive-cm.sh — plastic-scm plugin Post-task Reflection trigger
#
# Input (stdin): Claude Code PostToolUse hook JSON.
# Behavior: if the just-run Bash command matches `cm (checkin|merge|label)` and
# the tool succeeded, emit a hookSpecificOutput.additionalContext JSON on
# stdout instructing Claude to follow the SKILL.md "Post-task Reflection"
# protocol. Otherwise: silently exit 0 (no output = no injection).
#
# Success detection: Claude Code's Bash tool_response schema is not fully
# documented publicly. We use a defensive OR of common success signals:
#   - tool_response.is_error == false (Claude Code's canonical error flag)
#   - tool_response.success == true (Write-tool style)
# If neither field is present, we assume success (the hook fired, so the
# tool completed). Only `is_error == true` is treated as an explicit failure.
#
# Exit codes: always 0 unless jq is missing. Never exit 2 — we do not want to
# block cm commands retroactively.
#
# Debug: the raw stdin JSON is always written (overwrite) to
# "/tmp/cm-hook-last.json". Use this to diagnose whether the hook fires
# and to inspect Claude Code's actual input shape. System /tmp is cleared
# on reboot (no persistence) and not synced by cloud backup services.

set -u

# Dependency check — jq is part of Git Bash and most dev envs. If missing,
# we skip silently rather than fail the tool call.
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Read entire stdin
input=$(cat)

# Debug log: overwrite each invocation so the file always reflects the latest
# hook firing. Enables `ls /tmp/cm-hook-last.json` + timestamp check to
# verify the hook fired, and `cat` to inspect the actual tool_response shape.
debug_log="/tmp/cm-hook-last.json"
printf '%s\n' "$input" > "$debug_log" 2>/dev/null || true

# Extract fields
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty')
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
is_error=$(printf '%s' "$input" | jq -r '.tool_response.is_error // empty')
success=$(printf '%s' "$input" | jq -r '.tool_response.success // empty')

# Gate 1: Must be a Bash tool use
[ "$tool_name" = "Bash" ] || exit 0

# Gate 2: Command must match destructive cm subcommand at a word boundary.
# Regex explicitly lists 3 subcommands (no partial prefix like `cm checkout`).
# Anchored to whitespace or start-of-line before `cm` to avoid matching
# `mycm checkin` or comments.
if ! printf '%s' "$command" | grep -Eq '(^|[[:space:];|&])cm[[:space:]]+(checkin|merge|label)([[:space:];|&]|$)'; then
  exit 0
fi

# Gate 3: Tool must have succeeded.
# Only treat is_error=="true" or success=="false" as explicit failure.
# Everything else (including missing fields) → proceed.
if [ "$is_error" = "true" ] || [ "$success" = "false" ]; then
  exit 0
fi

# All gates passed — emit additionalContext for Claude.
jq -n '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: "A destructive `cm` command (checkin / merge / label) just completed successfully. Per claude-plastic-scm skill SKILL.md `## Post-task Reflection` protocol, evaluate this session against the 5 friction signals in `skills/plastic-scm/templates/reflection-prompt.md`. If ≥1 signal is present, draft a one-line summary and ask the user whether to capture as a gotcha issue. If all signals are absent, proceed silently."
  }
}'
