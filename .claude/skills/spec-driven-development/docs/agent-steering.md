# Agent Steering & Behavioral Control

**Domain:** How the SDD plugin guides Claude's behavior across the feature lifecycle through two complementary steering channels: system-reminder hooks that inject methodology and constraints, and CLI outputs that steer at phase transitions.

Agent steering in SDD answers a core question: *How does the harness ensure Claude follows the workflow without manual supervision?* The answer evolved over four feature releases, from basic phase-aware gates to a comprehensive, event-driven steering system that injects just enough context at exactly the right moments to keep the agent on-methodology without wasting attention budget.

## The Evolution

### Phase 1: Phase-Aware Gates (0005)

The initial steering layer focused on preventing agent mistakes by detecting the current phase and injecting constraints. The problem was twofold:

1. **Phase signal misalignment** — The phase detection used artifact existence (brief.md exists → brief phase) but didn't account for frontmatter status. Newly scaffolded artifacts had `status: draft` immediately, making the phase signal one step ahead of reality.
2. **Gates, not guides** — Hooks injected terse constraints ("no code in research") but zero methodology. After context compaction dropped SKILL.md, Claude had no process guidance.

The solution added frontmatter-aware phase detection (tolerant fallback to artifact existence) and introduced **prescriptive hook output**: per-phase operating rules and "next valid move" guidance appended to SessionStart output, replacing vague status messages with clear behavioral boundaries.

#### Status-Augmented Phase Detection

Prior to feature 0005, `sdd-phase.sh` used artifact existence alone to determine phase — but scaffolding creates artifacts immediately in `draft` status, causing the phase signal to advance before real work began.

The fix adds a status layer: when the next expected artifact already exists, phase always advances (preserving backward compatibility). When the next artifact is absent, `sdd-phase.sh` checks the current artifact's frontmatter `status` field — `draft` keeps the phase, `active` or `completed` advances it. This makes phase detection tolerant of scaffolded-but-not-started artifacts while remaining fast for normal workflows.

### Phase 2: Methodology Injection (0016)

With gates in place, the harness still couldn't carry methodology across context compaction. When SKILL.md dropped out of context, Claude lost the 10-step research process, the TDD loop, the artifact maintenance cadence — and developers had to manually re-orient the agent.

The solution introduced **three architectural pieces**:

1. **Phase reference files** (`references/phases/*.md`) — Seven markdown files, one per phase, containing the full methodology Claude needs to execute that phase correctly (process steps, strategy hints, exit criteria, maintenance expectations). Editable without touching bash code.
2. **Enhanced hook injection** — SessionStart now injects the full phase guide inline, ensuring methodology survives context compaction. UserPromptSubmit uses enriched rules (2-3 items with strategy hints like "use subagents for parallel scanning"). A new nudge system fires at meaningful events (task completion, phase transition, scratchpad staleness) rather than on a mod-6 counter.
3. **Integration into summaries** — The phase guide is copied into summary-compact.md, so it travels through the context-compaction fallback chain (summary-compact → continuity.md) and re-anchors Claude post-compaction.

Result: Claude stays on-methodology even after compaction, without developer intervention.

### Phase 3: Hardened Boundary Events (0019)

The phase-aware injection system worked but relied heavily on UserPromptSubmit as a universal injection point. This created inefficiencies:

1. **Injection bloat** — Every prompt turn injected the same context (phase rules + status + nudges) regardless of whether anything changed, wasting 200+ tokens per turn.
2. **Compaction reconciliation** — After context compaction, the agent had no structured way to verify that critical state (feature, phase, task) survived the summary. It had to reconstruct context from conversation history.
3. **Tool failure recovery** — Tool failures received no structured guidance, leaving Claude to guess the root cause.

The solution introduced **boundary-event hooks** at lifecycle boundaries where steering is most at risk:

- **PostToolUseFailure** — Fires after a tool fails. Records failure context and signals UserPromptSubmit to emit recovery guidance.
- **InstructionsLoaded** — Fires when instructions (SKILL.md) are loaded from a compacted context. Sets flag for re-orientation.

#### PostCompact Recovery Order

When PostCompact fires, the hook sources the feature summary in priority order:
1. `summary-compact.md` — minimal 10-15 line briefing, most resistant to compaction
2. `continuity.md` — fuller session context captured pre-compact
3. `state.json` — authoritative machine state as final fallback

