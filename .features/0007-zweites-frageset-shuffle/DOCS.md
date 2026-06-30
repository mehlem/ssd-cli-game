# Technical Reference: Zweites Frageset Shuffle

## Architecture Overview

Alle Änderungen liegen in `game.py`. Die Daten-Erweiterung (zweites Fragenset pro Phase) und die Zufallslogik sind voneinander getrennt: T-001 erweiterte die `PHASES`-Datenstruktur, T-002 änderte die Steuerlogik in `run_phase()`. `ask_question()` blieb unverändert — es empfängt ein bereits aufgelöstes, gemischtes interaktion-Dict und hat kein Wissen über die Herkunft der Daten.

Aufrufkette nach dem Feature:

```
main()
  for phase in PHASES
    run_phase(phase)
      random.choice([phase["interaktion"]] + phase["fragen"])  → wählt 1 von 2 Fragen
      correct_text = optionen[int(richtig) - 1]                → merkt Antworttext
      opts = optionen[:]; random.shuffle(opts)                  → mischt Kopie
      neues richtig = str(opts.index(correct_text) + 1)        → berechnet neuen Index
      ask_question(gemischtes_dict)                             → unverändert
```

## Components & Files

| File | Action | Purpose |
|:-----|:-------|:--------|
| `game.py` | modified | Einzige geänderte Datei: `PHASES`-Liste erweitert um `fragen`-Feld pro Phase-Dict; `run_phase()` erhielt Zufallsauswahl + Shuffle-Logik |

## Interface Changes

### `PHASES`-Datenstruktur (`game.py:330–742`)

Jedes der 7 PHASES-Dicts erhielt ein neues Feld `fragen`: eine Liste mit einem interaktion-Dict (das zweite Fragenset).

```python
# Vorher: ein interaktion-Dict direkt im Phase-Dict
phase = {
    "interaktion": { "typ": ..., "frage": ..., "optionen": [...], "richtig": "1", ... }
}

# Nachher: zusaetzliches fragen-Feld mit zweitem Fragenset
phase = {
    "interaktion": { ... },          # unveraendert
    "fragen": [
        { "typ": ..., "frage": ..., "optionen": [...], "richtig": "1", ... }  # zweite Frage
    ]
}
```

`fragen[0]["richtig"]` ist bei allen 7 neuen Fragen `"1"` — die korrekte Antwort steht vor dem Mischen immer an Position 1 (per Konvention aus brief.md Q3).

### `run_phase()` (`game.py:793ff`)

Vor dem Feature: `ask_question(phase["interaktion"])` direkt.

Nach dem Feature:
1. `random.choice([phase["interaktion"]] + phase["fragen"])` — wählt zufällig eine von zwei Fragen
2. `correct_text` vor Shuffle merken
3. `opts = interaktion["optionen"][:]; random.shuffle(opts)` — mischt Kopie der Optionen
4. `richtig = str(opts.index(correct_text) + 1)` — berechnet neuen Positions-Index
5. Kopie des interaktion-Dicts mit gemischten `opts` und neuem `richtig` an `ask_question()` übergeben

### `ask_question()` — unverändert

Diese Funktion blieb vollständig unberührt. Sie vergleicht Nutzereingabe mit `q["richtig"]` als Positions-String-Vergleich (`game.py:313`). Bei falscher Antwort berechnet sie den korrekten Antworttext via `q["optionen"][int(q["richtig"]) - 1]` (`game.py:319`).

## Testing & Verification

Keine automatisierte Test-Suite vorhanden (`test*.py` → keine Treffer, FC-007 aus research.md). Verifikation erfolgt per Python-Assertions und manuellem Spielen.

### AC-005: Struktur-Assertion (PHASES hat 2 Fragen pro Phase)

```bash
py -c "
from game import PHASES
for p in PHASES:
    total = len([p['interaktion']] + p['fragen'])
    assert total == 2, f'{p[\"name\"]}: {total} statt 2 Fragen'
print('OK - alle 7 Phasen haben 2 Fragen')
"
```

