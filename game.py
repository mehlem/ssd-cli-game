"""
SDD CLI Game — Spec-Driven Development interaktiv erleben.
Startet mit: py game.py  (Windows) oder  python3 game.py  (Unix)
"""

import os
import re
import sys
import shutil
import textwrap
import time
import random
import unicodedata
import json

# ---------------------------------------------------------------------------
# ANSI-Farbkonstanten (auf "" setzen für farblosen Fallback)
# ---------------------------------------------------------------------------
RESET  = "\033[0m"
FETT   = "\033[1m"
GRÜN   = "\033[32m"
ROT    = "\033[31m"
GELB   = "\033[33m"
BLAU   = "\033[34m"
CYAN   = "\033[36m"
GRAU   = "\033[90m"
ORANGE    = "\033[38;5;208m"
WEISS     = "\033[97m"
HELLGRAU  = "\033[37m"
PTA_BLAU  = "\033[38;2;0;111;185m"   # PTA Blue #006FB9


# ---------------------------------------------------------------------------
# Terminal-Hilfsfunktionen
# ---------------------------------------------------------------------------

def clear_screen():
    os.system("cls" if os.name == "nt" else "clear")


# ---------------------------------------------------------------------------
# Lade Banner-ASCII-Art beim Start (optional — fehlt die Datei, bleibt es leer)
# ---------------------------------------------------------------------------
_BANNER_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "SDD_ASCII-Art.txt")
try:
    with open(_BANNER_PATH, encoding="utf-8") as _f:
        _BANNER_LINES = [_l.rstrip() for _l in _f.readlines()]
except FileNotFoundError:
    _BANNER_LINES = []