This ordering ensures the resumed agent picks up the most useful briefing with the least re-reading, while guaranteeing a valid context even when summary files are absent.
- **SessionEnd** — Fires at session end. Refreshes summaries and resets session state.
- **SubagentStart** — Fires when an SDD named agent role starts (sdd-implementer, sdd-spec-reviewer, sdd-quality-reviewer, sdd-research-scout, sdd-plan-drafter). Automatically constructs and injects a dispatch packet from disk state — enabling hook-first dispatch without manual packet assembly.
- **SubagentStop** — Fires when a named SDD agent stops. Validates the Machine Result Record structure, correlates the result to the originating dispatch via `dispatch_id`, applies tiered validation (Tier 1 blocking, Tier 2 non-blocking with normalization), and persists the result to the feature workers ledger. Sets `session_flags.subagent_result_pending` for controller pickup.

**Session flags** (`session_flags` object in `.claude/tmp/sdd-state-cache.json`) coordinate across hooks:

- `post_compact_pending` — Set by PostCompact when state reconciliation detects drift; consumed by UserPromptSubmit to emit re-anchor.
- `instructions_reloaded` — Set by InstructionsLoaded on compact load; consumed by UserPromptSubmit to re-orient.
- `last_tool_failure` — Set by PostToolUseFailure; consumed by UserPromptSubmit to emit recovery guidance.
- `dispatch_epoch` — Reserved for subagent dispatch tracking (feature 0020).

Writers and readers form an acyclic flow: PostCompact, PostToolUseFailure, and InstructionsLoaded write flags; UserPromptSubmit and SessionEnd read and clear them.

### Channel 2: CLI Outputs (Bash Tool Results)

CLI command outputs fire at known phase transitions or action points and are Claude's first sight of the effect of its action. They carry action-specific guidance without requiring async hook timing.

**Key commands:**

- **sdd init** — Creates brief.md and related scaffolding. Output includes lean-brief intent-extraction instruction (gather context first, propose, ~3 intent-level questions with recommendations) and substantiveness gate.
- **sdd spec** — Creates spec.md. Output gates on "Problem + FRs + ACs" and warns against jumping to plan.
- **sdd research** — Creates research.md. Output gates on Affected Files rows and confidence verdict.
- **sdd plan** — Creates plan.md. Output gates on Architectural Decisions + Phases and warns against layer-based chunking.
- **sdd task start** — Marks a task in-progress. Output includes task boundary (Files, Implements, Verification) and scope-discipline warning.
- **sdd task complete** — Marks a task completed. Output includes next action (scratchpad then `sdd task next`) and failure-mode warnings.
- **sdd review** — Creates review.md. Output gates on verdict + evidence rows and warns against silent implementation.
- **sdd close** — Closes a feature. Output warns against resuming inside closed features.

Each output ends with a methodology pointer to the phase reference file (conditional on file existence), allowing Claude to self-serve deeper guidance without waiting for hooks.

## Key Concepts

### Behavioral Core Reuse

SDD now treats the behavioral steering core as a reusable source, not a one-off phrasing choice in each surface. The same six rules should recur across hooks, CLI outputs, templates, summaries, worker prompts, setup instructions, and evals:

- **Surface ambiguity**
- **Investigate before claiming**
- **Prefer the smallest viable solution**
- **Change surgically**
- **Treat done as verified evidence**
- **Reason through failures before retrying**

The value is not repetition for its own sake. The value is that each surface can derive compact, phase-appropriate guidance without drifting into contradictory wording. As of feature 0038, the behavioral core is consistently applied across hooks, CLI guidance, summaries, templates, worker prompts, setup output, and evals — not just SKILL.md — ensuring coherence across the entire steering system.

#### Canonical Steering-Core Source

The canonical behavioral core lives in `references/steering-core.md`. When adding new surfaces (new hook events, CLI commands, worker prompts, templates), import the rules verbatim from that file rather than paraphrasing. This prevents drift between surfaces over time. Eval assertions that validate behavioral compliance reference the same core by name (e.g., `anti-rationalization`, `investigate-before-claiming`) ensuring the eval taxonomy stays in sync with the active steering rules.

### Hard Gates

Hard gates are phase-specific constraints that prevent invalid state transitions. Enforced by:

1. `sdd-phase.sh` — Detects current phase based on artifact presence and status.
2. `sdd-stop-gate.sh` — Blocks progress if the current artifact fails readiness checks.
3. Semantic phase gates (0024) — Add prompt/agent judgment on top of structural checks for brief, spec, research, and plan artifacts.
4. CLI outputs — Include gate conditions so Claude understands quality expectations upfront.

Example (implement phase): "One task at a time; no scope expansion without task coverage. Gate: Each task's verification command must pass before marking complete."

### Rubric Advisor

