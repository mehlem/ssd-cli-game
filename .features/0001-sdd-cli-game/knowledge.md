---
id: KB-0001
feature: "0001-sdd-cli-game"
title: "Sdd Cli Game"
type: knowledge
schema_version: 2
status: active
created: 2026-06-26
updated: 2026-06-26
related:
  brief: BRIEF-0001
  spec: SPEC-0001
  research: RESEARCH-0001
  plan: PLAN-0001
  tasks: TASKS-0001
  review: REVIEW-0001
  scratchpad: SCRATCH-0001
  continuity: CONT-0001
tags: []
---

# Knowledge: Sdd Cli Game

## Quick Reference

<!-- Key facts, conventions, and patterns for this feature -->
<!-- A durable fact is reusable beyond this feature; it is not task status, a review verdict, or feature-local progress. -->

## Entries

- K-001: `curses` ist unter Windows Python (getestet: 3.14.3) nicht verfügbar (`ModuleNotFoundError: No module named '_curses'`). Cross-Platform Terminal-Spiele in Python müssen ANSI-Escape-Codes oder externe Bibliotheken (`blessed`, `rich`) verwenden. — graduated from scratchpad

- K-002: ANSI-Escape-Codes verfälschen `len()` — `len("\033[32mText\033[0m")` gibt die Byte-Länge inkl. Steuerzeichen zurück, nicht die sichtbare Breite. Für Padding-Berechnungen in Box-Funktionen `re.sub(r'\x1b\[[0-9;]*m', '', s)` vor `len()` anwenden. — graduated from review findings (F-001)

- K-003: Auf Windows-Systemen mit cp1252-Standardcodierung (typisch: CMD, ältere Terminal-Emulatoren) schlägt `print()` mit Unicode-Zeichen wie `─`, `│`, `┌` fehl. Fix: `sys.stdout.reconfigure(encoding='utf-8', errors='replace')` als erste Zeile in `main()`. — graduated from review findings (F-002)

- K-004: SDD Scope-Drift-Warnung beim Anlegen neuer Dateien: Wenn eine Datei in `tasks.md` unter Files gelistet ist, aber noch nicht in `task-scope.txt` steht, feuert der Pre-Tool-Hook eine Warnung. Fix: `sdd task scope-refresh <feature> <T-xxx>` ausführen. Die Warnung ist informativ — der Edit geht trotzdem durch. — graduated from scratchpad
