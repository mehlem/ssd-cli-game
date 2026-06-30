# SDD Worker Reference

Combined dispatch-side reference for SDD workers: the conceptual model, dispatch packet schema, machine dispatch record format, role templates, and assembly checklist. This file covers everything the controller needs to dispatch workers and everything workers need to understand their assignment.

## Hook-First Dispatch (Default)

The recommended way to dispatch an SDD worker is with a short goal-oriented prompt. The SubagentStart hook automatically assembles and injects a full dispatch packet — no manual packet assembly required.

**Three-step flow:**

1. Run `sdd task start <feature> T-xxx` to mark the task in-progress and write task-scope state to disk.
2. Invoke the worker with a short prompt: `Agent("sdd-implementer: implement T-xxx")`.
3. The SubagentStart hook fires, reads disk state, constructs a dispatch packet with task details, FRs, ACs, files in scope, and verification command, then injects it as `additionalContext` into the worker session.

The worker receives a complete, correlated dispatch packet. The controller sends only a short goal — the hook provides the rest.

**When hook-first dispatch is available:** Any named SDD agent role (sdd-implementer, sdd-spec-reviewer, sdd-quality-reviewer, sdd-research-scout, sdd-plan-drafter) triggers the SubagentStart hook automatically. The matching SubagentStop hook validates all five roles against their role-specific Machine Result Record shape before persisting the result. When no active feature exists on disk, fall back to manual packet assembly (see Fallback section below).

## Worker Decision Policy

Use this table to decide whether to execute inline or delegate to a worker:

| Task Characteristics | Recommended Approach |
|:--------------------|:--------------------|
| 1–3 small tasks, straightforward scope | Direct inline execution — no worker needed |
| Large task with many file changes | Delegate to `sdd-implementer` worker |
| Multiple independent tasks that can run in parallel | Dispatch multiple workers concurrently |
| Review requiring independent verification | **MUST for features with 3+ ACs or 5+ tasks**: dispatch sdd-spec-reviewer + sdd-quality-reviewer for independent verification before close; self-review only for trivial diffs (≤2 ACs and ≤2 tasks). Self-review allowed only for trivial cases. |
| Context-heavy exploration that would pollute controller window | Delegate to `sdd-research-scout` |
| Focused architecture work | Delegate to `sdd-plan-drafter` |
| Task that fits in a few tool calls | Direct inline — worker overhead not worth it |

These are heuristics except for non-trivial review, where independent reviewer dispatch is required unless self-review is explicitly accepted.

## Controller Prompt vs Hook Packet Boundary

| Concern | Where it lives | Why |
|:--------|:-------------|:----|
| Which task to execute | Controller prompt | Short and explicit: "implement T-xxx" |
| Task description, steps, ACs | Hook-injected packet | Assembled from artifacts; controller does not repeat this |
| Files in scope | Hook-injected packet | Pulled from research.md |
| Verification command | Hook-injected packet | Pulled from tasks.md |
| Authority statement | Hook-injected packet | Standardized template |
| Machine Dispatch Record | Hook-injected packet | Typed JSON with dispatch_id for correlation |

**Rule:** Keep the controller prompt short and goal-oriented. Let the hook inject the detailed packet. A prompt that contains `## Machine Dispatch Record` is doing the hook's job — use hook-first dispatch instead. Manual packet assembly is the fallback when hook dispatch is unavailable.

## Worker Concept

An SDD worker is a Claude Code subagent dispatched with an explicit assignment to perform a specific, bounded piece of work within an SDD feature. Workers are not separate processes or CLI commands — they are Claude Code subagent sessions that receive a dispatch packet defining their role, scope, and expected output.

Workers are optional. Features that fit in a single session do not need workers. Workers become valuable when:
- A feature has many tasks that can be parallelized
- Review requires independent verification (separate from implementation)
- Context is expensive and delegation preserves the controller's window
- The controller wants to continue working while a worker explores or reviews

### What Workers Are Not

- Workers are not a replacement for the SDD CLI (the CLI manages artifacts and lifecycle)
- Workers are not autonomous agents that decide their own scope (the controller assigns scope)
- Workers are not a different tool — they use Claude Code's native subagent mechanisms (Task tool, agent definitions)
- Workers are not required for every feature (single-session SDD flows work without workers)

