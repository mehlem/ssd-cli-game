---
id: SPEC-0002
feature: "0002-sdd-cli-game-interactive"
title: "Sdd Cli Game Interactive"
type: spec
schema_version: 2
status: completed
phase: design
created: 2026-06-26
updated: 2026-06-26
source: BRIEF-0002
links: {"derived_from":["BRIEF-0002"],"informed_by":[],"supersedes":[]}
based_on: {"BRIEF-0002":"sha256:a878530751291ad48bdc4f5055314c413f76e7d8d8482dfb65be6cecaa0233d6"}
related:
  brief: BRIEF-0002
  research: RESEARCH-0002
  plan: PLAN-0002
  tasks: TASKS-0002
  review: REVIEW-0002
  scratchpad: SCRATCH-0002
  continuity: CONT-0002
  knowledge: KB-0002
tags: []
---

# Spec: Sdd Cli Game Interactive

## Problem

Ein SDD-Einsteiger spielt das Spiel (0001) und drückt in jeder Phase nur Enter. Er hat keine Entscheidung getroffen, keinen Fehler gemacht, kein Feedback erhalten. Das Onboarding-Ziel — SDD-Denkmuster verinnerlichen — wird nicht erreicht. Das Spiel ist eine interaktive Dokumentation, kein Lernspiel.

## Solution

Jede der 7 Spielphasen erhält mindestens ein interaktives Element: eine Multiple-Choice-Frage, eine Entscheidungssituation oder eine PASS/FAIL-Urteilsfrage. Jede Antwort — richtig oder falsch — löst sofortiges Feedback mit Erklärung aus. Der Spielablauf bleibt linear; falsche Antworten blockieren nicht, sie lehren.

Eine spezifische Frage in der Brief- oder Design-Phase thematisiert den Vorteil von Markdown gegenüber anderen Standardformaten (JSON, XML, YAML) als Artefakt-Format.

## User Stories

- US-01: Als SDD-Einsteiger möchte ich in jeder Phase eine Entscheidung treffen, damit ich SDD-Konzepte durch Handeln verstehe, nicht durch Lesen.
- US-02: Als Spieler möchte ich bei falschen Antworten eine Erklärung bekommen, damit ich verstehe warum meine Antwort falsch war.
- US-03: Als Spieler möchte ich eine Frage über Artefakt-Formate beantworten, damit ich verstehe warum SDD auf Markdown setzt.
- US-04: Als Trainer möchte ich das Spiel als Quiz-Tool im Onboarding einsetzen, damit Teilnehmer aktiv mit SDD-Konzepten konfrontiert werden.

## Functional Requirements

- FR-001: Die Brief-Phase enthält eine Multiple-Choice-Frage die zeigt, was brief.md leisten muss: Der Spieler wählt aus 4 Optionen, welche der 5 Pflichtabschnitte (Motivation, Problem, Vision, Context, Constraints) in einer brief.md stehen müssen — und warum diese Phase vor jeder technischen Entscheidung kommt.
- FR-002: Die Brief- oder Design-Phase enthält eine Frage über den Vorteil von Markdown gegenüber JSON, XML und YAML als Artefakt-Format in SDD.
- FR-003: Die Design-Phase enthält eine Urteilsfrage: Der Spieler bewertet ein vorgegebenes Acceptance Criterion als gut formuliert oder schlecht formuliert.
- FR-004: Die Research-Phase enthält eine Entscheidungsfrage die die Evidence-Only-Regel vermittelt: Der Spieler sieht drei Aussagen über eine Codebasis und muss entscheiden, welche davon ein bestätigter Fakt (mit Dateireferenz), eine Hypothese oder ein Unbekanntes ist — um zu verstehen dass in Research kein Claim ohne gelesene Datei als Fakt gilt.
- FR-005: Die Plan-Phase enthält eine Reihenfolge-Entscheidung: Der Spieler ordnet 3 Tasks in die korrekte Abhängigkeitsreihenfolge.
- FR-006: Die Implement-Phase enthält eine Entscheidungssituation: Das Verifikationskommando schlägt fehl — was tut der Entwickler?
- FR-007: Die Review-Phase enthält eine PASS/FAIL-Urteilsfrage: Ein AC und eine Code-Beschreibung werden gegenübergestellt.
- FR-008: Die Close-Phase enthält eine Reflexionsfrage: Was gehört in ein knowledge.md — Spieler wählt aus 3 Optionen.
- FR-009: Jede Interaktion zeigt nach der Antwort Feedback das explizit das zugrundeliegende SDD-Prinzip nennt: bei richtiger Antwort eine Bestätigung mit dem Prinzip-Grund ("In SDD gilt: …"); bei falscher Antwort die korrekte Antwort plus den SDD-Grundsatz der dahintersteht. Feedback ist keine bloße Wertung ("richtig/falsch") sondern eine Lernaussage über das Plugin-Verhalten.
- FR-010: Falsche Antworten blockieren den Spielfortschritt nicht — das Spiel geht nach dem Feedback weiter.
- FR-011: Am Spielende zeigt die Zusammenfassung die Anzahl richtig beantworteter Fragen (Score).

