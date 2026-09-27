extends SceneTree
## Gera os PNGs de ícone (launcher do Android e loja) a partir dos SVGs antigos (a cartola).
## O ícone de hoje vem da arte do Nano Banana: python3 tools/app_icon.py.
## Uso: godot --headless -s res://tools/render_icons.gd

func _render(svg: String, px: int, out: String) -> void:
	var src := FileAccess.get_file_as_string("res://design/icons/%s.svg" % svg)
	var img := Image.new()
	var tmp := Image.new()
	tmp.load_svg_from_string(src, 1.0)
	img.load_svg_from_string(src, float(px) / tmp.get_width())
	img.save_png(out)
	print(out, " ", img.get_size())


func _init() -> void:
	_render("app_icon", 192, "res://design/store/icon_192.png")
	_render("app_icon", 512, "res://design/store/icon_512.png")
	_render("app_icon_fg", 432, "res://design/store/icon_fg_432.png")
	_render("app_icon_bg", 432, "res://design/store/icon_bg_432.png")
	quit()
