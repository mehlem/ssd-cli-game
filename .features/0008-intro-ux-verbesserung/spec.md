---
id: SPEC-0008
feature: "0008-intro-ux-verbesserung"
title: "Intro Ux Verbesserung"
type: spec
schema_version: 2
profile: lite
status: completed
phase: spec
created: 2026-06-29
updated: 2026-06-29
related:
  tasks: TASKS-0008
  review: REVIEW-0008
tags: []
---

# Spec: Intro UX Verbesserung

## Problem

Das Spiel zeigt beim Start das ASCII-Art Banner für 4 Sekunden ohne jede Rückmeldung — der Spieler weiß nicht ob etwas lädt. Die Titelseite hat keinen Exit-Hinweis. An allen anderen Stellen fehlt ebenfalls die Möglichkeit, das Spiel geordnet zu beenden.

## Solution

Drei Verbesserungen: (1) Unter dem ASCII-Art Banner erscheint eine animierte "loading..."-Zeile mit wachsenden Punkten. (2) Auf der Titelseite lautet der Pause-Text "[ Enter drücken um zu starten ] [x für Ende]". (3) An allen anderen Pause-Stellen erscheint zusätzlich "[x für Ende]" — drückt der Spieler x, wird das Spiel beendet.

## User Stories

- US-01: Als Spieler möchte ich beim Start eine Ladeanimation sehen, damit ich weiß dass das Spiel reagiert.
- US-02: Als Spieler möchte ich jederzeit mit x das Spiel geordnet beenden können.

## Functional Requirements

- FR-001: Während das ASCII-Art Banner angezeigt wird, erscheint unter dem Bild eine animierte Zeile "loading." → "loading.." → "loading..." die sich wiederholt, bis die 4 Sekunden abgelaufen sind.
- FR-002: Auf der Titelseite lautet der Pause-Text "[ Enter drücken um zu starten ] [x für Ende]".
- FR-003: An allen anderen Pause-Stellen erscheint der Text "[ Enter drücken um fortzufahren ] [x für Ende]".
- FR-004: Drückt der Spieler x (an einer beliebigen Pause-Stelle), wird das Spiel sofort beendet.

## Acceptance Criteria

- [ ] AC-001: Nach dem Start erscheint unterhalb des Banners eine animierte Zeile mit "loading" und wachsenden Punkten.
- [ ] AC-002: `inspect.getsource(show_intro)` enthält den String "zu starten" für die Titelseiten-Pause.
- [ ] AC-003: `inspect.getsource(pause)` enthält "[x für Ende]" im Standard-Pausetext.
- [ ] AC-004: `inspect.getsource(pause)` enthält einen sys.exit-Aufruf für Eingabe "x".

## Non-Goals

- Kein Schließen des Terminalfensters selbst (betriebssystemabhängig) — nur Beenden des Python-Prozesses.
- Keine Änderung an der 4-Sekunden-Gesamtdauer der Banner-Anzeige.

## Constraints

- Nur `game.py` wird geändert.
- Python 3 stdlib only (`time`, `sys`).
