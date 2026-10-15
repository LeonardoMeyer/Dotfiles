#!/usr/bin/env python3
"""Renumber files in each category folder as <prefix>-NN.<ext> with no gaps.

Files keep their existing relative order (by number in the name, then by name);
files with bad names are placed after the correctly numbered ones.
Usage: python3 fix_names.py [--dry-run]
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"}


def sort_key(path, prefix):
    m = re.fullmatch(rf"{prefix}-(\d+)", path.stem, re.IGNORECASE)
    return (0, int(m.group(1)), path.name) if m else (1, 0, path.name.lower())


def fix_folder(folder, dry_run):
    prefix = folder.name[:3]
    files = [f for f in folder.iterdir() if f.is_file() and f.suffix.lower() in IMAGE_EXTS]
    files.sort(key=lambda f: sort_key(f, prefix))
    width = max(2, len(str(len(files))))

    plan = []
    for i, f in enumerate(files, 1):
        new = f.with_name(f"{prefix}-{i:0{width}d}{f.suffix.lower()}")
        if new != f:
            plan.append((f, new))

    for old, new in plan:
        print(f"{folder.name}: {old.name} -> {new.name}")
    if dry_run or not plan:
        return

    # Two phases so renames never overwrite a file that hasn't moved yet.
    temps = []
    for old, new in plan:
        tmp = old.with_name(f".tmp_{old.name}")
        old.rename(tmp)
        temps.append((tmp, new))
    for tmp, new in temps:
        tmp.rename(new)


def main():
    dry_run = "--dry-run" in sys.argv
    for folder in sorted(p for p in ROOT.iterdir() if p.is_dir() and not p.name.startswith(".")):
        fix_folder(folder, dry_run)
    print("Done." if not dry_run else "Dry run only; no changes made.")


if __name__ == "__main__":
    main()
