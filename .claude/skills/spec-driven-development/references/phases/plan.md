# Plan Phase Guide

**Goal:** Decide HOW to build it, then break into executable tasks.
**Produces:** `.features/{{FEATURE}}/plan.md`, then `.features/{{FEATURE}}/tasks.md` | **Gate:** No production code.

## Phase Entry Contract

Invoke `/sdd-plan` before editing `plan.md` or `tasks.md`, or before running a
protected boundary command that exits Plan. Direct reads of this phase
reference, `SKILL.md`, `plan.md`, or `tasks.md` do not satisfy the routing
latch. The latch proves the agent routed through Plan guidance; it does not
prove artifact correctness.

`sdd plan create-tasks` scaffolds `tasks.md`; it does not by itself make the
feature ready for Implement. Keep using Plan guidance while authoring
`tasks.md` until it has substantive `## Approach` content and concrete task
headings. Task lifecycle execution (`sdd task next/start/complete`) belongs to
Implement after that readiness boundary.

## The Iron Law of Task Authoring

**NO TASK WITHOUT A RUNNABLE VERIFICATION COMMAND THAT PROVES BEHAVIOR.**

A verification command that always passes proves nothing. A verification that depends on a future task's output is not runnable at completion. Either failure makes the task unverifiable — and an unverifiable task cannot be marked complete without lying. (See also `## The Iron Law of Task Verification` in `implement.md` for the authoring-quality companion rule.)

If you find yourself writing "manually verify" or a command that only checks file existence without testing behavior, that's a sign the task is not yet atomic enough — refine it until you can express the correct outcome as a runnable command.

### Anti-patterns

- **"Let me add flexibility for future use cases."** Speculative abstraction. Plan for the FRs you have, not the FRs you imagine. One use-case, one function. If a future requirement materializes, plan for it then with real evidence.

## Process

First-entry autonomy check: if `.features/{{FEATURE}}/state.json` has `autonomous: null`, ask once whether to enable autonomous mode and record via `sdd autonomy on {{FEATURE}}` or `sdd autonomy off {{FEATURE}}`.
### plan.md
1. Read `.features/{{FEATURE}}/research.md` — use it as the foundation for all decisions.
2. Make Architectural Decisions (AD-xxx) — one per significant design choice, with rationale grounded in confirmed Research facts or explicitly named assumptions.
3. Define Vertical Slices (PH-xx) — each phase is end-to-end, independently demoable.
4. Each PH-xx references the FRs it implements.
5. Identify Risks & Mitigations from research.md concerns.
6. **Present phases to user. Ask: "Does the granularity feel right?" Iterate until approved.**

### tasks.md
7. Break each PH-xx into atomic tasks (T-xxx).
8. Each task: references its phase + FR, lists files, has ACs and a verification command.
9. Set each task status to `pending`.
10. Fill `## Approach` with the concrete implementation strategy. A placeholder
    or scaffold-only Approach keeps the feature in Plan task-authoring mode.

## Strategy

- Vertical slices beat horizontal layers — each slice should work end-to-end.
- Use confirmed Research facts for decisions, risks, task boundaries, and
  verification quality. If the evidence is a hypothesis or unknown, name that
  explicitly instead of treating it as settled.
- Prefer the smallest viable design that satisfies today's FRs before adding abstraction.
- Tasks must be small enough to complete in one session; if not, split them.
- Verification commands must be runnable — no "manually verify" without a script.
- A verification command must be fully executable at task completion. Every script it runs, subcommand it calls, or resource it reads must exist before the task starts OR be produced by this task's own implementation. Never write a verification that depends on work done by a future task.
- A verification command must prove the task's actual outcome — not a superficial proxy. A command that passes whether or not the implementation is correct is not a verification. `test -f file.sh` proves existence; it does not prove behavior. A valid verification fails when the implementation is broken.
- Prefer keeping normal TDD inside one implementation task: write the failing probe, make it green, refactor, then run the task Verification command.
- A red-test-only task is exceptional. Use it only when the red artifact is itself a useful deliverable; its Verification must prove the expected failure evidence and must not depend on a future implementation task's green suite.
- Verification for mutating SDD lifecycle commands must use a disposable fixture, not the active feature or real git repository.
- If multiple tasks share a resource (e.g., a growing test suite), every modifier task must declare the creator task in `Depends-on`. The creator task bootstraps the resource; later tasks extend it.
- If a task's file list comes from research.md Affected Files, cross-check it.
- For 15+ tasks or independent subsystems, consider Work Packages (wp-NN-name/).
- If you choose a larger abstraction, record why the simpler option is insufficient now rather than future-proofing by default.

## Artifacts to read

- `.features/{{FEATURE}}/research.md` — required. Affected Files table drives task file lists.
- `.features/{{FEATURE}}/spec.md` — every FR must be addressed by at least one task.
- `.features/{{FEATURE}}/brief.md` — constraints may eliminate or modify approaches.

## Maintenance

- Update `.features/{{FEATURE}}/plan.md` if user feedback changes phases.
- Update `.features/{{FEATURE}}/tasks.md` status fields as work progresses.
- Update `.features/{{FEATURE}}/scratchpad.md` with planning decisions.

## Exit criteria

Both `plan.md` and an execution-ready `tasks.md` exist. `tasks.md` has
substantive `## Approach` content, concrete task headings, and every FR from
spec.md is addressed by at least one task.