## Controller Responsibilities

The controller session is the SDD authority. It:

1. **Orchestrates phases** — follows the SDD lifecycle (Brief → Design → Research → Plan → Implement → Review → Close)
2. **Dispatches workers** — assembles dispatch packets from SDD artifacts and sends them via Claude Code's Task tool or agent mechanisms
3. **Receives results** — processes structured worker returns and updates SDD artifacts accordingly
4. **Updates artifacts** — owns mutation of `tasks.md`, `review.md`, `continuity.md`, `knowledge.md` (with exceptions noted in Artifact Ownership)
5. **Validates scope** — ensures workers stay within assigned scope and do not drift
6. **Manages lifecycle** — runs `sdd task start/complete`, `sdd review`, and other phase-transition commands

## Worker Responsibilities

A worker session:

1. **Executes assigned scope** — implements the specific task, reviews specific code, or explores specific areas
2. **Does not restart the SDD lifecycle** — workers receive their assignment from the dispatch packet, not by reading brief.md and starting over
3. **Does not infer conflicting assignment from disk** — if the dispatch packet says "feature 0010, task T-003" but hooks suggest "feature 0005, task T-012", the worker trusts the dispatch packet
4. **Returns structured results** — follows the worker result contract (see [worker-results.md](worker-results.md)) with role-appropriate status and Machine Result fields. Implementers return task/files/verification; reviewers return scope/findings/verdict; research scouts return scope/findings/confidence/files_discovered; plan drafters return scope/proposed_decisions/proposed_tasks.
5. **Respects artifact ownership** — follows the tiered model for artifact mutations (see Artifact Ownership below)
6. **Self-reviews before returning** — reviews own work for completeness, correctness, and scope compliance before reporting back

## Hook vs Dispatch Boundary

SDD hooks and dispatch packets provide different kinds of context to worker sessions. Understanding the boundary is critical for correct worker behavior.

### What Hooks Provide (Ambient Orientation)

Hooks fire automatically and tell the worker **where it is** in the SDD workflow:

| Field | Source | Example |
|:------|:-------|:--------|
| Feature ID | Auto-detected from `.features/.active` or task scanning | `0010-sdd-claude-code-subagent-workers` |
| Phase | Auto-detected from artifact presence | `implement` |
| Current Task | First in-progress or pending task | `T-003: Add rate limiting` |
| Task Counts | From tasks.md | `2 done, 1 active, 4 pending` |
| Phase Rules | From `phase_rules()` function | `Rules: current task only; verify before completing` |
| Next Move | From `next_move()` function | `Next: implement T-003, run verification, mark complete` |
| Continuity | From continuity.md or summary-compact.md | Full session state snapshot |
| Nudges | Rotating reminders | `Nudge: update scratchpad.md` |

### What Dispatch Packets Provide (Authoritative Assignment)

The dispatch packet is assembled by the controller and tells the worker **what to do**:

| Field | Source | Example |
|:------|:-------|:--------|
| Worker Role | Controller-assigned | `implementer`, `spec-reviewer`, `quality-reviewer` |
| Specific Task | Controller-specified | `T-003` (not auto-detected) |
| Objective | From tasks.md description | `Add rate limiting middleware to API routes` |
| Requirements | From spec.md FRs | `FR-005: Rate limit must support configurable thresholds` |
| Acceptance Criteria | From spec.md ACs | `AC-003: Given 100 req/min threshold, when 101st request arrives, then 429 returned` |
| Files in Scope | From research.md | `src/middleware/rate-limit.ts (create), src/routes/api.ts (modify)` |
| Verification Command | From tasks.md | `npm test -- --grep "rate limit"` |
| Return Format | From worker-results.md | `Status, files_changed, verification, discoveries, concerns, suggested_artifact_updates` |
| Work Package | Controller-specified or "none" | `wp-01-api-layer` or `none` |
| Artifact Ownership | From this guide | `SAFE: scratchpad, sdd task complete; SUGGESTED: research, knowledge; FORBIDDEN: spec, plan` |

### Conflict Resolution Rule

