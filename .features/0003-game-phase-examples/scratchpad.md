---
id: SCRATCH-0003
feature: "0003-game-phase-examples"
title: "Game Phase Examples"
type: scratchpad
schema_version: 2
status: active
created: 2026-06-26
updated: 2026-06-26
related:
  brief: BRIEF-0003
  spec: SPEC-0003
  research: RESEARCH-0003
  plan: PLAN-0003
  tasks: TASKS-0003
  review: REVIEW-0003
  continuity: CONT-0003
  knowledge: KB-0003
tags: []
---

# Scratchpad: Game Phase Examples

## Observations

- [2026-06-26] Feature initialized — entering Brief phase

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

### Out of Scope (Future Feature)

- **CLI vs. Skill Verwechslung erklären**: Fast alle Phasen haben einen gleichnamigen CLI-Befehl (`sdd spec`) UND einen Skill (`/sdd-spec`) — unterschiedliche Dinge. Ein künftiges Feature könnte einen Hilfe-Screen oder eine Einleitung ergänzen, die diesen Unterschied erklärt. Bewusst aus 0003 herausgehalten, um die 4-zeiligen Panels kompakt zu halten.

## Findings → Knowledge

<!-- Facts worth graduating to KNOWLEDGE.md. Prefix with → KNOWLEDGE when ready. -->

→ KNOWLEDGE: `ask_question()` in game.py endet bereits mit `pause()`. Jeder zusätzliche `pause()`-Aufruf im aufrufenden Code (z.B. in `run_phase()`) erzeugt einen doppelten Enter-Druck. Beim Erweitern von `run_phase()` sicherstellen, dass kein zweiter `pause()` nach `ask_question()` steht.

→ KNOWLEDGE (Future Feature): CLI-Befehl (`sdd spec`) und Skill (`/sdd-spec`) heißen fast gleich aber sind unterschiedliche Dinge — könnte Einsteiger verwirren. Idee für eigenes Feature: Hilfe-Screen oder Einleitung die diesen Unterschied erklärt.

## Open Questions

<!-- Quick-capture questions during work -->
