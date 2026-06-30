# SDD CLI Game: Interactive Learning Mode

## Problem

Feature 0001 produced a playable CLI game that walked users through the 7 SDD phases — but every phase ended with "press Enter to continue." Players read descriptions, made no decisions, encountered no consequences, and received no feedback. As brief.md states: the game was an interactive documentation, not a learning game. The onboarding goal — internalizing the SDD mindset — was not reached because the game produced no cognitive activation.

## Solution

Each of the 7 SDD phases received exactly one interactive element: a multiple-choice question, a decision situation, or a PASS/FAIL judgment question. Every answer — right or wrong — triggers immediate feedback that names a concrete SDD principle. Wrong answers explain why they are wrong; right answers explain why they are right. The linear game flow from 0001 was preserved. A score is accumulated across all 7 phases and shown in the final summary screen.

The implementation extended `game.py` from 0001 without rewriting it. A new `ask_question(q)` function handles all interaction types via a type-dispatch on a `typ` field. Each PHASES dict received a fifth key, `interaktion`, containing the question, options, correct answer, and two feedback strings.

The review passed all 8 acceptance criteria. Verdict: **PASS**.

## Key Decisions

**AD-001 — `interaktion` field embedded in PHASES dicts, not a separate list.**
Each phase dict received a fifth key `interaktion: dict` rather than a parallel `INTERACTIONS` list. The rejected alternative — a separate list indexed in parallel — was considered and dropped because parallel indexing is error-prone and severs phase data from its interaction content.

**AD-002 — Single `ask_question(q)` function with type dispatch.**
Rather than inlining interaction logic inside `run_phase()` (which would have made that function too large), a dedicated `ask_question(q)` function was introduced. It reads `q['typ']` (`"mc"`, `"passfail"`, `"order"`) and executes the corresponding mechanic. This keeps `run_phase()` unchanged in structure and makes `ask_question()` independently verifiable.

**AD-003 — `richtig` field stored as string, not numeric index.**
The correct-answer field stores the string value of the correct option (e.g., `"1"`) rather than an integer index. The rejected alternative — a numeric index — was dropped because `input().strip()` returns a string, and string-to-string comparison is more robust and avoids an unnecessary type conversion.

**AD-004 — Score accumulated in `main()` via `run_phase()` return value.**
`run_phase()` was changed from `-> None` to `-> int`, returning the result of `ask_question()`. `main()` accumulates with `score += run_phase(phase)`. A score object was considered and rejected as overkill for 7 rounds.

**AD-005 — Markdown-vs-JSON question placed in Design phase, not Brief phase.**
The spec allowed either Brief or Design for this question. Design was chosen because that phase defines WHAT — including how artifacts are documented. Brief covers WHY (problem definition); the artifact format question fits better in the phase that defines the output format of the workflow.

## Outcome

All 8 acceptance criteria passed in review:

- Every phase has exactly one interaction (AC-003: 7 PHASES entries, each with one `interaktion` key at `game.py:218-448`)
- Brief-phase MC question names `brief.md` and lists all 5 required sections (AC-001: `game.py:224-246`)
- Design-phase question contains "Markdown", "JSON", and "XML" (AC-002: `game.py:255-258`)
- All 7 `feedback_falsch` strings begin with "In SDD gilt:" (AC-004)
- All 7 `feedback_richtig` strings begin with "In SDD gilt:" (AC-005)
- Wrong answers do not block progression (AC-006)
- Summary shows `"Dein Score: {score} von {total} Fragen richtig"` (AC-007: `show_summary:482`)
- Only Python stdlib imports (AC-008: `game.py:6-10`)

Two minor findings were identified and fixed before the verdict was set: a `_SKELETON` dead-code block was removed, and a bare `open()` call was corrected. No critical issues remained.

One informal observation from the review: FR-003 (AC judgment question) ended up in the Review phase instead of the Design phase. No acceptance criterion enforced a specific phase for this question, so the controller adjudicated this as informally noted, not a violation.

## Lessons Learned

The scratchpad and knowledge.md for this feature contain no graduated entries — they were initialized but not populated during the run. The review record captures the two concrete implementation fixes (dead-code removal, bare `open()` correction) that emerged during quality review. Beyond those, the research artifact's confidence score of 94/100 reflected accurate scope clarity: the implementation touched exactly the files and functions identified upfront, with no surprises.

The risk identified in RISK-003 — that authoring 7 interaktion dicts with consistent schemas is error-prone — was mitigated by task-level schema verification commands that check all required fields across all 7 dicts in a single `py -c` invocation.

## Further Reading

- [DOCS.md](DOCS.md) — Technical reference: components, interface changes, verification commands, known limitations
- [brief.md](brief.md) — Problem statement, motivation, vision, and Q&A record
- [spec.md](spec.md) — Full functional requirements, acceptance criteria, non-goals, constraints
- [research.md](research.md) — Affected files, confirmed facts about `game.py`, system context diagram, risks
- [plan.md](plan.md) — Architectural decisions (AD-001 to AD-005), implementation phases
- [tasks.md](tasks.md) — Task breakdown (T-001 to T-005) with verification commands per task
- [review.md](review.md) — AC validation table with file:line evidence, adjudication, verdict
