# Lite Profile Phase Guide

**Goal:** Keep small work grounded without the full seven-artifact chain.
**Artifacts:** `.features/{{FEATURE}}/spec.md`, `tasks.md`, `review.md`, `scratchpad.md`, `continuity.md`, `knowledge.md`, `scope.txt`, `task-scope.txt`.
**Gate:** Same behavioral core, task gate, scope discipline, verification, and review verdict as full mode.

Lite has three working phases: Spec, Implement, Review. Close still finalizes the feature after `review.md` has `verdict: pass`.

## Shared Rules

- Do not write production code until `tasks.md` has at least one concrete `T-NNN` task.
- Keep WHAT and HOW separate: `spec.md` owns FRs/ACs; `tasks.md` owns `## Approach` and task execution.
- Update `.features/{{FEATURE}}/scratchpad.md` every 3-5 tool calls during implementation.
- Use the smallest viable change. Lite is for low-risk work, not hidden full features.
- If scope grows into multi-component, migration, auth, billing, or multi-day work, finish the current lite task honestly and start a follow-up full feature.

## Spec

**Goal:** Capture enough WHY/WHAT/HOW to start safely.
**Updates:** `spec.md`, `tasks.md`, `scope.txt` when affected files are known.
**Gate:** No production edits.

### Process

1. Read `spec.md` and `tasks.md`.
2. Confirm `spec.md` has a concrete Problem, at least one `FR-NNN`, and at least one `AC-NNN`.
3. Add compact codebase notes to `spec.md` when inspection changes scope or risk.
4. Fill `tasks.md` `## Approach` with 1-5 concrete bullets.
5. Add atomic `## T-NNN` tasks with Status, Implements, Files, and Verification.
6. Populate `scope.txt` with expected file paths once known.
7. Run `sdd check all {{FEATURE}}` before moving into implementation.

### Strategy

- Ask only when ambiguity changes behavior, verification, or scope.
- Keep research notes brief and evidence-backed; do not recreate full `research.md`.
- Keep Approach high-level. Detailed step-by-step work belongs in tasks.
- ACs must be testable or manually verifiable.

### The Iron Law of Verification

A VERIFICATION COMMAND MUST DEPEND ON ITS TASK'S STATUS — FAIL BEFORE, PASS AFTER.

If the exit code is the same whether or not this task is done, the command doesn't verify the task. Probe what THIS task introduces; move regression guards to a final task or shared test suite.

For red-test-only tasks, wrap expected-failure probes so Verification exits 0 when the expected failure is observed. The implementation task owns the final green suite.

### Exit criteria

- `spec.md` passes readiness.
- `tasks.md` has non-placeholder Approach content.
- At least one task is concrete and pending.

## Implement

**Goal:** Build one task at a time.
**Updates:** `tasks.md`, `scratchpad.md`, `task-scope.txt`, changed source/test files.
**Gate:** Current task only; no scope expansion without task coverage.

### Process

1. Find the next task: `sdd task next {{FEATURE}}`.
2. Start it: `sdd task start {{FEATURE}} T-xxx`.
3. Read every file listed in the task's Files field before editing.
4. If the task's Files field changes after start, run `sdd task scope-refresh {{FEATURE}} T-xxx` to update `task-scope.txt` without resetting status.
5. Implement the smallest change that satisfies the task.
6. Run the task Verification command.
7. Complete it: `sdd task complete {{FEATURE}} T-xxx`.
8. Record any non-obvious observation in `scratchpad.md`.

### Scope discipline

- If a needed file is outside task scope, stop and update the task artifact first.
- After updating a running task's Files field, refresh the derived boundary with `sdd task scope-refresh {{FEATURE}} T-xxx`.
- If the task is missing a verification command, add one before implementation.
- If verification fails, inspect the failure and fix root cause before retrying.
- Do not add deferred full-mode artifacts (`brief.md`, `research.md`, `plan.md`, `trace.json`) to make a lite feature "look complete."

### Exit criteria

All tasks in `tasks.md` have `> Status: completed`.

## Review

**Goal:** Validate each AC with evidence.
**Updates:** `review.md`, `scratchpad.md`.
**Gate:** No silent continued implementation.

### Process

1. Read `spec.md` before reading code.
2. Confirm all tasks are completed.
3. For each AC in `spec.md`, record PASS or FAIL with concrete evidence.
4. Run targeted tests and any feature-level verification command.
5. Check changed files against `scope.txt` and `task-scope.txt`.
6. Set `review.md` frontmatter `verdict: pass` or `verdict: fail`.

### Handling failures

- AC failure means return to Implement with a concrete task.
- Missing evidence means Review is incomplete, not pass.
- Critical quality issues should be recorded and fixed through task coverage.

### Exit criteria

`review.md` has `verdict: pass` and every AC row has PASS evidence. Then `sdd close {{FEATURE}}` may run; lite close does not produce archive output.
