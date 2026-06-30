---
name: sdd-help
description: >-
  Answer questions about how the Spec-Driven Development skill works — its
  phases, artifacts, CLI, hooks, subagents, templates, and conventions. Routes
  the question to the right source docs and delegates broad research to
  Explore subagents. Use when asked "how does SDD work", "what does <phase>
  do", "what's in <artifact>", "what CLI commands exist", or any other
  SDD-explanatory question.
argument-hint: "[your question about SDD]"
disable-model-invocation: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Agent
---

# SDD Help — Answer questions about Spec-Driven Development

You are answering a user question about the Spec-Driven Development skill and its supporting plugin. Your job is to **route the question to the correct source files, read (or delegate) the minimum necessary, then answer with citations**.

User question:

```
$ARGUMENTS
```

## Step 0 — Resolve the docs root

The SDD knowledge surface lives either inside the loaded plugin or inside the consumer copy installed by `/sdd-setup`. Pick the first that exists:

```!
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-development" ]; then
  echo "SDD_DOCS_ROOT=${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-development"
elif [ -d ".claude/skills/spec-driven-development" ]; then
  echo "SDD_DOCS_ROOT=$(pwd)/.claude/skills/spec-driven-development"
else
  echo "SDD_DOCS_ROOT=MISSING — neither \${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-development nor .claude/skills/spec-driven-development exists"
fi
```

If the resolver reports `MISSING`, tell the user the SDD skill is not installed in this workspace and stop.

Use the resolved path as `<SDD>` in all file references below.

## Step 1 — Scope guard

If the question is **not about SDD, its plugin, artifacts, CLI, hooks, subagents, templates, or conventions**, say so in one sentence and decline. Do not guess. Examples of out-of-scope: general git/bash help, unrelated tooling, opinions about the user's product. Questions about `.features/` workflow, `sdd <command>`, any artifact (brief/spec/research/plan/tasks/review), work packages, steering, hooks, subagents, or evals ARE in scope.

## Step 2 — Classify the question and pick sources

Match the question against this routing map. The map is authoritative — prefer these files before exploring.

| Topic | Primary sources | Secondary |
|---|---|---|
| Overview, Golden Circle, phases at a glance, behavioral core | `<SDD>/SKILL.md` | `<SDD>/docs/workflow-lifecycle.md` |
| Lifecycle deep dive, work packages, hook layers | `<SDD>/docs/workflow-lifecycle.md` | `<SDD>/SKILL.md` |
| Artifacts (brief, spec, research, plan, tasks, review, close) + state files (state.json, scope.txt, changes.log, continuity.md, scratchpad.md, knowledge.md) | `<SDD>/docs/artifacts-and-state.md`, `<SDD>/references/artifacts.md` | `<SDD>/templates/*.md`, `<SDD>/references/rubrics/*.md` |
| Phase allowances / forbidden actions per phase | `<SDD>/SKILL.md` (Hard Gates table), `<SDD>/references/phases/*.md` | — |
| CLI commands (`sdd init`, `sdd phase`, `sdd status`, `sdd research`, `sdd plan`, `sdd review`, `sdd close`, `sdd reopen`, `sdd scope`, `sdd wp`, `sdd customize`, `sdd trace acknowledge`, etc.) | `<SDD>/docs/cli-contract.md` | `<SDD>/scripts/sdd-<name>.sh`, `<SDD>/scripts/sdd.sh` |
| Project customization (customize, `.sdd/customization.yaml`, scope keys, interpolation tokens) | `<SDD>/references/customization.md`, `<SDD>/SKILL.md` (Project Customization) | `<SDD>/scripts/sdd-customize.sh`, `<SDD>/references/customization-template.yaml` |
| Rubric advisor (`sdd advise`, advisor hooks, advisor system prompt, `SDD_ADVISOR_DISABLED`) | `<SDD>/references/advisor-system-prompt.md`, `<SDD>/docs/cli-contract.md` | `<SDD>/scripts/sdd-advise.sh`, `<SDD>/references/rubrics/*.md` |
| Trace graph & suspect handling (`sdd trace coverage`, `sdd trace acknowledge`, `--confirmed`, `changes.log`) | `<SDD>/references/trace-coverage.md`, `<SDD>/references/trace-acknowledge.md` | `<SDD>/scripts/sdd-trace.sh`, `<SDD>/references/trace-rules.json` |
| Hooks (command / prompt / agent layers, stop gate, scope drift, precompact/postcompact, session-start) | `<SDD>/docs/plugin-architecture.md`, `<SDD>/docs/workflow-lifecycle.md` (Three-Layer section) | `<SDD>/scripts/sdd-hook*.sh`, `sdd-stop-gate.sh`, `sdd-scope-drift.sh`, `sdd-precompact.sh`, `sdd-postcompact.sh` |
| Subagents (implementer, spec-reviewer, quality-reviewer, research-scout, plan-drafter, archivist) | `<SDD>/docs/subagent-delegation.md`, `<SDD>/agents/*.md` | `<SDD>/references/workers.md`, `<SDD>/references/worker-results.md` |
| Steering / behavioral rules / NEEDS_CONTEXT semantics | `<SDD>/docs/agent-steering.md`, `<SDD>/references/steering-core.md` | `<SDD>/SKILL.md` (Behavioral Core, Non-Negotiables) |
| Work packages (wp workflow, wp-tasks, wp-review) | `<SDD>/docs/workflow-lifecycle.md` (Work Packages section), `<SDD>/templates/wp-*.md` | `<SDD>/references/workers.md`, `<SDD>/references/worker-results.md` |
| Evals (trigger evals, scenarios, rubrics) | `<SDD>/docs/eval-framework.md`, `<SDD>/evals/` | — |
| Templates (what goes in each artifact file) | `<SDD>/templates/<artifact>.md` | `<SDD>/references/artifacts.md` |
| Troubleshooting (stop gate firing, phase stuck, scope drift warnings, plugin silent in non-SDD sessions) | `<SDD>/SKILL.md` (Non-Negotiable Boundaries), `<SDD>/docs/agent-steering.md`, `<SDD>/docs/plugin-architecture.md` (self-gating) | relevant script under `<SDD>/scripts/` |

