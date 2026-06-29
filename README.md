# SDD CLI Game

Ein interaktives Terminal-Spiel, das die 7 Phasen von Spec-Driven Development
spielerisch demonstriert. Keine Installation, keine externen Abhängigkeiten.

## Voraussetzungen

- Python 3.8 oder neuer
- **Windows Terminal** (empfohlen für ANSI-Farben) oder ein Unix-Terminal

## Starten

**Windows:**
```
py game.py
```

**Unix / macOS:**
```
python3 game.py
```

## Was erwartet dich?

Du spielst einen PTA-Berater, der ein chaotisches KI-Projekt mit SDD rettet.
Das Spiel führt dich durch alle 7 SDD-Phasen:

1. **Brief** — WARUM existiert das Feature?
2. **Design** — WAS soll es tun?
3. **Research** — WO lebt es im Code?
4. **Plan** — WIE wird es gebaut?
5. **Implement** — Task für Task umsetzen
6. **Review** — Entspricht es dem Spec?
7. **Close** — Wissen sichern

Spieldauer: ca. 10–15 Minuten.

## Hinweise

- Das Spiel merkt sich, ob du die Einleitung bereits gesehen hast
  (`.sdd_game_seen` im Spielverzeichnis). Beim zweiten Start kannst du sie überspringen.
- Für volle Farbdarstellung: **Windows Terminal** verwenden,
  nicht die klassische `cmd.exe`.
- Das Spiel führt keine echten `sdd`-Befehle aus — alles ist simuliert.
