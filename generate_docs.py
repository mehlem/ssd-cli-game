"""
SDD CLI Game — Projektdokumentation generieren
Erzeugt dokumentation.html aus den .features/-Artefakten.
Aufruf: py generate_docs.py
"""
import os
import re

FEATURES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".features")
OUTPUT_FILE  = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dokumentation.html")

FEATURE_IDS = [
    "0001-sdd-cli-game",
    "0002-sdd-cli-game-interactive",
    "0003-game-phase-examples",
    "0004-frage-headline",
    "0005-score-basierter-ausgang",
    "0006-projekt-rename",
    "0007-zweites-frageset-shuffle",
    "0008-intro-ux-verbesserung",
    "0009-loading-animation-fix",
]

FEATURE_LABELS = {
    "0001-sdd-cli-game":               "0001 — SDD CLI Game (Grundgerüst)",
    "0002-sdd-cli-game-interactive":   "0002 — Interaktive Phasen-Engine",
    "0003-game-phase-examples":        "0003 — Phasen-Beispiel-Panels",
    "0004-frage-headline":             "0004 — Fragen-Headline",
    "0005-score-basierter-ausgang":    "0005 — Score-basierter Ausgang",
    "0006-projekt-rename":             "0006 — Projekt-Umbenennung",
    "0007-zweites-frageset-shuffle":   "0007 — Zweites Frageset + Shuffle",
    "0008-intro-ux-verbesserung":      "0008 — Intro UX Verbesserung",
    "0009-loading-animation-fix":      "0009 — Loading-Animation Fix",
}


