# Technical Reference: Projekt Rename

## Architecture Overview

Reiner Text-Ersetzungs-Fix ohne strukturelle Aenderungen. Das Feature operiert ausschliesslich auf den Anzeigetexten in `game.py`. Es gibt keine neuen Komponenten, keine API-Aenderungen und keine Logikveraenderungen. Das Muster: gezielte `replace_all`-Edits auf drei Textvarianten, gefolgt von einem assertion-basierten Verifikationsskript.

## Components & Files

| File | Action | Purpose |
|:-----|:-------|:--------|
| `game.py` | modified | Anzeigedatei des Beispielprojekts; enthaelt alle Spieltexte inkl. der 6 ersetzten Projektnamen-Vorkommen |

Kein anderes File wurde beruehrt. Das Feature hatte Scope-Boundary: ausschliesslich `game.py`.

## Interface Changes

Keine Aenderungen an Commands, APIs, Hooks oder Konfiguration. Einzige Auswirkung: Anzeigetexte in `game.py` nennen das Projekt jetzt einheitlich "PromptAndPray" bzw. "promptandpray".

Ersetzte Textvarianten (laut T-001):

| Vorher | Nachher |
|:-------|:--------|
| `SmartFlow-Projekt` | `PromptAndPray-Projekt` |
| `SmartFlow-Login` | `PromptAndPray-Login` |
| `smart-flow-login` | `promptandpray-login` |

## Testing & Verification

Beide Acceptance Criteria wurden per Python-Assertion verifiziert (review.md: AC-001 PASS, AC-002 PASS).

Verifikationsbefehl (aus tasks.md T-001):

```bash
cd "<projektpfad>" && python -c "
import re
txt = open('game.py', encoding='utf-8').read()
hits_old = len(re.findall(r'(?i)smartflow|smart-flow', txt))
hits_new = len(re.findall(r'(?i)promptandpray', txt))
assert hits_old == 0, f'FAIL: noch {hits_old} SmartFlow-Treffer'
assert hits_new >= 6, f'FAIL: nur {hits_new} PromptAndPray-Treffer'
print(f'OK - 0 SmartFlow, {hits_new} PromptAndPray')
"
```

Erwartete Ausgabe: `OK - 0 SmartFlow, N PromptAndPray` (N >= 6)

Zusaetzlich geprueft (review.md Verified Clean): Kein Hardcoded Secret (password, secret, key, token) in der Datei gefunden.

## Known Limitations

- `game.py` Zeile 219 ("PromptAndPray good vibes 2.0") war bereits korrekt und wurde bewusst nicht angefasst. Bei kuenftigen Rename-Operationen auf dieser Datei ist zu beachten, dass dieser Eintrag eine abweichende Formatierung ("good vibes 2.0"-Suffix) hat und nicht durch einen einfachen Regex-Replace auf "PromptAndPray" veraendert werden sollte.
- Das Feature hat kein research.md. Die Scope-Conformance-Tabelle in review.md weist deshalb `(no research.md found)` aus — die tatsaechliche Aenderung beschraenkte sich jedoch nachweislich auf `game.py`.
- knowledge.md und scratchpad.md enthalten ausschliesslich Template-Geruest; keine graduierten Erkenntnisse wurden festgehalten.

## Further Reading

- [README.md](./README.md) — Narrativer Ueberblick: Problem, Entscheidungen, Outcome, Lessons Learned
- [spec.md](./spec.md) — Anforderungen, Acceptance Criteria, Non-Goals, Constraints
- [tasks.md](./tasks.md) — T-001 mit Scope Boundary und vollstaendigem Verifikationsskript
- [review.md](./review.md) — AC-Validierungstabelle, Scope-Conformance-Tabelle, Verdict
