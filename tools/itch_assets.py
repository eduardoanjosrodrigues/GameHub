#!/usr/bin/env python3
"""Gera as imagens da página do itch.io em design/itch/ (veja docs/ITCH.md).

  cover_630x500.png   capa (a miniatura que aparece nas listas do itch)
  shots/*.png         capturas de tela, copiadas das pastas do tour. Rode um tour por jogo (num
                      tour só, um aviso de "Sair da partida?" sobra por cima das telas do fim):
                      for g in hub game halli avalon sh coup quem_foi sintonia ito; do
                        godot -- --tour=/tmp/tour_$g --tour-set=$g --tour-size=1080x1920; done
                      tools/itch_assets.py /tmp/tour_*
"""
import pathlib
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "design" / "itch"
MOSTARDA = (227, 172, 44) # o fundo do ícone
TINTA = (31, 29, 26)
PAPEL = (245, 239, 227)
COVERS = ["avalon", "coup", "secret_hitler", "quem_foi"]
# Capturas escolhidas do tour, na ordem da página: (prefixo no nome do arquivo do tour, nome final).
SHOTS = [
	("home", "01_inicio"),
	("turn_explainer", "02_chapeu"),
	("hg_table4_play", "03_halli_galli"),
	("av_player_reveal", "04_avalon"),
	("sh_board_policy", "05_secret_hitler"),
	("coup_player_turn", "06_coup"),
	("qf_player_accuse", "07_quem_foi"),
	("sint_board_reveal", "08_sintonia"),
	("ito_board_reveal_mid", "09_ito"),
]


def font(name: str, size: int, weight: str) -> ImageFont.FreeTypeFont:
	f = ImageFont.truetype(str(ROOT / "design" / "fonts" / name), size)
	f.set_variation_by_name(weight)
	return f


def cover() -> None:
	W, H, top = 630, 500, 230
	img = Image.new("RGB", (W, H), PAPEL)
	d = ImageDraw.Draw(img)
	d.rectangle((0, 0, W, top), fill=MOSTARDA)
	fan = Image.open(ROOT / "design" / "store" / "icon_fg_432.png").convert("RGBA")
	fan = fan.crop(fan.getbbox())
	k = 150 / fan.height
	fan = fan.resize((int(fan.width * k), 150), Image.LANCZOS)
	img.paste(fan, (30, (top - fan.height) // 2), fan)
	x = 30 + fan.width + 22
	# O título ocupa o que sobra da largura, com margem.
	size = 80
	while size > 30 and font("Fraunces.ttf", size, b"Black").getlength("GameHub") > W - x - 30:
		size -= 2
	d.text((x, 40), "GameHub", font=font("Fraunces.ttf", size, b"Black"), fill=TINTA)
	sub = font("Manrope.ttf", 23, b"Bold")
	d.text((x + 3, 140), "8 jogos de festa", font=sub, fill=TINTA)
	d.text((x + 3, 170), "cada um no seu celular", font=sub, fill=TINTA)
	# Embaixo, as capas de quatro jogos numa grade 2x2.
	cw, ch, gap = (W - 3 * 12) // 2, (H - top - 3 * 12) // 2, 12
	for i, g in enumerate(COVERS):
		art = Image.open(ROOT / "games" / g / "art" / "capa.webp").convert("RGB")
		k = max(cw / art.width, ch / art.height)
		art = art.resize((int(art.width * k) + 1, int(art.height * k) + 1), Image.LANCZOS)
		l, t = (art.width - cw) // 2, (art.height - ch) // 2
		art = art.crop((l, t, l + cw, t + ch))
		mask = Image.new("L", (cw, ch), 0)
		ImageDraw.Draw(mask).rounded_rectangle((0, 0, cw - 1, ch - 1), 14, fill=255)
		px, py = gap + (i % 2) * (cw + gap), top + gap + (i // 2) * (ch + gap)
		img.paste(art, (px, py), mask)
		d.rounded_rectangle((px, py, px + cw - 1, py + ch - 1), 14, outline=TINTA, width=3)
	img.save(OUT / "cover_630x500.png")
	print("ok: design/itch/cover_630x500.png")


def shots(tours: list) -> None:
	dst = OUT / "shots"
	shutil.rmtree(dst, ignore_errors=True)
	dst.mkdir(parents=True)
	files = sorted(f for t in tours for f in pathlib.Path(t).glob("*.png"))
	for prefix, name in SHOTS:
		match = [f for f in files if f.stem.split("_", 1)[1] == prefix]
		if not match:
			print(f"faltou a captura {prefix}")
			continue
		shutil.copy(match[0], dst / f"{name}.png")
	print(f"ok: {len(list(dst.glob('*.png')))} capturas em design/itch/shots/")


if __name__ == "__main__":
	OUT.mkdir(parents=True, exist_ok=True)
	cover()
	if len(sys.argv) > 1:
		shots(sys.argv[1:])
