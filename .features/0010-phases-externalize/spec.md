---
id: SPEC-0010
feature: "0010-phases-externalize"
title: "PHASES-Daten in externe JSON-Datei auslagern"
type: spec
schema_version: 2
profile: lite
status: completed
phase: spec
created: 2026-06-30
updated: 2026-06-30
links: {"derived_from":[],"informed_by":[],"supersedes":[]}
related:
  tasks: TASKS-0010
  review: REVIEW-0010
  scratchpad: SCRATCH-0010
  continuity: CONT-0010
  knowledge: KB-0010
tags: []
---

# Spec: PHASES-Daten in externe JSON-Datei auslagern

## Problem

Die `PHASES`-Liste in `game.py` umfasst ~450 Zeilen fest eingebetteten Spielinhalt
(7 Phasen mit je Fragen, Feedback-Texten und Rollenbeispielen). Inhalt erweitern oder
korrigieren erfordert Python-Syntax-Kenntnis und Bearbeitung der Quelldatei. Content-Pflege
und Programm-Logik sind unnötig verflochten.

## Solution

Die `PHASES`-Liste wird in eine externe Datei `phases.json` (UTF-8) neben `game.py`
ausgelagert. `game.py` lädt die Daten beim Start per `json.load()` aus dieser Datei.
Fehlt die Datei, bricht das Spiel mit einer klaren Fehlermeldung ab. Das Verhalten des
Spiels ändert sich für den Spieler nicht.

## User Stories

- US-01: Als Content-Editor möchte ich Fragen und Texte der Spielphasen in einer
  JSON-Datei bearbeiten, ohne Python-Syntax zu kennen oder die Logikdatei anzufassen.

## Functional Requirements

- FR-001: `game.py` lädt die Phasendaten aus `phases.json` im selben Verzeichnis.
- FR-002: Fehlt `phases.json` beim Start, gibt das Spiel eine verständliche Fehlermeldung
  auf stderr aus und beendet sich mit Exit-Code 1.
- FR-003: `phases.json` enthält alle 7 Phasen mit identischer Struktur wie der bisherige
  `PHASES`-Literal (name, zweck, kernfrage, prompt, interaktion, beispiel, fragen).
- FR-004: `game.py` enthält nach dem Umbau keinen `PHASES = [...]`-Literal mehr.

## Acceptance Criteria

- [ ] AC-001: Gegeben `phases.json` existiert korrekt, wenn `py game.py` gestartet wird,
  dann verhält sich das Spiel identisch zur Vorgängerversion (alle 7 Phasen,
  Fragen, Feedback-Texte).
- [ ] AC-002: Gegeben `phases.json` fehlt, wenn `py game.py` gestartet wird, dann
  erscheint eine Fehlermeldung mit dem erwarteten Pfad und das Programm endet mit
  Exit-Code 1.
- [ ] AC-003: Gegeben der Text einer Frage in `phases.json` wird geändert, wenn
  `py game.py` gestartet wird, dann erscheint der geänderte Text im Spiel.
- [ ] AC-004: `game.py` enthält nach dem Umbau keinen `PHASES = [...]`-Literal mehr
  (prüfbar per Textsuche).

## Scope

- In scope: `game.py` (PHASES-Literal entfernen, Loader hinzufügen), `phases.json` (neu anlegen)
- Explizit: keine Änderung an Spiellogik, Rendering oder Inhalten der Phasen

## Non-Goals

- YAML-Unterstützung
- JSON-Schema-Validierung beim Laden
- Hot-Reload (kein Neuladen ohne Neustart)
- Inhaltliche Änderungen an Fragen oder Texten
- Neue externe Abhängigkeiten (nur Python-stdlib)

## Constraints

- Nur Python-stdlib (`json`-Modul) — kein pip-Paket
- `phases.json` liegt im selben Verzeichnis wie `game.py`
- Python 3.8+ Kompatibilität beibehalten

## Codebase Notes

- `PHASES` definiert in `game.py:339–783` (~450 Zeilen, Liste von 7 Dicts)
- Jede Phase: `name`, `zweck`, `kernfrage`, `prompt`, `interaktion` (dict), `beispiel` (dict), `fragen` (list of dicts)
- `interaktion`/`fragen`-Einträge: `typ`, `frage`, `optionen` (list), `richtig` (str "1"–"4"), `feedback_richtig`, `feedback_falsch`
- Verwendet in: `run_phase()` (~Z. 826), `show_summary()` (~Z. 846/853), `main()` (~Z. 925)
- `os`, `sys`, `json` (nach Umbau) sind bereits importiert bzw. müssen ergänzt werden
- Laderoutine muss auf Modulebene laufen, da PHASES global referenziert wird

## Open Questions

*(keine)*
