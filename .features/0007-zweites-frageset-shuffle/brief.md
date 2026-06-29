---
id: BRIEF-0007
feature: "0007-zweites-frageset-shuffle"
title: "Zweites Frageset Shuffle"
type: brief
schema_version: 2
status: completed
phase: brief
created: 2026-06-29
updated: 2026-06-29
related:
  spec: SPEC-0007
  research: RESEARCH-0007
  plan: PLAN-0007
  tasks: TASKS-0007
  review: REVIEW-0007
  scratchpad: SCRATCH-0007
  continuity: CONT-0007
  knowledge: KB-0007
tags: []
---

# Brief: Zweites Frageset Shuffle

<!-- =====================================================================
LEAN BRIEF INSTRUCTIONS (read before filling)

Posture: intent-extraction, not interview.
1. Gather context FIRST — read CLAUDE.md, .features/INDEX.md, recent feature briefs,
   and 1–2 scoped repo files relevant to this feature. Don't ask before inspecting.
2. Propose ideas or draft inferable sections (Problem, Context, Constraints) from
   inference. Label inferred content with source: <!-- inferred from CLAUDE.md -->
3. Ask only intent-level questions (Motivation, Vision). Soft cap ~3 questions total.
4. Forbidden question types:
   - Research/plan-phase questions (what files to touch, what data flows look like)
   - Code-logic questions (how to implement)
   - Anything answerable by inspecting CLAUDE.md / INDEX.md / scoped repo files
5. Every question MUST come paired with a **Recommended**: line carrying a proposed
   answer or idea — the user should be able to confirm/redirect quickly.
6. All 5 sections below are required, but Problem / Context / Constraints are usually
   fillable by interpretation. Don't ask one question per section.
===================================================================== -->

## Short Description

Zweites Frageset pro Phase + zufällige Antwort-Reihenfolge

## Long Description

Das Spiel hat pro Phase genau eine Frage mit vier Antworten in fester Reihenfolge. Wer das Spiel ein zweites Mal spielt, kennt bereits die richtige Antwortnummer auswendig — der Lerneffekt geht verloren. Dieses Feature fügt ein zweites Frageset hinzu (7 neue Fragen) und mischt die Antwort-Reihenfolge bei jedem Spielstart, sodass Wiederholen echtes Verstehen erfordert.

## Motivation

Ein Lernspiel dessen Antworten sich nicht verändern verliert seinen Wert nach dem ersten Durchlauf. Spieler die das Spiel ein zweites oder drittes Mal spielen, können die richtigen Antworten auswendig abrufen, ohne die SDD-Prinzipien zu verstehen. Das Feature stellt sicher, dass jede Runde eine echte Lernerfahrung bleibt.

## Problem

Spieler die das Spiel wiederholen wissen nach der ersten Runde: "Phase 1 = Antwort 1, Phase 4 = Antwort 3". Das Auswendiglernen der Antwort-Position ersetzt das Verstehen des Inhalts. Das Spiel verliert seinen Lernwert nach der ersten Runde. <!-- inferred aus Nutzerwunsch + Spielstruktur game.py -->

## Vision

Beim Spielstart wird für jede Phase zufällig eine von zwei Fragen ausgewählt, und die Antwortoptionen werden in zufälliger Reihenfolge angezeigt. Ein Spieler der das Spiel drei Mal spielt, sieht unterschiedliche Fragen und Antwort-Positionen — er muss jedes Mal inhaltlich nachdenken.

## Context

- **Stakeholders**: SDD-Einsteiger, die das Spiel mehrfach spielen wollen <!-- inferred aus 0001–0003 Brief -->
- **Urgency**: Logische Erweiterung nach Abschluss der Beispiel-Panels und Score-Logik (0003–0006) <!-- inferred aus Feature-Verlauf -->
- **Prior attempts**: Keine — erstmals in 0007
- **Related work**: Baut auf `PHASES`-Datenstruktur (0001), `ask_question()` (0001), Score-Logik (0005) auf

## Constraints

- Nur `game.py` wird geändert <!-- inferred aus bisherigen Features -->
- Python 3 stdlib only — `random` ist verfügbar, keine neuen Abhängigkeiten
- Linearer Spielablauf bleibt erhalten (kein Zurück)
- Jede Phase bekommt genau 2 Fragen — nicht mehr, nicht weniger
- Die 7 neuen Fragen müssen inhaltlich korrekt und zum jeweiligen SDD-Prinzip passend sein