### T-002 Verifikation: run_phase() nutzt random.choice + shuffle

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
assert 'Verstaendnisfrage' in out, 'FAIL: Fragen-Panel fehlt'
print('OK - run_phase nutzt random.choice + shuffle auf fragen-Liste')
"
```

### Schluessel-Invariante: richtig nach Shuffle korrekt

Kritisch zu pruefen: nach jedem Shuffle muss `richtig` auf die tatsaechlich korrekte Antwort zeigen. AC-002 und AC-003 in review.md verifizieren dies mit `game.py:794-797` als Evidenz.

### Review-Ergebnis

| AC | Status | Kern-Evidenz |
|:---|:-------|:-------------|
| AC-001 (Varianz zwischen Starts) | PASS | `game.py:793,796` |
| AC-002 (richtige Antwort nach Shuffle) | PASS | `game.py:316-317,794-797` |
| AC-003 (falsche Antwort nach Shuffle) | PASS | `game.py:320-321` |
| AC-004 (Score 7 bei 7 richtigen) | PASS | `game.py:874-877` |
| AC-005 (2 Fragensets importierbar) | PASS | `game.py:365,426,491,554,617,684,742` |

## Known Limitations

**Unvollstaendige `fragen`-Migration (Future Cleanup)**
AD-001 (plan.md) sah vor, `interaktion` vollstaendig in `fragen[0]` zu migrieren und das `interaktion`-Feld zu entfernen. Die Implementierung behaelt `interaktion` in allen PHASES-Dicts und kombiniert `[phase["interaktion"]] + phase["fragen"]` in `run_phase()`. `fragen` enthaelt daher nur 1 Element statt 2. Das Verhalten ist korrekt, die Datenstruktur ist inkonsistenter als geplant. Ein Folge-Feature kann `interaktion` aus allen 7 PHASES-Dicts entfernen und `fragen` auf 2 volle Eintraege umstellen — ohne Verhaltensaenderung.

**Positions-String-Invariante erfordert eindeutige Antworttexte**
Die Shuffle-Logik in `run_phase()` setzt voraus, dass alle 4 Antwortoptionen einer Frage unterschiedliche Texte haben. `opts.index(correct_text)` gibt den Index des ersten Treffers zurueck — bei Duplikaten wuerde es ggf. die falsche Position zurueckgeben. Alle 14 aktuellen Fragen (7 × 2) haben eindeutige Optionen. Bei kuenftigen Fragen-Ergaenzungen muss diese Invariante sichergestellt werden.

**Keine automatisierte Test-Suite**
Es gibt keine `test*.py`-Dateien. Verifikation erfolgt ausschliesslich durch Python-Assertions auf Modulstruktur und manuelles Spielen.

**Trace-Score 42.86%**
Drei Trace-Regeln schlugen fehl (plan.Addresses, plan.Acceptance, review.Validates) — fehlende formale Metadaten-Links in plan.md und review.md. Kein Funktionsproblem, aber der automatische Trace-Report zeigt lueckenhaften Artefakt-Linking.

**T-002-Verifikation initial gescheitert**
Das Verifikations-Script fuer T-002 schlug mit `exit 1` fehl (scratchpad.md Open Questions, 2026-06-29T12:33:49). Die Evidence liegt in `.features/0007-zweites-frageset-shuffle/verification/T-002.json`. Die spaetere Review-Verifikation bestaetigte PASS — der initiale Failure war ein Zwischenstand.

## Further Reading

- [README.md](./README.md) — Narrative Uebersicht: Problem, Entscheidungen, Outcome, Lessons Learned
- [research.md](./research.md) — Vollstaendige Code-Analyse von `game.py`, Positions-String-Befund, Risiken
- [plan.md](./plan.md) — AD-001 bis AD-003 mit abgelehnten Alternativen
- [tasks.md](./tasks.md) — T-001/T-002 Scope-Grenzen und vollstaendige Verifikationsbefehle
- [review.md](./review.md) — AC-Verifikationstabelle mit file:line-Belegen, Adjudication-Protokoll
- [scratchpad.md](./scratchpad.md) — Future-Cleanup-Notiz, T-002-Verification-Failure-Log
