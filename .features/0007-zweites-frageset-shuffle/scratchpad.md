---
id: SCRATCH-0007
feature: "0007-zweites-frageset-shuffle"
title: "Zweites Frageset Shuffle"
type: scratchpad
schema_version: 2
status: active
created: 2026-06-29
updated: 2026-06-29
related:
  brief: BRIEF-0007
  spec: SPEC-0007
  research: RESEARCH-0007
  plan: PLAN-0007
  tasks: TASKS-0007
  review: REVIEW-0007
  continuity: CONT-0007
  knowledge: KB-0007
tags: []
---

# Scratchpad: Zweites Frageset Shuffle

## Observations

- [2026-06-29] Feature initialized — entering Brief phase

## Progress Notes

<!-- Informal tracking alongside formal tasks.md -->

## Reasoning State

### Active Assumptions

<!-- Working assumptions discovered during execution -->

### Open Ambiguity

<!-- Ambiguities to resolve before making more changes -->

### Current Blocker

<!-- The concrete blocker slowing or stopping execution right now -->

### Next Verification Target

<!-- The next verification command, evidence check, or acceptance target -->

### Active Scope Boundary

<!-- What this task should and should not touch while implementation is active -->

## Ideas & Alternatives

<!-- Approaches considered, design alternatives, what-ifs -->

## Findings → Knowledge

<!-- Facts worth graduating to KNOWLEDGE.md. Prefix with → KNOWLEDGE when ready. -->

→ KNOWLEDGE: `ask_question()` nutzt `q["richtig"]` als 1-basierten Positions-String. Beim Shuffle: `correct_text` VOR dem Shuffle merken, dann `str(shuffled_opts.index(correct_text) + 1)` als neues `richtig` setzen. Funktioniert nur wenn alle Antworttexte eindeutig sind (was in allen 14 Fragen von 0007 zutrifft).

→ KNOWLEDGE (Future Cleanup 0007): `fragen` enthält nur das zweite interaktion-Dict (1 Element); `run_phase()` kombiniert `[phase["interaktion"]] + phase["fragen"]`. Plan.md AD-001 sah vollständige Migration `interaktion` → `fragen[0]` vor — aufgeschoben. Ein Folge-Feature kann `interaktion` aus PHASES-Dicts entfernen und `fragen` auf 2 Einträge erweitern.

## Open Questions

<!-- Quick-capture questions during work -->

- [2026-06-29T12:33:49] Verification FAILED for T-002 (exit 1). Evidence captured at .features/0007-zweites-frageset-shuffle/verification/T-002.json.