## Q&A Record

### Q1: Wie soll das zweite Frageset ausgewählt werden — pro Spielrunde zufällig oder abwechselnd?

**Recommended**: Zufällig pro Spielstart — bei jedem `py game.py` wird für jede Phase zufällig eine der zwei Fragen gewählt. Das gibt mehr Varianz als ein striktes Alternieren.
**Answer**: Zufällig pro Spielstart.

### Q2: Sollen die Antworten immer gemischt werden (auch beim ersten Frageset), oder nur wenn das zweite Frageset gezogen wird?

**Recommended**: Immer mischen — unabhängig welche Frage gezogen wird, die Antwort-Reihenfolge ist immer zufällig. Das verhindert Auswendiglernen vollständig.
**Answer**: Immer mischen.

### Q3: Welche Fragen soll das zweite Frageset enthalten?

**Recommended**: Sieben neue Fragen, eine pro Phase, im selben Stil wie das erste Set — anderer Blickwinkel auf dasselbe SDD-Prinzip.
**Answer**: Bestätigt. Abgenommene Fragen + Antworten (richtige Antwort = Option 1 vor dem Mischen):

| Phase | Frage | Richtig | Falsch 1 | Falsch 2 | Falsch 3 |
|---|---|---|---|---|---|
| 1 Brief | "Das Team will ein Login-Feature bauen. Wann darf der Entwickler anfangen zu coden?" | Erst wenn brief.md alle 5 Abschnitte hat und Design freigegeben ist | Sobald das Problem klar ist | Direkt — Coding ist die beste Dokumentation | Nach einem 15-Minuten-Meeting mit dem PO |
| 2 Design | "Jana schreibt ein AC: 'Der Login soll gut funktionieren.' Warum ist das kein valides AC?" | Es ist nicht prüfbar — 'gut' kann nicht verifiziert werden | Es ist zu kurz — ACs müssen mindestens 3 Sätze lang sein | Es fehlt der Bezug zur Datenbank | ACs dürfen keine Verben enthalten |
| 3 Research | "Die Research-Phase ist abgeschlossen. Was darf der Entwickler in research.md als Fakt eintragen?" | Nur Aussagen die durch Dateilesen bestätigt wurden, mit Datei:Zeile-Beleg | Alle Vermutungen und Hypothesen ohne Einschränkung | Nur Aussagen die der Tech-Lead genehmigt hat | Eine Zusammenfassung des KI-Chats |
| 4 Plan | "Wann ist ein Task in tasks.md bereit für die Implementierung?" | Wenn er einen Verifikationsbefehl hat, der nach Abschluss grün sein muss | Wenn der Entwickler ihn verstanden hat | Wenn er mindestens 5 Schritte beschreibt | Wenn der PO ihn genehmigt hat |
| 5 Implement | "Max hat Task T-002 fast fertig, sieht aber einen offensichtlichen Bug in T-001-Code. Was tut er?" | Er notiert den Bug im Scratchpad und meldet ihn — T-001 ist nicht sein aktiver Task | Er fixt den Bug direkt — es sind nur 2 Zeilen | Er pausiert T-002 und öffnet T-001 wieder | Er wartet bis Review und hofft dass der Reviewer es findet |
| 6 Review | "Der Implementierer sagt: 'Ich habe AC-003 getestet, es läuft.' Was macht der Reviewer?" | Er prüft AC-003 selbst mit Datei-Evidenz — 'ich habe getestet' ist kein Beweis | Er vertraut dem Implementierer und hakt AC-003 ab | Er fragt den Implementierer nach mehr Details | Er überspringt AC-003 und prüft die anderen |
| 7 Close | "Das Feature ist reviewed und abgenommen. Was ist KEIN Teil von Close?" | Neue Anforderungen hinzufügen die beim Review aufgefallen sind | Erkenntnisse aus dem Scratchpad in KNOWLEDGE.md graduieren | `sdd close` ausführen um Artefakte zu finalisieren | Prüfen ob alle Tasks abgeschlossen sind |