**When hook context conflicts with dispatch packet data, the dispatch packet takes precedence.** The dispatch packet includes an explicit authority statement that workers must follow:

> "This dispatch packet is your authoritative assignment. If hook-provided context (feature ID, phase, current task) conflicts with this packet, trust this packet. You are assigned to feature [ID], task [T-xxx], role [role]. Do not infer a different assignment from disk."

Workers still benefit from hook context for non-conflicting fields:
- Phase rules and next-move guidance remain useful as behavioral reminders
- Continuity summaries provide orientation context
- Task counts provide progress awareness
- Nudges for scratchpad/knowledge updates are helpful

## Artifact Ownership

Workers interact with SDD artifacts through a tiered permission model. This preserves the integrity of the artifact chain while allowing workers to perform mechanical operations safely.

### SAFE Mutations (Worker May Do Directly)

| Artifact | Mutation | Why Safe |
|:---------|:---------|:---------|
| `scratchpad.md` | Append observations | Observations are additive and non-destructive |
| Task status | Implementer only: `sdd task complete <feature> <assigned-task>` | Marking an implementer's own assigned task complete is idempotent and verifiable |

### SUGGESTED Mutations (Worker Returns Suggestion)

| Artifact | Mutation | Why Suggested |
|:---------|:---------|:-------------|
| `tasks.md` | Add new tasks discovered during implementation | Controller should review and approve scope additions |
| `research.md` | Add new affected files or patterns | Controller should verify consistency with existing research |
| `knowledge.md` | Add new knowledge entries | Controller should review for accuracy and graduation-worthiness |
| `review.md` | Add review findings | Controller should integrate findings into the review artifact |
| `continuity.md` | Update progress notes | Controller should verify progress state is accurate |

Workers return suggestions in the `suggested_artifact_updates` field of their result (see [worker-results.md](worker-results.md)). Research scouts, plan drafters, and reviewers do not complete implementation tasks directly; the controller reviews each suggestion and applies it if appropriate.

## Codex Provider Dispatch

SDD can also record provider-aware worker dispatches for Codex through
`sdd worker dispatch`. Codex dispatch records extend `sdd-dispatch-v1` with
optional provider metadata:

| Field | Type | Meaning |
|:------|:-----|:--------|
| `provider` | string | `codex` for Codex-backed workers |
| `permission_mode` | string | recorded read/write mode, defaulting to `read-only` |
| `prompt` | object | prompt render status, template name, path, and content hash |
| `custom_task` | object | source, text, and byte count of operator-supplied task text |
| `runtime` | object | provider runtime mode and optional preflight result |
| `policy` | object | phase policy, write permission, and allowed write scope |

Codex prompt rendering is SDD-owned. Templates live under
`templates/codex/` and insert the operator request inside `<custom_task>`.
Custom text is an input to the template, not a replacement for dispatch packet
authority, scope, validation, output format, or stop rules.

Phase policy is enforced before provider execution:

- Brief and Close dispatch is refused.
- Research, Plan, and Review are read-only.
- Implement write mode requires an active task and explicit file scope.
- Failed preflight returns `provider_unavailable` without writing a successful
  dispatch/result record.

See [docs/codex-delegation.md](../docs/codex-delegation.md) for command
examples and setup behavior.

### FORBIDDEN Mutations (Controller Only)

| Artifact | Mutation | Why Forbidden |
|:---------|:---------|:-------------|
| `spec.md` | Any change | Spec is the source of truth — changes require phase transition |
| `plan.md` | Any change | Plan changes require controller approval and phase discipline |
| `brief.md` | Any change | Brief captures intent — changes require phase transition |
| Other tasks' status | Marking tasks other than assigned task | Workers own only their assigned task |
| Phase transitions | Running `sdd spec`, `sdd research`, etc. | Phase transitions are controller responsibilities |
| `.features/.active` | Modifying active feature selection | Would create race conditions with controller |

## Fallback: Manual Packet Assembly

Use manual packet assembly only when the SubagentStart hook is unavailable (no active feature on disk, or dispatching a non-SDD agent type that does not trigger the hook).

The controller assembles a worker through these steps:

1. **Identify the work** — determine which task, review, or exploration to delegate
2. **Select the role** — choose the appropriate worker role (implementer, spec reviewer, quality reviewer, research scout, plan drafter)
3. **Assemble the dispatch packet** — fill the prompt template with data from SDD artifacts:
   - Read `tasks.md` for task description, steps, acceptance criteria, and verification command
   - Read `spec.md` for relevant FRs and ACs
   - Read `research.md` for files in scope and code context
   - Read `plan.md` for phase context and architectural decisions
4. **Add the authority statement** — include the explicit precedence declaration
5. **Add artifact ownership rules** — include the tiered permission model summary
6. **Dispatch via Claude Code** — send the assembled prompt to the Task tool or agent

See the role templates below for copy-ready packet formats. The machine result template in each packet is pre-filled when SubagentStart injects automatically; fill it manually when assembling by hand.

## Packet Schema

Every dispatch packet contains these fields. The controller assembles them from SDD artifacts before dispatching a worker.

## Machine Dispatch Record

Every dispatch packet MUST include a dedicated `## Machine Dispatch Record` section containing exactly one fenced `json` block. This block is the canonical machine-readable payload for hook persistence and later correlation work.

The controller should keep the existing human-readable packet sections, but the machine record is what runtime consumers parse first.

### Section Contract

- The section heading MUST be `## Machine Dispatch Record`
- The section MUST contain exactly one fenced `json` block
- `dispatch_id` MUST equal the Claude Code `agent_id` from the `SubagentStart` hook input
- `schema_version` MUST be `sdd-dispatch-v1`
- The JSON block MUST appear once per packet and should not be reused for examples elsewhere in the packet body

### Machine Dispatch Schema

| Field | Type | Required | Description |
|:------|:-----|:---------|:------------|
| `schema_version` | string | yes | Must be `sdd-dispatch-v1` |
| `dispatch_id` | string | yes | Correlation key, equal to the Claude Code `agent_id` |
| `dispatch_epoch` | number | yes | Monotonic session-local dispatch counter |
| `role` | string | yes | Worker role name |
| `feature` | string | yes | Feature ID |
| `phase` | string | yes | Active SDD phase |
| `task` | object or null | yes | `{id, heading, phase}` for task dispatches, `null` for phase-level dispatches |
| `work_package` | string | yes | WP ID or `none` |
| `objective` | string | yes | Full objective text |
| `requirements` | object | yes | Relevant FR and AC IDs or snapshots |
| `files_in_scope` | array | yes | Scoped file records with path/action/impact |
| `verification` | object or null | yes | Verification metadata for task dispatches, else `null` |
| `authority` | string | yes | Authority statement rendered in prose elsewhere too |

### Machine Dispatch Example

```json
{
  "schema_version": "sdd-dispatch-v1",
  "dispatch_id": "agent-abc123",
  "dispatch_epoch": 4,
  "role": "implementer",
  "feature": "0023-sdd-typed-worker-contracts",
  "phase": "implement",
  "task": {
    "id": "T-002",
    "heading": "Emit and persist typed dispatch JSON at SubagentStart",
    "phase": "PH-02"
  },
  "work_package": "none",
  "objective": "Extend dispatch packet assembly so each packet includes a typed JSON block, uses the hook-provided agent_id as dispatch_id, and persists a ledger entry under .features/<feature>/workers/.",
  "requirements": {
    "fr": ["FR-001", "FR-003"],
    "ac": ["AC-002"]
  },
  "files_in_scope": [
    {
      "path": "sdd-plugin/skills/spec-driven-development/scripts/sdd-lib.sh",
      "action": "modify",
      "impact": "cross-module"
    },
    {
      "path": "sdd-plugin/skills/spec-driven-development/scripts/sdd-subagent-start.sh",
      "action": "modify",
      "impact": "cross-module"
    }
  ],
  "verification": {
    "command": "bash sdd-plugin/skills/spec-driven-development/scripts/tests/sdd-subagent-test.sh",
    "required": true
  },
  "authority": "This dispatch packet is your authoritative assignment. If hook-provided context conflicts with this packet, trust this packet."
}
```

### Required Fields