If a referenced path doesn't resolve, use `Glob` under `<SDD>/` to find the nearest match. File names may have evolved; the topic columns are the stable contract.

## Step 3 — Decide: read inline vs delegate to subagent(s)

| Question shape | Read strategy |
|---|---|
| Narrow, touches ≤2 files from the map | Read inline with `Read`. No subagent. |
| Single topic area, needs 3–5 files | Spawn **one** `Explore` subagent with the specific files + question. Summarize its result. |
| Broad / comparative / "give me a tour" / "how does SDD work end-to-end" | Spawn **parallel** `Explore` subagents — one per topic area needed (e.g., one for lifecycle, one for artifacts, one for hooks, one for subagents). Issue all in a single message. Synthesize their results. |

When spawning subagents:
- Give each agent the exact files to read (from the routing map) and one specific sub-question.
- Ask each for a tight bulleted summary under 250 words with `file:line` citations.
- Do not ask a subagent to "research SDD" with no scope — always scope to a topic area.

## Step 4 — Answer

Format your response for the user:
1. **Lead with a 1–2 sentence direct answer.** No preamble.
2. **Back it up with citations** in `path:line` form (e.g., `docs/workflow-lifecycle.md:42`). Paths relative to `<SDD>` are fine.
3. **For procedural questions**, show the exact command in a fenced block.
4. **For comparative / lifecycle questions**, use a short table or ordered list.
5. **Close with one offer** to go deeper on a related area if useful — do not pad with multiple offers.

Keep the whole answer under ~300 words unless the user explicitly asked for depth. Brevity beats completeness — the user can ask follow-ups in the same conversation.

## Empty or vague question

If `$ARGUMENTS` is empty or a single word like "help", do not guess. Show this menu and ask which area they want:

```
SDD help — pick an area or ask a specific question:
  1. Overview & phases (Golden Circle, phase gates)
  2. Artifacts & state files (brief, spec, research, plan, tasks, review, state.json, scope.txt)
  3. CLI commands (sdd init / phase / status / research / plan / review / close / reopen / wp)
  4. Hooks & the harness (command, prompt, agent layers; stop gate; scope drift)
  5. Subagents (implementer, reviewers, scout, plan-drafter, archivist)
  6. Steering & behavioral rules
  7. Work packages
  8. Evals & trigger rules
  9. Templates (what goes in each artifact file)
 10. Troubleshooting
 11. Project Customization (sdd customize init/check, .sdd/customization.yaml, scope keys, interpolation tokens)
 12. Rubric advisor (sdd advise, advisor hooks, SDD_ADVISOR_DISABLED)
```

## One final rule

Never answer SDD questions from memory or training. The repo is the source of truth — read it, cite it, then answer.
