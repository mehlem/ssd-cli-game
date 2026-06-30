# Subagent Delegation: Worker Contracts, Roles, and Automated Dispatch

SDD enables Claude Code-native subagent workers to execute bounded tasks within the SDD feature lifecycle. This domain consolidates the worker contract model (feature 0010), the canonical agent role pack (feature 0011), and automated dispatch with result validation via hooks (feature 0020).

## The Worker Model

An SDD worker is a Claude Code subagent dispatched with an explicit assignment to perform a specific, bounded piece of work. Workers are optional — features that fit in a single controller session do not need workers. Workers become valuable when a feature has independent tasks to parallelize, review requires verification separation, or the controller wants to preserve context while delegating.

**Workers are not:**
- Separate processes or CLI commands — they are Claude Code subagent sessions
- Autonomous agents that decide their own scope — the controller assigns scope explicitly
- A replacement for the SDD CLI — the CLI manages artifacts and lifecycle; workers execute tasks
- Required for every feature — single-session SDD flows work without workers

(Feature 0010: Worker Contracts and Authority Model)

## Authority Model: Controller vs Worker

The **controller session** is the SDD authority:

1. Orchestrates phases and lifecycle transitions
2. Assembles and dispatches workers with explicit assignments
3. Receives and validates worker results
4. Updates SDD artifacts (`tasks.md`, `review.md`, `continuity.md`, `knowledge.md`)
5. Manages scope boundaries and prevents scope drift

A **worker session**:

1. Executes only the assigned scope
2. Does not restart the SDD lifecycle (no `sdd init`, `sdd spec`, etc.)
3. Does not infer conflicting assignment from disk — the dispatch packet is authoritative
4. Returns structured results with status, files changed, verification, and suggested updates
5. Respects the tiered artifact ownership model
6. Self-reviews before returning

### Hook vs Dispatch Boundary

**Hooks provide ambient orientation** — where the worker is in the workflow (feature, phase, current task, task counts, phase rules, continuity context).

**Dispatch packets provide authoritative assignment** — what the worker must do (role, specific task, objective, requirements, files in scope, verification command, work package context, artifact ownership rules).

**Conflict resolution rule:** When hook context conflicts with dispatch packet data, the dispatch packet takes precedence. The packet includes an explicit authority statement that workers must follow:

> "This dispatch packet is your authoritative assignment. If hook-provided context (feature ID, phase, current task) conflicts with this packet, trust this packet. You are assigned to feature [ID], task [T-xxx], role [role]. Do not infer a different assignment from disk."

Workers still benefit from non-conflicting hook context for behavioral guidance, continuity awareness, and progress signals.

### Shared Worker Posture

Every worker role should inherit the same behavioral posture even when their responsibilities differ:

- **Surface ambiguity** instead of guessing silently; return `NEEDS_CONTEXT` when the assignment cannot be grounded.
- **Investigate before claiming** by reading the relevant artifact or code before reporting conclusions.
- **Prefer the smallest viable solution** instead of speculative abstraction or future-proofing.
- **Change surgically** within the assigned scope.
- **Treat done as verified evidence** by tying completion to the task's verification or cited review evidence.

## The Five Agent Roles

SDD ships five canonical agent role definitions in `.claude/agents/` (automatically registered by the plugin). Each role has constrained tools, explicit artifact ownership rules, and role-specific prohibitions.

(Feature 0011: Agent Role Pack)

### Research Scout

**Phase**: Research  
**Execution**: Background + worktree isolation  
**Mutates code**: No  
**Tools**: Read, Glob, Grep, Bash  
**Special**: Can run isolated in a worktree while the controller continues elsewhere

Use when you need codebase exploration, feasibility analysis, or pattern discovery while preserving controller context. Returns findings with confidence scoring (0-100) across five dimensions: scope clarity, pattern familiarity, dependency awareness, edge case coverage, and test strategy.

**Prohibitions**: Do not modify code or test files; do not restart the SDD lifecycle; do not expand exploration scope without approval.

### Plan Drafter

**Phase**: Plan  
**Execution**: Foreground  
**Mutates code**: No  
**Tools**: Read, Glob, Grep  
**Special**: Produces architectural decisions (AD-xxx) and task decomposition (T-xxx)

Use when you need focused architecture design or task decomposition. Plan drafter output requires explicit controller approval before any implementation begins.

**Prohibitions**: Do not implement code; do not modify spec.md or brief.md; do not begin implementation without approval.

### Task Implementer