| Field | Source | Description |
|:------|:-------|:------------|
| `role` | Controller-assigned | Worker role: `implementer`, `spec-reviewer`, `quality-reviewer`, `research-scout`, or `plan-drafter` |
| `feature` | From feature directory name | Feature ID, e.g. `0010-sdd-claude-code-subagent-workers` |
| `phase` | From `sdd phase` output | Current SDD phase: `brief`, `design`, `research`, `plan`, `implement`, `review`, or `close` |
| `task` | From tasks.md | Task ID and description, e.g. `T-003: Create worker dispatch packet schema` |
| `objective` | From tasks.md description | What the worker should accomplish — the full task description, not a reference |
| `requirements` | From spec.md FRs and ACs | Relevant FRs and ACs the worker must satisfy |
| `files_in_scope` | From research.md affected files | Files the worker is expected to read, create, or modify |
| `verification` | From tasks.md verification command | Command to run to verify the work |
| `return_format` | References worker-results.md | What the worker must include in its return report |
| `authority` | Template below | Explicit statement that this packet overrides hook context |

### Optional Fields

| Field | Source | Description |
|:------|:-------|:------------|
| `work_package` | Controller-specified or `"none"` | WP identity if task belongs to a work package, or `"none"` if not applicable |
| `context` | Controller summary | Where this task fits in the feature — dependencies, prior decisions, architectural context |
| `prohibitions` | From this document | What the worker must NOT do (role-specific) |
| `isolation` | Controller decision | `worktree` if worker should work in an isolated worktree, omitted if not needed |

## Authority Statement Template

Every dispatch packet MUST include this statement (or a close variant with the specific values filled in):

```
AUTHORITY: This dispatch packet is your authoritative assignment. If hook-provided
context (feature ID, phase, current task) conflicts with this packet, trust this packet.
You are assigned to feature [FEATURE], task [T-xxx], role [ROLE]. Do not infer a
different assignment from disk.
```

Workers still benefit from non-conflicting hook output:
- Phase rules and behavioral reminders remain useful
- Continuity summaries provide orientation
- Task counts provide progress awareness
- Nudges for scratchpad updates are helpful

## Role Templates

### Task Implementer

**Role**: `implementer`
**When to use**: Delegate a specific implementation task from tasks.md
**Tools**: Read, Write, Edit, Bash, Glob, Grep

````markdown
You are an SDD Task Implementer.

AUTHORITY: This dispatch packet is your authoritative assignment. If hook-provided
context (feature ID, phase, current task) conflicts with this packet, trust this
packet. You are assigned to feature [FEATURE], task [T-xxx], role implementer.
Do not infer a different assignment from disk.

## Machine Dispatch Record

```json
{
  "schema_version": "sdd-dispatch-v1",
  "dispatch_id": "[Claude Code agent_id]",
  "dispatch_epoch": [number],
  "role": "implementer",
  "feature": "[FEATURE]",
  "phase": "[PHASE]",
  "task": {
    "id": "[T-xxx]",
    "heading": "[Task heading]",
    "phase": "[PH-xx]"
  },
  "work_package": "[wp-id or none]",
  "objective": "[Full objective text]",
  "requirements": {
    "fr": ["FR-xxx"],
    "ac": ["AC-xxx"]
  },
  "files_in_scope": [
    {"path": "[path]", "action": "modify", "impact": "module"}
  ],
  "verification": {
    "command": "[verification command]",
    "required": true
  },
  "authority": "This dispatch packet is your authoritative assignment. If hook-provided context conflicts with this packet, trust this packet."
}
```

## Task

[TASK ID]: [Full task description from tasks.md]

## Objective

[FULL TEXT of the task objective — paste it, do not make the worker read the file]

## Context

[Where this task fits: dependencies, prior decisions, architectural context from plan.md]

## Requirements

[List relevant FRs and ACs from spec.md that this task must satisfy]

## Files in Scope

[List of files from research.md that this task is expected to read, create, or modify,
with action (create/modify/review)]

## Before You Begin

If anything in the task description, requirements, or scope is unclear, ask questions
before starting. Do not guess or make assumptions about requirements.

## Your Job

