# Technical Reference: Score-basierter Ausgang

## Architecture Overview

Einzelne Funktion, einzelne Datei. Die Aenderung fuegt eine `if/else`-Verzweigung in `show_summary()` ein. Es gibt keine neuen Module, keine neuen Abhaengigkeiten und keine Aenderungen an der Aufrufstelle. Der Kontrollfluss bleibt linear; der Verzweigungspunkt ist `score > 6`.

```
show_summary(score, total)
  |
  +-- score > 6  --> Erfolgstext ("Du hast das SmartFlow-Projekt gerettet.")
  |
  +-- score <= 6 --> Ermutigungstext (SmartFlow-Referenz, Einladung zur Wiederholung)
  |
  [beide Pfade] --> Score-Anzeige ("von 7") + Phasenliste
```

## Components & Files

| File | Action | Purpose |
|:-----|:-------|:--------|
| `game.py` | modified | Enthaelt `show_summary()`. Verzweigung auf score > 6 bei Zeile 641 eingefuegt; Ermutigungstext im else-Zweig ab Zeile 653. |

Alle anderen Dateien wurden nicht veraendert (Scope-Grenze laut spec.md Constraints und tasks.md Scope Boundary).

## Interface Changes

`show_summary(score, total)` — Signatur unveraendert. Rueckgabewert unveraendert (None). Seiteneffekt (stdout-Ausgabe) jetzt score-abhaengig.

| Aufruf | Ausgabe-Pfad |
|:-------|:-------------|
| `show_summary(7, 7)` | Erfolgstext, Score-Zeile, Phasenliste |
| `show_summary(6, 7)` | Ermutigungstext, Score-Zeile, Phasenliste |
| `show_summary(0, 7)` | Ermutigungstext, Score-Zeile, Phasenliste |

## Testing & Verification

Kein separates Testfile. Verifikation erfolgt ueber ein Inline-Skript aus tasks.md T-001, das stdout captured und gegen alle vier ACs prueft.

```bash
py -c "
import io, sys
from game import show_summary

def capture(score, total):
    sys.stdout = io.StringIO()
    try: show_summary(score, total)
    except: pass
    out = sys.stdout.getvalue()
    sys.stdout = sys.__stdout__
    return out

o7 = capture(7, 7)
o6 = capture(6, 7)
o0 = capture(0, 7)
assert 'SmartFlow-Projekt gerettet' in o7, 'AC-001 FAIL'
assert 'SmartFlow-Projekt gerettet' not in o6, 'AC-002 FAIL: Erfolgstext bei score=6'
assert 'SmartFlow' in o6, 'AC-002 FAIL: kein SmartFlow bei score=6'
assert 'SmartFlow-Projekt gerettet' not in o0, 'AC-003 FAIL'
assert 'von 7' in o7 and 'von 7' in o6, 'AC-004 FAIL'
print('OK - alle ACs bestanden')
"
```

Erwartete Ausgabe bei korrekter Implementierung: `OK - alle ACs bestanden`

Alle vier ACs wurden im Review als PASS verifiziert (review.md, AC-Validierungstabelle).

## Known Limitations

- Der Schwellwert `score > 6` ist hartcodiert. Wird die Gesamtfragenzahl kuenftig veraendert, muss der Schwellwert manuell angepasst werden. Eine dynamische Variante (z.B. `score == total`) war expliziter Non-Goal in spec.md.
- Es existieren nur zwei Ausgabe-Kategorien. Ein abgestuftes Feedback fuer mittlere Scores (z.B. 4-6) ist nicht implementiert und wurde als Non-Goal klassifiziert.
- Das review.md enthaelt keine ausgefuellten Code-Quality-Eintraege (Correctness, Tests, Security etc.) — diese Kategorien wurden im Review als leere Vorlage belassen. Die AC-Validierung ist vollstaendig; die Code-Quality-Tabelle ist lediglich ein Stub.
- scope.txt und changes.log sind fuer dieses Feature nicht vorhanden; die Dateiliste basiert ausschliesslich auf tasks.md und review.md.

## Further Reading

- [README.md](README.md) — Narrativer Ueberblick: Problem, Entscheidungen, Outcome
- [spec.md](spec.md) — Vollstaendige Anforderungen, AC-Definitionen, Non-Goals, Constraints
- [tasks.md](tasks.md) — Implementierungsschritte, Scope-Grenze, Verifikationsskript
- [review.md](review.md) — AC-Validierungsergebnisse mit file:line-Belegen