**Phase**: Implement  
**Execution**: Foreground  
**Mutates code**: Yes (task scope only)  
**Tools**: Read, Write, Edit, Bash, Glob, Grep  
**Special**: Can mark assigned task complete via `sdd task complete`

Use when delegating a specific implementation task from tasks.md. The implementer has full tool access within assigned scope but cannot modify forbidden artifacts or other tasks' status.

**Self-review checklist before returning:**
- **Completeness**: Did I implement everything the task requires?
- **Quality**: Is this my best work? Are names clear?
- **Discipline**: Did I stay within scope? Did I avoid overbuilding?
- **Testing**: Do tests verify real behavior? Did I run verification?

**Prohibitions**: Do not restart the SDD lifecycle; do not infer conflicting assignment from disk; do not expand scope; do not modify forbidden artifacts; do not mark other tasks complete.

### Spec Reviewer

**Phase**: Review  
**Execution**: Foreground  
**Mutates code**: No  
**Tools**: Read, Glob, Grep  
**Special**: Independently verifies implementation against specification

Use after implementation to verify that code matches spec requirements. Spec reviewers are skeptical and independent — they read actual code, not implementer claims.

**Verified-Only Protocol (non-negotiable):**
- Read actual code before reporting any finding
- Cite `file:line` for every finding
- Drop unverified claims — uncertainty is not a finding
- Ban phrases like "consider adding", "ensure that", "might cause", "could lead to"
- Use Verified Clean to record explicitly checked areas with no issues

**Prohibitions**: Do not modify code or test files; do not trust implementer reports; do not restart the SDD lifecycle; do not modify forbidden artifacts.

### Code Quality Reviewer

**Phase**: Review  
**Execution**: Foreground  
**Mutates code**: No (Bash for test runs only)  
**Tools**: Read, Glob, Grep, Bash  
**Special**: Runs test suites and linters without modifying code

Use after spec review passes to verify code quality (correctness, tests, security, performance, readability, file organization).

**Prohibitions**: Do not modify code or test files; do not restart the SDD lifecycle; do not modify forbidden artifacts.

### Typical Dispatch Sequence

For a feature task: Research scout (optional) → Plan drafter (optional) → Implementer → Spec reviewer → Quality reviewer

The controller validates results at each handoff. Only the implementer mutates production code.

## Dispatch Packets

The dispatch packet is an explicit assignment that the controller assembles from SDD artifacts and sends to the worker. It is the authoritative source of truth for what the worker must do.

(Feature 0010: Dispatch Packet Schema)

### Packet Contents

**Required fields:**
- `role` — worker role (implementer, spec-reviewer, quality-reviewer, research-scout, plan-drafter)
- `feature` — feature ID (e.g., 0010-sdd-claude-code-subagent-workers)
- `phase` — current SDD phase
- `task` — task ID and description (e.g., T-003: Create dispatch schema)
- `objective` — full task description (paste it, do not reference)
- `requirements` — relevant FRs and ACs from spec.md
- `files_in_scope` — files from research.md with action (create/modify/review)
- `verification` — verification command from tasks.md
- `return_format` — reference to worker-results.md
- `authority` — explicit precedence statement

**Optional fields:**
- `work_package` — WP identity or "none"
- `context` — architectural context and dependencies
- `prohibitions` — role-specific artifact ownership rules
- `isolation` — "worktree" if needed

#### Required Fields

| Field | Type | Description |
|:------|:-----|:------------|
| `role` | string | Agent role name (e.g. `sdd-implementer`) |
| `feature` | string | Feature ID (e.g. `0001-user-auth`) |
| `phase` | string | Current phase name |
| `task` | string | Task ID being delegated (e.g. `T-003`) |
| `objective` | string | Plain-language statement of what to accomplish |
| `requirements` | string[] | FR-xxx / AC-xxx IDs this task satisfies |
| `files_in_scope` | string[] | File paths the worker is authorized to read/write |
| `verification` | string | How the controller will verify the result |
| `return_format` | string | Expected result format (always include the typed JSON block) |
| `authority` | string | Explicit statement of what the worker may and may not mutate |

#### Optional Fields

| Field | Type | Description |
|:------|:-----|:------------|
| `work_package` | string | WP ID if delegating within a work package |
| `context` | string | Additional background the worker needs |
| `prohibitions` | string[] | Explicit list of forbidden actions |
| `isolation` | string | `worktree` to isolate file mutations |

### Packet Assembly Checklist

