#!/usr/bin/env bash
set -euo pipefail
command -v jq >/dev/null 2>&1 || exit 0
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"

INPUT="$(cat)"
LOAD_REASON="$(printf '%s' "$INPUT" | jq -r '.load_reason // empty' 2>/dev/null)" || LOAD_REASON=""

[ "$LOAD_REASON" = "compact" ] || exit 0

IFS='|' read -r FEATURE _ <<< "$(sdd_detect_feature_phase)" || exit 0
[ "$FEATURE" = "none" ] && exit 0

sdd_set_session_flag "instructions_reloaded" "true" || true
exit 0
