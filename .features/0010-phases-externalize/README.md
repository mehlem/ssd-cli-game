# PHASES-Daten in externe JSON-Datei auslagern

## Problem

Die Spielphasendaten des SDD-CLI-Games waren als ~450-Zeilen-Python-Literal `PHASES = [...]`
direkt in `game.py` (Zeilen 339–783) eingebettet. Jede inhaltliche Korrektur — eine
Frageformulierung, ein Feedback-Text, ein Rollenbeispiel — erforderte das Bearbeiten von
Produktionscode mit Python-Syntaxkenntnissen. Content-Pflege und Programmlogik waren unnötig
verflochten. Das Risiko, beim Bearbeiten eines Textes versehentlich die Python-Struktur zu
beschädigen, war real.

## Solution

Die sieben Spielphasen wurden in eine neue Datei `phases.json` (UTF-8, ~25 KB) neben `game.py`
ausgelagert. `game.py` lädt die Phasendaten beim Start einmalig per `json.load()`. Fehlt
`phases.json`, bricht das Programm mit einer verständlichen Fehlermeldung auf stderr ab (Exit-Code 1).
Für den Spieler ändert sich das Verhalten nicht. Die Implementierung nutzt ausschließlich
Python-stdlib (`json`-Modul) — kein pip-Paket.

Review-Verdict: **pass** (sdd-spec-reviewer + sdd-quality-reviewer, Commit `1b4d14e`).
Alle vier Acceptance Criteria wurden bestätigt.

## Key Decisions

**JSON statt YAML.** YAML wurde als Alternativformat in den Non-Goals explizit ausgeschlossen.
JSON ist in der Python-stdlib direkt verfügbar, benötigt kein pip-Paket, und der bestehende
Content enthält keine Multiline-Blöcke, für die YAML einen Darstellungsvorteil hätte.

**`__file__`-relativer Pfad statt `cwd`.** Der Loader konstruiert den Pfad mit
`os.path.join(os.path.dirname(os.path.abspath(__file__)), "phases.json")`. Die Alternative
— `open("phases.json")` relativ zum Arbeitsverzeichnis — würde fehlschlagen, wenn das Spiel
aus einem anderen Verzeichnis gestartet wird. Das `__file__`-Pattern macht den Loader
pfadunabhängig.

**Modulebene statt Lazy-Loading.** `PHASES` wird auf Modulebene geladen, nicht innerhalb
einer Funktion. Die Alternative (Lazy-Loading in `main()`) hätte erfordert, `PHASES` als
Parameter durch alle aufrufenden Funktionen zu schleusen oder als Global erst spät zu setzen.
Da `PHASES` in `run_phase()`, `show_summary()` und `main()` benötigt wird, ist das
Einmal-Laden auf Modulebene das sauberste Pattern.

**AST-Extraktion statt direktem Import für T-001.** Beim Erzeugen von `phases.json` aus dem
alten Literal wurde `ast.literal_eval()` verwendet, nicht `import game`. Der direkte Import
wäre wegen ANSI-Sequenzen und `os.system()`-Aufrufen auf Modulebene riskant gewesen — der
AST-Parse führt keinen Code aus.

**Nur `FileNotFoundError` abgefangen.** Ein invalides `phases.json` wirft
`json.JSONDecodeError`, der als unbehandelter Traceback propagiert. Die Alternative — beide
Fälle abdecken — war Spec-Non-Goal: JSON-Schema-Validierung und robuste Fehlerbehandlung
für korrupte Dateien sind bewusst ausgeschlossen. Das Finding wurde als bekannte Limitation
in knowledge.md (K-003) dokumentiert.

## Outcome

Alle vier Acceptance Criteria bestanden ohne Einschränkung:

| AC | Ergebnis |
|:---|:---------|
| AC-001: 7 Phasen korrekt geladen | PASS |
| AC-002: Fehlermeldung + Exit 1 bei fehlendem File | PASS |
| AC-003: Geänderter Text erscheint sofort beim nächsten Start | PASS |
| AC-004: Kein `PHASES = [...]`-Literal mehr in game.py | PASS |

`game.py` schrumpfte von 43.215 auf 17.837 Zeichen (-58 %). Der einzige Minor-Befund
(unbehandelter `json.JSONDecodeError`) wurde adjudiziert: kein Blocker, außerhalb Spec-Scope,
als K-003 dokumentiert.

## Lessons Learned

**AST-Parse schützt vor Side-Effects.** `ast.literal_eval()` ist der sichere Weg, um
Python-Datenstrukturen aus Quelldateien zu extrahieren, wenn der betreffende Code auf
Modulebene Side-Effects hat (ANSI-Ausgabe, `os.system()`-Aufrufe). Ein direkter Import
hätte diese Side-Effects ausgelöst (K-001).

**F-Strings akzeptieren keine Literal-`\n`.** Der ursprüngliche Loader-Code enthielt
`f"...\n..."` mit einem echten Zeilenumbruch im String-Literal — das erzeugt
`SyntaxError: unterminated f-string literal`. Die Meldung wurde auf einen einzeiligen
String umgestellt (K-002).

**Scope-Refresh nach Edits.** Nach dem ersten Edit an `game.py` musste der SDD-Scope-Refresh
zweimal ausgeführt werden — einmal nach dem initialen Edit, einmal nach der Korrektur des
F-String-Fehlers. Das ist ein normaler Workflow-Schritt, nicht ein Fehler.

## Further Reading

- [DOCS.md](DOCS.md) — Technische Referenz: Loader-Code, phases.json-Schema, Fehlerverhalten, Erweiterungshinweise
- [spec.md](spec.md) — Anforderungen, Acceptance Criteria, Constraints, Non-Goals
- [tasks.md](tasks.md) — Aufgabenplanung (T-001: JSON erzeugen, T-002: Loader einbauen) mit Verifikationsbefehlen
- [review.md](review.md) — Vollstaendige AC-Validierung, Code-Quality-Checks, Adjudication der Minor-Findings
- [scratchpad.md](scratchpad.md) — Implementierungsnotizen (AST-Extraktion, F-String-Fehler, scope-refresh)
- [knowledge.md](knowledge.md) — Drei graduierte Erkenntnisse (K-001 AST, K-002 F-String, K-003 JSONDecodeError)
