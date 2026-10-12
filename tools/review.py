"""Generate review.html showcasing the rendered drip tray views.

Usage: review.py MODEL.scad DIMENSIONS.echo OUTPUT.html
Screenshots are expected next to OUTPUT.html.
"""

import html
import re
import sys
from pathlib import Path

VIEWS = [
    ("assembly", "Assembly", "Tray with the grid inserted, grid top flush with the rim."),
    ("exploded", "Exploded", "Grid lifted out of the tray."),
    ("section", "Section", "Corner cut through a leg: wall, clearance, leg fillet, flush top."),
    ("tray", "Tray", "Outer tray with rounded corners and bottom edges."),
    ("grid", "Grid", "Insert in assembled orientation; the legs hide under the hex web."),
    ("grid_print", "Grid, print orientation", "Plate on the build plate, legs pointing up."),
]

PARAMETER = re.compile(r"^(\w+)\s*=\s*(.+?);\s*(?://\s*(.*))?$")
SECTION = re.compile(r"^/\* \[(.+)\] \*/$")
ECHO = re.compile(r"^ECHO: (.*)$")


def parameters(scad):
    """Customizer parameters as (section, name, value, comment), excluding View and Hidden."""
    section = None
    for line in scad.read_text().splitlines():
        if match := SECTION.match(line.strip()):
            section = match.group(1)
            if section == "Hidden":
                return
        elif section not in (None, "View") and (match := PARAMETER.match(line.strip())):
            yield (section, *match.groups(default=""))


def derived(echo):
    lines = [m.group(1) for m in map(ECHO.match, echo.read_text().splitlines()) if m]
    if not lines:
        sys.exit(f"{echo}: no ECHO output found")
    return re.split(r",\s*(?=\w+ = )", lines[0])


def render(scad, echo):
    rows = "\n".join(
        f"<tr><td>{html.escape(section)}</td><td><code>{html.escape(name)}</code></td>"
        f"<td><code>{html.escape(value)}</code></td><td>{html.escape(comment)}</td></tr>"
        for section, name, value, comment in parameters(scad)
    )
    facts = "\n".join(f"<li><code>{html.escape(fact)}</code></li>" for fact in derived(echo))
    figures = "\n".join(
        f'<figure><a href="{name}.png"><img src="{name}.png" alt="{html.escape(title)}"></a>'
        f"<figcaption><strong>{html.escape(title)}</strong> {html.escape(caption)}</figcaption></figure>"
        for name, title, caption in VIEWS
    )
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Drip Tray Review</title>
<style>
:root {{ --bg: #fafafa; --fg: #222; --muted: #666; --card: #fff; --line: #ddd; }}
@media (prefers-color-scheme: dark) {{
  :root {{ --bg: #16181c; --fg: #e6e6e6; --muted: #999; --card: #1f2227; --line: #333; }}
}}
body {{ margin: 0; padding: 24px 16px; background: var(--bg); color: var(--fg);
       font: 15px/1.5 system-ui, sans-serif; }}
main {{ max-width: 1200px; margin: 0 auto; }}
h1 {{ margin: 0 0 4px; }}
p.lead {{ margin: 0 0 24px; color: var(--muted); }}
.hero img {{ width: 100%; }}
.views {{ display: grid; gap: 16px; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); }}
figure {{ margin: 0 0 16px; background: var(--card); border: 1px solid var(--line); border-radius: 8px;
         overflow: hidden; }}
figure img {{ display: block; width: 100%; height: auto; }}
figcaption {{ padding: 8px 12px; color: var(--muted); }}
figcaption strong {{ color: var(--fg); margin-right: 4px; }}
.tables {{ display: grid; gap: 24px; grid-template-columns: 2fr 1fr; }}
@media (max-width: 800px) {{ .tables {{ grid-template-columns: 1fr; }} }}
.scroll {{ overflow-x: auto; }}
table {{ border-collapse: collapse; width: 100%; }}
th, td {{ text-align: left; padding: 6px 10px; border-bottom: 1px solid var(--line); }}
ul {{ padding-left: 20px; }}
</style>
</head>
<body>
<main>
<h1>Drip Tray</h1>
<p class="lead">Generated from <code>{html.escape(scad.name)}</code>.</p>
<div class="views">
{figures}
</div>
<div class="tables">
<section>
<h2>Parameters</h2>
<div class="scroll"><table>
<thead><tr><th>Group</th><th>Name</th><th>Value</th><th>Note</th></tr></thead>
<tbody>
{rows}
</tbody>
</table></div>
</section>
<section>
<h2>Derived</h2>
<ul>
{facts}
</ul>
</section>
</div>
</main>
</body>
</html>
"""


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    scad, echo, output = map(Path, sys.argv[1:])
    output.write_text(render(scad, echo))


if __name__ == "__main__":
    main()
