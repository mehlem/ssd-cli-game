---
id: CONT-0011
feature: "0011-phases-externalize"
title: "Phases Externalize"
type: continuity
schema_version: 2
# status: active | completed | abandoned | superseded
# Detection treats completed/abandoned/superseded as inactive — set explicitly
# when a feature is replaced (add `superseded_by:`) or dropped.
status: completed
created: 2026-06-30
updated: 2026-06-30
related:
  brief: BRIEF-0011
  spec: SPEC-0011
  research: RESEARCH-0011
  plan: PLAN-0011
  tasks: TASKS-0011
  review: REVIEW-0011
  scratchpad: SCRATCH-0011
  knowledge: KB-0011
tags: []
---

# Continuity: Phases Externalize

## Goal

Den ~450-Zeilen PHASES-Literal aus game.py in eine externe `phases.json`-Datei auslagern,
damit Spielinhalt ohne Python-Kenntnisse bearbeitet werden kann. game.py lädt die Daten
beim Start per `json.load()`. Spielverhalten ändert sich für den Nutzer nicht.

## Constraints / Assumptions

- Nur Python-stdlib (`json`) — keine neuen Abhängigkeiten
- `phases.json` liegt im selben Verzeichnis wie `game.py`
- F-Strings dürfen keine Literal-Zeilenumbrüche enthalten (SyntaxError-Falle)

## Key Decisions

- AST-basierte Extraktion (`ast.literal_eval`) für T-001 gewählt statt direktem Import,
  da game.py ANSI-Sequenzen und `os.system()` auf Modulebene ausführt
- Fehlerfall (fehlende phases.json): einzeilige Fehlermeldung + `sys.exit(1)`
- JSON statt YAML: keine externe Abhängigkeit, Python-stdlib ausreichend

## State

<!-- SDD-AUTO-START -->
### Done

- T-001: phases.json aus PHASES-Literal erzeugt (7 Phasen, AST-Extraktion)
- T-002: PHASES-Loader in game.py eingebaut, import json ergänzt, Literal entfernt

### Now

- Review abgeschlossen — verdict: pass (4/4 ACs PASS, kein Critical-Finding)

### Next

- sdd close ausführen
- Scratchpad-Erkenntnisse in knowledge.md graduieren (JSONDecodeError-Limitation als Folge-Feature notieren)

### Working Set

- game.py (geändert: import json, PHASES-Loader Z. 349–361)
- phases.json (neu, ~25 KB, 7 Phasen)
- .features/0011-phases-externalize/review.md (in Bearbeitung)
<!-- SDD-AUTO-END -->

## Open Questions

- Kein offener Punkt — Reviewer-Ergebnisse ausstehend, aber kein Blocker bekannt

## Reasoning State

### Active Assumptions

- phases.json wurde korrekt aus dem PHASES-Literal extrahiert (Verifikation: 7 Einträge, json.load grün)
- Spielverhalten ist nach Umbau identisch (noch nicht manuell getestet, Loader-Verifikation grün)

### Open Ambiguity

- Fehlermeldung bei ungültigem JSON (nicht valides phases.json): aktuell unbehandelt —
  `json.JSONDecodeError` propagiert als unbehandelte Exception; kein AC fordert das ab,
  Quality-Reviewer soll beurteilen ob das ein Problem ist

### Current Blocker

- Keiner — warte auf Reviewer-Ergebnisse

### Next Verification Target

- AC-002: `py game.py` ohne phases.json → Exit-Code 1 + Fehlermeldung prüfen
- Reviewer-Ergebnisse einarbeiten → verdict in review.md setzen

### Active Scope Boundary

- In scope: game.py, phases.json
- Out of scope: alle anderen Dateien, Spiellogik, Testdateien
