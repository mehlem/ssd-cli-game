---
id: SPEC-0006
feature: "0006-projekt-rename"
title: "Projekt Rename"
type: spec
schema_version: 2
profile: lite
status: completed
phase: spec
created: 2026-06-29
updated: 2026-06-29
related:
  tasks: TASKS-0006
  review: REVIEW-0006
tags: []
---

# Spec: Projekt Rename

## Problem

`game.py` nennt das Beispielprojekt an 6 Stellen "SmartFlow" bzw. "smart-flow". In der Einleitung heißt das Projekt bereits "PromptAndPray good vibes 2.0". Die Inkonsistenz verwirrt Spieler.

## Solution

Alle 6 Vorkommen von "SmartFlow" und "smart-flow" in `game.py` werden durch "PromptAndPray" bzw. "promptandpray" ersetzt.

## User Stories

- US-01: Als Spieler möchte ich durchgängig denselben Projektnamen sehen, damit das Spiel konsistent wirkt.

## Functional Requirements

- FR-001: `game.py` enthält nach der Änderung keinen Treffer mehr für "SmartFlow" oder "smart-flow" (case-insensitive).

## Acceptance Criteria

- [ ] AC-001: `grep -i "smartflow\|smart-flow" game.py` gibt keine Treffer zurück.
- [ ] AC-002: `grep -i "promptandpray" game.py` liefert mindestens 6 Treffer.

## Non-Goals

- Keine Änderung an anderen Textstellen, Logik oder Struktur.
- "PromptAndPray good vibes 2.0" in Zeile 219 bleibt unverändert — das ist bereits korrekt.

## Constraints

- Nur `game.py` wird geändert.
