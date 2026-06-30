# Autonomous Halt Criteria

Autonomous mode removes routine phase-boundary approval prompts after Brief. It does not remove gates. Halt immediately on any hard halt below, and use the soft halt only when the question cannot be answered from existing artifacts or codebase reads.

Null state: `autonomous: null` is treated as off until set; the autonomy question fires once at brief completion (see `references/phases/brief.md`).

## Hard Halts

1. **Suspect artifacts**
   - Signal: `trace.suspect_artifacts > 0` from `state.json` / `sdd_trace_suspect_summary_json`.
   - Halt because downstream artifacts may be stale.

2. **Repeated tool failure**
   - Signal: the same tool target fails twice in succession via `session_flags.last_tool_failure`.
   - Halt because retrying the same failing operation is no longer informative.

3. **Repeated verification failure**
   - Signal: the same task verification command fails on its second consecutive run.
   - Halt because task completion evidence is not trustworthy yet.

## Soft Halt

Halt for intent ambiguity only when the open question changes behavior, scope, or verification and cannot be answered by reading `brief.md`, `spec.md`, `research.md`, `plan.md`, `tasks.md`, or the relevant code. Before halting, restate the exact question and explain why the artifacts/codebase do not answer it.
Do not soft-halt for routine phase approval, implementation sequencing, or questions answered by existing artifacts.

`self_review_without_dispatch`: in review phase, halt or soft-block when non-trivial autonomous work has a passing self-review but no recorded `sdd-spec-reviewer` and `sdd-quality-reviewer` result files. The remediation is to dispatch reviewers, or explicitly accept self-review with `sdd autonomy --self-reviewed <feature>`.

Subagent dispatch is non-interactive under autonomy mode — autonomy means no per-phase user confirmation, not no tool calls. Reviewers should be dispatched without halting unless their findings require a user decision.

## Message Format

Use this form exactly:

```text
SDD autonomous halt: <one-line reason>.
Uncertain: <what is unclear>.
Inspect: <which artifact/path>.
Next: <concrete user action to unblock>.
Avoid: <failure mode of pushing through>.
```

## Auto-Resume

This is the autonomous auto-resume contract.
When the user resolves a halt, resume without asking for a separate continue command. Start with one line:

```text
Got it — proceeding with X based on Y. Halts still active.
```

That line must restate the resolved blocker and the basis for the decision. Then continue from the current phase/task with the same halt criteria active.
