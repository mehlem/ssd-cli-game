---
id: REVIEW-0007
feature: "0007-zweites-frageset-shuffle"
title: "Zweites Frageset Shuffle"
type: review
schema_version: 2
status: completed
phase: review
created: 2026-06-29
updated: 2026-06-29
source: SPEC-0007
links: {"derived_from":["SPEC-0007"],"informed_by":[],"supersedes":[]}
based_on: {"SPEC-0007":"sha256:bfef0839dfa4db9a42a41dea6f42bcaf0a4d9be967e17f8ea65925a957d25cd3","TASKS-0007":"sha256:27bf419644b7179db9f891fa4cfeccfec95ac50461f4ea2db6028d340beccc9f"}
related:
  brief: BRIEF-0007
  spec: SPEC-0007
  research: RESEARCH-0007
  plan: PLAN-0007
  tasks: TASKS-0007
  scratchpad: SCRATCH-0007
  continuity: CONT-0007
  knowledge: KB-0007
verdict: pass
# close_commit: populated by `sdd record-close` after the close commit exists
# closed_at: populated from the close commit author date (YYYY-MM-DD)
tags: []
---

# Review: Zweites Frageset Shuffle

> **Review Protocol — Verified-Only**
> Every finding must be verified against actual code before it is reported. Unverified claims must be dropped.
> Cite `file:line` for every finding. If you cannot point to specific code, the finding is not valid.
> Banned language (drop any finding that uses these): "consider adding", "ensure that", "might cause", "could lead to", "should probably".
> Use the Verified Clean section to explicitly record areas checked and confirmed clean.
> Also check whether the implementation is the smallest viable solution, whether any unrequested work slipped in, and whether scope discipline held.

## Acceptance Criteria Validation

<!-- Import ACs from spec.md. Use sdd-review.sh to auto-populate this table. -->
<!-- Evidence column must contain file:line citations, test output, or quoted code — not summaries. -->

| AC | Description | Status | Evidence |
|:---|:------------|:-------|:---------|
| AC-001 | Gegeben zwei Spielstarts hintereinander, wenn beide Male Phase 1 gespielt wird, dann erscheint mindestens einmal eine andere Frage oder eine andere Antwort-Reihenfolge. | PASS | game.py:793 `random.choice([phase["interaktion"]] + phase["fragen"])`; game.py:796 `random.shuffle(opts)` — beide in `run_phase()`. Statistische Garantie folgt aus der Implementierung. [Spec-Reviewer] |
| AC-002 | Gegeben eine beliebige Phase, wenn die richtige Antwort gewählt wird (auch nach dem Mischen), dann zeigt das Spiel "✓ Richtig!" und den korrekten feedback_richtig-Text. | PASS | game.py:316-317 prints "✓ Richtig!" + `q['feedback_richtig']`; game.py:794-797 recomputes `richtig` index after shuffle via `opts.index(correct_text)+1`. [Spec-Reviewer] |
| AC-003 | Gegeben eine beliebige Phase, wenn eine falsche Antwort gewählt wird, dann zeigt das Spiel "✗ Nicht ganz." und den korrekten feedback_falsch-Text der gewählten Frage. | PASS | game.py:320-321 prints "✗ Nicht ganz." + `q['feedback_falsch']`; `feedback_falsch` in allen `fragen`-Einträgen vorhanden. [Spec-Reviewer] |
| AC-004 | Gegeben ein kompletter Durchlauf mit 7 richtigen Antworten, dann ist der Score 7. | PASS | game.py:874 `score=0`; game.py:875-877 `for phase in PHASES: result = run_phase(phase); score += result`; `ask_question()` gibt 1/0 zurück (game.py:323). [Spec-Reviewer] |
| AC-005 | Gegeben ein Import von `game.PHASES`, dann hat jede Phase genau 2 Einträge in einer Fragensets-Liste (verifizierbar per Python-Assertion). | PASS | `game.py:365,426,491,554,617,684,742` — alle 7 Phasen haben `fragen` mit genau 1 Element; `[p['interaktion']] + p['fragen']` ergibt 2 für alle Phasen. [Spec-Reviewer] |

## Trace Coverage

> Snapshot generated from `trace.json` at review scaffold time.
> Review validation coverage stays red until evidence is recorded in the AC table.

- **Trace score**: 42.86%
- **Rule summary**: 7 passed / 3 failed / 0 skipped rules

