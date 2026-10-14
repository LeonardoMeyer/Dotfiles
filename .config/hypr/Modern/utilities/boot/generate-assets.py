#!/usr/bin/env python3
"""Render the static images of the boot splash from a Pywal palette.

usage: generate-assets.py PALETTE_CONF OUTPUT_DIR [PREVIEW_PNG]
PALETTE_CONF holds lines of the form colorN=#rrggbb (N = 0..15).
Keep the layout constants in sync with retro-modern-arch.script.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1920, 1080          # reference screen
CW, CH = 960, 548          # card size
M = 90                     # transparent margin around the card for the shadow
R = 28                     # card corner radius
PAD = 56
SS = 4                     # supersampling for shapes

BOLD_FONTS = [
    "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf",
    "/usr/share/fonts/TTF/JetBrainsMonoNLNerdFont-Bold.ttf",
    "/usr/share/fonts/TTF/DejaVuSansMono-Bold.ttf",
    "/usr/share/fonts/dejavu/DejaVuSansMono-Bold.ttf",
]
REG_FONTS = [f.replace("-Bold", "-Regular") for f in BOLD_FONTS[:2]] + [
    "/usr/share/fonts/TTF/DejaVuSansMono.ttf",
    "/usr/share/fonts/dejavu/DejaVuSansMono.ttf",
]


def font(candidates, size):
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def load_palette(path):
    pal = {}
    for line in Path(path).read_text().splitlines():
        if line.startswith("color") and "=" in line:
            key, value = line.strip().split("=", 1)
            h = value.lstrip("#")
            pal[int(key[5:])] = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    if len(pal) != 16:
        sys.exit("generate-assets: expected 16 colors in " + path)
    return pal


def mix(a, b, t):
    return tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))


def lighten(c, t):
    return mix(c, (255, 255, 255), t)


def rgba(c, alpha):
    return (c[0], c[1], c[2], round(255 * alpha))


def rounded_mask(size, radius, box=None):
    w, h = size
    m = Image.new("L", (w * SS, h * SS), 0)
    x0, y0, x1, y1 = box if box else (0, 0, w, h)
    ImageDraw.Draw(m).rounded_rectangle(
        (x0 * SS, y0 * SS, x1 * SS - 1, y1 * SS - 1), radius * SS, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def make_background(pal):
    return Image.new("RGB", (W, H), mix(pal[0], (0, 0, 0), 0.5))


def spaced_text(draw, xy, text, fnt, fill, spacing):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=fnt, fill=fill)
        x += draw.textlength(ch, font=fnt) + spacing
    return x


def make_card(pal, bg):
    left, top = (W - CW) // 2, (H - CH) // 2
    blurred = bg.filter(ImageFilter.GaussianBlur(28)).convert("RGBA")
    glass = blurred.crop((left, top, left + CW, top + CH))
    glass = Image.alpha_composite(glass, Image.new("RGBA", glass.size, rgba(pal[15], 0.055)))
    sheen = Image.new("RGBA", glass.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sheen)
    for y in range(CH // 2):
        sd.line((0, y, CW, y), fill=rgba((255, 255, 255), 0.07 * (1 - y / (CH / 2))))
    glass = Image.alpha_composite(glass, sheen)

    canvas = Image.new("RGBA", (CW + 2 * M, CH + 2 * M), (0, 0, 0, 0))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 150), (M, M + 26), rounded_mask((CW, CH), R))
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(34)))
    card = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    card.paste(glass, (M, M), rounded_mask((CW, CH), R))
    canvas = Image.alpha_composite(canvas, card)

    # Static content is drawn supersampled on its own layer.
    layer = Image.new("RGBA", (CW * SS, CH * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    def S(v):
        return round(v * SS)

    def rr(x0, y0, x1, y1, r, fill=None, outline=None, width=1):
        d.rounded_rectangle((S(x0), S(y0), S(x1) - 1, S(y1) - 1), S(r),
                            fill=fill, outline=outline, width=width * SS if outline else 0)

    # Card border: bright on top, faint at the bottom.
    ring = Image.new("L", (CW * SS, CH * SS), 0)
    ImageDraw.Draw(ring).rounded_rectangle((0, 0, CW * SS - 1, CH * SS - 1), S(R), outline=255, width=S(1.5))
    fade = np.linspace(0.32, 0.10, CH * SS, dtype=np.float32)[:, None]
    border_a = np.asarray(ring, dtype=np.float32) * fade
    border = Image.new("RGBA", ring.size, (255, 255, 255, 0))
    border.putalpha(Image.fromarray(border_a.astype(np.uint8), "L"))
    layer = Image.alpha_composite(layer, border)
    d = ImageDraw.Draw(layer)

    # ASCII Arch logo + brand
    accent = pal[13]
    logo = [
        "      /\\      ",
        "     /  \\     ",
        "    /\\   \\    ",
        "   /      \\   ",
        "  /   ,,   \\  ",
        " /   |  |  -\\ ",
        "/_-''    ''-_\\",
    ]
    logo_font = font(BOLD_FONTS, S(18))
    line_h = 21
    for i, row in enumerate(logo):
        d.text((S(PAD), S(44 + i * line_h)), row, font=logo_font, fill=rgba(accent, 1))
    bx = PAD + 250
    spaced_text(d, (S(bx), S(66)), "ARCH LINUX", font(BOLD_FONTS, S(34)), rgba(pal[15], 1), S(3))
    spaced_text(d, (S(bx), S(118)), "booting system", font(REG_FONTS, S(16)), rgba(pal[7], 0.8), S(1))
    d.text((S(bx), S(150)), "-" * 28, font=font(REG_FONTS, S(16)), fill=rgba(pal[8], 0.8))

    # Terminal panel
    px0, py0, px1, py1 = PAD, 206, CW - PAD, 372
    rr(px0, py0, px1, py1, 14, fill=(0, 0, 0, 82), outline=rgba((255, 255, 255), 0.08))
    d.text((S(px0 + 20), S(py0 + 11)), "# system log", font=font(REG_FONTS, S(13)), fill=rgba(pal[8], 1))
    tag_font = font(REG_FONTS, S(13))
    tag = "journalctl -f"
    d.text((S(px1 - 20) - d.textlength(tag, font=tag_font), S(py0 + 11)), tag,
           font=tag_font, fill=rgba(pal[7], 0.7))
    d.line((S(px0 + 1), S(py0 + 40), S(px1 - 1), S(py0 + 40)), fill=rgba((255, 255, 255), 0.07), width=S(1))
    # Prompt chevron next to the newest line
    cy = py0 + 124
    d.line((S(px0 + 24), S(cy - 8), S(px0 + 33), S(cy)), fill=rgba(accent, 1), width=S(3))
    d.line((S(px0 + 33), S(cy), S(px0 + 24), S(cy + 8)), fill=rgba(accent, 1), width=S(3))

    # Palette strip: square blocks
    sw, gap, sy = 22, 14, 470
    for i in range(16):
        x = PAD + i * (sw + gap)
        rr(x, sy, x + sw, sy + sw, 3, fill=rgba(pal[i], 1), outline=rgba((255, 255, 255), 0.18))
    lab_font = font(BOLD_FONTS, S(13))
    label = "PYWAL"
    lw = sum(d.textlength(c, font=lab_font) + S(3) for c in label) - S(3)
    spaced_text(d, (S(CW - PAD) - lw, S(sy + 4)), label, lab_font, rgba(pal[8], 1), S(3))

    layer = layer.resize((CW, CH), Image.LANCZOS)
    canvas.alpha_composite(layer, (M, M))
    return canvas


def main():
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    pal = load_palette(sys.argv[1])
    out = Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    bg = make_background(pal)
    card = make_card(pal, bg)
    card.save(out / "card.png", optimize=True)
    if len(sys.argv) == 4:
        prev = bg.convert("RGBA")
        prev.alpha_composite(card, ((W - card.width) // 2, (H - card.height) // 2))
        prev.convert("RGB").save(sys.argv[3])


if __name__ == "__main__":
    main()
