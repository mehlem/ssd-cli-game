---
id: SPEC-0005
feature: "0005-score-basierter-ausgang"
title: "Score Basierter Ausgang"
type: spec
schema_version: 2
profile: lite
status: completed
phase: spec
created: 2026-06-29
updated: 2026-06-29
related:
  tasks: TASKS-0005
  review: REVIEW-0005
tags: []
---

# Spec: Score Basierter Ausgang

## Problem

`show_summary()` zeigt immer denselben Erfolgstext ("Du hast das SmartFlow-Projekt gerettet."), unabhängig davon wie viele Fragen der Spieler richtig beantwortet hat. Bei niedrigem Score ist diese Aussage nicht zutreffend und motiviert nicht zur Wiederholung.

## Solution

`show_summary()` zeigt abhängig vom Score zwei unterschiedliche Texte: bei mehr als 6 richtigen Antworten den bisherigen Erfolgstext, bei 6 oder weniger einen ermutigenden Text der zur Wiederholung einlädt.

## User Stories

- US-01: Als Spieler mit 7/7 möchte ich den Erfolgstext sehen, damit mein Ergebnis gewürdigt wird.
- US-02: Als Spieler mit ≤6/7 möchte ich einen ermutigenden Text sehen, damit ich motiviert bleibe, das Spiel erneut zu spielen.

## Functional Requirements

- FR-001: Bei score > 6 zeigt `show_summary()` den bisherigen Erfolgstext ("Du hast das SmartFlow-Projekt gerettet. Jana nickt anerkennend.").
- FR-002: Bei score ≤ 6 zeigt `show_summary()` einen ermutigenden Text, der das SmartFlow-Projekt nennt und zur Wiederholung einlädt.
- FR-003: In beiden Pfaden werden Score und Sterne-Anzeige weiterhin angezeigt.
- FR-004: In beiden Pfaden wird die durchlaufene Phasenliste weiterhin angezeigt.

## Acceptance Criteria

- [ ] AC-001: Gegeben score=7, wenn show_summary(7, 7) aufgerufen wird, dann enthält die Ausgabe "Du hast das SmartFlow-Projekt gerettet".
- [ ] AC-002: Gegeben score=6, wenn show_summary(6, 7) aufgerufen wird, dann enthält die Ausgabe NICHT "Du hast das SmartFlow-Projekt gerettet" sondern einen ermutigenden Text mit "SmartFlow".
- [ ] AC-003: Gegeben score=0, wenn show_summary(0, 7) aufgerufen wird, dann enthält die Ausgabe einen ermutigenden Text mit "SmartFlow".
- [ ] AC-004: In beiden Pfaden enthält die Ausgabe "von 7" (Score-Anzeige).

## Non-Goals

- Keine Änderung an der Sterne-Anzeige oder der Phasenliste.
- Keine dritte Score-Kategorie (z.B. "mittel").
- Kein anderer Schwellwert als score > 6.

## Constraints

- Nur `show_summary()` in `game.py` wird geändert.
- Keine neuen Abhängigkeiten.