- **Prompt hooks on artifact edits and writes** — lightweight authoring guardrails for `brief.md`, `spec.md`, `research.md`, and `plan.md` when the artifact body alone is enough to see that the edit is still placeholder-heavy or too thin.
- **Rubric Advisor hooks on phase-advance + edit events** — non-blocking, grounded suggestions (see references/advisor-system-prompt.md).
- **Separated plan boundaries** — `sdd plan both/create-all` is intentionally blocked with a precondition failure because a single combined scaffold would skip the distinct research-to-plan and plan-to-tasks checkpoints.

The storage contract stays derived:

- Advisor hooks evaluate against `references/rubrics/*.md`
- Advisor results are written to `.features/<feature>/semantic/<artifact>.json`
- `sdd-status.sh` projects those files into `state.json.semantic_readiness`
- Freshness is derived by comparing the current artifact hash with the hash stored in the sidecar

The command contract stays split on purpose:

- `sdd advise <artifact> <feature>` is the shell-side on-demand advisor surface
- Claude Code `PreToolUse` prompt and agent hooks own rubric judgment
- Direct CLI usage reports pending/current/stale state; hook-mediated flows create or refresh sidecars

### Advisor Opt-Out

The supported opt-out path uses Claude Code's built-in controls rather than an SDD-only bypass:

- Disable the SDD plugin when you do not want semantic enforcement in a project
- Or use Claude Code's built-in hook disable controls such as `disableAllHooks` when you need hooks off temporarily

SDD does not add a separate feature-local semantic bypass flag because prompt hooks cannot reliably consult feature-local state before they run. A custom toggle would only disable part of the enforcement path and create ambiguous behavior.

This keeps structural checks fast and deterministic while allowing higher-quality semantic judgment exactly at the boundaries where shallow artifacts would otherwise leak forward.

### Phase-Aware Injection

Methodology varies by phase. Rather than embedding all process guidance in SKILL.md (which may be compacted), SDD injects phase-specific content at the right moments:

- **SessionStart** — Full phase guide from `references/phases/{phase}.md`.
- **UserPromptSubmit** — Enriched rules (2-3 items with strategy hints).
- **CLI commands** — Phase-specific gates and pitfalls.

Phase reference files are the single source of truth for phase methodology. They are markdown (editable without touching bash), support `{{FEATURE}}` placeholders (substituted at injection time), and are composed at inject time (not compiled into scripts).

### Brief Phase: Lean Intent-Extraction Steering

The brief phase uses a dedicated steering pattern distinct from other phases. At `UserPromptSubmit`, the hook appends a compact per-turn cue reinforcing the lean posture: gather context first, propose options or draft inferable sections, ask only intent-level questions, each paired with a recommendation. At `SessionStart`, the hook injects a full intent-extraction block that lists forbidden question types (research/plan-phase, code-logic, inspectable) and the soft cap (~3 questions) explicitly.

The `sdd_brief_interview_state_json` helper evaluates brief.md content to determine which sections are still unfilled, producing a structured cue for the next focus. The `summary.md` file gains a `## Brief Interview State` section so context-compacted agents re-acquire their position.

This keeps the brief-phase agent on track turn-by-turn — proposing and drafting from inference instead of interrogating.

#### Brief Sections and Inference Rules

All 5 sections are required for the gate (`interview_complete=true`), but only Motivation and Vision are typically intent-level questions. Problem, Context, and Constraints are usually fillable by interpretation from the user's answers + repo inspection (CLAUDE.md, INDEX, related features), with inferred content labeled `<!-- inferred from <source> -->` to preserve audit traceability.

1. **Motivation** — Why does this matter? *(intent-level — usually requires a question)*
2. **Problem** — Who has it, what's their experience? *(usually inferable from Motivation + repo)*
3. **Vision** — What does success look like? *(intent-level — usually requires a question)*
4. **Context** — Stakeholders, urgency, related work *(usually inferable from CLAUDE.md, INDEX, related features)*
5. **Constraints** — Non-negotiables *(usually inferable from CLAUDE.md + repo conventions)*

The `sdd_brief_interview_state_json` helper parses `brief.md` section headings to evaluate which sections have substantive content (non-placeholder, non-comment). It produces a JSON state object with:
- `sections` — a map of section names to completion status (true/false)
- `missing_sections` — an array of unfilled sections
- `next_focus` — the recommended next section to address
- `interview_complete` — boolean true when all five sections have content

This state drives per-turn steering cues appended to `UserPromptSubmit` heartbeats (showing the next focus and lean-brief rules), and full intent-extraction blocks at `SessionStart` and in summary files. The compact cue is short enough to repeat every prompt without context bloat while still reinforcing the soft cap and forbidden-question types.

### Delta-Only State

UserPromptSubmit uses session flags to emit context only when state has changed:

