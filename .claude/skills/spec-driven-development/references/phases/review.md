# Review Phase Guide

**Goal:** Verify the feature meets its spec — AC by AC, with evidence.
**Produces:** `.features/{{FEATURE}}/review.md` | **Gate:** No silent continued implementation; record findings first.

## Phase Entry Contract

Invoke `/sdd-review` before editing `review.md` or running a protected boundary
command from Review. Review routes to `/sdd-review`, never `/sdd-research`.
Direct reads of this phase reference, `SKILL.md`, or `review.md` do not satisfy
the routing latch. The latch proves the agent routed through Review guidance;
it does not prove review correctness.

## The Iron Law of Review

**NO REVIEW VERDICT WITHOUT READING SPEC BEFORE CODE AND EVIDENCE FOR EVERY AC.**

Reading code before spec creates confirmation bias — you verify what was built, not what was required. A verdict without per-AC evidence is an assertion, not a review. Self-review on non-trivial work inherits the implementer's blind spots by design; that's why independent dispatch is the rule for ≥3 ACs or ≥5 tasks (see Reviewer Dispatch Discipline below).

If you find yourself ready to set `verdict: pass` after reading the implementation but before checking each AC against the spec, that's a sign the order has flipped — start over from spec.md, form expectations from the ACs, then verify the code against those expectations.

### Anti-patterns

- **"Review can happen later."** Review is a phase, not optional cleanup. Deferring it is the #1 signal that drift is about to enter the trace. If review feels premature, the implementation is too — return to Implement until the ACs can be evaluated honestly.

## Process

First-entry autonomy check: if `.features/{{FEATURE}}/state.json` has `autonomous: null`, ask once whether to enable autonomous mode and record via `sdd autonomy on {{FEATURE}}` or `sdd autonomy off {{FEATURE}}`.
0. **Scaffold review.md** — run `sdd review <feature>` to create the artifact and auto-import ACs from spec.md.
1. **Read spec.md before reading any code.** Form expectations from ACs, then verify against implementation.
2. **Reviewer Dispatch Discipline:** dispatch sdd-spec-reviewer + sdd-quality-reviewer for independent verification before close; self-review only for trivial diffs (≤2 ACs and ≤2 tasks).
3. **Validate each AC** — for every AC-xxx in spec.md, record: PASS or FAIL with concrete evidence (file:line or test output).
4. **Compare Files Changed** against research.md Affected Files — flag unexpected additions or missing changes.
5. **Code quality check** — correctness, tests present, no security issues, reasonable performance, readable.
6. **Run the project test suite** — paste actual output as evidence.
7. **Set verdict** in review.md frontmatter: `pass` or `fail`.

## Reviewer Dispatch Discipline

Implementer self-review is the failure mode this phase exists to prevent. For non-trivial work, dispatch `sdd-spec-reviewer` for spec compliance and `sdd-quality-reviewer` for code quality before close; the SubagentStart hook auto-injects their dispatch packets.

Canonical rule: dispatch sdd-spec-reviewer + sdd-quality-reviewer for independent verification before close; self-review only for trivial diffs (≤2 ACs and ≤2 tasks).

Codex review-support imports are evidence only. They may surface useful findings
in adjudication support tables, but they do not satisfy the required
`sdd-spec-reviewer` / `sdd-quality-reviewer` dispatches and cannot set the
Review verdict by themselves.

Under autonomy mode, reviewer dispatch is non-interactive: autonomy means no per-phase user confirmation, not no tool calls. If deliberate self-review is necessary for a non-trivial feature, make the override explicit with `sdd autonomy --self-reviewed <feature>`.

## Handling failures

- **AC failure** → return to Implement. Create new tasks in tasks.md for each failing AC. Do not silently fix.
- **Critical quality issue** → record in review.md, fix immediately, re-verify.
- **Minor issue** → note in review.md, proceed to pass verdict if all ACs pass.
- **Never trust "I already tested it"** — ask what was tested and what the output was.
- **Never retry blindly** — if evidence is missing or a test fails, state what is uncertain and inspect the relevant output before deciding the next move.

## Strategy

- Read spec before code: form expectations first, verify second. Avoids confirmation bias.
- One AC at a time — don't batch-verify. Each needs individual evidence.
- Investigate before claiming — unread code and missing evidence are not findings.
- Flag unrequested work, overbuilding, and scope drift explicitly.
- If a test suite is slow, run targeted tests for affected modules first.
- Use subagents to run tests in parallel if multiple test suites exist.

## Artifacts to read

- `.features/{{FEATURE}}/spec.md` — required. Every AC must be evaluated.
- `.features/{{FEATURE}}/research.md` — expected file changes to cross-check.
- `.features/{{FEATURE}}/tasks.md` — confirm all tasks are completed before reviewing.

## Maintenance

- Populate `.features/{{FEATURE}}/review.md` with per-AC results as you go.
- Set `verdict: pass` or `verdict: fail` in frontmatter when done.
- Update `.features/{{FEATURE}}/scratchpad.md` with review findings.

## Exit criteria

`review.md` exists with `verdict: pass`. Every AC from spec.md is marked PASS with evidence.
