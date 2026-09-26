extends SceneTree
## Gera os PNGs de ícone (launcher do Android e loja).
## Se existir design/icons/app_icon_art.png (ou .jpg), a arte do Nano Banana (docs/app_icon_prompts.md),
## ela vira todos os tamanhos: o fundo adaptativo é a cor lisa dos cantos da arte, e a frente é a arte
## inteira (o desenho já vem no meio, longe do recorte do Android). Senão, usa os SVGs.
## Uso: godot --headless -s res://tools/render_icons.gd

const ART := ["res://design/icons/app_icon_art.png", "res://design/icons/app_icon_art.jpg"]


func _render(svg: String, px: int, out: String) -> void:
	var src := FileAccess.get_file_as_string("res://design/icons/%s.svg" % svg)
	var img := Image.new()
	var tmp := Image.new()
	tmp.load_svg_from_string(src, 1.0)
	img.load_svg_from_string(src, float(px) / tmp.get_width())
	img.save_png(out)
	print(out, " ", img.get_size())


func _save(img: Image, px: int, out: String) -> void:
	var c := img.duplicate() as Image
	c.resize(px, px, Image.INTERPOLATE_LANCZOS)
	c.save_png(out)
	print(out, " ", c.get_size())


## Cor média dos quatro cantos: o fundo liso da arte.
func _corner_color(img: Image) -> Color:
	var s := Color(0, 0, 0, 0)
	var n := 0
	var w := img.get_width()
	var h := img.get_height()
	for cx in [0, w - 24]:
		for cy in [0, h - 24]:
			for x in range(cx, cx + 24, 4):
				for y in range(cy, cy + 24, 4):
					s += img.get_pixel(x, y)
					n += 1
	return Color(s.r / n, s.g / n, s.b / n, 1.0)


func _init() -> void:
	for path in ART:
		if not FileAccess.file_exists(path):
			continue
		var img := Image.new()
		var bytes := FileAccess.get_file_as_bytes(path)
		if (img.load_png_from_buffer(bytes) if path.ends_with(".png") else img.load_jpg_from_buffer(bytes)) != OK:
			continue
		img.convert(Image.FORMAT_RGBA8)
		# Recorta no quadrado do meio, caso a arte venha retangular.
		var side := mini(img.get_width(), img.get_height())
		img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
		_save(img, 192, "res://design/store/icon_192.png")
		_save(img, 512, "res://design/store/icon_512.png")
		_save(img, 432, "res://design/store/icon_fg_432.png")
		var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
		bg.fill(_corner_color(img))
		bg.save_png("res://design/store/icon_bg_432.png")
		print("fundo ", bg.get_pixel(0, 0).to_html(false))
		quit()
		return
	_render("app_icon", 192, "res://design/store/icon_192.png")
	_render("app_icon", 512, "res://design/store/icon_512.png")
	_render("app_icon_fg", 432, "res://design/store/icon_fg_432.png")
	_render("app_icon_bg", 432, "res://design/store/icon_bg_432.png")
	quit()
