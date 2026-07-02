---
id: TASKS-0010
feature: "0010-phases-externalize"
title: "PHASES-Daten in externe JSON-Datei auslagern"
type: tasks
schema_version: 2
status: completed
phase: implement
created: 2026-06-30
updated: 2026-06-30
source: SPEC-0010
links: {"derived_from":["SPEC-0010"],"informed_by":[],"supersedes":[]}
related:
  spec: SPEC-0010
  review: REVIEW-0010
  scratchpad: SCRATCH-0010
  continuity: CONT-0010
  knowledge: KB-0010
tags: []
---

# Tasks: PHASES-Daten in externe JSON-Datei auslagern

## Approach

- T-001 extrahiert den PHASES-Literal aus game.py in eine neue Datei phases.json,
  ohne game.py zu verändern.
- T-002 ersetzt den Literal in game.py durch einen json.load()-Aufruf mit Fehlerbehandlung.
- Die Reihenfolge ist fix: T-002 setzt voraus, dass phases.json aus T-001 vorhanden ist.

---

## T-001: phases.json aus PHASES-Literal erzeugen

> Status: completed
> Depends-on: []
> Implements: ["FR-003"]
> Files: ["phases.json (create)"]

### Description

Die aktuelle `PHASES`-Liste aus `game.py` als valides JSON in `phases.json` serialisieren.
`game.py` bleibt in diesem Schritt unverändert.

### Done When

- `phases.json` existiert im Projektverzeichnis
- Die Datei enthält valides JSON mit exakt 7 Phasen-Einträgen
- Alle Schlüssel und Texte entsprechen dem aktuellen PHASES-Literal in game.py

### Non-Goals

- Keine Änderung an game.py in diesem Schritt
- Keine inhaltlichen Änderungen an Phasentexten oder Fragen

### Scope Boundary

- In scope: `phases.json` (neu anlegen)
- Out of scope: `game.py`, alle anderen Dateien

### Steps

1. PHASES-Literal aus game.py lesen
2. Als JSON mit `json.dumps(..., ensure_ascii=False, indent=2)` serialisieren
3. In `phases.json` (UTF-8) schreiben

### Acceptance Criteria

- [x] `phases.json` existiert und ist valides JSON
- [x] `json.load(open('phases.json'))` liefert eine Liste mit 7 Einträgen

### Verification

```bash
py -c "import json; d=json.load(open('phases.json', encoding='utf-8')); assert len(d)==7, f'Erwartet 7 Phasen, gefunden: {len(d)}'; print('T-001 OK: 7 Phasen in phases.json')"
```

---

## T-002: PHASES-Loader in game.py einbauen

> Status: completed
> Depends-on: ["T-001"]
> Implements: ["FR-001", "FR-002", "FR-004"]
> Files: ["game.py (modify)"]

### Description

Den `PHASES = [...]`-Literal (game.py:339–783) durch eine `json`-Laderoutine ersetzen.
Fehlt `phases.json`, gibt das Programm eine verständliche Fehlermeldung aus und endet
mit Exit-Code 1. Das `json`-Modul muss in den Imports ergänzt werden.

### Done When

- `game.py` enthält keinen `PHASES = [...]`-Literal mehr
- `game.py` lädt `PHASES` via `json.load()` aus `phases.json`
- Fehlt `phases.json`, bricht das Skript mit Exit-Code 1 und einer lesbaren Fehlermeldung ab
- `py -m py_compile game.py` läuft fehlerfrei durch

### Non-Goals

- Kein JSON-Schema-Validator
- Keine Änderung an Spiellogik oder Rendering-Funktionen

### Scope Boundary

- In scope: `game.py` — Import-Block (json hinzufügen), PHASES-Literal ersetzen durch Loader
- Out of scope: alle anderen Dateien, Spiellogik, Testdateien

### Steps

1. `import json` im Import-Block ergänzen (nach `import unicodedata`)
2. `PHASES = [...]`-Block (Z. 339–783) durch Laderoutine ersetzen:
   ```python
   _PHASES_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "phases.json")
   try:
       with open(_PHASES_PATH, encoding="utf-8") as _f:
           PHASES = json.load(_f)
   except FileNotFoundError:
       print(f"Fehler: phases.json nicht gefunden.\nErwartet: {_PHASES_PATH}", file=sys.stderr)
       sys.exit(1)
   ```
3. Syntaxcheck durchführen

### Acceptance Criteria

- [x] `py -m py_compile game.py` gibt keinen Fehler
- [x] `PHASES = [` ist nicht mehr im Quelltext von game.py enthalten
- [x] Import `json` ist im Modul vorhanden

### Verification

```bash
py -c "src=open('game.py', encoding='utf-8').read(); assert 'PHASES = [' not in src, 'PHASES-Literal noch vorhanden'; import game; assert len(game.PHASES)==7; print('T-002 OK: Loader aktiv, 7 Phasen geladen')"
```
