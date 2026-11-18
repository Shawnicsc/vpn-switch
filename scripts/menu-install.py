#!/usr/bin/env python3
"""Insert or remove the vpn-switch menu block in an Omarchy menu JSONC file.

The file is a single JSON object with // comments. We intentionally do not try
to parse JSONC: the block is inserted right after the root '{', between stable
markers, so comments and user rows stay untouched.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

BEGIN = "  // >>> vpn-switch menu (managed by install.sh) >>>"
END = "  // <<< vpn-switch menu <<<"
BLOCK_RE = re.compile(
    r"[ \t]*// >>> vpn-switch menu \(managed by install\.sh\) >>>.*?// <<< vpn-switch menu <<<[ \t]*\n?[ \t]*,?\n?",
    re.S,
)


def fail(message: str) -> None:
    print(f"menu-install: {message}", file=sys.stderr)
    raise SystemExit(1)


def remove_block(text: str) -> tuple[str, bool]:
    new, count = BLOCK_RE.subn("", text)
    return new, count > 0


def insert_block(text: str, fragment: str) -> str:
    text, _ = remove_block(text)
    opening = text.find("{")
    if opening < 0:
        fail("menu file does not contain a root JSON object")

    head = text[: opening + 1]
    rest = text[opening + 1 :]
    block = f"\n{BEGIN}\n{fragment.strip()}\n{END}\n"
    if rest.strip().startswith("}") or rest.strip() == "":
        return head + block + rest.lstrip("\n")
    return head + block + ",\n" + rest.lstrip("\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("menu_file", type=Path)
    parser.add_argument("fragment", type=Path, nargs="?")
    parser.add_argument("--remove", action="store_true")
    args = parser.parse_args()

    if not args.menu_file.is_file():
        fail(f"menu file not found: {args.menu_file}")

    text = args.menu_file.read_text(encoding="utf-8")
    if args.remove:
        text, changed = remove_block(text)
        if changed:
            args.menu_file.write_text(text, encoding="utf-8")
        return

    if args.fragment is None:
        fail("fragment file is required unless --remove is used")
    if not args.fragment.is_file():
        fail(f"fragment not found: {args.fragment}")

    fragment = args.fragment.read_text(encoding="utf-8")
    args.menu_file.write_text(insert_block(text, fragment), encoding="utf-8")


if __name__ == "__main__":
    main()
