# Brief Phase Guide

**Goal:** Understand WHY this feature needs to exist before writing any engineering artifacts.
**Produces:** `.features/{{FEATURE}}/brief.md` | **Gate:** No code, no spec, no design.

## Phase Entry Contract

Invoke `/sdd-brief` before editing `brief.md` or running a protected boundary
command that exits Brief. Direct reads of this phase reference, `SKILL.md`, or
`brief.md` do not satisfy the routing latch. The latch proves the agent routed
through Brief guidance; it does not prove artifact correctness.

## The Iron Law of Brief

**NO DESIGN, RESEARCH, OR CODE QUESTIONS IN THE BRIEF PHASE.**

The Brief phase extracts motivation and intent — not architecture, not implementation. Questions about which files to touch, how data flows, or what the schema looks like jump phases and waste the user's time on things the codebase will answer for free in Research.

If you find yourself drafting a question about how the feature will be built, that's a sign you're ahead of the phase — defer it to Research or Plan and return to *why this needs to exist* and *what success looks like*.

## Process

1. Check `.features/{{FEATURE}}/` — does brief.md already exist? If yes, read it first.
2. **Step 1 — gather context.** Before your first user-facing message, inspect: `CLAUDE.md`, `.features/INDEX.md`, recent feature briefs, and 1–2 scoped repo files relevant to the feature name. Don't ask before inspecting.
3. **Step 2 — propose, don't only ask.** When intent is clear enough to suggest, present a recommended approach or 2–3 options and ask the user to confirm/redirect. Reserve open questions for cases where neither inspection nor reasoning narrows the answer.
4. **Step 3 — draft inferable sections.** Problem, Context, and Constraints can usually be inferred from `CLAUDE.md`, project conventions, related features, and the user's intent statement. Draft them — and **label inferred content with source** (e.g., `<!-- inferred from CLAUDE.md -->`). Do not fabricate.
5. Ask only **intent-level questions** — the kind that surface Motivation and Vision. **Forbidden question types:**
   - Research/plan-phase questions (what files to touch, what data flows look like — those belong in `sdd research`)
   - Code-logic questions (how the feature is implemented — those belong in `sdd plan`)
   - Inspectable questions (anything `CLAUDE.md`, `INDEX.md`, or scoped repo files would answer)
6. **Soft cap ~3 questions.** Each question MUST come paired with a `**Recommended**:` line carrying a proposed answer or idea. Beyond the cap, draft and confirm rather than continuing to interview.
7. Continue until intent is clear enough to write spec.md (typically 1–3 questions, or zero if intent was already explicit).
8. Write brief.md capturing the Q&A conversation and any inferred-section labels with all required sections.
9. Once intent is locked: summarize shared understanding and confirm direction before proceeding.

## Strategy

- **Inspect before asking — every answerable question must be unasked.**
- **Propose first, ask second.** Lead with a recommendation or option set; questions are a fallback.
- **Each question carries a recommendation.** No exceptions — the user should always be able to confirm/redirect quickly.
- Surface competing interpretations explicitly — if ambiguity changes scope or behavior, do not pick silently.
- If the user's latest message already resolves the next branch, summarize and update instead of asking again.
- All 5 sections (Motivation, Problem, Vision, Context, Constraints) are required — but Problem, Context, and Constraints are usually fillable by interpretation from the intent-level Q&A + repo inspection. Do not ask one question per section.

## Artifacts to read

- `.features/{{FEATURE}}/brief.md` — if it exists, orient from it before asking anything.
- `CLAUDE.md` / project root — understand existing conventions and context.
- `.features/INDEX.md` — recent features for related work and naming conventions.

## Maintenance

- Update `.features/{{FEATURE}}/brief.md` after each significant answer.
- Add each question + answer to the Q&A Record section. Record the `**Recommended**:` line you proposed.
- Update `.features/{{FEATURE}}/scratchpad.md` with timestamped observations.

## brief.md required sections

All 5 are required for the gate. Problem, Context, and Constraints may be filled by interpretation (with source labels) when not explicitly user-stated.

- **Motivation** — WHY this exists *(intent-level — usually requires a question)*
- **Problem** — WHO has it, what is their experience *(often inferable from Motivation + repo)*
- **Vision** — What success looks like *(intent-level — usually requires a question)*
- **Context** — Stakeholders, urgency, prior attempts *(usually inferable from `CLAUDE.md`, INDEX, related features)*
- **Constraints** — Non-negotiables *(usually inferable from `CLAUDE.md` + repo conventions)*
- **Q&A Record** — Each question with `**Recommended**:` + actual answer

## Exit criteria

`brief.md` exists with all 5 sections substantively filled — by interpretation (with `<!-- inferred from <source> -->` labels) where not user-stated. User's intent is clear enough to translate into requirements. If autonomy is off or null, summarize shared understanding and get user confirmation before moving to spec. If autonomy is on, advance directly with `sdd spec {{FEATURE}}`.

At brief completion, ask: "Run remaining phases autonomously? Halts only on listed blockers." Record yes with `sdd autonomy on {{FEATURE}}`, no with `sdd autonomy off {{FEATURE}}`.
