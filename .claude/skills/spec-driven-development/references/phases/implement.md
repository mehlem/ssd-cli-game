# Implement Phase Guide

**Goal:** Build it, task by task.
**Updates:** `.features/{{FEATURE}}/tasks.md`, `.features/{{FEATURE}}/scratchpad.md`, `research.md` if new files discovered. | **Gate:** One task at a time; no scope expansion without task coverage.

## Phase Entry Contract

Invoke `/sdd-implement` before editing `tasks.md` for task execution or running
a protected boundary command from Implement. Direct reads of this phase
reference, `SKILL.md`, or `tasks.md` do not satisfy the routing latch. The
latch proves the agent routed through Implement guidance; it does not prove
task completion or artifact correctness.

Implement starts when `tasks.md` is execution-ready: it has substantive
`## Approach` content and concrete task headings. If `tasks.md` still contains
only scaffold or placeholder authoring content, stay in Plan and use
`/sdd-plan` while finishing the task breakdown.

## The Iron Law of Task Completion

**NO TASK COMPLETE WITHOUT THE VERIFICATION COMMAND PASSING.**

Writing the code is not the definition of done. Running the verification command and seeing it pass is the definition of done. A task marked complete before its verification command passes is a phantom completion — it corrupts the trace, misleads reviewers, and creates debt that surfaces as a bug or a failing AC in Review.

This is the *completion-honesty* companion to `## The Iron Law of Task Verification` (below): one rule says the verification command must be a real test (authoring quality), the other says you must actually run it before claiming done (completion honesty). Both rules are needed; neither alone is sufficient.

If you find yourself thinking "verification will pass, I'm sure of it" or "I'll run it after the next task," that's a sign the task is not yet done — running the command is part of the work, not a follow-up to it.

### Anti-patterns

- **"This is a small code tweak."** Small tweaks still need task alignment and verification. Atomicity is a property of the task, not the diff.
- **"I'll update artifacts after."** Updating tasks.md and scratchpad.md *before* the edit prevents drift. After-the-fact updates are how scope creep enters the trace.
- **"Close enough to current scope."** Either map the change to an active task or record a scope change. "Close enough" is unverifiable — and unverifiable changes corrupt the audit trail.
- **"I'll also improve this adjacent code."** Drive-by refactoring inflates the diff and dilutes the review. Mention it as a follow-up; do not fix it without a task.
- **"Let me add flexibility for future use cases."** Speculative. Implement the requested case only. Future requirements can earn their own tasks when they materialize.

## Process

First-entry autonomy check: if `.features/{{FEATURE}}/state.json` has `autonomous: null`, ask once whether to enable autonomous mode and record via `sdd autonomy on {{FEATURE}}` or `sdd autonomy off {{FEATURE}}`.
1. **Pre-flight reads:** brief.md (WHY), spec.md (WHAT), research.md (WHERE), tasks.md (DO).
2. Confirm `tasks.md` is execution-ready; if not, return to Plan task authoring.
3. Find the next pending task: `sdd task next {{FEATURE}}`
4. Mark it in-progress: `sdd task start {{FEATURE}} T-xxx`
5. **Worker Dispatch Decision:** For small or straightforward tasks, execute inline. For large tasks with many file changes, or when parallel execution is valuable, use hook-first dispatch: invoke `sdd-implementer` with a short goal prompt — the SubagentStart hook auto-injects the full dispatch packet.
6. Read every file listed in the task's Files field before modifying them.
7. If legitimate file discovery changes the active task's Files field, update the artifact first, then run `sdd task scope-refresh {{FEATURE}} T-xxx`.
8. Implement using TDD when applicable — red → green → refactor. Normal TDD usually stays inside one implementation task.
9. Run the task's verification command. It must pass before marking complete.
10. Mark task complete: `sdd task complete {{FEATURE}} T-xxx`
11. Update `.features/{{FEATURE}}/scratchpad.md` with what was done and learned.
12. Repeat from step 3 for the next task.

## Scope discipline

- **One task at a time, in order.** Never jump ahead.
- Before editing any file, verify it is listed in the active task's scope.
- If you expand an in-progress task's Files field, run `sdd task scope-refresh {{FEATURE}} T-xxx` before editing the newly covered file.
- If task intent or scope is ambiguous, state the assumption and clarify before editing; do not guess silently.
- If a change feels necessary but isn't in the task: check existing tasks, update the plan, or decline. Never silently expand scope.
- If the user says "while you're at it" or "just a small tweak": stop. Map it to a task first.
- Keep diffs surgical — do not clean adjacent code unless your change made it obsolete.

## Scratchpad cadence

- Update `.features/{{FEATURE}}/scratchpad.md` every 3–5 tool calls.
- Record: what was done, what was learned, any open questions, any scope risks.
- This is the session continuity record — future sessions depend on it.
- Before ending an implement-phase session, append decisions to `.features/<id>/continuity.md` `## Key Decisions` and reasoning state to `## Reasoning State`.

## Strategy

- Use TDD (write failing test first) for any non-trivial logic.
- Keep normal red → green → refactor work in one task when possible. If the task is explicitly a red-test-only task, its Verification should pass when the expected failure is observed; the dependent implementation task owns the final green suite.
- Prefer the simplest implementation that satisfies the task's ACs.
- If a task's verification command fails, diagnose root cause — do not mark complete.
- Treat verification as the definition of done, not a follow-up step.
- If the verification command fails with "No such file or directory" or "command not found", the task implementation is incomplete — creating or wiring that resource is part of the task, not a pre-condition. Fix before marking complete.
- If a new file is discovered during implementation, add it to research.md.

## The Iron Law of Task Verification

A TASK'S VERIFICATION COMMAND MUST DEPEND ON THIS TASK'S STATUS — FAIL BEFORE THE TASK IS DONE, PASS AFTER.

If the command's exit code is the same whether or not this task is done, it doesn't verify the task. It answers a different question, leaving the actual completion claim unproven.

Expected-failure probes are diagnostics, not completion gates by themselves. For a red-test-only task, wrap the probe so the Verification command exits 0 when the expected failure is observed and exits non-zero when the probe unexpectedly passes or fails for the wrong reason.

If your verification mixes a new-behavior probe with a regression baseline — whether via `&&`, multiple test invocations, a combined test runner, a CI step, or any other chaining mechanism — separate them. The regression baseline belongs in a separate task, a final integration task, or a shared test suite, where it can fail honestly without blocking individual completion.

## Artifacts to read

- `.features/{{FEATURE}}/tasks.md` — the authoritative task list. Read before every session.
- `.features/{{FEATURE}}/research.md` — file locations and patterns to follow.
- `.features/{{FEATURE}}/scratchpad.md` — previous session state.

## Maintenance

- Update task status in `.features/{{FEATURE}}/tasks.md` (pending → in-progress → completed).
- Update `.features/{{FEATURE}}/scratchpad.md` after each task.
- Update `.features/{{FEATURE}}/research.md` if new files/patterns discovered.
- Keep `.features/<id>/continuity.md` current outside the auto-managed `## State` fence whenever decisions, assumptions, blockers, or verification targets change.

## Exit criteria

All tasks in `.features/{{FEATURE}}/tasks.md` have `status: completed`.
