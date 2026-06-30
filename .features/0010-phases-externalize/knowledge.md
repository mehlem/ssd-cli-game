---
id: KB-0011
feature: "0011-phases-externalize"
title: "Phases Externalize"
type: knowledge
schema_version: 2
status: active
created: 2026-06-30
updated: 2026-06-30
related:
  brief: BRIEF-0011
  spec: SPEC-0011
  research: RESEARCH-0011
  plan: PLAN-0011
  tasks: TASKS-0011
  review: REVIEW-0011
  scratchpad: SCRATCH-0011
  continuity: CONT-0011
tags: []
---

# Knowledge: Phases Externalize

## Quick Reference

Externe Datendateien neben game.py: `os.path.join(os.path.dirname(os.path.abspath(__file__)), "datei")` ist das korrekte Pattern für pfad-unabhängiges Laden.

## Entries

K-001: `ast.literal_eval()` über AST-Parse ist die sichere Methode um Python-Datenstrukturen aus einer Quelldatei zu extrahieren, ohne den Modul-Code auszuführen. Nützlich wenn das Modul ANSI-Codes, `os.system()` oder andere Side-Effects auf Modulebene enthält.

K-002: F-Strings dürfen keine Literal-Zeilenumbrüche (`\n`) enthalten — das erzeugt `SyntaxError: unterminated f-string literal`. Für mehrzeilige Fehlermeldungen entweder einzeiliger String mit Leerzeichen, oder `print()` zweimal aufrufen.

K-003: `except FileNotFoundError` fängt fehlendes File ab, aber `json.JSONDecodeError` (ungültiges JSON) propagiert unbehandelt. Wer robuste externe Datei-Lader schreibt, sollte beide Fälle abdecken — dieser Loader deckt nur den Missing-File-Fall (Spec-Non-Goal: keine JSON-Schema-Validierung).
