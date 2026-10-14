#!/usr/bin/env python3
"""Builds the wallpaper picker index: thumbnails plus a pywal palette per image, cached."""
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

LIBRARY = Path(os.environ.get("WALLPAPER_LIBRARY", Path.home() / "wallpapers" / "library"))
CACHE = Path.home() / ".cache" / "wallpaper-picker"
THUMBS = CACHE / "thumbs"
PALETTES = CACHE / "palettes.json"
INDEX = CACHE / "index.json"
EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif"}


def write_atomic(path: Path, text: str) -> None:
    tmp = path.with_suffix(path.suffix + f".{os.getpid()}.tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


def key_for(path: Path) -> str:
    stat = path.stat()
    return hashlib.sha1(f"{path}:{stat.st_mtime_ns}:{stat.st_size}".encode()).hexdigest()


def make_thumb(path: Path, key: str) -> Path:
    thumb = THUMBS / f"{key}.jpg"
    if not thumb.exists():
        tmp = thumb.with_suffix(".tmp.jpg")
        subprocess.run(
            ["magick", f"{path}[0]", "-auto-orient", "-thumbnail", "640x360^",
             "-gravity", "center", "-extent", "640x360", "-quality", "85", str(tmp)],
            check=True, capture_output=True,
        )
        tmp.rename(thumb)
    return thumb


def make_palette(thumb: Path) -> list[str]:
    with tempfile.TemporaryDirectory() as out:
        subprocess.run(
            ["wal", "-i", str(thumb), "-n", "-s", "-t", "-e", "-q", "--cols16", "--out-dir", out],
            check=True, capture_output=True,
        )
        data = json.loads((Path(out) / "colors.json").read_text())
    return [data["colors"][f"color{i}"] for i in range(16)]


def main() -> None:
    THUMBS.mkdir(parents=True, exist_ok=True)
    palettes = json.loads(PALETTES.read_text()) if PALETTES.exists() else {}

    files = sorted(
        p for p in LIBRARY.glob("*/*") if p.is_file() and p.suffix.lower() in EXTENSIONS
    )

    def work(path: Path):
        key = key_for(path)
        try:
            thumb = make_thumb(path, key)
            colors = palettes.get(key) or make_palette(thumb)
        except (subprocess.CalledProcessError, OSError, KeyError, ValueError) as err:
            print(f"skip {path}: {err}", file=sys.stderr)
            return None
        return key, {
            "path": str(path),
            "name": path.stem,
            "theme": path.parent.name,
            "thumb": str(thumb),
            "colors": colors,
        }

    with ThreadPoolExecutor(max_workers=4) as pool:
        results = [r for r in pool.map(work, files) if r]

    write_atomic(PALETTES, json.dumps({k: v["colors"] for k, v in results}))
    write_atomic(INDEX, json.dumps([v for _, v in results]))
    print(f"indexed {len(results)} wallpapers")


if __name__ == "__main__":
    main()
