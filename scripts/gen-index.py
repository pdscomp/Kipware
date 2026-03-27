#!/usr/bin/env python3
"""
gen-index.py — Generate nginx-style autoindex HTML files for Kipware GH Pages.

Subcommands:
  root <output>          Write the top-level /Kipware/ index (main/ and kip/).
  tree <pages_dir> <feed_name>
                         Walk pages_dir and write index.html for every directory
                         that does not already have one, including the root which
                         lists feed_name/ as its sole child.
"""

import datetime
import os
import sys
from html import escape
from pathlib import Path

MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
NAME_WIDTH = 51   # nginx autoindex column width

ROOT_BRANCHES = [
    ("kip/",  "kip/"),
    ("main/", "main/"),
]


# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

def fmt_date(ts: float) -> str:
    d = datetime.datetime.utcfromtimestamp(ts)
    return f"{d.day:02d}-{MONTHS[d.month - 1]}-{d.year} {d.hour:02d}:{d.minute:02d}"


def fmt_now() -> str:
    return fmt_date(datetime.datetime.utcnow().timestamp())


def fmt_size(path: Path) -> str:
    return '-' if path.is_dir() else str(path.stat().st_size)


def entry_line(href: str, name: str, date_str: str, size_str: str = '-') -> str:
    if len(name) > NAME_WIDTH:
        visible = name[:NAME_WIDTH - 3] + "..>"
    else:
        visible = name
    padding = " " * (NAME_WIDTH - len(visible))
    size_col = size_str.rjust(20)
    return (f'<a href="{escape(href, quote=True)}">'
            f'{escape(visible)}</a>{padding}{date_str}{size_col}')


def build_page(title: str, parent_href: "Optional[str]", entry_lines: "List[str]") -> str:
    lines = [
        "<!doctype html>",
        "<html>",
        f"<head><title>Index of {escape(title)}</title></head>",
        "<body>",
        f"<h1>Index of {escape(title)}</h1><hr><pre>",
    ]
    if parent_href is not None:
        lines.append(f'<a href="{escape(parent_href, quote=True)}">../</a>')
    lines.extend(entry_lines)
    lines += ["</pre><hr></body>", "</html>", ""]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

def cmd_root(output_path: str) -> None:
    """Write the top-level /Kipware/ index listing main/ and kip/."""
    now = fmt_now()
    lines = [entry_line(href, name, now) for href, name in ROOT_BRANCHES]
    page = build_page("/Kipware/", None, lines)
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    Path(output_path).write_text(page)


def cmd_tree(pages_dir: str, feed_name: str) -> None:
    """Walk pages_dir and write a missing index.html for every directory."""
    root = Path(pages_dir).resolve()

    # Root of the pages tree: list the feed subdirectory
    feed_path = root / feed_name
    root_index = root / "index.html"
    if not root_index.exists() and feed_path.is_dir():
        lines = [entry_line(f"{feed_name}/", f"{feed_name}/",
                            fmt_date(feed_path.stat().st_mtime))]
        root_index.write_text(build_page(f"/{feed_name}/", None, lines))

    # All other subdirectories
    for directory in sorted(p for p in root.rglob("*") if p.is_dir()):
        index_path = directory / "index.html"
        if index_path.exists():
            continue
        rel = directory.relative_to(root)
        title = "/" + rel.as_posix() + "/"
        children = sorted(directory.iterdir(),
                          key=lambda p: (not p.is_dir(), p.name.lower()))
        lines = [
            entry_line(
                c.name + ("/" if c.is_dir() else ""),
                c.name + ("/" if c.is_dir() else ""),
                fmt_date(c.stat().st_mtime),
                fmt_size(c),
            )
            for c in children
        ]
        index_path.write_text(build_page(title, "../", lines))


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def usage() -> None:
    print(__doc__, file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        usage()
    sub = sys.argv[1]
    if sub == "root" and len(sys.argv) == 3:
        cmd_root(sys.argv[2])
    elif sub == "tree" and len(sys.argv) == 4:
        cmd_tree(sys.argv[2], sys.argv[3])
    else:
        usage()
