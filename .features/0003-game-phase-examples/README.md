# Game Phase Examples

## Problem

Das SDD-Lernspiel (Features 0001 und 0002) vermittelte nach jeder Phase abstraktes Feedback
zu SDD-Prinzipien — aber keine konkrete Handlungsanleitung. Spieler verstanden, *was* eine
Phase bedeutet, wussten aber nicht, *was sie im Terminal tippen*, was das Plugin automatisch
tut und welche Datei danach auf der Festplatte liegt. Diese Lücke verhinderte, dass Spieler
nach dem Spiel eigenständig mit dem SDD-Plugin starten konnten.

## Solution

Nach dem Feedback jeder Phase erscheint automatisch ein vierzeiliges Beispiel-Panel, das eine
echte SDD-Session dieser Phase zeigt: Aktion des Product Owners, Befehl des Entwicklers,
automatische Reaktion von Claude Code und das entstehende Artefakt. Das Panel wird vor der
Phasenfrage angezeigt, sodass Spieler mit Kontext in die Frage gehen. Parallel wurde der
Zurück-Mechanismus (z-Taste) entfernt, da er mit dem neuen Panel-Layout mehrdeutig geworden
wäre. Das Review-Verdict lautet **pass** nach Behebung eines kritischen Bugs.

## Key Decisions

**AD-001: Beispieldaten inline in PHASES-Dicts speichern, nicht in separater Konstante.**
Jedes der 7 Phase-Dicts erhielt ein neues Feld `beispiel` mit den vier Unterfeldern `po`,
`entwickler`, `claude`, `artefakt`. Abgelehnt wurde eine separate `BEISPIELE`-Liste, die
parallel zu `PHASES` gepflegt werden müsste — sie hätte Sync-Fehler riskiert und Daten von
ihrer Phase getrennt. Das neue Feld folgt dem Muster des bereits vorhandenen `interaktion`-
Felds im selben Dict.

**AD-002: Direkter `print_box()`-Aufruf in `run_phase()`, keine neue Hilfsfunktion.**
Das Panel wird mit einem einzigen `print_box()`-Aufruf gerendert. Eine eigene
`show_beispiel_panel()`-Funktion wurde verworfen, weil sie bei einem einzigen Aufrufort
keinen Mehrwert gebracht hätte. `print_box()` war bereits erprobt und behandelt
Zeilenumbruch automatisch.

**AD-003: Zurück-Mechanismus vollständig entfernen, nicht umbauen.**
`can_go_back`-Parameter, z-Taste-Abfrage, `phase_scores`-Dict und die `if result is None:`-
Logik wurden chirurgisch aus `run_phase()` und `main()` entfernt. Abgelehnt wurde eine
Variante, bei der "Zurück" nur die Phase, nicht das Panel überspringt — sie hätte Komplexität
erhöht ohne klaren Nutzen. Der lineare Ablauf ist einfacher und konsistenter mit dem neuen
Panel-Flow.

**AD-004: Product Owner in allen 7 Phasen sichtbar halten, nicht ausblenden.**
In Phasen ohne PO-Beteiligung (Research, Plan, Implement, Close) zeigt das PO-Feld explizit
"Keine Aufgabe in dieser Phase" plus eine kurze Begründung. Abgelehnt wurde das Ausblenden
des PO-Felds in inaktiven Phasen — das hätte die konsistente Vier-Felder-Struktur gebrochen
und die Rolle des PO im Gesamtprozess verborgen.

**AD-005: Beispielinhalte vor Implementierung vollständig abnehmen.**
Alle 28 Texte (7 Phasen × 4 Felder) wurden gemeinsam mit dem Nutzer in Brief Q3 erarbeitet
und abgenommen, bevor die erste Codezeile geschrieben wurde. Abgelehnt wurde eine iterative
Befüllung während der Implementierung, die Rückfragen in der Implement-Phase erzeugt hätte.

## Outcome

Review-Verdict: **pass** nach einem kritischen Fund. Der Spec-Reviewer entdeckte eine
doppelte `pause()`-Aufruf-Kette: `ask_question()` endet intern bereits mit `pause()`, ein
zusätzlicher `pause()`-Aufruf in `run_phase()` erzeugte einen zweiten erforderlichen
Enter-Druck und verletzte AC-001. Der Fehler wurde während des Reviews behoben und vom
Quality-Reviewer bestätigt.

Alle 6 Acceptance Criteria wurden verifiziert:

- AC-001 bis AC-005: PASS (nach Bug-Fix)
- AC-006 (80-Zeichen-Breite): PASS — `print_box()` begrenzt auf 76 Zeichen bei
  80-Spalten-Terminal, langer Text bricht automatisch um

Die Trace-Coverage liegt bei 40 % (7/10 Regeln bestanden). Die drei fehlgeschlagenen Regeln
betreffen fehlende formale `addresses`- und `validates`-Verknüpfungen in plan.md und
review.md — die inhaltliche Abdeckung der FRs und ACs ist vollständig, nur die
Metadaten-Verlinkung fehlt.

## Lessons Learned

**Doppeltes `pause()` ist ein stilles Bug-Muster in game.py.** `ask_question()` endet
bereits mit `pause()`. Jeder weitere `pause()`-Aufruf im aufrufenden Code erzeugt einen
zweiten Enter-Druck, der den Spielfluss bricht. Dieser Fund entstand erst im Review und
war im Research nicht als Risiko identifiziert worden — obwohl `ask_question()` in
research.md dokumentiert war.

**Emoji-Breite in `print_box()` war das erwartete Risiko, blieb aber ohne Auswirkung.**
Research identifizierte das Emoji-Padding von Wide-Zeichen (🧑, 👤, 🤖, 📄) als offenen
Punkt. Im Review gab es dazu keinen negativen Befund — `_display_len()` behandelt
Wide-Zeichen korrekt genug für den gegebenen Einsatz.

**Deferred Feature: CLI vs. Skill-Verwechslung.** Fast alle SDD-Phasen haben sowohl einen
CLI-Befehl (`sdd spec`) als auch einen gleichnamigen Skill (`/sdd-spec`) — unterschiedliche
Dinge. Einsteiger könnten das verwechseln. Bewusst aus 0003 herausgehalten, um die
Panels kompakt zu halten. Geeignet als eigenes Feature.

## Further Reading

- [DOCS.md](./DOCS.md) — Technische Referenz: Komponenten, Interface-Änderungen,
  Verifikationsbefehle
- [brief.md](./brief.md) — Problemstellung, Motivation und vollständige Q3-Tabelle mit
  allen 28 abgenommenen Beispieltexten
- [spec.md](./spec.md) — Anforderungen, User Stories, 6 Acceptance Criteria
- [research.md](./research.md) — Betroffene Code-Stellen, Risiken, Confidence-Score
- [plan.md](./plan.md) — Architekturentscheidungen AD-001 bis AD-003, 3 Implementierungsphasen
- [tasks.md](./tasks.md) — T-001 bis T-003 mit Verifikationsbefehlen
- [review.md](./review.md) — AC-Nachweise, Bug-Fund und Adjudication-Protokoll
- [scratchpad.md](./scratchpad.md) — Observations und Findings aus der Implementierung
