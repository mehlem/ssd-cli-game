---
id: BRIEF-0002
feature: "0002-sdd-cli-game-interactive"
title: "Sdd Cli Game Interactive"
type: brief
schema_version: 2
status: completed
phase: brief
created: 2026-06-26
updated: 2026-06-26
related:
  spec: SPEC-0002
  research: RESEARCH-0002
  plan: PLAN-0002
  tasks: TASKS-0002
  review: REVIEW-0002
  scratchpad: SCRATCH-0002
  continuity: CONT-0002
  knowledge: KB-0002
tags: []
---

# Brief: Sdd Cli Game Interactive

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

Interaktive Spielelemente für das SDD CLI Game — Multiple-Choice, Entscheidungen und Feedback pro Phase

## Long Description

Das bestehende SDD CLI Game (0001) führt Spieler passiv durch die 7 Phasen: beschreibender Text, dann Enter drücken. Dieses Feature erweitert das Spiel um echte Interaktion: pro Phase mindestens eine Spielaufgabe (Multiple-Choice-Frage, Entscheidungssituation oder Urteilsfrage) mit sofortigem Feedback. Darunter fällt auch eine spezifische Frage in einer frühen Phase über den Vorteil von Markdown gegenüber anderen Standardformaten (JSON, XML, YAML) als Artefakt-Format in SDD.

## Motivation

Das Spiel soll Lernen durch Erleben ermöglichen — nicht durch Lesen. Wer passiv durch Phasenbeschreibungen scrollt, nimmt das SDD-Denkmuster nicht wirklich auf. Erst wenn der Spieler selbst entscheiden muss, Fehler machen kann und Feedback bekommt, entsteht echtes Verständnis. Ohne dieses Feature bleibt das Spiel eine interaktive Dokumentation, kein Lernspiel.

## Problem

Spieler des aktuellen Spiels erleben die 7 SDD-Phasen als reine Lektüre — jede Phase endet mit "Enter drücken". Es gibt keine Entscheidungen, keine Herausforderungen, kein Scheitern-und-Lernen. Das Onboarding-Ziel ("SDD-Denkmuster verinnerlichen") wird nicht erreicht, weil das Spiel keine kognitive Aktivierung erzeugt. <!-- inferred from Nutzer-Feedback nach erstem Spieldurchlauf + 0001-sdd-cli-game/spec.md -->

## Vision

Ein Spieler durchläuft alle 7 Phasen und muss in jeder Phase mindestens eine echte Entscheidung treffen. Bei falschen Antworten bekommt er eine kurze Erklärung warum — nicht nur "falsch". Am Ende hat der Spieler nicht nur gelesen, sondern aktiv mit SDD-Konzepten interagiert und Feedback auf seine Urteile bekommen. Das Spiel ist in 10–15 Minuten spielbar und fühlt sich nach einem Quiz-Abenteuer an, nicht nach einer Diashow.

## Context

- **Stakeholders**: SDD-Einsteiger als Spieler; sekundär: Trainer die das Spiel im Onboarding einsetzen <!-- inferred from 0001 brief.md -->
- **Urgency**: 0001 ist abgeschlossen und spielbar — direktes Folge-Feature, Lücke ist durch ersten Spieldurchlauf konkret benannt <!-- inferred from Nutzerfeedback in dieser Session -->
- **Prior attempts**: 0001-sdd-cli-game — lineares Spiel ohne Interaktion, jetzt als Basis vorhanden <!-- inferred from feature history -->
- **Related work**: Baut direkt auf `game.py` aus 0001 auf; Phasendaten (`PHASES`), Hilfsfunktionen und Spielstruktur werden erweitert

## Constraints

- Baut auf `game.py` aus 0001 auf — kein Neuschreiben, erweiternd
- Python 3 stdlib only, keine externen Pakete <!-- inherited from 0001 -->
- Linearer Spielablauf bleibt erhalten — keine Verzweigungen oder Save-States
- Interaktion über `input()` — kein plattformspezifisches Keyboard-Handling
- Jede Phasen-Interaktion muss in ~1 Minute abschließbar sein (Gesamtspielzeit ≤15 Min.)

## Q&A Record

### Q1: Welche Interaktionsformen sollen pro Phase eingesetzt werden?

**Recommended**: Multiple-Choice (1–3 auswählen) als Hauptmechanik — universell verständlich, kein Tipp-Aufwand, sofort bewertbar. Ergänzt durch offene Kurzeingaben ("Was würdest du schreiben?") mit Musterantwort als Spiegel — kein automatisches Bewerten.
**Answer**: Multiple-Choice + Entscheidungssituationen + Urteilsfragen (PASS/FAIL) — je nach Phasencharakter die passende Mechanik.

### Q2: In welcher Phase kommt die Markdown-Frage?

**Recommended**: Brief- oder Design-Phase — dort wird thematisiert, *warum* Artefakte als Markdown-Dateien existieren. Die Frage "Warum Markdown statt JSON/XML?" passt zum WHY-Charakter der frühen Phasen.
**Answer**: In eine der frühen Phasen (Brief oder Design).