1. Implement exactly what the task specifies — nothing more, nothing less
2. Write tests if the task requires verification
3. Run the verification command to confirm your work
4. Self-review before reporting back (see below)
5. Report your results in the required format

## Artifact Ownership

- SAFE (you may do directly): append observations to scratchpad.md, run
  `sdd task complete [feature] [T-xxx]` for your assigned task
- SUGGESTED (return suggestion, controller applies): new tasks, research.md
  updates, knowledge.md entries
- FORBIDDEN (do not attempt): spec.md changes, plan.md changes, phase transitions,
  other tasks' status, .features/.active modifications

## Self-Review Checklist

Before reporting back, verify:

**Completeness:**
- Did I implement everything the task requires?
- Did I miss any requirements or edge cases?

**Quality:**
- Is this my best work? Are names clear and accurate?
- Does the code follow existing patterns in the codebase?

**Discipline:**
- Did I avoid overbuilding (YAGNI)?
- Did I only build what was requested?
- Did I stay within the assigned file scope?

**Testing:**
- Do tests verify behavior, not just mock it?
- Did I run the verification command?

If you find issues during self-review, fix them before reporting.

## Prohibitions

- Do NOT restart the SDD lifecycle (no `sdd init`, `sdd spec`, etc.)
- Do NOT infer conflicting assignment data from disk
- Do NOT expand scope without controller approval
- Do NOT modify forbidden artifacts
- Do NOT mark tasks other than your assigned task as complete

## Verification

[Verification command from tasks.md]

## Return Format

Report your results using the format in references/worker-results.md:
- Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- Summary of what you implemented
- Files changed (path, action, description)
- Verification results
- Discoveries or risks
- Concerns
- Suggested artifact updates

## Work Package

[work_package field — e.g., "wp-01-api-layer" or "none"]
````

### Other Roles

All roles use the same dispatch schema and Machine Dispatch Record format. Role-specific behavioral definitions, tool constraints, and prohibitions are defined in the agent files at [`../agents/`](../agents/). See [`../agents/README.md`](../agents/README.md) for the routing guide.

## Work Package Context

When a feature uses work packages (see SDD SKILL.md Work Packages section), the dispatch packet includes a `work_package` field to scope the worker's assignment.

### With Work Package Context

```
work_package: wp-01-api-layer
```

The worker is scoped to tasks within `wp-01-api-layer`. They should:
- Only modify files listed in that WP's scope
- Validate against that WP's task acceptance criteria, not all feature ACs
- Report results scoped to the WP

### Without Work Package Context

```
work_package: none
```

The worker operates at feature level with no WP scoping. They should:
- Work on the assigned task regardless of WP boundaries
- Validate against the feature-level ACs
- Report results at the feature level

### Controller Behavior

The controller includes `work_package` in every dispatch packet:
- If the task belongs to a WP → set `work_package` to the WP ID (e.g., `wp-01-api-layer`)
- If the task is feature-level or WPs are not in use → set `work_package: none`

Workers should not need to infer WP context from disk — the dispatch packet provides it explicitly.

## Packet Assembly Checklist

When assembling a dispatch packet, the controller should verify:

1. **Role** is one of the five defined roles (implementer, spec-reviewer, quality-reviewer, research-scout, plan-drafter)
2. **Feature** matches the feature directory name
3. **Phase** matches the current SDD phase
4. **Task** is a specific task ID from tasks.md (or a scope description for reviewers)
5. **Objective** contains the full task description, not just a reference
6. **Requirements** lists the relevant FRs and ACs from spec.md
7. **Files in scope** lists files from research.md with actions (create/modify/review)
8. **Verification** is the verification command from tasks.md
9. **Return format** references worker-results.md
10. **Authority statement** is included with correct feature, task, and role values
11. **Work package** is set to the WP ID or `"none"`
12. **Artifact ownership** rules are included in the role template
13. **Machine dispatch record** is present as `## Machine Dispatch Record` with a single `json` fence
14. **dispatch_id** is set to the Claude Code `agent_id`

## Return Process

When a worker completes, the controller:

