#!/usr/bin/env python3
"""Extract one version's section out of CHANGELOG.md as release notes.

Called by .github/workflows/release.yml, which needs the same section in two
shapes:

  --format markdown  the GitHub Release body
  --format html      Sparkle's <description>, which renders HTML

The HTML pass is the point of this file. Sparkle draws <description> as HTML in
its update window, so markdown handed over raw shows up as literal asterisks and
dashes -- which is what shipped up to v1.5.0, where the description was whatever
`gh release create --generate-notes` produced (a bare "Full Changelog" compare
link) rather than anything from the changelog.

Deliberately not using a markdown library: the runner has no third-party
packages installed, and the changelog only ever uses `###` headings, `-` bullets
with wrapped continuation lines, bold, inline code, and links. Converting that
subset by hand is smaller than vendoring a dependency for it.

Exits non-zero when the section is missing or empty, so a release fails loudly
instead of publishing an update whose notes are blank.
"""

import argparse
import html
import re
import sys

# Matches "## [1.5.0] - 2026-09-01" and "## [Unreleased]", capturing the label
# so the bracket form stays optional for hand-written sections.
HEADING = re.compile(r"^##\s+\[?([^\]\s]+)\]?(?:\s+-\s+(.*))?\s*$")


def extract(text: str, version: str) -> str:
    """Return the body of one `## [version]` section, headings included."""
    wanted = version.lstrip("v")
    lines = text.split("\n")

    start = None
    for i, line in enumerate(lines):
        m = HEADING.match(line)
        if m and m.group(1).lstrip("v") == wanted:
            start = i + 1
            break
    if start is None:
        return ""

    end = len(lines)
    for i in range(start, len(lines)):
        if HEADING.match(lines[i]):
            end = i
            break

    return "\n".join(lines[start:end]).strip()


def inline(text: str) -> str:
    """Escape HTML, then re-introduce the inline markdown subset as tags."""
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"\*([^*]+)\*", r"<em>\1</em>", out)
    # Links last: the label may itself have been marked up above.
    out = re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)", r'<a href="\2">\1</a>', out)
    return out


def to_html(section: str) -> str:
    """Convert the changelog subset to HTML.

    Bullets carry across lines in this changelog (entries are wrapped at ~80
    columns), so a continuation line -- indented, non-empty, not itself a bullet
    -- is folded into the open <li> rather than starting a new one.
    """
    blocks: list[str] = []
    items: list[str] = []

    def flush() -> None:
        if items:
            body = "".join(f"    <li>{inline(i)}</li>\n" for i in items)
            blocks.append(f"<ul>\n{body}</ul>")
            items.clear()

    for raw in section.split("\n"):
        line = raw.rstrip()

        if not line.strip():
            continue

        if line.startswith("### "):
            flush()
            blocks.append(f"<h3>{inline(line[4:].strip())}</h3>")
        elif line.lstrip().startswith("- "):
            items.append(line.lstrip()[2:].strip())
        elif items and raw.startswith((" ", "\t")):
            items[-1] += " " + line.strip()
        else:
            flush()
            blocks.append(f"<p>{inline(line.strip())}</p>")

    flush()
    return "\n".join(blocks)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--version", required=True, help="1.5.0, v1.5.0 or Unreleased")
    p.add_argument("--format", choices=("markdown", "html"), default="html")
    p.add_argument("--path", default="CHANGELOG.md")
    args = p.parse_args()

    try:
        with open(args.path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError as exc:
        print(f"error: cannot read {args.path}: {exc}", file=sys.stderr)
        return 1

    section = extract(text, args.version)
    if not section:
        print(
            f"error: CHANGELOG.md has no entries under [{args.version}].\n"
            "Add them before tagging -- an update with blank release notes tells\n"
            "the user nothing about what they are installing.",
            file=sys.stderr,
        )
        return 1

    print(section if args.format == "markdown" else to_html(section))
    return 0


if __name__ == "__main__":
    sys.exit(main())
