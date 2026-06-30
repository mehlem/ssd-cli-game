---
id: REVIEW-0011
feature: "0011-phases-externalize"
title: "PHASES-Daten in externe JSON-Datei auslagern"
type: review
schema_version: 2
status: completed
phase: review
created: 2026-06-30
updated: 2026-06-30
source: SPEC-0011
links: {"derived_from":["SPEC-0011"],"informed_by":[],"supersedes":[]}
based_on: {"SPEC-0011":"sha256:8dd45eb3ba434f745a4eb23616af78cf37eed2b3ad83858fcc558221d89ad018","TASKS-0011":"sha256:4cebe9e2c365442c4c400dab0a6d497f73f754b1c13809ae27fb4dc2d8f26ccb"}
related:
  brief: BRIEF-0011
  spec: SPEC-0011
  tasks: TASKS-0011
  scratchpad: SCRATCH-0011
  continuity: CONT-0011
  knowledge: KB-0011
verdict: pass
tags: []
---

# Review: PHASES-Daten in externe JSON-Datei auslagern

> Reviewer: sdd-spec-reviewer (dispatch a061c64ecc0db8b3a) + sdd-quality-reviewer (dispatch a634a2cd60bfeeaa3)
> Methode: Spec zuerst gelesen, dann Code — unabhängig von Implementierungsangaben

## Acceptance Criteria Validation

| AC | Beschreibung | Status | Evidenz |
|:---|:-------------|:-------|:--------|
| AC-001 | phases.json existiert → Spiel lädt 7 Phasen korrekt | PASS | `phases.json:3,43,83,123,163,203,243` — 7 benannte Phasen; `game.py:354-356` json.load(); `game.py:498-499` for phase in PHASES: run_phase(phase) |
| AC-002 | phases.json fehlt → stderr-Meldung + Exit-Code 1 | PASS | `game.py:357-359` — `except FileNotFoundError: print(f"Fehler: … {_PHASES_PATH}", file=sys.stderr); sys.exit(1)` |
| AC-003 | Geänderter Text in phases.json erscheint im Spiel | PASS | `game.py:356` PHASES = json.load(_f) — kein Cache; Änderung in Datei wirkt sofort beim nächsten Start |
| AC-004 | game.py enthält keinen `PHASES = [...]`-Literal mehr | PASS | grep `PHASES\s*=\s*\[` in game.py → kein Treffer im Quelltext (nur .features/-Markdown) |

## Code Quality

| Kategorie | Status | Notizen |
|:----------|:-------|:--------|
| Correctness | ✓ ok | json.load korrekt; `__file__`-relativer Pfad robust |
| Security | ✓ ok | Kein Path-Traversal-Risiko; Pfad ist hartcodiert relativ zu `__file__` |
| Performance | ✓ ok | Einmaliges Laden beim Start, kein wiederholter I/O |
| Readability | ✓ ok | Stil konsistent mit rest of file (os.path-Pattern, try/except-Block) |
| Smallest viable solution | ✓ ok | `import json` + 6-Zeilen-Loader ersetzt ~450 Zeilen Literal; keine Abstraktion für Einzelfall |
| Unrequested work | ✓ ok | Kein Drive-by-Cleanup, keine zusätzlichen Features |
| Scope discipline | ✓ ok | Nur `game.py` und `phases.json` geändert — bestätigt durch beide Reviewer |

## Adjudication

<!-- SDD-ADJUDICATION:START -->
**F-001 (Quality-Reviewer, minor):** `game.py:354-359` — `except`-Block fängt nur `FileNotFoundError`. Ein invalides `phases.json` wirft `json.JSONDecodeError`, der als unbehandelter Traceback propagiert.

**Adjudication:** Kein Blocker. Spec Non-Goals schließen JSON-Schema-Validierung explizit aus. FR-002 deckt nur den Fehlerfall "Datei fehlt" ab. Finding wird als bekannte Limitation in knowledge.md aufgenommen für ein ggf. folgendes Feature.

**F-002 (Quality-Reviewer, informational):** Fehlermeldung einzeilig statt zweizeilig wie im tasks.md-Template. AC-002 fordert nur "verständliche Fehlermeldung" — erfüllt.

**Adjudication:** Keine Aktion erforderlich.
<!-- SDD-ADJUDICATION:END -->

## Scope Conformance

| Datei | Erwartet | Geändert | Status | Notizen |
|:------|:---------|:---------|:-------|:--------|
| game.py | ja (T-002) | ja | ✓ konform | import json + Loader-Block; ~450 Zeilen Literal entfernt |
| phases.json | ja (T-001) | ja (neu) | ✓ konform | 7 Phasen, UTF-8, ~25 KB |
| generate_docs.py | nein | nein | ✓ sauber | Bestätigt durch Quality-Reviewer |
| alle anderen | nein | nein | ✓ sauber | Kein Drive-by |

## Files Changed

| Datei | Tasks | Aktion | Zeilen |
|:------|:------|:-------|:-------|
| game.py | T-002 | modifiziert | +8, -450 (Literal entfernt, Loader + import json eingefügt) |
| phases.json | T-001 | neu angelegt | ~500 (7 Phasen, JSON) |

## Test Results

```
T-001 Verifikation:
py -c "import json; d=json.load(open('phases.json', encoding='utf-8')); assert len(d)==7 …"
→ T-001 OK: 7 Phasen in phases.json

T-002 Verifikation:
py -c "src=open('game.py', encoding='utf-8').read(); assert 'PHASES = [' not in src …; import game; assert len(game.PHASES)==7 …"
→ T-002 OK: Loader aktiv, 7 Phasen geladen

py -m py_compile game.py
→ Syntaxcheck: OK
```

## Issues Found

### Critical (must fix before close)

| Issue | Location | Evidenz |
|:------|:---------|:--------|
| (keine) | — | — |

### Minor (noted, can proceed)

| Issue | Location | Evidenz |
|:------|:---------|:--------|
| `json.JSONDecodeError` unbehandelt | game.py:354-359 | `except FileNotFoundError` — kein `except json.JSONDecodeError`; Traceback bei invalidem JSON. Außerhalb Spec-Scope (Non-Goals). |

## Verified Clean

| Bereich | Methode | Ergebnis |
|:--------|:--------|:---------|
| PHASES-Literal entfernt | grep `PHASES\s*=\s*\[` in game.py | Kein Treffer im Quelltext |
| 7 Phasen in phases.json | grep `"name": "[0-9]` in phases.json | 7 Treffer an Zeilen 3,43,83,123,163,203,243 |
| import json auf Modulebene | grep `^import json` in game.py | game.py:14 — stdlib, kein pip-Paket |
| generate_docs.py unverändert | grep phases.json + PHASES | Kein Treffer |
| Syntaxcheck | py -m py_compile game.py | Keine Fehler |
| Hardcoded secrets | grep password/secret/key/token | Keine gefunden |
