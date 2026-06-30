# Technical Reference: PHASES-Daten in externe JSON-Datei auslagern

## Architecture Overview

`game.py` laedt `phases.json` einmalig auf Modulebene beim Programmstart. Die Variable `PHASES`
ist danach ein globales Python-`list`-Objekt mit 7 Dicts — funktional identisch zum frueheren
Literal. Kein Cache, kein Hot-Reload: Aenderungen an `phases.json` wirken erst beim naechsten
`py game.py`.

```
phases.json  ──json.load()──>  PHASES (global, list[dict])
                                    │
                    ┌───────────────┼───────────────┐
                run_phase()   show_summary()      main()
```

Beide Dateien muessen im selben Verzeichnis liegen. Der Pfad wird
`__file__`-relativ aufgeloest (nicht relativ zum Arbeitsverzeichnis).

## Components & Files

| Datei | Aktion | Zweck |
|:------|:-------|:------|
| `game.py` | modifiziert | `import json` hinzugefuegt (Z. 14); PHASES-Literal (~450 Zeilen) durch 11-Zeilen-Loader ersetzt (Z. 349–359) |
| `phases.json` | neu angelegt | 7 Spielphasen als JSON-Array, UTF-8, ~25 KB, ~500 Zeilen |

## Loader-Code (game.py:349–359)

```python
# ---------------------------------------------------------------------------
# Phasendaten aus phases.json laden
# ---------------------------------------------------------------------------

_PHASES_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "phases.json")
try:
    with open(_PHASES_PATH, encoding="utf-8") as _f:
        PHASES = json.load(_f)
except FileNotFoundError:
    print(f"Fehler: phases.json nicht gefunden. Erwartet: {_PHASES_PATH}", file=sys.stderr)
    sys.exit(1)
```

`_PHASES_PATH` ist eine private Modulvariable — nur fuer den Loader, nicht von anderen
Funktionen verwendet. `PHASES` ist weiterhin global und wird von `run_phase()`,
`show_summary()` und `main()` direkt referenziert.

## phases.json — Datenstruktur

Oberste Ebene: JSON-Array mit 7 Objekten (eine Phase je Eintrag).

### Phase-Objekt

| Schluessel | Typ | Beschreibung |
|:-----------|:----|:-------------|
| `name` | string | Anzeigename, z. B. `"1 · Brief"` |
| `zweck` | string | Kurzbeschreibung der Phase |
| `kernfrage` | string | Leitfrage fuer den Spieler |
| `prompt` | string | Aufgabentext der Phase |
| `interaktion` | object | Einzelne Interaktionsfrage (siehe unten) |
| `beispiel` | object | Rollenbeispiel mit `po`, `entwickler`, `claude`, `artefakt` |
| `fragen` | array | Liste weiterer Multiple-Choice-Fragen |

### Frage-Objekt (in `interaktion` und `fragen[]`)

| Schluessel | Typ | Beschreibung |
|:-----------|:----|:-------------|
| `typ` | string | Immer `"mc"` (Multiple Choice) |
| `frage` | string | Fragetext |
| `optionen` | array[string] | 4 Antwortoptionen |
| `richtig` | string | `"1"`–`"4"` (1-basierter Index der korrekten Option) |
| `feedback_richtig` | string | Erklaerungstext bei richtiger Antwort |
| `feedback_falsch` | string | Erklaerungstext bei falscher Antwort |

### Beispiel-Einstieg

```json
[
  {
    "name": "1 · Brief",
    "zweck": "...",
    "kernfrage": "...",
    "prompt": "...",
    "interaktion": { "typ": "mc", "frage": "...", "optionen": [...], "richtig": "1", ... },
    "beispiel": { "po": "...", "entwickler": "...", "claude": "...", "artefakt": "..." },
    "fragen": [ { "typ": "mc", ... } ]
  },
  ...
]
```

## Interface Changes

- `import json` wurde in den Import-Block von `game.py` aufgenommen (Z. 14, nach `import unicodedata`).
- Die globale Variable `PHASES` existiert weiterhin mit identischer Struktur — keine
  Aenderung an aufrufenden Funktionen.
- Neues Fehlerverhalten: fehlt `phases.json`, gibt das Programm eine Meldung auf stderr aus
  und beendet sich mit Exit-Code 1 (vorher: `NameError` oder laufzeitfehler irgendwo in
  `run_phase()`).

