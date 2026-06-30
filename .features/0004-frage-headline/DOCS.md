# Technical Reference: Frage Headline

## Architecture Overview

Einzel-Funktions-Patch. Die gesamte Feature-Logik liegt in einem einzigen `print_box()`-Aufruf innerhalb von `ask_question()` in `game.py`. Keine neuen Komponenten, keine Datenstrukturänderungen, keine zusätzlichen Abhängigkeiten. Das Erweiterungsmuster nutzt die bestehende Listenargument-Schnittstelle von `print_box()`, die mehrere Zeilen als Listenelemente annimmt.

## Components & Files

| File | Action | Purpose |
|:-----|:-------|:--------|
| `game.py` | Modified | `ask_question()` — `print_box()`-Aufruf um Headline-String und Leerzeilen-Trenner erweitert |

Scope.txt ist leer; die einzige betroffene Datei ist aus `tasks.md` (T-001, "Files: game.py (modify)") und `review.md` (AC-001-Nachweis bei `game.py:302`) belegt.

## Interface Changes

**`ask_question()` in `game.py`**

Vorher:
```python
print_box([q["frage"]])
```

Nachher (`game.py:302`):
```python
print_box(["Hier eine Verständnisfrage zur Arbeit mit SDD", "", q["frage"]])
```

Kein Änderung an der Signatur von `ask_question()` selbst. Keine neuen Parameter, keine Konfigurationsoptionen, keine API-Erweiterungen.

**Acceptance Criterion AC-001** (aus spec.md):
- Gegeben eine beliebige Phase, wenn die Fragen-Box angezeigt wird, dann lautet die erste Zeile der Box exakt "Hier eine Verständnisfrage zur Arbeit mit SDD".

## Testing & Verification

**Verifikationsstatus:** T-001 PASS (exit_code 0, stdout "OK", erfasst in `verification/T-001.json` am 2026-06-29T09:10:22Z)

**Verifikationsbefehl** (aus tasks.md T-001):

```bash
py -c "from game import PHASES, ask_question; import io, sys; sys.stdout = io.StringIO(); [exec('try:\n ask_question(PHASES[0][\"interaktion\"])\nexcept: pass')]; out = sys.stdout.getvalue(); sys.stdout = sys.__stdout__; assert 'Hier eine Verständnisfrage' in out, 'Headline fehlt'; print('OK')"
```

Erwartete Ausgabe: `OK`

**AC-Tabelle aus review.md:**

| AC | Status | Nachweis |
|:---|:-------|:---------|
| AC-001 | PASS | `game.py:302` — `print_box(["Hier eine Verständnisfrage zur Arbeit mit SDD", "", q["frage"]])` |

**Geprüfte Bereiche (Verified Clean):**
- Hardcoded Secrets: Grep auf password/secret/key/token — kein Befund.

## Known Limitations

- Der Headline-Text ist als Literal-String in `game.py:302` hartcodiert. Soll er geändert werden, muss `ask_question()` direkt editiert werden — es gibt keine Konstante oder Konfigurationsvariable.
- Das lite-Profil dieses Features enthält kein research.md; daher ist die Scope-Conformance-Tabelle in review.md ohne Referenz-Datei ("no research.md found").
- scratchpad.md und knowledge.md enthalten keine inhaltlichen Einträge — limited information available zu Beobachtungen oder dauerhaften Erkenntnissen aus der Implementierung.

## Further Reading

- [README.md](./README.md) — Narrativer Rückblick: Problem, Entscheidungen, Outcome
- [spec.md](./spec.md) — Vollständige Anforderungen, Non-Goals, Constraints
- [tasks.md](./tasks.md) — T-001 mit Steps und Verifikationsbefehl
- [review.md](./review.md) — AC-Validierung, Scope Conformance, Issues
- [verification/T-001.json](./verification/T-001.json) — Maschinenlesbares Verifikationsergebnis
