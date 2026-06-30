# Technical Reference: Game Phase Examples

## Architecture Overview

Das Feature erweitert eine einzelne Datei (`game.py`) mit zwei voneinander unabhängigen
Eingriffen:

1. **Datenerweiterung**: Jedes der 7 Dicts in der `PHASES`-Liste erhält ein neues Feld
   `beispiel` mit vier Unterfeldern (`po`, `entwickler`, `claude`, `artefakt`).
2. **Rendering**: `run_phase()` ruft `print_box()` mit den vier Beispiel-Zeilen auf —
   zwischen Kernfrage-Ausgabe und `ask_question()`-Aufruf.
3. **Entfernung**: Der `can_go_back`-Parameter, die z-Taste-Abfrage, das `phase_scores`-Dict
   und die `if result is None:`-Zurück-Logik wurden aus `run_phase()` und `main()` entfernt.

Kein neues Modul, keine neue Hilfsfunktion, keine neuen Abhängigkeiten.

## Components & Files

| File | Action | Purpose |
|:-----|:-------|:--------|
| `game.py` | modify | Einzige geänderte Datei: +56 Zeilen `beispiel`-Felder in PHASES-Dicts, +7 Zeilen `print_box()`-Aufruf in `run_phase()`, -12 Zeilen Zurück-Mechanismus |

## Interface Changes

### PHASES Dict-Schema (game.py:330–600)

Jedes der 7 Phase-Dicts hat jetzt ein zusätzliches Feld:

```python
"beispiel": {
    "po":         "...",   # Product Owner — Rolle oder "Keine Aufgabe in dieser Phase"
    "entwickler": "...",   # Konkreter CLI-Befehl oder Aktion
    "claude":     "...",   # Was das Plugin automatisch tut
    "artefakt":   "...",   # Entstandene Datei / Dokument
}
```

Phasen ohne PO-Beteiligung (Research, Plan, Implement, Close): `po`-Wert beginnt mit
"Keine Aufgabe in dieser Phase" gefolgt von einer kurzen Begründung (FR-003, AC-003).

### `run_phase()` Signatur (game.py)

Vorher: `run_phase(phase, can_go_back=False)`
Nachher: `run_phase(phase)`

Der `can_go_back`-Parameter existiert nicht mehr. Aufrufe in `main()` übergeben kein
`can_go_back`-Argument mehr (AD-003).

### Rendering-Reihenfolge in `run_phase()`

```
clear_screen()
print_box([phase["name"]])          ← Phase-Name-Box (unverändert)
print zweck + kernfrage             ← (unverändert)
print_box(beispiel-panel)           ← NEU: 4-zeiliges Beispiel-Panel
ask_question(phase["interaktion"])  ← (unverändert)
                                      ask_question() endet intern mit pause()
                                      kein zweiter pause()-Aufruf danach
```

### `main()` Score-Akkumulation (game.py:695–697)

Vorher: `phase_scores`-Dict mit Zurück-Logik (`if result is None: ...`).
Nachher: linearer `for`-Loop, direkte `score += result`-Akkumulation.

## Testing & Verification

Keine automatisierten Tests vorhanden (bekannt aus Research, FC-006). Alle drei Tasks haben
Verifikationsbefehle, die manuell oder in einem Python-Interpreter ausgeführt werden.

### T-001: Alle 7 beispiel-Felder vorhanden

```bash
py -c "from game import PHASES; errs=[p['name'] for p in PHASES if not all(k in p.get('beispiel',{}) for k in ['po','entwickler','claude','artefakt'])]; print('FAIL:',errs) if errs else print('OK - alle 7 beispiel-Felder vorhanden'); assert not errs"
```

### T-002: Beispiel-Panel wird gerendert

```bash
py -c "
import io, sys
sys.stdout = io.StringIO()
from game import run_phase, PHASES
try:
    run_phase(PHASES[0])
except (EOFError, SystemExit):
    pass
out = sys.stdout.getvalue()
sys.stdout = sys.__stdout__
assert '🧑' in out or 'po' in out.lower() or 'Product Owner' in out, 'Beispiel-Panel fehlt'
print('OK - Beispiel-Panel wird gerendert')
"
```

### T-003: Zurück-Mechanismus entfernt

```bash
py -c "import inspect, game; src = inspect.getsource(game.run_phase); assert 'can_go_back' not in src, 'can_go_back noch vorhanden'; assert 'phase_scores' not in inspect.getsource(game.main), 'phase_scores noch vorhanden'; print('OK - Zurück-Mechanismus entfernt')"
```

### Manueller Gesamttest

`py game.py` — alle 7 Phasen durchspielen. Pro Phase erscheint das Beispiel-Panel
automatisch vor der Frage. z-Taste hat keine Wirkung.

AC-006 (Kompaktheit bei 80-Zeichen-Terminal) ist nur manuell prüfbar, da `print_box()` bei
vertikaler Expansion (Zeilenumbruch langer Texte) keine Terminal-Höhe prüft.

## Known Limitations

**Emoji-Padding in `print_box()`**: `print_box()` (game.py:106–115) nutzt `_display_len()`
nicht für Padding-Berechnung der Rahmen-Ausrichtung. Wide-Zeichen (🧑, 👤, 🤖, 📄) können
zu minimal verschobenen Box-Rahmen führen. Im Review kein negativer Befund — das Risiko
bleibt aber offen (research.md Risks & Concerns).

**Vertikale Kompaktheit ungeprüft**: AC-006 spezifiziert "80 Zeichen Breite" und ist dafür
bestätigt. Eine explizite Terminal-Höhenbegrenzung gibt es nicht — bei langen PO-Texten
(~120 Zeichen) wächst das Panel vertikal durch Zeilenumbruch. Ob das bei allen 7 Phasen auf
einen Bildschirm passt, bleibt ohne formales Prüfkriterium (review.md AC-006 Note).

**Keine automatisierten Tests**: `game.py` hat 0 % automatisierte Testabdeckung. Alle
Verifikation ist manuell oder über ad-hoc `py -c`-Befehle. Das ist kein neues Defizit —
es bestand bereits vor diesem Feature (FC-006).

**Deferred: CLI vs. Skill-Unterschied**: `sdd spec` (CLI-Befehl) und `/sdd-spec` (Skill)
heißen fast gleich, tun aber verschiedene Dinge. Einsteiger könnten das in den
Beispiel-Panels falsch interpretieren. Bewusst nicht in 0003 adressiert — geeignet als
eigenes Feature (scratchpad.md "Out of Scope").

**Trace-Coverage 40 %**: Drei SDD-Trace-Regeln schlugen fehl (`plan.Addresses`,
`plan.Acceptance`, `review.Validates`) wegen fehlender formaler Metadaten-Verknüpfungen in
plan.md und review.md. Die inhaltliche Abdeckung aller FRs und ACs ist vollständig.

## Further Reading

- [README.md](./README.md) — Narrative Zusammenfassung: Problem, Entscheidungen, Outcome,
  Lessons Learned
- [brief.md](./brief.md) — Vollständige Q3-Tabelle mit allen 28 abgenommenen Beispieltexten
  (Primärquelle für PHASES-Inhalte)
- [research.md](./research.md) — Code-Stellen, Confidence-Score, Risikobewertung
- [plan.md](./plan.md) — AD-001 bis AD-003 mit verworfenen Alternativen
- [tasks.md](./tasks.md) — T-001 bis T-003 mit vollständigen Verifikationsbefehlen
- [review.md](./review.md) — AC-Nachweise mit `file:line`-Zitaten, Bug-Fund, Adjudication