## Acceptance Criteria

- [ ] AC-001: Gegeben die Brief-Phase startet, wenn der Spieler die Interaktion erreicht, dann wird eine Multiple-Choice-Frage mit mindestens 3 Optionen angezeigt, die den Begriff "brief.md" und mindestens zwei der fünf Pflichtabschnitte (Motivation, Problem, Vision, Context, Constraints) nennt.
- [ ] AC-002: Gegeben eine frühe Phase (Brief oder Design), wenn der Spieler die Interaktion erreicht, dann enthält eine Frage die Begriffe "Markdown", "JSON" und mindestens ein weiteres Format.
- [ ] AC-003: Gegeben alle 7 Phasen wurden durchlaufen, wenn das Spiel endet, dann hat jede Phase genau eine Interaktion gehabt (verifizierbar durch 7 Interaktionselemente im Quelltext).
- [ ] AC-004: Gegeben ein Spieler wählt eine falsche Antwort, wenn das Feedback erscheint, dann enthält es die richtige Antwort und einen Satz der mit "In SDD" oder "Das SDD-Plugin" beginnt und das zugrundeliegende Prinzip erklärt.
- [ ] AC-005: Gegeben ein Spieler wählt eine richtige Antwort, wenn das Feedback erscheint, dann enthält es eine Bestätigung und einen Satz der mit "In SDD" oder "Das SDD-Plugin" beginnt und das Prinzip hinter der richtigen Antwort begründet.
- [ ] AC-006: Gegeben eine falsche Antwort wurde gegeben, wenn das Feedback angezeigt wurde, dann fährt das Spiel mit der nächsten Phase fort (kein Block).
- [ ] AC-007: Gegeben alle Interaktionen wurden beantwortet, wenn die Zusammenfassung erscheint, dann zeigt sie die Anzahl richtiger Antworten (z.B. "5 von 7 richtig").
- [ ] AC-008: Gegeben das Spiel wird gestartet, dann werden keine neuen externen Pakete benötigt (nur Python stdlib).

## Non-Goals

- Kein Scoring-System mit Highscore oder Persistenz
- Keine verzweigenden Storylines basierend auf Antworten
- Keine Wiederholung von Fragen bei falscher Antwort (einmaliger Durchlauf)
- Keine Zeitbegrenzung pro Frage
- Keine neuen ASCII-Grafiken für jede Frage (bestehende Grafiken aus 0001 bleiben)

## Constraints

- Erweitert `game.py` aus Feature 0001 — kein Neuschreiben der Basis
- Python 3 stdlib only, keine externen Pakete
- Linearer Spielablauf — jede Phase hat genau eine Interaktion
- Interaktionsmechanik ausschließlich über `input()` (Zahl eingeben oder j/n)
- Gesamtspieldauer bleibt ≤15 Minuten

## Open Questions

- (keine — alle Kernentscheidungen in Brief geklärt)
