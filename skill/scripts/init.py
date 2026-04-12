#!/usr/bin/env python3
"""One-shot initializer — creates ~/.auto-apply/ and seeds it from templates.

This is the non-conversational path. Claude typically walks the user through
each field via the skill instructions (see references/initialization.md), but
if the user just wants the files seeded with defaults they can edit by hand,
this script does that.

Usage:
  python3 init.py              # Seed any missing files from templates, skip existing
  python3 init.py --force      # Overwrite everything with template defaults
  python3 init.py --only preferences  # Only seed the preferences file
"""

import argparse
import shutil
import sys
from pathlib import Path

TARGETS = {
    "profile": "profile.json",
    "preferences": "preferences.json",
    "applications": "applications.csv",
}


def main():
    parser = argparse.ArgumentParser(description="Initialize ~/.auto-apply from templates")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing files (default: skip existing)",
    )
    parser.add_argument(
        "--only",
        choices=sorted(TARGETS.keys()),
        default=None,
        help="Only initialize one target",
    )
    parser.add_argument(
        "--home",
        default=str(Path.home() / ".auto-apply"),
        help="Override the target directory (default: ~/.auto-apply)",
    )
    args = parser.parse_args()

    # Templates live alongside this script's parent directory: <skill>/templates/
    skill_dir = Path(__file__).resolve().parent.parent
    templates_dir = skill_dir / "templates"
    if not templates_dir.is_dir():
        print(f"error: templates directory not found at {templates_dir}", file=sys.stderr)
        sys.exit(1)

    target_dir = Path(args.home).expanduser()
    target_dir.mkdir(parents=True, exist_ok=True)

    to_init = [args.only] if args.only else list(TARGETS.keys())

    created = []
    skipped = []
    for key in to_init:
        filename = TARGETS[key]
        src = templates_dir / filename
        dst = target_dir / filename
        if dst.exists() and not args.force:
            skipped.append(str(dst))
            continue
        shutil.copy2(src, dst)
        created.append(str(dst))

    if created:
        print("Created:")
        for p in created:
            print(f"  {p}")
    if skipped:
        print("Skipped (already exists, use --force to overwrite):")
        for p in skipped:
            print(f"  {p}")

    if created and "profile.json" in "".join(created):
        print()
        print("Next: edit profile.json to fill in your real info.")
        print("  Required: name, email, phone, linkedin, resume_path")


if __name__ == "__main__":
    main()
