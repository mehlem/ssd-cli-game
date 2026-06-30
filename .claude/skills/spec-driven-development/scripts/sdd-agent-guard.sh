#!/usr/bin/env bash
set -euo pipefail
command -v jq >/dev/null 2>&1 || exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

sdd_has_active_feature || exit 0

INPUT="$(cat)"

# Extract tool input fields
AGENT_TYPE="$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // .tool_input.agent_type // empty')"
PROMPT="$(printf '%s' "$INPUT" | jq -r '.tool_input.prompt // empty')"

# Allow through: no agent type, or non-sdd agent types
if [ -z "$AGENT_TYPE" ]; then exit 0; fi
case "$AGENT_TYPE" in
  sdd-*) ;;
  *) exit 0 ;;
esac

# Allow through: sdd agent but prompt does not contain Machine Dispatch Record
if ! printf '%s' "$PROMPT" | grep -q '## Machine Dispatch Record'; then
  exit 0
fi

# Block: sdd agent with a prompt that already contains the dispatch record.
# The controller should use a short goal prompt; the SubagentStart hook injects the packet.
REASON="The prompt for ${AGENT_TYPE} already contains a '## Machine Dispatch Record' block. Use a short goal-oriented prompt instead — the SubagentStart hook will auto-inject the dispatch packet from disk state. Example: \"${AGENT_TYPE}: implement T-xxx\". Remove the machine dispatch record from the prompt and try again."

jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
exit 2