def read_file(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return ""


def strip_frontmatter(text):
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            return text[end + 4:].strip()
    return text.strip()


def extract_section(text, heading):
    pattern = rf"##\s+{re.escape(heading)}\s*\n(.*?)(?=\n##\s|\Z)"
    m = re.search(pattern, text, re.DOTALL)
    return m.group(1).strip() if m else ""


def extract_acs(text):
    section = extract_section(text, "Acceptance Criteria")
    lines = [l.strip() for l in section.splitlines() if l.strip().startswith("- [")]
    return lines


def extract_frs(text):
    section = extract_section(text, "Functional Requirements")
    lines = [l.strip() for l in section.splitlines() if l.strip().startswith("- FR-")]
    return lines


def extract_tasks(text):
    tasks = []
    for m in re.finditer(r"##\s+(T-\d+):\s*(.+?)\n.*?>\s*Status:\s*(\w+)", text, re.DOTALL):
        tasks.append((m.group(1), m.group(2).strip(), m.group(3).strip()))
    return tasks


def extract_verdict(text):
    m = re.search(r"verdict:\s*(\w+)", text)
    return m.group(1) if m else "pending"


def extract_problem(text):
    return extract_section(text, "Problem")


def extract_solution(text):
    return extract_section(text, "Solution")


def md_to_html_line(line):
    line = re.sub(r"`([^`]+)`", r"<code>\1</code>", line)
    line = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", line)
    return line


def build_feature_html(fid):
    base = os.path.join(FEATURES_DIR, fid)
    spec        = strip_frontmatter(read_file(os.path.join(base, "spec.md")))
    brief       = strip_frontmatter(read_file(os.path.join(base, "brief.md")))
    tasks       = strip_frontmatter(read_file(os.path.join(base, "tasks.md")))
    review_raw  = read_file(os.path.join(base, "review.md"))
    review      = strip_frontmatter(review_raw)

    label   = FEATURE_LABELS.get(fid, fid)
    verdict = extract_verdict(review_raw)
    problem = extract_problem(spec) or extract_section(brief, "Problem")
    solution = extract_solution(spec)
    frs     = extract_frs(spec)
    acs     = extract_acs(spec)
    task_list = extract_tasks(tasks)

    verdict_class = "verdict-pass" if verdict == "pass" else "verdict-pending"
    verdict_text  = "✓ PASS" if verdict == "pass" else f"⏳ {verdict}"

    html = f'<section class="feature" id="{fid}">\n'
    html += f'  <h2>{label} <span class="{verdict_class}">{verdict_text}</span></h2>\n'

    if problem:
        html += '  <div class="block">\n'
        html += '    <h3>Problem</h3>\n'
        html += f'    <p>{md_to_html_line(problem[:500])}</p>\n'
        html += '  </div>\n'

    if solution:
        html += '  <div class="block">\n'
        html += '    <h3>Lösung</h3>\n'
        html += f'    <p>{md_to_html_line(solution[:500])}</p>\n'
        html += '  </div>\n'

    if frs:
        html += '  <div class="block">\n'
        html += '    <h3>Funktionale Anforderungen</h3>\n'
        html += '    <ul>\n'
        for fr in frs:
            html += f'      <li>{md_to_html_line(fr.lstrip("- "))}</li>\n'
        html += '    </ul>\n'
        html += '  </div>\n'

    if acs:
        html += '  <div class="block">\n'
        html += '    <h3>Akzeptanzkriterien</h3>\n'
        html += '    <ul>\n'
        for ac in acs:
            status_icon = "✓" if "- [x]" in ac else "○"
            text = re.sub(r"^-\s*\[.\]\s*", "", ac)
            html += f'      <li><span class="ac-icon">{status_icon}</span> {md_to_html_line(text)}</li>\n'
        html += '    </ul>\n'
        html += '  </div>\n'

    if task_list:
        html += '  <div class="block">\n'
        html += '    <h3>Tasks</h3>\n'
        html += '    <table>\n'
        html += '      <tr><th>Task</th><th>Titel</th><th>Status</th></tr>\n'
        for tid, title, status in task_list:
            status_class = "status-done" if status == "completed" else "status-open"
            html += f'      <tr><td><code>{tid}</code></td><td>{md_to_html_line(title)}</td><td class="{status_class}">{status}</td></tr>\n'
        html += '    </table>\n'
        html += '  </div>\n'

    html += '</section>\n'
    return html


def build_html(features_html):
    nav_items = ""
    for fid in FEATURE_IDS:
        label = FEATURE_LABELS.get(fid, fid)
        nav_items += f'    <li><a href="#{fid}">{label}</a></li>\n'

    return f"""<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SDD CLI Game — Projektdokumentation</title>
<style>
  :root {{
    --bg: #0f1117;
    --surface: #1a1d27;
    --border: #2d3142;
    --accent: #006FB9;
    --accent2: #00a3ff;
    --text: #e2e8f0;
    --muted: #8892a4;
    --pass: #22c55e;
    --pending: #f59e0b;
    --code-bg: #252836;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ background: var(--bg); color: var(--text); font-family: 'Segoe UI', system-ui, sans-serif; display: flex; min-height: 100vh; }}

  nav {{
    width: 280px; min-width: 280px; background: var(--surface); border-right: 1px solid var(--border);
    padding: 2rem 0; position: sticky; top: 0; height: 100vh; overflow-y: auto;
  }}
  nav h1 {{ font-size: 0.85rem; font-weight: 700; letter-spacing: 0.1em; text-transform: uppercase;
             color: var(--accent2); padding: 0 1.5rem; margin-bottom: 1.5rem; }}
  nav ul {{ list-style: none; }}
  nav li a {{ display: block; padding: 0.45rem 1.5rem; font-size: 0.82rem; color: var(--muted);
              text-decoration: none; border-left: 3px solid transparent; transition: all 0.15s; }}
  nav li a:hover {{ color: var(--text); border-left-color: var(--accent); background: rgba(0,111,185,0.08); }}

  main {{ flex: 1; padding: 3rem; max-width: 900px; }}

  .intro {{ background: var(--surface); border: 1px solid var(--border); border-radius: 8px;
            padding: 2rem; margin-bottom: 3rem; }}
  .intro h1 {{ font-size: 1.8rem; color: var(--accent2); margin-bottom: 0.75rem; }}
  .intro p {{ color: var(--muted); line-height: 1.7; margin-bottom: 0.75rem; }}
  .intro code {{ background: var(--code-bg); padding: 0.15rem 0.4rem; border-radius: 4px;
                 font-size: 0.85rem; color: var(--accent2); }}
  .intro .artifact-grid {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; margin-top: 1rem; }}
  .artifact-badge {{ background: var(--code-bg); border: 1px solid var(--border); border-radius: 6px;
                     padding: 0.5rem 0.75rem; font-size: 0.8rem; color: var(--accent2); text-align: center; }}

  .feature {{ background: var(--surface); border: 1px solid var(--border); border-radius: 8px;
              padding: 2rem; margin-bottom: 2rem; }}
  .feature h2 {{ font-size: 1.15rem; color: var(--text); margin-bottom: 1.25rem;
                 display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 0.5rem; }}
  .feature .block {{ margin-bottom: 1.25rem; }}
  .feature h3 {{ font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.08em;
                 color: var(--muted); margin-bottom: 0.6rem; }}
  .feature p {{ color: var(--muted); line-height: 1.65; font-size: 0.9rem; }}
  .feature ul {{ list-style: none; padding: 0; }}
  .feature ul li {{ font-size: 0.88rem; color: var(--muted); padding: 0.3rem 0; border-bottom: 1px solid var(--border); }}
  .feature ul li:last-child {{ border-bottom: none; }}
  .ac-icon {{ color: var(--pass); margin-right: 0.4rem; font-weight: bold; }}
  code {{ background: var(--code-bg); padding: 0.12rem 0.35rem; border-radius: 3px; font-size: 0.82rem; color: var(--accent2); }}
  table {{ width: 100%; border-collapse: collapse; font-size: 0.85rem; }}
  th {{ text-align: left; padding: 0.5rem; background: var(--code-bg); color: var(--muted); font-weight: 600; }}
  td {{ padding: 0.45rem 0.5rem; border-bottom: 1px solid var(--border); color: var(--muted); }}

  .verdict-pass {{ background: rgba(34,197,94,0.15); color: var(--pass); padding: 0.2rem 0.6rem;
                   border-radius: 99px; font-size: 0.78rem; font-weight: 700; white-space: nowrap; }}
  .verdict-pending {{ background: rgba(245,158,11,0.15); color: var(--pending); padding: 0.2rem 0.6rem;
                      border-radius: 99px; font-size: 0.78rem; font-weight: 700; white-space: nowrap; }}
  .status-done {{ color: var(--pass); }}
  .status-open {{ color: var(--pending); }}

  footer {{ margin-top: 3rem; padding-top: 1.5rem; border-top: 1px solid var(--border);
            font-size: 0.8rem; color: var(--muted); text-align: center; }}
</style>
</head>
<body>
<nav>
  <h1>SDD CLI Game</h1>
  <ul>
    <li><a href="#intro">Einführung</a></li>
{nav_items}  </ul>
</nav>
<main>
  <div class="intro" id="intro">
    <h1>SDD CLI Game — Projektdokumentation</h1>
    <p>
      Dieses Dokument zeigt wie das SDD CLI Game selbst mit
      <strong>Spec-Driven Development (SDD)</strong> entwickelt wurde.
      Jedes der 9 Features durchlief die vollständige Artifact-Chain:
    </p>
    <div class="artifact-grid">
      <div class="artifact-badge">brief.md<br><small>WHY</small></div>
      <div class="artifact-badge">spec.md<br><small>WHAT</small></div>
      <div class="artifact-badge">research.md<br><small>WHERE</small></div>
      <div class="artifact-badge">plan.md<br><small>HOW</small></div>
      <div class="artifact-badge">tasks.md<br><small>DO</small></div>
      <div class="artifact-badge">review.md<br><small>VERIFY</small></div>
    </div>
    <p style="margin-top:1rem;">
      Die SDD-Artefakte jedes Features enthalten die vollständige fachliche Dokumentation.
      <code>sdd archive &lt;feature&gt;</code> generiert je Feature eine README.md und DOCS.md.
      Der vollständige Workflow: <code>Brief → Design → Research → Plan → Implement → Review → Close</code>
    </p>
  </div>
{features_html}
  <footer>Generiert mit generate_docs.py · SDD CLI Game · PTA GmbH</footer>
</main>
</body>
</html>
"""


if __name__ == "__main__":
    features_html = ""
    for fid in FEATURE_IDS:
        features_html += build_feature_html(fid)
    html = build_html(features_html)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"OK — dokumentation.html generiert ({len(html):,} Zeichen)")
