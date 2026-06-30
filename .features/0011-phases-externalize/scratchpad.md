---
id: SCRATCH-0011
feature: "0011-phases-externalize"
title: "Phases Externalize"
type: scratchpad

## Implementierungsnotizen

- T-001: AST-basierte Extraktion via `ast.literal_eval()` war zuverlässiger als direkter Import, da game.py ANSI-Sequenzen und `os.system()` auf Modulebene hat.
- T-002: F-String mit `\n` (Literal-Zeilenumbruch) wirft SyntaxError — auf einzeiligen String umgestellt.
- scope-refresh für T-002 musste zweimal ausgeführt werden (einmal nach erstem Edit, einmal nach Korrektur).
- game.py: 43215 → 17837 Zeichen nach Umbau (-58 %)
schema_version: 2
status: active
created: 2026-06-30
updated: 2026-06-30
related:
  brief: BRIEF-0011
  spec: SPEC-0011
  research: RESEARCH-0011
  plan: PLAN-0011
  tasks: TASKS-0011
  review: REVIEW-0011
  continuity: CONT-0011
  knowledge: KB-0011
tags: []
---

# Scratchpad: Phases Externalize

## Observations

- [2026-06-30] Feature initialized — entering Brief phase

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

## Open Questions

<!-- Quick-capture questions during work -->
