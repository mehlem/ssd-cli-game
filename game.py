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
    import re as _re
    w     = terminal_width()
    max_w = max(len(l) for l in _BANNER_LINES)
    pad   = " " * max(0, (w - max_w) // 2)
    # Suche: letzter großer Leerraum (≥10 Spaces) gefolgt von Inhalt am Zeilenende
    _gap = _re.compile(r'(\s{10,})(\S.*)$')
    for i, line in enumerate(_BANNER_LINES):
        if i < 19:
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
    if antwort == "x":
        sys.exit(0)


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
            wrapped = textwrap.wrap(_ANSI_RE.sub("", subline), width=w - 4) or [""]
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


def _fax_print(lines, pause_before=3.0, char_delay=0.07, colors=None):
    """Text zeilenweise buchstabenweise ausgeben — wie eine eingehende Fax-Nachricht.
    colors: optionale Liste von ANSI-Farbcodes je Zeile (None = keine Farbe)."""
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


def _print_side_by_side(left_lines, right_lines, left_color, right_color):
    """Zwei vorberechnete Box-Zeilenlisten nebeneinander ausgeben."""
    h = max(len(left_lines), len(right_lines))
    lw = max(len(l) for l in left_lines) if left_lines else 0
    left_pad  = [l.ljust(lw) for l in left_lines]  + [" " * lw] * (h - len(left_lines))
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

    while terminal_width() < 150:
        print()
        print_centered(f"{GELB}{FETT}Für optimale Darstellung bitte das Terminalfenster maximieren.{RESET}")
        print()
        antwort = input(
            f"  {GRAU}[ Fenster maximiert? Enter drücken um fortzufahren ]  [x für Ende]{RESET}  "
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
    pause(f"\n  {GRAU}[ Enter drücken um zu starten ]  [x für Ende]{RESET} ")

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
    pause()

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
    pause()

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
    pause(f"\n  {GRÜN}{FETT}[ Enter — Abenteuer beginnen ]{RESET} ")


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
    pause()
    return 1 if richtig else 0


# ---------------------------------------------------------------------------
# Phasendaten — alle 7 SDD-Phasen (T-004 + interaktion-Schema T-001)
# ---------------------------------------------------------------------------

PHASES = [
    {
        "name": "1 · Brief",
        "zweck": "Kläre WARUM das Feature existieren soll, bevor irgendeine Zeile Code entsteht.",
        "kernfrage": "Was ist das Problem? Wer hat es? Was passiert, wenn wir es nicht lösen?",
        "prompt": "Du schreibst die Motivation für das PromptAndPray-Login. Was ist das WHY?",
        "interaktion": {
            "typ": "mc",
            "frage": "Welche Abschnitte gehören zwingend in eine brief.md? Wähle die vollständige Liste.",
            "optionen": [
                "Motivation, Problem, Vision, Context, Constraints",
                "Problem, Solution, User Stories, Acceptance Criteria",
                "WHY, WHAT, WHERE, HOW, DO",
                "Motivation, Stakeholders, Budget, Timeline",
            ],
            "richtig": "1",
            "feedback_richtig": (
                "In SDD gilt: brief.md beantwortet ausschließlich das WHY. "
                "Die 5 Pflichtabschnitte (Motivation, Problem, Vision, Context, Constraints) "
                "stellen sicher, dass alle Beteiligten das Problem verstehen, "
                "bevor eine technische Entscheidung getroffen wird."
            ),
            "feedback_falsch": (
                "In SDD gilt: brief.md ist keine Spec (kein Solution/AC) "
                "und kein Projektplan (kein Budget/Timeline). "
                "Die 5 Pflichtabschnitte sind: Motivation, Problem, Vision, Context, Constraints — "
                "alles WHY-Ebene, nichts WHAT oder HOW."
            ),
        },
        "beispiel": {
            "po": "Nutzer brechen beim Signup ab, weil das Formular zu lang ist. Ziel: Registrierung verein-"
                "  fachen, damit mehr Besucher zu Kunden werden und der Support weniger Rückfragen bekommt.",
            "entwickler": 'Leitet daraus Feature-Name und Ziel ab → sdd init login-feature "Reduce signup friction"',
            "claude": "Erstellt brief.md, stellt WHY-Fragen (Motivation, Problem, Vision), aktiviert Brief-Phase-Gates",
            "artefakt": ".features/0001-login-feature/brief.md mit Motivation, Problem & Vision",
        },
        "fragen": [
            {
                "typ": "mc",
                "frage": "Das Team will ein Login-Feature bauen. Wann darf der Entwickler anfangen zu coden?",
                "optionen": [
                    "Erst wenn brief.md alle 5 Abschnitte hat und Design freigegeben ist",
                    "Sobald das Problem klar ist",
                    "Direkt — Coding ist die beste Dokumentation",
                    "Nach einem 15-Minuten-Meeting mit dem PO",
                ],
                "richtig": "1",
                "feedback_richtig": (
                    "In SDD gilt: kein Code vor dem Artifact-Chain-Start. brief.md muss vollständig sein "
                    "(alle 5 Abschnitte: Motivation, Problem, Vision, Context, Constraints) und die "
                    "Phase-Gate-Freigabe für Design muss erfolgt sein — erst dann beginnt das WHAT."
                ),
                "feedback_falsch": (
                    "In SDD gilt: Das Problem zu kennen reicht nicht aus. Das Team muss WHY vollständig "
                    "dokumentiert haben — alle 5 Pflichtabschnitte in brief.md — bevor mit Design "
                    "begonnen werden darf."
                ),
            },
        ],
    },
    {
        "name": "2 · Design (Spec)",
        "zweck": "Definiere WAS das Feature tun soll — in prüfbaren Anforderungen, nicht in Code.",
        "kernfrage": "Welche Funktionen braucht es? Wie sehen die Akzeptanzkriterien aus?",
        "prompt": "Schreibe eine User Story: 'Als [Wer] möchte ich [Was], damit [Warum].'",
        "interaktion": {
            "typ": "mc",
            "frage": (
                "Warum speichert SDD seine Artefakte als Markdown-Dateien (.md) "
                "statt in einem strukturierten Format wie JSON oder XML?"
            ),
            "optionen": [
                "Markdown ist menschenlesbar, versionierbar mit Git und braucht kein Spezialtool",
                "Markdown wird von KI-Tools besser verarbeitet als JSON oder XML",
                "JSON und XML sind zu komplex für Nicht-Entwickler",
                "Markdown-Dateien sind kleiner und schneller zu laden",
            ],
            "richtig": "1",
            "feedback_richtig": (
                "In SDD gilt: Artefakte sind primär für Menschen — Entwickler, Reviewer, KI-Assistenten. "
                "Markdown ist in jedem Texteditor lesbar, lässt sich mit git diff nachverfolgen, "
                "und erfordert kein Werkzeug zum Öffnen oder Bearbeiten. "
                "JSON/XML hingegen sind maschinenoptimiert und erschweren kollaboratives Schreiben."
            ),
            "feedback_falsch": (
                "In SDD gilt: Der Hauptgrund für Markdown ist Menschenlesbarkeit + Git-Versionierbarkeit. "
                "KI-Tools können beides gut lesen. Komplexität oder Dateigröße spielen keine Rolle. "
                "Markdown ermöglicht es, Artefakte direkt im Terminal, in VS Code oder auf GitHub "
                "zu lesen und zu reviewen — ohne Zwischentool."
            ),
        },
        "beispiel": {
            "po": "Das Formular soll maximal 3 Pflichtfelder haben. Nach der Eingabe muss ein neuer Nutzer"
                "  sich sofort einloggen können — ohne E-Mail-Bestätigung im ersten Schritt.",
            "entwickler": "Übersetzt PO-Wunsch in messbare Anforderungen → sdd spec 0001-login-feature, schreibt User"
                "  Stories & Akzeptanzkriterien in spec.md",
            "claude": "Schlägt funktionale Anforderungen (FR-001 …) und Akzeptanzkriterien (AC-001 …) vor, warnt"
                "  bei widersprüchlichen oder unvollständigen Anforderungen",
            "artefakt": ".features/0001-login-feature/spec.md mit User Stories, FRs und prüfbaren ACs",
        },
        "fragen": [
            {
                "typ": "mc",
                "frage": "Jana schreibt ein AC: 'Der Login soll gut funktionieren.' Warum ist das kein valides AC?",
                "optionen": [
                    "Es ist nicht prüfbar — 'gut' kann nicht verifiziert werden",
                    "Es ist zu kurz — ACs müssen mindestens 3 Sätze lang sein",
                    "Es fehlt der Bezug zur Datenbank",
                    "ACs dürfen keine Verben enthalten",
                ],
                "richtig": "1",
                "feedback_richtig": (
                    "In SDD gilt: Jedes AC muss durch einen Befehl, eine Datei oder eine explizite Prüfung "
                    "verifizierbar sein. 'Gut funktionieren' ist eine Meinung, kein prüfbares Kriterium — "
                    "ein Reviewer kann es weder bestätigen noch widerlegen."
                ),
                "feedback_falsch": (
                    "In SDD gilt: Die Länge oder technische Tiefe eines ACs ist nicht entscheidend. "
                    "Entscheidend ist: Kann es bewiesen werden? 'Gut' ist nicht messbar — "
                    "ein AC muss eine klare Pass/Fail-Bedingung haben."
                ),
            },
        ],
    },
    {
        "name": "3 · Research",
        "zweck": "Finde heraus WO das Feature in der Codebasis lebt — mit Beweisen, nicht Vermutungen.",
        "kernfrage": "Welche Dateien werden berührt? Welche Muster existieren bereits?",
        "prompt": "Nenne zwei Dateien, die du dir vor der Implementierung anschauen würdest.",
        "interaktion": {
            "typ": "mc",
            "frage": (
                "Jana liest den Code und notiert drei Aussagen. "
                "Welche davon ist ein bestätigter Fakt für research.md?\n\n"
                "  A) 'Die login()-Funktion validiert das Passwort'\n"
                "  B) 'auth.py:42 enthält eine login()-Funktion' (nach Lesen der Datei)\n"
                "  C) 'Das Auth-Modul hat vermutlich einen Session-Cache'"
            ),
            "optionen": [
                "Aussage B — bestätigter Fakt mit Dateireferenz",
                "Aussage A — klar und präzise formuliert",
                "Aussage C — vernünftige Annahme basierend auf Erfahrung",
                "Alle drei — Research sollte alles dokumentieren",
            ],
            "richtig": "1",
            "feedback_richtig": (
                "In SDD gilt: Ein Fakt in research.md braucht eine Quellenangabe (Datei:Zeile). "
                "Aussage B ist ein Fakt — sie wurde durch Lesen von auth.py:42 bestätigt. "
                "Aussage A klingt präzise, ist aber eine Behauptung ohne Beweis. "
                "Aussage C ist eine Hypothese. Beide gehören in die entsprechenden Abschnitte, "
                "nie in 'Facts'."
            ),
            "feedback_falsch": (
                "In SDD gilt: Research unterscheidet strikt zwischen Fakt, Hypothese und Unbekanntem. "
                "Nur Aussagen mit Dateireferenz sind Fakten. "
                "Aussage B ('auth.py:42') ist der einzige Fakt — die anderen sind Behauptungen "
                "oder Hypothesen, auch wenn sie plausibel klingen."
            ),
        },
        "beispiel": {
            "po": "Keine Aufgabe in dieser Phase — die fachlichen Vorgaben aus Brief und Design sind"
                "  abgeschlossen. Research ist reine Entwicklerarbeit.",
            "entwickler": "sdd research 0001-login-feature — gibt den Startschuss, liest danach research.md und"
                "  prüft ob alle betroffenen Dateien gefunden wurden",
            "claude": "Durchsucht die Codebase, kartiert betroffene Dateien (auth.py, forms.py …), identifiziert"
                "  Abhängigkeiten und Risiken, füllt research.md",
            "artefakt": ".features/0001-login-feature/research.md mit Dateiliste, Abhängigkeiten und Risiken",
        },
        "fragen": [
            {
                "typ": "mc",
                "frage": "Die Research-Phase ist abgeschlossen. Was darf der Entwickler in research.md als Fakt eintragen?",
                "optionen": [
                    "Nur Aussagen die durch Dateilesen bestätigt wurden, mit Datei:Zeile-Beleg",
                    "Alle Vermutungen und Hypothesen ohne Einschränkung",
                    "Nur Aussagen die der Tech-Lead genehmigt hat",
                    "Eine Zusammenfassung des KI-Chats",
                ],
                "richtig": "1",
                "feedback_richtig": (
                    "In SDD gilt: research.md unterscheidet strikt Fakten (mit Datei:Zeile-Beleg), "
                    "Hypothesen (explizit markiert) und Unbekannte. Nur Aussagen die durch Dateilesen "
                    "bestätigt wurden, gehören in den Fakten-Abschnitt."
                ),
                "feedback_falsch": (
                    "In SDD gilt: Hypothesen sind erlaubt, müssen aber explizit als solche markiert sein. "
                    "Eine Vermutung ohne Dateireferenz ist kein Fakt — auch wenn sie noch so plausibel klingt."
                ),
            },
        ],
    },
    {
        "name": "4 · Plan",
        "zweck": "Entscheide WIE es gebaut wird — Architekturentscheidungen und atomare Tasks.",
        "kernfrage": "Wie wird es gebaut? In welchen Scheiben? Wie prüfen wir jede?",
        "prompt": "Formuliere eine Architekturentscheidung: 'Wir verwenden X statt Y, weil…'",
        "interaktion": {
            "typ": "mc",
            "frage": (
                "Drei Tasks für das PromptAndPray-Login sind geplant:\n\n"
                "  T-A: Datenbank-Schema für Users anlegen\n"
                "  T-B: Login-Endpoint implementieren\n"
                "  T-C: Session-Token generieren\n\n"
                "Welche Reihenfolge ist korrekt, damit keine Task auf unfertige Abhängigkeiten trifft?"
            ),
            "optionen": [
                "T-A → T-C → T-B  (Schema, dann Token, dann Endpoint)",
                "T-B → T-A → T-C  (Endpoint zuerst, dann Rest)",
                "T-A → T-B → T-C  (Schema, dann Endpoint, dann Token)",
                "Alle gleichzeitig — Tasks sind unabhängig",
            ],
            "richtig": "3",
            "feedback_richtig": (
                "In SDD gilt: Tasks werden so geschnitten, dass jede Task auf abgeschlossenen "
                "Vorgängern aufbaut. T-A (Schema) muss vor T-B (Endpoint) fertig sein, "
                "weil der Endpoint die User-Tabelle braucht. T-C (Token) baut auf dem Endpoint auf. "
                "Diese Abhängigkeitskette heißt 'Depends-on' in tasks.md."
            ),
            "feedback_falsch": (
                "In SDD gilt: Abhängigkeiten bestimmen die Task-Reihenfolge. "
                "Der Login-Endpoint (T-B) braucht das Datenbank-Schema (T-A). "
                "Der Session-Token (T-C) braucht einen funktionierenden Endpoint (T-B). "
                "Richtige Reihenfolge: T-A → T-B → T-C."
            ),
        },
        "beispiel": {
            "po": "Keine Aufgabe in dieser Phase — Architektur und Aufgabenzerlegung sind reine Entwicklerarbeit.",
            "entwickler": "sdd plan create 0001-login-feature — trifft Architekturentscheidungen, genehmigt die Task-Liste bevor die Umsetzung startet",
            "claude": "Leitet aus research.md konkrete Architekturentscheidungen (AD-001 …) ab, zerlegt die Umsetzung in atomare, unabhängig prüfbare Tasks (T-001 …)",
            "artefakt": ".features/0001-login-feature/plan.md + tasks.md mit abhängigkeitsgeordneten Tasks",
        },
        "fragen": [
            {
                "typ": "mc",
                "frage": "Wann ist ein Task in tasks.md bereit für die Implementierung?",
                "optionen": [
                    "Wenn er einen Verifikationsbefehl hat, der nach Abschluss grün sein muss",
                    "Wenn der Entwickler ihn verstanden hat",
                    "Wenn er mindestens 5 Schritte beschreibt",
                    "Wenn der PO ihn genehmigt hat",
                ],
                "richtig": "1",
                "feedback_richtig": (
                    "In SDD gilt: Ein Task ist erst implementierbar wenn sein Verifikationsbefehl runnable ist — "
                    "er schlägt JETZT fehl und muss NACH dem Task grün sein. "
                    "Ohne messbares Done-Kriterium ist 'fertig' nicht beweisbar."
                ),
                "feedback_falsch": (
                    "In SDD gilt: Verstehen, Schrittanzahl und PO-Genehmigung ersetzen keinen lauffähigen "
                    "Verifikationsbefehl. Ohne ihn gibt es keine objektive Fertigstellungsbedingung — "
                    "'fertig' bleibt eine Behauptung."
                ),
            },
        ],
    },
    {
        "name": "5 · Implement",
        "zweck": "Baue genau einen Task auf einmal — nicht mehr, nicht weniger.",
        "kernfrage": "Ist die Verifikation für diesen Task grün? Dann erst: nächster Task.",
        "prompt": "Was ist das Verifikationskommando für deinen ersten Task?",
        "interaktion": {
            "typ": "mc",
            "frage": (
                "Max führt das Verifikationskommando für T-001 aus:\n\n"
                "  > py -c \"import auth; assert callable(auth.login)\"\n"
                "  AssertionError\n\n"
                "Was tut Max als nächstes?"
            ),
            "optionen": [
                "Root Cause suchen: auth.py lesen und verstehen warum login() fehlt",
                "Den Task als fertig markieren — der Code existiert irgendwo",
                "Mehr Code schreiben bis der Fehler verschwindet",
                "Das Verifikationskommando anpassen damit es passt",
            ],
            "richtig": "1",
            "feedback_richtig": (
                "In SDD gilt: Ein Task ist erst fertig wenn die Verifikation grün ist — "
                "nicht wenn der Code geschrieben wurde. "
                "Bei einem Fehler kommt zuerst die Ursachenanalyse, "
                "dann die chirurgische Korrektur. "
                "Das Verifikationskommando zu fälschen würde den Sinn von SDD zerstören."
            ),
            "feedback_falsch": (
                "In SDD gilt: 'Done' bedeutet Verifikation bestanden, nicht 'Code geschrieben'. "
                "Weder blind mehr Code schreiben noch das Kommando anpassen sind korrekt. "
                "Der einzige Weg: Root Cause verstehen, dann gezielt fixen."
            ),
        },
        "beispiel": {
            "po": "Keine Aufgabe in dieser Phase — der Plan ist freigegeben, die Umsetzung läuft.",
            "entwickler": "sdd task start 0001-login-feature T-001 — startet genau einen Task, prüft das Ergebnis, markiert ihn als erledigt, dann weiter mit T-002",
            "claude": "Implementiert Task für Task, führt nach jedem Task den Verifikationsbefehl aus und markiert erst dann done — kein Task gilt als fertig ohne bestandene Prüfung",
            "artefakt": "Geänderte Produktionsdateien (auth.py, forms.py …) + aktualisierter Task-Status in tasks.md",
        },
        "fragen": [
            {
                "typ": "mc",
                "frage": (
                    "Max hat Task T-002 fast fertig, sieht aber einen offensichtlichen Bug in T-001-Code. "
                    "Was tut er?"
                ),
                "optionen": [
                    "Er notiert den Bug im Scratchpad und meldet ihn — T-001 ist nicht sein aktiver Task",
                    "Er fixt den Bug direkt — es sind nur 2 Zeilen",
                    "Er pausiert T-002 und öffnet T-001 wieder",
                    "Er wartet bis Review und hofft dass der Reviewer es findet",
                ],
                "richtig": "1",
                "feedback_richtig": (
                    "In SDD gilt: Scope-Disziplin. Max darf nur Dateien im aktiven Task T-002 anfassen. "
                    "Den Bug in T-001 im Scratchpad notieren und dem Controller melden — "
                    "dann als neuer Task oder T-001-Reopen behandeln. "
                    "'Während ich hier bin' ist genau die Denkweise, die Scope-Drift erzeugt."
                ),
                "feedback_falsch": (
                    "In SDD gilt: Auch 2 Zeilen außerhalb des aktiven Tasks sind ein Scope-Verstoß. "
                    "Direktes Fixen ohne Taskzuordnung untergräbt die Traceability. "
                    "Pausieren und T-001 erneut öffnen entscheidet der Controller — nicht der Implementierer."
                ),
            },
        ],
    },
    {
        "name": "6 · Review",
        "zweck": "Prüfe unabhängig, ob der Code dem Spec entspricht — kein Selbst-Review.",
        "kernfrage": "Erfüllt der Code alle Akzeptanzkriterien? Gibt es Scope-Drift?",
        "prompt": "Welches AC würdest du als erstes prüfen, und wie?",
        "interaktion": {
            "typ": "mc",
            "frage": (
                "Das AC lautet: 'Gegeben ein ungültiges Passwort, wenn login() aufgerufen wird, "
                "dann gibt die Funktion False zurück.'\n\n"
                "Der Code tut: Bei falschem Passwort wird eine Exception geworfen.\n\n"
                "Wie lautet dein Review-Urteil?"
            ),
            "optionen": [
                "FAIL — der Code wirft eine Exception statt False zurückzugeben",
                "PASS — eine Exception ist auch eine Form von 'nicht eingeloggt'",
                "PASS — der Implementierer hat es sicher richtig gemeint",
                "HOLD — zuerst den Implementierer fragen was er beabsichtigt hat",
            ],
            "richtig": "1",
            "feedback_richtig": (
                "In SDD gilt: Review prüft den Code gegen den Spec — unabhängig und ohne Annahmen. "
                "Das AC sagt explizit 'gibt False zurück'. Eine Exception ist kein False. "
                "Das ist ein FAIL — klar, evidenzbasiert, ohne Interpretation. "
                "Der Reviewer vertraut dem Spec, nicht der Absicht des Implementierers."
            ),
            "feedback_falsch": (
                "In SDD gilt: Review ist keine Interpretationsübung. "
                "Das AC sagt 'False zurückgeben' — der Code wirft eine Exception. "
                "Das ist FAIL. Weder 'gut gemeint' noch Rückfragen ersetzen die Spec-Prüfung. "
                "Das SDD-Plugin enforced: Reviewer liest Spec, dann Code — in dieser Reihenfolge."
            ),
        },
        "beispiel": {
            "po": 'Prüft fachlich: "Ist das, was gebaut wurde, das was ich in Brief und Design gemeint habe?" — bestätigt oder meldet Abweichungen vom ursprünglichen Ziel',
            "entwickler": "sdd review 0001-login-feature — liest spec.md zuerst, prüft dann den Code gegen jeden AC, dokumentiert Befunde in review.md",
            "claude": "Validiert jeden AC mit Belegen aus dem Code, setzt verdict: pass oder fail mit Begründung — kein Verdict ohne gelesene Spec",
            "artefakt": ".features/0001-login-feature/review.md mit AC-Nachweisen und finalem Verdict",
        },
        "fragen": [
            {
                "typ": "mc",
                "frage": "Der Implementierer sagt: 'Ich habe AC-003 getestet, es läuft.' Was macht der Reviewer?",
                "optionen": [
                    "Er prüft AC-003 selbst mit Datei-Evidenz — 'ich habe getestet' ist kein Beweis",
                    "Er vertraut dem Implementierer und hakt AC-003 ab",
                    "Er fragt den Implementierer nach mehr Details",
                    "Er überspringt AC-003 und prüft die anderen",
                ],
                "richtig": "1",
                "feedback_richtig": (
                    "In SDD gilt: Review ist unabhängige Verifikation. 'Ich habe getestet' ist eine "
                    "Behauptung — kein Beweis. Der Reviewer liest die Spec, liest den Code, und findet "
                    "konkrete file:line-Evidenz oder führt den Verifikationsbefehl selbst aus."
                ),
                "feedback_falsch": (
                    "In SDD gilt: Der Reviewer vertraut keiner Behauptung ohne Beleg. "
                    "Rückfragen oder Überspringen ersetzen keine eigene Verifikation. "
                    "Jedes AC braucht Evidenz — das ist der Sinn von unabhängigem Review."
                ),
            },
        ],
    },
    {
        "name": "7 · Close",
        "zweck": "Sichere das gewonnene Wissen und schließe das Feature sauber ab.",
        "kernfrage": "Was haben wir gelernt? Was trägt ins nächste Feature?",
        "prompt": "Notiere einen Satz, den du ins KNOWLEDGE.md schreiben würdest.",
        "interaktion": {
            "typ": "mc",
            "frage": "Was gehört in die knowledge.md beim Abschluss eines Features?",
            "optionen": [
                "Wiederverwendbares Wissen: Muster, Stolpersteine, technische Entdeckungen",
                "Eine Zusammenfassung aller Tasks und ob sie bestanden haben",
                "Das Review-Verdict und die Namen der Reviewer",
                "Links zu allen Pull Requests und Commits des Features",
            ],
            "richtig": "1",
            "feedback_richtig": (
                "In SDD gilt: knowledge.md speichert dauerhaftes, wiederverwendbares Wissen — "
                "Muster die auch beim nächsten Feature gelten, Fallstricke die vermieden werden sollten, "
                "technische Entdeckungen die das Team nicht nochmal neu herausfinden soll. "
                "Task-Status, Review-Verdicts und Commits gehören ins Artifact-Log, nicht in Knowledge."
            ),
            "feedback_falsch": (
                "In SDD gilt: knowledge.md ist kein Protokoll — es ist ein Wissensspeicher. "
                "Weder Task-Status noch Review-Daten noch Commit-Links gehören hinein. "
                "Das SDD-Plugin graduiert nur Einträge die über das aktuelle Feature hinaus "
                "wertvoll sind: Muster, Gotchas, Erkenntnisse."
            ),
        },
        "beispiel": {
            "po": "Keine Aufgabe in dieser Phase — das Feature ist live, das Ziel ist erreicht.",
            "entwickler": "sdd close 0001-login-feature — bestätigt den Abschluss, prüft ob alle Erkenntnisse dokumentiert sind",
            "claude": "Promoviert wertvolle Erkenntnisse aus dem Scratchpad in KNOWLEDGE.md, finalisiert alle Artefakte, schließt das Feature ab",
            "artefakt": ".features/0001-login-feature/knowledge.md + abgeschlossene Feature-Artefakte",
        },
        "fragen": [
            {
                "typ": "mc",
                "frage": "Das Feature ist reviewed und abgenommen. Was ist KEIN Teil von Close?",
                "optionen": [
                    "Neue Anforderungen hinzufügen die beim Review aufgefallen sind",
                    "Erkenntnisse aus dem Scratchpad in KNOWLEDGE.md graduieren",
                    "`sdd close` ausführen um Artefakte zu finalisieren",
                    "Prüfen ob alle Tasks abgeschlossen sind",
                ],
                "richtig": "1",
                "feedback_richtig": (
                    "In SDD gilt: Close ist kein Ort für neuen Scope. Anforderungen die beim Review "
                    "auffallen, gehören in ein eigenes Feature via `sdd init`. "
                    "Close schließt ab — es erweitert nicht. Neuer Scope in Close umgeht "
                    "Brief, Design und Review."
                ),
                "feedback_falsch": (
                    "In SDD gilt: Knowledge-Graduation, `sdd close` ausführen und Task-Status prüfen "
                    "sind legitime Close-Aktivitäten. Neuer Scope dagegen gehört in ein neues Feature "
                    "mit vollständigem Artifact-Chain."
                ),
            },
        ],
    },
]


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
    interaktion = random.choice([phase["interaktion"]] + phase["fragen"])
    correct_text = interaktion["optionen"][int(interaktion["richtig"]) - 1]
    opts = interaktion["optionen"][:]
    random.shuffle(opts)
    interaktion = dict(interaktion, optionen=opts, richtig=str(opts.index(correct_text) + 1))
    points = ask_question(interaktion)
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
    if score > 6:
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
            f"  {GRAU}[ Enter — neu starten ]  [ d — Dokumentation öffnen ]  [ x — Ende ]{RESET}  "
        ).strip().lower()
        if antwort == "x":
            sys.exit(0)
        elif antwort == "d":
            import webbrowser as _wb
            import os as _os2
            _doc = _os2.path.join(_os2.path.dirname(_os2.path.abspath(__file__)), "dokumentation.html")
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
    if not os.path.exists(_MARKER):
        with open(_MARKER, "w"):
            pass


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