1. **Steady state** — Minimal heartbeat (~50 tokens): feature, phase, task, counts.
2. **Compaction detected** — Re-anchor message: feature, phase, task, phase rules, phase guide.
3. **Tool failure detected** — Recovery guidance: tool name, error, is_verification flag.
4. **Instruction reload detected** — Re-orientation: phase rules.

When no flags are set and no event-driven nudge triggers, emit only the heartbeat. This preserves attention budget for actual work while maintaining session orientation.

### Boundary Events

Boundary events are lifecycle moments where steering is most at risk:

- **PostCompact** — Risk: steering drift from context compaction. Mitigation: state reconciliation + re-anchor flag.
- **PostToolUseFailure** — Risk: agent loses context on failure. Mitigation: failure recording + recovery guidance flag.
- **InstructionsLoaded (compact)** — Risk: methodology lost if SKILL.md compacted. Mitigation: re-orientation flag.
- **SessionEnd** — Risk: next session inherits stale state. Mitigation: summary refresh + flag reset.

Boundary-event hooks run synchronously and execute within tight timeouts (PostCompact: 5s, SessionEnd: 1.5s). They are designed to be fast, side-effect-focused, and acyclic (no circular flag dependencies).

### CLI Steering

CLI outputs are the agent's first feedback after action. They replace decorative banners with prescriptive guidance structured in a consistent form:

```
[Action result]
Gate: [specific quality bar]
Pitfall: [common mistake]
Next: [explicit next action]
[Methodology pointer]
```

Gates are phrased in observable, testable terms (e.g., "at least 1 FR and 1 AC") mirroring the checks in `sdd-check.sh`. Pitfalls call out the most common failure mode for that phase transition. This immediate, action-specific feedback prevents the most common mistakes before they snowball.

## Implementation

All steering logic lives in the SDD plugin scripts directory:

- **sdd-hook.sh** — Main hook adapter. Routes based on hook_event_name and manages output formatting. Calls sdd-lib.sh functions for phase detection, rules, guides, and maintenance hints.
- **sdd-lib.sh** — Shared library. Provides functions:
  - `sdd_steering_core_json()` and related accessors — read the canonical steering core with safe fallback
  - `sdd_phase_guide($phase, $feature)` — Reads and substitutes phase reference file.
  - `sdd_phase_rules($phase)` — Returns enriched 2-3 item rules with strategy hints.
  - `sdd_read_session_flags()` / `sdd_set_session_flag()` / `sdd_reset_session_flags()` — Session flag management.
  - `sdd_maintenance_hints($phase)` — Returns event-driven nudges (compaction, task completion, scratchpad staleness).
  - `sdd_phase_reference_line($phase)` — Conditional methodology pointer.
- **references/steering-core.md** — Canonical behavioral steering core used to keep wording coherent across surfaces.
- **sdd-*.sh** (init, spec, research, plan, task, review, close) — Individual commands. Each embeds CLI output logic and calls `sdd_phase_reference_line()` for the methodology pointer.
- **references/phases/{brief,design,research,plan,implement,review,close}.md** — Phase methodology sources. Editable markdown with `{{FEATURE}}` placeholders.

## Design Principles

1. **Inject less per turn, more at boundaries** — UserPromptSubmit stays minimal in steady state; boundary events carry focused, high-signal information.
2. **Methodology is editable, not coded** — Phase reference files are markdown, not embedded in bash. Non-engineers can tune process guidance.
3. **Gates are observable** — Gate phrasing mirrors actual checks in sdd-check.sh, not aspirational prose. Claude can verify compliance.
4. **No redundant steering** — Each channel (hooks, CLI) carries distinct information. Hooks provide ambient methodology; CLI provides action-specific guidance.
5. **Acyclic flag flow** — Session flags enable cross-hook coordination without creating circular dependencies or race conditions.
6. **Graceful degradation** — All hooks and commands work even if jq is missing, phase reference files don't exist, or state caches are stale.
7. **One behavioral core, many surfaces** — shared wording should be derived once and reused compactly rather than rewritten from scratch in every file.

## Related Features

- **0005** — Phase-aware gates and prescriptive hook output.
- **0016** — Phase reference files, enhanced SessionStart, event-driven nudges.
- **0019** — Boundary-event hooks (PostCompact, PostToolUseFailure, InstructionsLoaded, SessionEnd), delta-only UserPromptSubmit, session flags.
- **0021** — CLI output restructuring for action-specific steering.
- **0035** — Brief-phase interview state tracking.
- **0037** — Steering guidance emitted to stderr in JSON mode.
- **0038** — Behavioral core reuse hardened across all surfaces.