## Testing & Verification

### T-001 — phases.json erzeugt und valide

```bash
py -c "import json; d=json.load(open('phases.json', encoding='utf-8')); assert len(d)==7, f'Erwartet 7 Phasen, gefunden: {len(d)}'; print('T-001 OK: 7 Phasen in phases.json')"
```

### T-002 — Loader aktiv, Literal entfernt

```bash
py -c "src=open('game.py', encoding='utf-8').read(); assert 'PHASES = [' not in src, 'PHASES-Literal noch vorhanden'; import game; assert len(game.PHASES)==7; print('T-002 OK: Loader aktiv, 7 Phasen geladen')"
```

### Syntaxcheck

```bash
py -m py_compile game.py
```

### Weitere Pruefungen (aus review.md)

| Pruefung | Kommando | Erwartetes Ergebnis |
|:---------|:---------|:--------------------|
| Literal entfernt | `grep "PHASES\s*=\s*\["` in game.py | Kein Treffer im Quelltext |
| 7 Phasen in JSON | `grep '"name": "[0-9]'` in phases.json | 7 Treffer (Z. 3,43,83,123,163,203,243) |
| import json | `grep "^import json"` in game.py | game.py:14 |
| Syntaxcheck | `py -m py_compile game.py` | Keine Fehler |

## Known Limitations

**`json.JSONDecodeError` unbehandelt (K-003).**
Der `except`-Block in `game.py:357` faengt nur `FileNotFoundError`. Ein syntaktisch
ungueliges `phases.json` (z. B. nach einem Tippfehler beim Bearbeiten) erzeugt einen
unbehandelten Traceback statt einer verstaendlichen Fehlermeldung. Dies ist ein bekanntes
und adjudiziertes Finding aus dem Review (Minor, kein Blocker). Spec-Non-Goals schliessen
JSON-Schema-Validierung explizit aus.

Wer diesen Fall abdecken moechte, ergaenzt:

```python
except json.JSONDecodeError as e:
    print(f"Fehler: phases.json ist kein gueltiges JSON: {e}", file=sys.stderr)
    sys.exit(1)
```

**Kein Hot-Reload.**
Aenderungen an `phases.json` erfordern einen Neustart von `game.py`. Kein Watcher,
kein Reload-Mechanismus — Spec-Non-Goal.

## Knowledge Entries

**K-001 — AST-Extraktion bei Side-Effect-Modulen.**
`ast.literal_eval()` ist der sichere Weg, um Python-Datenstrukturen aus einer Quelldatei
zu extrahieren, ohne den Modul-Code auszufuehren. Relevant wenn das Modul ANSI-Ausgabe,
`os.system()`-Aufrufe oder andere Side-Effects auf Modulebene enthaelt (wie `game.py`).

**K-002 — Kein Literal-`\n` in F-Strings.**
F-Strings duerfen keine Literal-Zeilenumbrueche enthalten — das erzeugt
`SyntaxError: unterminated f-string literal`. Fuer mehrzeilige Fehlermeldungen: einzeiliger
String mit Leerzeichen, oder zwei separate `print()`-Aufrufe.

**K-003 — `FileNotFoundError` vs. `json.JSONDecodeError`.**
`except FileNotFoundError` faengt nur das fehlende File ab. Robuste externe Datei-Lader
sollten beide Faelle behandeln. Dieser Loader deckt absichtlich nur den Missing-File-Fall ab.

## Further Reading

- [README.md](README.md) — Narrativer Ueberblick: Motivation, Entscheidungen, Outcome, Lessons Learned
- [spec.md](spec.md) — 4 FRs, 4 ACs, Constraints, Non-Goals, Codebase-Notizen
- [tasks.md](tasks.md) — T-001 und T-002 mit Done-When-Kriterien und Verifikationsbefehlen
- [review.md](review.md) — AC-Validierung, Code-Quality-Tabelle, Adjudication, Scope-Conformance
- [knowledge.md](knowledge.md) — Graduierte Erkenntnisse K-001 bis K-003
- [scratchpad.md](scratchpad.md) — Rohnotizen zur Implementierung (AST, F-String-Fehler, scope-refresh)