def _print_banner():
    """Banner-Block zentriert: Haupttext weiß, Unterlängen-Balken in PTA-Blau.
    Zeilen mit Inhalt auf BEIDEN Seiten (z.B. 'p'-Unterlänge rechts): links blau, rechts weiß."""
    if not _BANNER_LINES:
        return
    w     = terminal_width()
    max_w = max(len(l) for l in _BANNER_LINES)
    pad   = " " * max(0, (w - max_w) // 2)
    # Suche: letzter großer Leerraum (≥10 Spaces) gefolgt von Inhalt am Zeilenende
    _gap = re.compile(r'(\s{10,})(\S.*)$')
    # Zeile 19 = erste Unterlängen-Zeile in SDD_ASCII-Art.txt (Farbwechsel weiß → PTA-Blau)
    _BANNER_COLOUR_SPLIT = 19
    for i, line in enumerate(_BANNER_LINES):
        if i < _BANNER_COLOUR_SPLIT:
            print(pad + WEISS + line + RESET)
        else:
            stripped = line.rstrip()
            m = _gap.search(stripped)
            if m and m.start() > 0 and stripped[:m.start()].strip():
                # Linker Teil blau, Lücke neutral, rechter Teil ('p'-Unterlänge) weiß
                left = stripped[:m.start()]
                gap  = m.group(1)
                right = m.group(2)
                print(pad + PTA_BLAU + left + RESET + gap + WEISS + right + RESET)
            else:
                print(pad + PTA_BLAU + line + RESET)


def pause(msg=f"\n  {GRAU}[ Enter drücken um fortzufahren ]  [x für Ende]{RESET} "):
    antwort = input(msg).strip().lower()
    return antwort == "x"


def terminal_width():
    return shutil.get_terminal_size(fallback=(80, 24)).columns


_ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")


def _visible_len(s):
    return len(_ANSI_RE.sub("", s))


def _display_len(s):
    """Terminal-Anzeigebreite: ANSI strippen, Emoji/Wide-Zeichen als 2 Spalten zählen."""
    s = _ANSI_RE.sub("", s)
    return sum(2 if unicodedata.east_asian_width(c) in ("W", "F") else 1 for c in s)


def print_centered(text, color=""):
    w = terminal_width()
    for line in text.splitlines():
        pad = max(0, (w - _display_len(line)) // 2)
        print(" " * pad + color + line + RESET)


def print_box(lines, color=BLAU):
    w = min(terminal_width() - 4, 114)
    h_line = "─" * (w - 2)
    print(f"  {color}┌{h_line}┐{RESET}")
    for line in lines:
        for subline in line.split("\n"):
            plain = _ANSI_RE.sub("", subline)
            wrapped = textwrap.wrap(plain, width=w - 4) or [""]
            for wline in wrapped:
                padding = " " * max(0, w - 4 - _display_len(wline))
                print(f"  {color}│{RESET}  {wline}{padding}{color}│{RESET}")
    print(f"  {color}└{h_line}┘{RESET}")


# ---------------------------------------------------------------------------
# Narrative Einleitung — PTA-Geschichte (T-002)
# ---------------------------------------------------------------------------

# VIBE-Buchstaben 3 breit, 5 hoch, 1 Leerzeichen Abstand — ergibt 15 Zeichen pro Zeile
_VIBE_ART = [
    "█ █ ███ ██  ███",
    "█ █  █  █ █ █  ",
    " █   █  ██  ██ ",
    " █   █  █ █ █  ",
    " █  ███ ██  ███",
]

# CHAOS in Block-Buchstaben, 4 Zeichen breit je Letter, 1 Leerzeichen Abstand = 24 Zeichen/Zeile
_CHAOS_ART = [
    " ███ █  █  ██   ██   ███",
    "█    █  █ █  █ █  █ █   ",
    "█    ████ ████ █  █  ██ ",
    "█    █  █ █  █ █  █    █",
    " ███ █  █ █  █  ██  ███ ",
]


def _vibe_box_lines():
    """VIBE-Box mit gestricheltem Rahmen (21 Zeichen breit, 9 Zeilen hoch)."""
    inner = 19
    h = "╌" * inner
    top   = "┌" + h + "┐"
    bot   = "└" + h + "┘"
    empty = "│" + " " * inner + "│"
    art   = [f"│  {row}  │" for row in _VIBE_ART]
    return [top, empty] + art + [empty, bot]


def _chaos_box_lines():
    """Chaos-Box mit gestricheltem Rahmen und CHAOS-Block-Art (28 Zeichen breit, 9 Zeilen hoch)."""
    inner = 26  # 1 Padding + 24 Kunst + 1 Padding
    h     = "╌" * inner
    top   = "┌" + h + "┐"
    bot   = "└" + h + "┘"
    empty = "│" + " " * inner + "│"
    art   = [f"│ {row} │" for row in _CHAOS_ART]
    return [top, empty] + art + [empty, bot]


def _fax_print(lines, pause_before=0.5, char_delay=0.04, colors=None):
    """Text zeilenweise buchstabenweise ausgeben — wie eine eingehende Fax-Nachricht.
    colors: optionale Liste von ANSI-Farbcodes je Zeile (None = keine Farbe)."""
    try:
        time.sleep(pause_before)
        for idx, line in enumerate(lines):
            color = (colors[idx] if colors and idx < len(colors) else "") or ""
            if color:
                print(color, end="", flush=True)
            for ch in line:
                print(ch, end="", flush=True)
                time.sleep(char_delay + random.uniform(0, 0.02))
            print(RESET if color else "")
            time.sleep(0.25)
    except KeyboardInterrupt:
        print()
        for idx, line in enumerate(lines):
            color = (colors[idx] if colors and idx < len(colors) else "") or ""
            print(color + line + (RESET if color else ""))


def _print_side_by_side(left_lines, right_lines, left_color, right_color):
    """Zwei vorberechnete Box-Zeilenlisten nebeneinander ausgeben."""
    h = max(len(left_lines), len(right_lines))
    lw = max(_display_len(l) for l in left_lines) if left_lines else 0
    left_pad  = [l + " " * max(0, lw - _display_len(l)) for l in left_lines] + [" " * lw] * (h - len(left_lines))
    right_pad = list(right_lines) + [""] * (h - len(right_lines))
    for lv, rv in zip(left_pad, right_pad):
        print(f"  {left_color}{lv}{RESET}  {right_color}{rv}{RESET}")

SDD_ASCII = r"""
    ╔══════════════════════════════════╗
    ║  Brief → Spec → Research → Plan  ║
    ║     Klar    Prüfbar   Sicher     ║
    ║                                  ║
    ║     "Wir wissen was wir tun."    ║
    ╚══════════════════════════════════╝
"""


def show_intro():
    clear_screen()

    if terminal_width() < 150:
        print()
        print_centered(f"{GELB}{FETT}Für optimale Darstellung empfehlen wir ≥150 Spalten.{RESET}")
        print_centered(f"{GRAU}Aktuell: {terminal_width()} Spalten — du kannst trotzdem fortfahren.{RESET}")
        print()
        antwort = input(
            f"  {GRAU}[ Enter drücken um fortzufahren ]  [x für Ende]{RESET}  "
        ).strip().lower()
        if antwort == "x":
            sys.exit(0)
        clear_screen()

    print()
    _print_banner()
    print()
    print_centered(f"{FETT}{CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{RESET}")
    print_centered(f"{FETT}{CYAN}     S D D  —  C L I  G A M E     {RESET}")
    print_centered(f"{FETT}{CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{RESET}")
    print_centered(f"{GRAU}Spec-Driven Development interaktiv erleben  {RESET}")
    print()
    if pause(f"\n  {GRAU}[ Enter drücken um zu starten ]  [x für Ende]{RESET} "):
        sys.exit(0)

    # --- Szene 1: Das Chaos-Projekt ---
    clear_screen()
    print()
    print_box([
        "Montag, 08:47 Uhr. PTA-Buero, Konferenzraum 3.",
        "",
        "Max Muster, Consultant bei der PTA GmbH, starrt auf seinen Bildschirm.",
        "Das Schulungsprojekt 'PromptAndPray good vibes' sollte laengst fertig sein.",
    ], color=GELB)
    print()
    _print_side_by_side(_vibe_box_lines(), _chaos_box_lines(), WEISS, ORANGE)
    print()
    _fax_print(
        [
            'KI:  "hier ist dein Feature!"',
            'git push --force ¯\\_(ツ)_/¯',
            'Dev: "warum funktioniert das nicht?!"',
        ],
        colors=["", HELLGRAU, ""],
    )
    print()
    print_box([
        "Das Team hat tagelang mit KI-Tools entwickelt — schnell, spontan,",
        "intuitiv. Mit 'Vibe-Coding' sollte es doch leicht zu schaffen sein.",
        "",
        "Heute Morgen: Der Coach testet. Nichts funktioniert wie besprochen.",
        "Kein Mensch weiß mehr, was welcher Code eigentlich tun soll.",
    ], color=ROT)
    print()
    if pause():
        sys.exit(0)

    # --- Szene 2: Der Kollege mit dem Plan ---
    clear_screen()
    print()
    print_box([
        "Dann betritt Jana das Büro. Ruhig. Kaffee in der Hand.",
        "",
        "  'Max, zeig mir euer letztes Feature-Verzeichnis.'",
        "  'Wir... haben keins. Wir haben direkt gecoded.'",
        "  Jana nickt langsam. 'Das ist das Problem.'",
    ], color=CYAN)
    print()
    print(f"{GRÜN}{SDD_ASCII}{RESET}")
    print()
    print_box([
        "Jana öffnet ihr Terminal und tippt: sdd init promptandpray-login",
        "",
        "  'Bevor eine Zeile Code entsteht, beantworten wir drei Fragen:'",
        "  'WARUM brauchen wir das?  WAS soll es tun?  WIE prüfen wir es?'",
        "",
        "  'Das nennt sich Spec-Driven Development — SDD.'",
        "  'KI ist ein mächtiges Werkzeug. Aber Werkzeuge brauchen einen Plan.'",
    ], color=GRÜN)
    print()
    if pause():
        sys.exit(0)

    # --- Szene 3: Deine Mission ---
    clear_screen()
    print()
    print(f"{FETT}{GRÜN}Deine Mission{RESET}")
    print()
    print_box([
        "Du spielst jetzt eine vollständige SDD-Runde durch —",
        "als wärst du Jana und rettest das PromptAndPray-Projekt.",
        "",
        "Du durchläufst alle 7 Phasen:",
        "",
        "  1. Brief       — WARUM existiert das Feature?",
        "  2. Design      — WAS soll es genau tun?",
        "  3. Research    — WO lebt es im Code?",
        "  4. Plan        — WIE wird es gebaut?",
        "  5. Implement   — Bau es Task für Task.",
        "  6. Review      — Stimmt es mit dem Spec überein?",
        "  7. Close       — Wissen sichern, Feature abschließen.",
        "",
        "Kein echter Code. Kein echtes Plugin. Nur du und die Methodik.",
    ], color=BLAU)
    print()
    if pause(f"\n  {GRÜN}{FETT}[ Enter — Abenteuer beginnen ]{RESET} "):
        sys.exit(0)


# ---------------------------------------------------------------------------
# Interaktions-Engine (T-001, Feature 0002)
# ---------------------------------------------------------------------------

def ask_question(q):
    print()
    print_box(["Hier eine Verständnisfrage zur Arbeit mit SDD", "", q["frage"]], color=GELB)
    print()
    for i, opt in enumerate(q["optionen"], 1):
        print(f"  {FETT}{i}{RESET}  {opt}")
    print()
    gueltig = [str(i) for i in range(1, len(q["optionen"]) + 1)]
    while True:
        antwort = input(f"  Deine Wahl [{'/'.join(gueltig)}]: ").strip()
        if antwort in gueltig:
            break
        print(f"  {ROT}Bitte eine Zahl zwischen 1 und {len(q['optionen'])} eingeben.{RESET}")
    richtig = antwort == q["richtig"]
    print()
    if richtig:
        print(f"  {GRÜN}{FETT}✓ Richtig!{RESET}")
        print(f"  {GRÜN}{q['feedback_richtig']}{RESET}")
    else:
        korrekte_opt = q["optionen"][int(q["richtig"]) - 1]
        print(f"  {ROT}{FETT}✗ Nicht ganz.{RESET}  Richtig wäre: {FETT}{korrekte_opt}{RESET}")
        print(f"  {ROT}{q['feedback_falsch']}{RESET}")
    if pause():
        sys.exit(0)
    return 1 if richtig else 0


# ---------------------------------------------------------------------------
# Phasendaten aus phases.json laden
# ---------------------------------------------------------------------------

_PHASES_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "phases.json")
try:
    with open(_PHASES_PATH, encoding="utf-8") as _f:
        PHASES = json.load(_f)
except FileNotFoundError:
    print(f"Fehler: phases.json nicht gefunden. Erwartet: {_PHASES_PATH}", file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# Phasen-Renderer — mit Interaktion (T-005 + T-001)
# ---------------------------------------------------------------------------

def run_phase(phase):
    clear_screen()
    print()
    print_box([phase["name"]], color=CYAN)
    print()
    print(f"  {FETT}Zweck:{RESET}")
    print(f"  {phase['zweck']}")
    print()
    print(f"  {FETT}{GELB}Kernfrage:{RESET}")
    print(f"  {GELB}{phase['kernfrage']}{RESET}")
    print()
    b = phase["beispiel"]
    _bw = min(terminal_width() - 4, 114)
    _felder = [
        ("🧑 Product Owner:  ", b["po"]),
        ("👤 Entwickler:     ", b["entwickler"]),
        ("🤖 Claude Code:    ", b["claude"]),
        ("📄 Artefakt:       ", b["artefakt"]),
    ]
    _panel = []
    for _lbl, _txt in _felder:
        _lw = _display_len(_lbl)
        _tw = max(_bw - 4 - _lw, 20)
        _wrapped = textwrap.wrap(_txt, width=_tw) or [""]
        _panel.append(_lbl + _wrapped[0])
        _indent = " " * _lw
        for _l in _wrapped[1:]:
            _panel.append(_indent + _l)
    print_box(_panel, color=GRÜN)
    print()
    rohe_frage = random.choice([phase["interaktion"]] + phase["fragen"])
    correct_text = rohe_frage["optionen"][int(rohe_frage["richtig"]) - 1]
    opts = rohe_frage["optionen"][:]
    random.shuffle(opts)
    frage = dict(rohe_frage, optionen=opts, richtig=str(opts.index(correct_text) + 1))
    points = ask_question(frage)
    return points


# ---------------------------------------------------------------------------
# Abschluss-Zusammenfassung — mit Score (T-006 + T-001)
# ---------------------------------------------------------------------------

def show_summary(score, total):
    clear_screen()
    print()
    print(f"{FETT}{GRÜN}★  Glückwunsch — du hast alle 7 Phasen durchlaufen!  ★{RESET}")
    print()
    sterne = "★" * score + "☆" * (total - score)
    if score >= total:
        nachricht = [
            "Du hast das PromptAndPray-Projekt gerettet. Jana nickt anerkennend.",
            "",
            f"Dein Score: {FETT}{score} von {total}{RESET} Fragen richtig  {GRÜN}{sterne}{RESET}",
            "",
            "Was du erlebt hast:",
        ] + [f"  {GRÜN}✓{RESET}  {p['name']}" for p in PHASES] + [
            "",
            "SDD ist kein Bremsklotz — es ist dein Sicherheitsnetz.",
            "Strukturiertes Vorgehen macht KI-Unterstützung erst wirklich mächtig.",
        ]
    else:
        nachricht = [
            f"Dein Score: {FETT}{score} von {total}{RESET} Fragen richtig  {GELB}{sterne}{RESET}",
            "",
            "Was du erlebt hast:",
        ] + [f"  {GRÜN}✓{RESET}  {p['name']}" for p in PHASES] + [
            "",
            "Mit etwas mehr Übung kannst du Projekte wie das PromptAndPray-Projekt retten, wenn du SDD verwendest.",
            "",
            "Spiele noch einmal — jede Runde bringt dich der Methode näher.",
        ]
    print_box(nachricht, color=GRÜN)
    print()
    print_box([
        f"{FETT}{CYAN}SDD-Projektdokumentation{RESET}",
        "",
        "Dieses Spiel wurde selbst mit Spec-Driven Development entwickelt.",
        "Die SDD-Artefakte jedes Features (brief.md, spec.md, research.md,",
        "plan.md, tasks.md, review.md) enthalten die vollständige Dokumentation.",
        f"{GRAU}sdd archive <feature>{RESET} generiert je Feature README.md + DOCS.md.",
        "",
        f"Projektdokumentation aller Features:  {FETT}dokumentation.html{RESET}",
    ], color=BLAU)
    print()
    while True:
        antwort = input(
            f"  {GRAU}[ Enter — Ende ]  [ d — Dokumentation öffnen ]{RESET}  "
        ).strip().lower()
        if antwort == "x":
            sys.exit(0)
        elif antwort == "d":
            import webbrowser as _wb
            _doc = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dokumentation.html")
            _wb.open(_doc)
        else:
            break
    print()


# ---------------------------------------------------------------------------
# Einstiegspunkt — vollständig verdrahtet (T-006)
# ---------------------------------------------------------------------------

_MARKER = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".sdd_game_seen")


def _intro_already_seen():
    return os.path.exists(_MARKER)


def _mark_intro_seen():
    open(_MARKER, "w").close()


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    clear_screen()

    skip = False
    if _intro_already_seen():
        antwort = input(
            f"\n  {GELB}Du hast die Einleitung bereits gesehen.{RESET}"
            f"\n  Überspringen? {FETT}[j/n]{RESET} "
        ).strip().lower()
        skip = antwort == "j"

    if not skip:
        show_intro()
        _mark_intro_seen()

    score = 0
    for phase in PHASES:
        result = run_phase(phase)
        score += result

    show_summary(score, len(PHASES))


if __name__ == "__main__":
    main()
