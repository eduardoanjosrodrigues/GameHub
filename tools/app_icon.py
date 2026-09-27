#!/usr/bin/env python3
"""Gera os PNGs do ícone do app a partir da arte do Nano Banana (docs/app_icon_prompts.md).

Lê art_originais/app_icon/app_icon_art.{png,jpg} (fora do APK), separa o fundo liso (preenchimento a partir dos cantos) e
encaixa o desenho na área que o Android nunca recorta: um círculo de 61% do lado no ícone adaptativo.
O fundo adaptativo é a cor lisa da própria arte. Sem a arte, rode tools/render_icons.gd (SVGs).
Uso: python3 tools/app_icon.py [--preview pasta]
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageStat

ROOT = Path(__file__).resolve().parent.parent
STORE = ROOT / "design/store"
SENTINEL = (255, 0, 255)


def load_art() -> Image.Image:
    for ext in ("png", "jpg", "jpeg", "webp"):
        p = ROOT / f"art_originais/app_icon/app_icon_art.{ext}"
        if p.exists():
            return Image.open(p).convert("RGB")
    sys.exit("arte não encontrada em art_originais/app_icon/app_icon_art.*")


def split(art: Image.Image) -> tuple[Image.Image, tuple]:
    """Desenho com fundo transparente, e a cor do fundo."""
    keyed = art.copy()
    w, h = keyed.size
    for xy in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if keyed.getpixel(xy) != SENTINEL:
            ImageDraw.floodfill(keyed, xy, SENTINEL, thresh=48)
    bgmask = Image.new("L", (w, h), 0)
    px, km = keyed.load(), bgmask.load()
    for y in range(h):
        for x in range(w):
            if px[x, y] == SENTINEL:
                km[x, y] = 255
    color = tuple(int(c) for c in ImageStat.Stat(art, bgmask).median)
    fg = art.convert("RGBA")
    fg.putalpha(Image.eval(bgmask, lambda v: 255 - v))
    return fg.crop(fg.getbbox()), color


def radius(fg: Image.Image) -> float:
    """Maior distância de um pixel do desenho ao centro dele."""
    a = fg.getchannel("A").load()
    w, h = fg.size
    cx, cy = w / 2, h / 2
    r = 0.0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if a[x, y] > 128:
                r = max(r, math.hypot(x - cx, y - cy))
    return r


def compose(fg: Image.Image, r: float, side: int, frac: float, bg) -> Image.Image:
    """Desenho centrado, com o raio ocupando `frac` do lado. bg None = transparente."""
    s = frac * side / r
    d = fg.resize((max(1, round(fg.width * s)), max(1, round(fg.height * s))), Image.LANCZOS)
    out = Image.new("RGBA", (side, side), (*bg, 255) if bg else (0, 0, 0, 0))
    out.alpha_composite(d, ((side - d.width) // 2, (side - d.height) // 2))
    return out


def main() -> None:
    fg, bg = split(load_art())
    r = radius(fg)
    # Adaptativo: o círculo seguro tem 66/108 do lado; deixa uma folguinha.
    compose(fg, r, 432, 0.29, None).save(STORE / "icon_fg_432.png")
    Image.new("RGBA", (432, 432), (*bg, 255)).save(STORE / "icon_bg_432.png")
    # Antigo (192) e loja (512): quadrado inteiro, a loja arredonda os cantos.
    for side in (192, 512):
        compose(fg, r, side, 0.40, bg).save(STORE / f"icon_{side}.png")
    print("fundo #%02X%02X%02X" % bg)
    if "--preview" in sys.argv:
        out = Path(sys.argv[sys.argv.index("--preview") + 1])
        full = Image.alpha_composite(Image.open(STORE / "icon_bg_432.png"), Image.open(STORE / "icon_fg_432.png"))
        sheet = Image.new("RGBA", (4 * 460, 460), (245, 239, 227, 255))
        shapes = [("circle", None), ("squircle", 0.3), ("rounded", 0.16), ("teardrop", None)]
        for i, (name, rr) in enumerate(shapes):
            m = Image.new("L", (432, 432), 0)
            dr = ImageDraw.Draw(m)
            if name == "circle":
                dr.ellipse([0, 0, 431, 431], fill=255)
            elif name == "teardrop":
                dr.rounded_rectangle([0, 0, 431, 431], radius=216, fill=255)
                dr.rectangle([216, 216, 431, 431], fill=255)
            else:
                dr.rounded_rectangle([0, 0, 431, 431], radius=int(432 * rr), fill=255)
            # O launcher mostra só os 72/108 do meio.
            crop = full.crop((72, 72, 360, 360)).resize((432, 432))
            sheet.paste(crop, (14 + i * 460, 14), m)
        sheet.save(out / "icon_masks.png")
        Image.open(STORE / "icon_512.png").save(out / "icon_512.png")


if __name__ == "__main__":
    main()