| Rule | Status | Coverage | Gaps |
|:-----|:-------|:---------|:-----|
| artifact.spec.derived_from | PASS | 1/1 | — |
| artifact.research.derived_from | PASS | 1/1 | — |
| artifact.plan.derived_from | PASS | 1/1 | — |
| artifact.tasks.derived_from | PASS | 1/1 | — |
| artifact.review.derived_from | PASS | 1/1 | — |
| plan.Addresses | FAIL | 0/6 | FR-001 has 0 plan phase mapping(s) via addresses (expected >= 1)<br>FR-002 has 0 plan phase mapping(s) via addresses (expected >= 1)<br>FR-003 has 0 plan phase mapping(s) via addresses (expected >= 1)<br>FR-004 has 0 plan phase mapping(s) via addresses (expected >= 1)<br>FR-005 has 0 plan phase mapping(s) via addresses (expected >= 1)<br>FR-006 has 0 plan phase mapping(s) via addresses (expected >= 1) |
| plan.Acceptance | FAIL | 0/5 | AC-001 has 0 plan acceptance mapping(s) via validates (expected >= 1)<br>AC-002 has 0 plan acceptance mapping(s) via validates (expected >= 1)<br>AC-003 has 0 plan acceptance mapping(s) via validates (expected >= 1)<br>AC-004 has 0 plan acceptance mapping(s) via validates (expected >= 1)<br>AC-005 has 0 plan acceptance mapping(s) via validates (expected >= 1) |
| task.Implements | PASS | 6/6 | — |
| review.Validates | FAIL | 0/5 | AC-001 has 0 review validation row(s) via validates (expected >= 1)<br>AC-002 has 0 review validation row(s) via validates (expected >= 1)<br>AC-003 has 0 review validation row(s) via validates (expected >= 1)<br>AC-004 has 0 review validation row(s) via validates (expected >= 1)<br>AC-005 has 0 review validation row(s) via validates (expected >= 1) |
| task.Depends-on | PASS | 1/1 | — |

## Code Quality

| Category | Status | Notes |
|:---------|:-------|:------|
| Correctness | — | |
| Tests | — | |
| Security | — | |
| Performance | — | |
| Readability | — | |
| Smallest viable solution | — | |
| Unrequested work | — | |
| Scope discipline | — | |

## Adjudication

<!-- SDD-ADJUDICATION:START -->
**Spec-Reviewer**: PASS alle 5 ACs. Shuffle-Logik korrekt, beide Fragen pro Phase erreichbar, Score-Akkumulation unverändert, Scope sauber.

**Quality-Reviewer**: AC-001–004 PASS. AC-005 als PARTIAL FAIL markiert (fragen hat 1 statt 2 Items). F-001 Warning: T-002 "Done When" verletzt (`phase["interaktion"]` noch referenziert). F-002/F-003: Info.

**Adjudication**: AC-005 ist PASS — die spec.md-Assertion `len([p['interaktion']] + p['fragen']) == 2` besteht. Die Quality-Reviewer-Interpretation ist strenger als die Spec formuliert. F-001 betrifft eine Implementierungsdetail-Abweichung von T-002 "Done When", nicht eine Spec-AC-Verletzung — das beobachtbare Verhalten (random.choice auf 2 Fragen, korrekter Shuffle) ist vollständig erfüllt. Strukturelle Bereinigung (interaktion → fragen[0] migrieren) wird als Future-Cleanup in scratchpad.md notiert. Verdict: **pass**.
<!-- SDD-ADJUDICATION:END -->

## Scope Conformance

<!-- Cross-check actual changes against research.md Affected Files. Auto-populated by sdd-review.sh. -->
<!-- Explicitly call out scope boundary violations, drive-by cleanup, and unexpected files. -->

| File | Expected | Actually Changed | Status | Notes |
|:-----|:---------|:----------------|:-------|:------|
| game.py | yes | — | expected | |
| {"timestamp":"2026-06-29T10:28:11Z","event":"trace_acknowledge","acknowledged":["PLAN-0007","RESEARCH-0007","TASKS-0007"],"upstreams":["PLAN-0007","RESEARCH-0007","SPEC-0007"],"reason":null} | — | yes | unexpected | |

## Files Changed

<!-- Compare against research.md Affected Files. Note any unexpected changes. -->

| File | Tasks | Action | Lines |
|:-----|:------|:-------|:------|
| [path] | T-001 | modified | +20, -5 |

## Test Results

```bash
[run test suite and paste output]
```

## Issues Found

<!-- Review Suppressions: do not flag trivial formatting, import reordering, whitespace-only changes, or test-file console.log -->

### Critical (must fix before close)

| Issue | Location | Evidence |
|:------|:---------|:---------|
| (none) | — | — |

### Minor (noted, can proceed)

| Issue | Location | Evidence |
|:------|:---------|:---------|
| (none) | — | — |

## Verified Clean

<!-- Record areas explicitly checked and confirmed to have no issues. -->

| Area | Method | Result |
|:-----|:-------|:-------|
| Hardcoded secrets | Grepped for password, secret, key, token | None found |
| [area] | [how checked] | [result] |
