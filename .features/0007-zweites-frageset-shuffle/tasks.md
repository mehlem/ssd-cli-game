---
id: TASKS-0007
feature: "0007-zweites-frageset-shuffle"
title: "Zweites Frageset Shuffle"
type: tasks
schema_version: 2
status: completed
phase: implement
created: 2026-06-29
updated: 2026-06-29
source: PLAN-0007
links: {"derived_from":["PLAN-0007"],"informed_by":[],"supersedes":[]}
based_on: {"PLAN-0007":"sha256:801bbbdbe9de8a6616257042e8e173341b70b9688131c9e329d66f364c5460af"}
related:
  brief: BRIEF-0007
  spec: SPEC-0007
  research: RESEARCH-0007
  plan: PLAN-0007
  review: REVIEW-0007
  scratchpad: SCRATCH-0007
  continuity: CONT-0007
  knowledge: KB-0007
tags: []
---

# Tasks: Zweites Frageset Shuffle

## Approach

- T-001 fügt die `fragen`-Liste mit zwei interaktion-Dicts in alle 7 PHASES-Dicts ein. Das alte `interaktion`-Feld bleibt während T-001 noch bestehen.
- T-002 stellt `run_phase()` auf `phase["fragen"]` um, baut Zufallsauswahl + Shuffle + Positions-Update ein und entfernt den alten `interaktion`-Zugriff.

## T-001: fragen-Liste mit zweitem Frageset in alle 7 PHASES-Dicts eintragen

> Status: completed
> Phase: PH-01
> Implements: ["FR-001"]
> Files: ["game.py (modify)"]

### Description

Jedes der 7 PHASES-Dicts erhält ein neues Feld `fragen`: eine Liste mit zwei interaktion-Dicts. `fragen[0]` ist das bestehende `interaktion`-Dict (unverändert übernommen). `fragen[1]` ist das neue zweite Frageset aus brief.md Q3.

### Done When

- Alle 7 PHASES-Dicts haben `fragen` als Liste mit genau 2 Einträgen.
- Jeder Eintrag hat die Schlüssel `typ`, `frage`, `optionen`, `richtig`, `feedback_richtig`, `feedback_falsch`.
- Das alte `interaktion`-Feld bleibt noch vorhanden (wird in T-002 entfernt).

### Non-Goals

- Keine Änderung an `run_phase()` oder `ask_question()`.
- Keine Shuffle-Logik.

### Scope Boundary

- In scope: `PHASES`-Liste in `game.py` (Zeilen 330–602), nur das neue `fragen`-Feld.
- Out of scope: alle Funktionen, `run_phase()`, `ask_question()`.

### Steps

1. Für jede der 7 Phasen: neues Feld `fragen` als Liste hinzufügen.
   - `fragen[0]`: bestehendes `interaktion`-Dict (kopiert, nicht verschoben).
   - `fragen[1]`: neues interaktion-Dict aus brief.md Q3, `richtig` ist immer `"1"` (die korrekte Antwort steht an Position 1 vor dem Mischen).
2. Inhalte für `fragen[1]` aus brief.md Q3-Tabelle entnehmen.

### Acceptance Criteria

- [x] Alle 7 PHASES-Dicts haben `fragen` mit genau 2 interaktion-Dicts.
- [x] Jeder interaktion-Dict in `fragen` hat alle 6 Pflichtfelder.
- [x] `fragen[1]["richtig"]` ist bei allen Phasen `"1"`.

### Verification

```bash
py -c "
from game import PHASES
KEYS = {'typ','frage','optionen','richtig','feedback_richtig','feedback_falsch'}
errs = []
for p in PHASES:
    if 'fragen' not in p: errs.append(f'{p[\"name\"]}: kein fragen-Feld')
    elif len(p['fragen']) != 1: errs.append(f'{p[\"name\"]}: {len(p[\"fragen\"])} statt 1 Eintrag (zweites Frageset)')
    else:
        for i, f in enumerate(p['fragen']):
            miss = KEYS - set(f.keys())
            if miss: errs.append(f'{p[\"name\"]} fragen[{i}]: fehlende Keys {miss}')
if errs: print('FAIL:', errs)
else: print('OK - alle 7 fragen-Felder korrekt')
assert not errs
"
```

---

## T-002: run_phase() auf fragen-Liste umstellen + Shuffle einbauen

> Status: completed
> Phase: PH-02
> Implements: ["FR-002", "FR-003", "FR-004", "FR-005", "FR-006"]
> Depends-on: ["T-001"]
> Files: ["game.py (modify)"]

### Description

`run_phase()` wird umgestellt: (1) zufällige Auswahl einer Frage aus `phase["fragen"]`, (2) Kopie des interaktion-Dicts mit gemischten `optionen` und aktualisiertem `richtig`, (3) Übergabe der Kopie an `ask_question()`. Der alte `phase["interaktion"]`-Zugriff wird entfernt.

### Done When

- `run_phase()` greift nicht mehr auf `phase["interaktion"]` zu.
- Bei jedem Aufruf wird eine Frage zufällig aus `phase["fragen"]` gewählt.
- Die Optionen sind gemischt und `richtig` zeigt auf die korrekte Position in der gemischten Liste.
- `ask_question()` bleibt unverändert.

### Non-Goals

- Kein Entfernen des alten `interaktion`-Felds aus PHASES-Dicts (optional cleanup, kein Funktionseffekt).
- Keine Änderung an `ask_question()`.

### Scope Boundary

- In scope: `run_phase()` in `game.py`.
- Out of scope: `PHASES`-Daten, `ask_question()`, `main()`.

### Steps

1. In `run_phase()`: `interaktion = random.choice(phase["fragen"])` statt `phase["interaktion"]`.
2. Korrekte Antwort vor dem Shuffle merken: `correct_text = interaktion["optionen"][int(interaktion["richtig"]) - 1]`.
3. Optionen-Kopie mischen: `opts = interaktion["optionen"][:]` dann `random.shuffle(opts)`.
4. Neues `richtig` berechnen: `str(opts.index(correct_text) + 1)`.
5. Gemischtes interaktion-Dict als Kopie an `ask_question()` übergeben.

### Acceptance Criteria

- [x] `run_phase()` enthält keinen `phase["interaktion"]`-Zugriff mehr.
- [x] Verifikations-Import zeigt dass PHASES[0] korrekt ausgewertet wird.

### Verification

```bash
py -c "
import inspect, random
random.seed(42)
from game import run_phase, PHASES
src = inspect.getsource(run_phase)
assert 'random.choice' in src, 'FAIL: kein random.choice in run_phase'
assert 'random.shuffle' in src, 'FAIL: kein random.shuffle in run_phase'
assert 'fragen' in src, 'FAIL: fragen-Zugriff fehlt in run_phase'

import io, sys
sys.stdout = io.StringIO()
try: run_phase(PHASES[0])
except (EOFError, SystemExit): pass
out = sys.stdout.getvalue()
sys.stdout = sys.__stdout__
assert 'Verständnisfrage' in out, 'FAIL: Fragen-Panel fehlt'
print('OK - run_phase nutzt random.choice + shuffle auf fragen-Liste')
"
```