1. Select the appropriate role for the work
2. Read the task description, requirements, files, and verification from SDD artifacts
3. Fill in all required fields — do not ask the worker to read files
4. Include the authority statement with exact feature, task, and role values
5. Include artifact ownership rules from the role template
6. Set work_package to the WP ID or "none"

Complete templates are in `references/workers.md`.

## Automated Dispatch via Hooks (Primary Path)

SDD provides two hook points that automate dispatch packet injection and result validation. Hook-first (hook-driven) dispatch is the recommended approach — the controller sends a short goal prompt, and the hook handles packet assembly automatically. Manual packet assembly (see `references/workers.md`) is the fallback when hooks are unavailable.

(Feature 0020: Subagent Dispatch & Validation Hooks; Feature 0036: Stop-hook hardening and tiered validation)

### SubagentStart Hook

When an SDD agent (sdd-implementer, sdd-spec-reviewer, sdd-quality-reviewer, sdd-research-scout, or sdd-plan-drafter) starts, the SubagentStart hook automatically:

1. Reads current SDD state from disk (feature, phase, current task)
2. Constructs a standardized dispatch packet from artifacts:
   - Feature ID and phase
   - Current task and objective
   - Relevant FRs and ACs from spec.md
   - Files in scope from research.md
   - Verification command from tasks.md
   - Authority statement
3. Embeds a dedicated `## Machine Dispatch Record` section with a single `json` block using `schema_version: sdd-dispatch-v1`, `dispatch_id == agent_id`, and the typed dispatch payload
4. Persists that typed payload to `.features/<feature>/workers/dispatch-<dispatch_id>.json`
5. Injects the packet as `additionalContext` into the subagent
6. Generates a pre-filled result JSON template matching the worker's role and embeds it in the worker prompt so the worker knows exactly what structure to return
7. Increments `session_flags.dispatch_epoch` for traceability

The hook fires automatically — the controller does not assemble packets by hand. If no active feature exists or SDD artifacts are missing, the hook exits gracefully.

**Result Template Injection:** The SubagentStart hook embeds a pre-filled result JSON template in the worker assignment so the worker knows exactly what structure to return. This template includes the correct `schema_version`, placeholder fields for required sections, and role-specific status values, allowing workers to fill in their work details without guessing the output format.

**Project Customization Injection:** When `.sdd/customization.yaml` (and optionally `.features/<active>/customization.yaml`) exists, the SubagentStart hook augments the dispatch packet with a `<project_customization>` block containing the `notes.global`, `notes.<agent_role>`, and `notes.learned` slices merged across project and feature files. Because subagents start with empty conversation context that does not inherit the controller session, the dispatch packet is the only path through which workers see project conventions. When neither customization file exists, the hook short-circuits and emits no `<project_customization>` block. Schema details, scope keys, and interpolation tokens are documented in `references/customization.md`.

### SubagentStop Hook

When an SDD agent stops, the SubagentStop hook automatically:

1. Checks the agent type (spec-reviewer, quality-reviewer, or implementer)
2. Validates that `last_assistant_message` contains required result structure:
   - For implementers: `## Worker Result`, `## Machine Result Record`, a single `json` fence with `schema_version: sdd-result-v1`, `**Status**:` with a valid implementer value, `### Files Changed`, and `### Verification`
   - For reviewers: `## Worker Result`, `## Machine Result Record`, a single `json` fence with `schema_version: sdd-result-v1`, `**Status**:` with a valid reviewer value, and `### Findings`
3. Extracts the typed result JSON, verifies `dispatch_id == agent_id`, validates role-specific required fields, and blocks the stop with a concrete repair message if any part is missing or malformed
4. Resolves the originating feature from `.features/*/workers/dispatch-<dispatch_id>.json`, so result persistence still lands on the correct feature even if the active selection changed before the worker stopped
5. Persists the accepted typed result payload to `.features/<feature>/workers/result-<dispatch_id>.json`
6. Sets `session_flags.subagent_result_pending` to a structured object containing `feature`, `phase`, `role`, `dispatch_id`, `status`, `result_path`, and `transcript_path`

Validation uses a two-tier model (feature 0036 hardening):

### Validation Tiers

**Tier 1 (blocking):** dispatch_id match, schema_version, required status value, feature ID match. A Tier 1 failure aborts the result — the worker is asked to retry with a filled example.

**Tier 2 (non-blocking):** missing optional fields, warnings array gaps, recommendation quality. Tier 2 failures generate warnings in the result but do not block acceptance.

Bounded retry: after 3 failed Tier 1 attempts, the controller escalates to the user rather than retrying indefinitely.

These validation tiers ensure result consistency while allowing graceful degradation:

- **Initial validation** (attempts 1-2): Full two-tier validation runs. Results failing Tier 1 are blocked with a collect-all error message and a pre-filled repair example JSON.
- **Tier 2 handling**: Results failing Tier 2 are persisted with a `warnings` array. Normalization runs automatically before Tier 2: flat `task_id` strings, string verification values, and string-array files_changed are coerced to the canonical object shapes.
- **Bounded retry (attempt 3+)**: After 3 failed attempts, the hook relaxes to Tier 1 only and persists with a degraded quality warning. This replaces the old `stop_hook_active=true` bypass that caused all worker results to be silently dropped on retry.

Blocked results include all errors at once plus a filled-in example JSON matching the worker's role and dispatch context, so workers can repair in a single iteration.

#### Tier 1 (Blocking) — Exhaustive Field List

All of the following must be present, valid, and match the dispatch context:

| Field | Validation |
|:------|:-----------|
| `dispatch_id` | Must equal `agent_id` (set by SubagentStart hook) |
| `schema_version` | Must be present and one of: `sdd-dispatch-v1`, `sdd-result-v1` |
| `status` | Must be one of the allowed values for the worker's role (e.g., `DONE`, `DONE_WITH_CONCERNS`, `BLOCKED`, `NEEDS_CONTEXT` for implementers; `PASS`, `FAIL`, `NEEDS_CONTEXT` for reviewers) |
| `feature` | Must match the active feature ID in the dispatch packet context |

#### Tier 2 (Non-Blocking) — Structural Completeness

After Tier 1 passes, Tier 2 validation checks for well-formed optional fields and role-specific completeness:

| Condition | Handling |
|:----------|:---------|
| `warnings` array missing (even if empty) | Add `warnings: []` during normalization; note as warning |
| `files_changed` array missing (implementer results) | Add `files_changed: []` during normalization; note as warning |
| `confidence` score missing (research-scout results) | Add `confidence: 0` during normalization; note as warning |
| Recommendation fields unpopulated (reviewer results) | Add `recommendation: null` during normalization; note as warning |
| `summary` field missing | Auto-fill with placeholder; note as warning |

#### Result Normalization

Before Tier 2 validation runs, the SubagentStop hook normalizes the raw result — coercing flat `task_id` strings into `{id, status}` objects and bare string verification fields into `{command, result, exit_code}` objects. Normalization runs silently; the worker is never re-prompted for normalized fields.

### Worker-Choice Heuristics

Not every task warrants a subagent dispatch. Use workers for:
- Tasks requiring deep file exploration across 5+ files
- Tasks with clear authority boundaries (read-only review, isolated implementation)
- Tasks in parallel work packages that can run concurrently

Avoid workers for:
- Small, local changes (< 3 files, < 20 lines)
- Tasks that require back-and-forth clarification
- Single-step scaffolding commands (`sdd spec`, `sdd plan create`)

### Graceful Scope for Phase-Level Dispatch

When no current task exists (e.g., dispatching a research scout during research phase or plan drafter during plan phase):

- SubagentStart still injects: feature, phase, and scope from research.md
- Task-specific fields (task ID, verification command) are omitted
- The packet includes phase-appropriate context instead

## Artifact Ownership

The worker artifact model preserves controller authority while allowing workers to operate safely.

### SAFE Mutations (Worker May Do Directly)

| Artifact | Mutation |
|:---------|:---------|
| `scratchpad.md` | Append observations |
| Task status | `sdd task complete <feature> <assigned-task>` for own task only |

### SUGGESTED Mutations (Worker Returns Suggestion)

| Artifact | Mutation |
|:---------|:---------|
| `tasks.md` | Add new tasks discovered during work |
| `research.md` | Add new affected files or patterns |
| `knowledge.md` | Add new knowledge entries |
| `review.md` | Add review findings |
| `continuity.md` | Update progress notes |

Workers return suggestions in the `suggested_artifact_updates` field of their result. The controller reviews and applies them.

### FORBIDDEN Mutations (Controller Only)

| Artifact | Mutation |
|:---------|:---------|
| `spec.md` | Any change |
| `plan.md` | Any change |
| `brief.md` | Any change |
| Other tasks' status | Marking tasks other than assigned task |
| Phase transitions | Running `sdd spec`, `sdd research`, etc. |
| `.features/.active` | Modifying active feature |

## Result Contract

Every worker must return structured results following the `references/worker-results.md` contract. The SubagentStop hook validates structure; the controller validates quality.

