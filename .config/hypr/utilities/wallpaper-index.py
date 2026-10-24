#!/usr/bin/env python3
"""Builds the wallpaper picker index: thumbnails, a screen-sized copy and a pywal palette per image, cached."""
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
# Palettes come from the original image, like color-apply.sh, so the preview shows the colors applying gives.
PALETTES = CACHE / "palettes-full.json"
INDEX = CACHE / "index.json"
EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif"}


def write_atomic(path: Path, text: str) -> None:
    tmp = path.with_suffix(path.suffix + f".{os.getpid()}.tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


def key_for(path: Path) -> str:
    stat = path.stat()
    return hashlib.sha1(f"{path}:{stat.st_mtime_ns}:{stat.st_size}".encode()).hexdigest()


# Everything the picker shows of one wallpaper, made in a single ImageMagick run from one decode (large JPEGs are
# decoded at reduced size straight away):
#   thumb    640x360, the cards and the panel's blurred backdrop
#   screen   screen-sized JPEG, the full-screen preview (flipping through decodes it in a few milliseconds)
def make_assets(path: Path, key: str) -> tuple[Path, Path]:
    thumb, screen = THUMBS / f"{key}.jpg", THUMBS / f"{key}-s.jpg"
    files = [thumb, screen]
    if not all(f.exists() for f in files):
        tmp = [f.with_name(f"{f.stem}.{os.getpid()}.tmp{f.suffix}") for f in files]
        subprocess.run(
            ["magick", "-define", "jpeg:size=1920x1080", f"{path}[0]", "-auto-orient",
             "-thumbnail", "1920x1080^", "-write", "mpr:s", "-quality", "88", "-write", str(tmp[1]), "+delete",
             "mpr:s", "-thumbnail", "640x360^", "-gravity", "center", "-extent", "640x360",
             "-quality", "85", str(tmp[0])],
            check=True, capture_output=True,
        )
        for t, f in zip(tmp, files):
            os.replace(t, f)
    return thumb, screen


def make_palette(path: Path) -> list[str]:
    with tempfile.TemporaryDirectory() as out:
        subprocess.run(
            ["wal", "-i", str(path), "-n", "-s", "-t", "-e", "-q", "--cols16", "--out-dir", out],
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
            thumb, screen = make_assets(path, key)
            colors = palettes.get(key) or make_palette(path)
        except (subprocess.CalledProcessError, OSError, KeyError, ValueError) as err:
            print(f"skip {path}: {err}", file=sys.stderr)
            return None
        return key, {
            "path": str(path),
            "name": path.stem,
            "theme": path.parent.name,
            "thumb": str(thumb),
            "screen": str(screen),
            "colors": colors,
        }

    with ThreadPoolExecutor(max_workers=4) as pool:
        results = [r for r in pool.map(work, files) if r]

    # Cached files no longer used (wallpapers removed or changed, older formats) go, so the cache only ever holds
    # what is shown.
    live = {Path(v[f]).name for _, v in results for f in ("thumb", "screen")}
    for f in THUMBS.iterdir():
        if f.name not in live and ".tmp" not in f.name:
            f.unlink(missing_ok=True)

    write_atomic(PALETTES, json.dumps({k: v["colors"] for k, v in results}))
    (CACHE / "palettes.json").unlink(missing_ok=True)
    write_atomic(INDEX, json.dumps([v for _, v in results]))
    print(f"indexed {len(results)} wallpapers")


if __name__ == "__main__":
    main()
