# Projekt Rename: SmartFlow zu PromptAndPray

## Problem

`game.py` enthielt an 6 Stellen die veralteten Bezeichnungen "SmartFlow" und "smart-flow" (in Varianten wie "SmartFlow-Projekt", "SmartFlow-Login", "smart-flow-login"). Die Einleitung des Spiels verwendete bereits den korrekten Namen "PromptAndPray good vibes 2.0". Diese Inkonsistenz zwischen den Anzeigetexten verwirrte Spieler, da sie je nach Kontext zwei verschiedene Projektnamen zu sehen bekamen.

## Solution

Alle 6 betroffenen Textstellen in `game.py` wurden durch den einheitlichen Namen ersetzt: "SmartFlow-Projekt" wird zu "PromptAndPray-Projekt", "SmartFlow-Login" zu "PromptAndPray-Login" und "smart-flow-login" zu "promptandpray-login". Keine anderen Dateien, keine Logik und keine Struktur wurden verändert. Die bereits korrekte Zeile 219 ("PromptAndPray good vibes 2.0") blieb unangetastet.

## Key Decisions

**Nur `game.py` anpassen, keine anderen Dateien.** Der Scope wurde bewusst auf diese eine Datei beschraenkt. Eine breitere Suche ueber weitere Projektdateien wurde als Out-of-Scope definiert, da nur `game.py` die sichtbaren Spieltexte enthaelt.

**Drei separate `replace_all`-Edits statt eines einzigen Regex-Passes.** Jede Textvariante (smart-flow-login, SmartFlow-Projekt, SmartFlow-Login) wurde einzeln ersetzt. Ein einziger Regex-Pass ueber alle Varianten haette das Risiko unbeabsichtigter Kollateralersetzungen erhoeht; die granulare Variante ist nachvollziehbarer und leichter pruefbar.

**Zeile 219 explizit als Non-Goal festgehalten.** Der bereits korrekte Eintrag "PromptAndPray good vibes 2.0" wurde als Ausnahme dokumentiert, um ihn bei der Verifikation nicht faelschlicherweise als Fehler zu werten.

**Verifikation per Python-Skript statt manuellem grep.** Die Abnahme erfolgte ueber ein eingebettetes Python-Skript, das beide Bedingungen (0 SmartFlow-Treffer, mind. 6 PromptAndPray-Treffer) als Assertions prueft. Ein manuelles grep haette keine automatisierte Fehlermeldung geliefert.

## Outcome

Review-Verdict: **PASS**

Beide Acceptance Criteria wurden bestaetigt:

- AC-001: `grep -i "smartflow|smart-flow" game.py` liefert 0 Treffer.
- AC-002: `grep -i "promptandpray" game.py` liefert mindestens 6 Treffer.

Keine kritischen oder minoren Issues wurden im Review gefunden. Die Verifikation auf Hardcoded Secrets ergab ebenfalls keine Befunde.

## Lessons Learned

Die scratchpad.md und knowledge.md dieses Features enthalten nur Template-Geruest ohne graduierte Erkenntnisse. Das deutet darauf hin, dass die Aenderung so geradlinig verlief, dass keine Beobachtungen festgehalten wurden — ein Zeichen fuer einen reibungslosen Ablauf bei einem eng gefassten Textfix.

Fuer kuenftige reine Text-Ersetzungs-Features gilt: Die explizite Dokumentation der unveraendert bleibenden Zeilen (hier Zeile 219) in Non-Goals und Scope Boundary verhindert, dass korrekte bestehende Texte faelschlicherweise als Fehler bewertet oder ersetzt werden.

## Further Reading

- [DOCS.md](./DOCS.md) — Technische Referenz: Komponenten, Verifikationsbefehle, bekannte Grenzen
- [spec.md](./spec.md) — Problem, Solution, Acceptance Criteria, Non-Goals, Constraints
- [tasks.md](./tasks.md) — T-001 mit Beschreibung, Done-When-Kriterien und Verifikationsskript
- [review.md](./review.md) — AC-Validierungstabelle, Verifikationsergebnis, Verdict PASS
- [scratchpad.md](./scratchpad.md) — Arbeitsnotizen (nur Template, keine Eintraege)
- [knowledge.md](./knowledge.md) — Durable facts (nur Template, keine Eintraege)