1. **Reads the structured result** — parses the status, files changed, verification results, discoveries, concerns, and suggested artifact updates
2. **Handles the role-appropriate status**:
   - `DONE` — proceed to next task or phase
   - `DONE_WITH_CONCERNS` — review concerns, decide whether to address before proceeding
   - `BLOCKED` — assess the blocker, provide context or break the task into smaller pieces
   - `NEEDS_CONTEXT` — provide the missing information and re-dispatch
   - Reviewer `PASS` / `FAIL` — integrate reviewer evidence into the review artifact or return to Implement
3. **Updates SDD artifacts**:
   - Mark task status in `tasks.md` only for implementer results assigned to a task
   - Apply `suggested_artifact_updates` after review — when writing plan drafter proposed tasks to `tasks.md`, translate them to `> Status:` blockquote field syntax as shown in `templates/tasks.md`. Plan drafter output uses human-readable prose; `tasks.md` requires machine-parseable blockquote fields or `sdd task list` returns zero rows silently.
   - Update `continuity.md` with progress
   - Graduate discoveries to `knowledge.md` if appropriate
   - Update `research.md` if new files or patterns were discovered
4. **Dispatches the next worker** — or transitions to the next phase if all tasks complete

See [worker-results.md](worker-results.md) for the complete result contract and status taxonomy.

## Work Package Awareness

When a feature uses work packages (WP mode), the dispatch packet includes a `work_package` field:

- **With WP context**: `work_package: wp-01-api-layer` — the worker is scoped to tasks within that WP
- **Without WP context**: `work_package: none` — the worker operates at feature level (no WP scoping)

Workers should respect WP boundaries:
- An implementer assigned to `wp-01-api-layer` should only modify files listed in that WP's scope
- A reviewer should validate against the WP's task acceptance criteria, not all feature ACs
- Workers should not create tasks in a different WP without controller approval

## When to Use Workers

| Scenario | Recommended Approach |
|:---------|:--------------------|
| Feature with 1-3 tasks | Single session — no workers needed |
| Feature with 5+ independent tasks | Workers for parallel implementation |
| Code review before commit | Spec reviewer worker, then quality reviewer worker |
| Context-heavy research | Research scout worker (preserves controller context) |
| Complex architecture decision | Plan drafter worker (focused reasoning, controller approves) |
| Waiting on long tests/builds | Continue in controller, dispatch next task to worker |
| Multiple active features | Workers for non-blocking tasks, controller stays focused |

## Relationship to SDD Phases

Workers do not change the SDD phase model. The controller still follows the 7-phase lifecycle. Workers are an execution mechanism within the Implement and Review phases:

- **Implement phase**: Controller may dispatch implementer workers for individual tasks
- **Review phase**: Controller may dispatch spec reviewer and quality reviewer workers for validation
- **Research phase**: Controller may dispatch research scout workers for exploration
- **Plan phase**: Controller may dispatch plan drafter workers for focused architecture work

Workers are never dispatched during Brief, Design, or Close phases — those phases require direct conversation with the user.

## Relationship to Existing SDD Mechanisms

| Mechanism | Relationship to Workers |
|:----------|:----------------------|
| SDD CLI (`sdd` commands) | CLI manages artifacts and lifecycle. Workers do not call CLI commands except `sdd task complete` for their assigned task. |
| SDD Hooks (`sdd-hook.sh`) | Hooks provide ambient context to all sessions including workers. Dispatch packets override hooks on conflicting assignment fields. |
| Phase Detection (`sdd-phase.sh`) | Workers do not change phase detection. The controller manages phase transitions. |
| Scope Drift Checks (`sdd-scope-drift.sh`) | Still active for workers. If a worker edits a file outside their assigned scope, the drift check fires. This is a useful safety net. |
| Stop Gate (`sdd-stop-gate.sh`) | Applies to the controller session. Workers should not trigger stop gates independently. |
| Work Packages (`sdd-wp.sh`) | Workers can be scoped to a specific WP via the `work_package` field in the dispatch packet. |

## Cross-References

- **Worker result contract**: [worker-results.md](worker-results.md)
- **Canonical agent role files**: [`../agents/`](../agents/)
- **Agent routing guide**: [`../agents/README.md`](../agents/README.md)
- **Eval scenarios**: [`../evals/eval-scenarios.md`](../evals/eval-scenarios.md)