**Compatibility boundary:** Reader paths remain backward-compatible with older features that have no `workers/` ledger entries yet. New worker writes are not backward-compatible by design: once typed worker contracts are enabled, workers must emit the dedicated machine-result JSON block so `SubagentStop`, status, summaries, and downstream adjudication can correlate results reliably.

For adjudication-aware review flows, reviewer workers should also populate the optional machine-result arrays `requirements_checked` and `verified_clean` whenever possible. The controller merge path can use those fields to project typed requirement rows and clean-area evidence into `review.md` without reparsing prose.

### Status Taxonomy

- `DONE` — task completed successfully, verification passed, no concerns
- `DONE_WITH_CONCERNS` — task completed but with caveats (quality issues, technical debt, unresolved edge cases)
- `BLOCKED` — cannot complete due to missing dependencies, architectural blockers, or insufficient context
- `NEEDS_CONTEXT` — missing information to proceed; task requires clarification or additional context

### Implementer Result Format

```markdown
## Worker Result

**Status**: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
**Task**: T-xxx: [task description]
**Role**: implementer

### Summary
[What was implemented or attempted]

### Files Changed
| Path | Action | Description |
|:-----|:-------|:------------|
| [path] | create/modify | [what and why] |

### Verification
**Command**: [command]
**Result**: [pass/fail/partial with details]

### Discoveries
[Optional — new patterns, risks, dependencies]

### Concerns
[Optional — only when status is DONE_WITH_CONCERNS]

### Suggested Artifact Updates
[Optional — proposals for controller to review and apply]
```

### Reviewer Result Format

```markdown
## Worker Result

**Status**: PASS | FAIL | NEEDS_CONTEXT
**Scope**: [what was reviewed]
**Role**: spec-reviewer | quality-reviewer

### Findings
| ID | Severity | Category | Description | Location | Evidence | Suggestion |

### Verified Clean
[Areas explicitly checked with no issues found]

### Verdict
[Overall assessment and recommendation]
```

All findings at critical or important severity **must** cite `file:line` and include concrete evidence (quoted code, test output, grep result). Summaries and speculative descriptions do not qualify as evidence.

## Work Package Awareness

When a feature uses work packages (WP mode), dispatch packets include a `work_package` field:

- **With WP context**: `work_package: wp-01-api-layer` — the worker is scoped to tasks within that WP, only modifies files in that WP's scope, validates against WP task acceptance criteria
- **Without WP context**: `work_package: none` — the worker operates at feature level with no WP scoping

The dispatch packet explicitly provides WP context — workers should not infer it from disk.

## Adoption

The SDD plugin automatically registers all five agent roles via `plugin.json`. Once the plugin is installed, the roles are available natively with no manual file copying required.

**Invoke directly from terminal:**
```bash
claude --agent sdd-research-scout
claude --agent sdd-implementer
claude --agent sdd-spec-reviewer
claude --agent sdd-quality-reviewer
claude --agent sdd-plan-drafter
```

**Or dispatch from within a session** using `Ctrl+B` (background agent picker) and selecting the role by name.

**For local testing** (load plugin from disk):
```bash
claude --plugin-dir ./sdd-plugin --agent sdd-research-scout
```

See `agents/README.md` for phase-to-role routing, tool envelopes, and detailed role descriptions.

### Plugin Registration

The five agent roles are declared in `plugin.json` under the `agents` key. When the SDD plugin is loaded (`claude --plugin-dir ./sdd-plugin` or installed from marketplace), Claude Code registers these agents automatically — no manual file copying required.

For standalone installs (without the plugin), `sdd setup` copies the agent definitions from `skills/spec-driven-development/agents/` into the target project's `.claude/agents/` directory.

### Adoption

To use a worker role:
1. **Plugin install** — roles are available immediately via `claude --agent <name>` or `Ctrl+B`
2. **Standalone** — run `sdd setup` to copy agent definitions; then invoke via `claude --agent <name>`
3. **Manual** — copy individual `.md` files from `agents/` to your project's `.claude/agents/`

See `agents/README.md` for the full routing guide: which role to dispatch in each phase, authority boundaries, and tool restrictions per role.

## Related References

- `agents/README.md` — role pack adoption guide and routing matrix
- `agents/sdd-implementer.md`, `sdd-spec-reviewer.md`, etc. — canonical agent definitions
- `references/workers.md` — conceptual model, dispatch guide, and packet schema
- `references/worker-results.md` — result contract and status taxonomy
- `scripts/sdd-subagent-start.sh`, `sdd-subagent-stop.sh` — hook implementations
