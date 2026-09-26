class_name AvalonArt
extends RefCounted
## Textos dos personagens e desenho das peças do Avalon (docs/PLANO_AVALON.md §6).
## Retratos: games/avalon/art/roles/<nome>.png, gerados no Nano Banana (docs/avalon_prompts.md).
## Enquanto não existem, a carta mostra um marcador: cor do lado + emblema + nome.

const ART := "res://games/avalon/art/"
const BEM := Color("#2B59C3")
const MAL := Color("#C8392B")
const BEM_ESCURO := Color("#1F4494")
const MAL_ESCURO := Color("#9E2A1F")

const ROLES := {
	"merlin": {"nome": "Merlin", "bem": true, "texto": "Você sabe quem é do mal (menos Mordred). Ajude o bem sem se entregar: se no fim o Assassino descobrir quem você é, o mal vence."},
	"percival": {"nome": "Percival", "bem": true, "texto": "Você vê Merlin e Morgana, mas não sabe quem é quem. Descubra qual é o verdadeiro Merlin e proteja ele."},
	"servo": {"nome": "Servo leal de Arthur", "bem": true, "texto": "Você não sabe de nada. Preste atenção em quem vota e em quem falha as missões."},
	"assassino": {"nome": "Assassino", "bem": false, "texto": "Sabote as missões. Se o bem completar 3 missões, você tem uma última chance: adivinhar quem é Merlin."},
	"morgana": {"nome": "Morgana", "bem": false, "texto": "Pro Percival, você aparece como se fosse Merlin. Use isso pra enganar ele."},
	"mordred": {"nome": "Mordred", "bem": false, "texto": "Merlin não sabe que você é do mal. Aproveite a confiança."},
	"oberon": {"nome": "Oberon", "bem": false, "texto": "Você é do mal, mas não sabe quem são os outros, e eles não sabem que você é. Sabote sozinho."},
	"lacaio": {"nome": "Lacaio de Mordred", "bem": false, "texto": "Sabote as missões sem ser descoberto."},
}
const SPECIAL_INFO := {
	"merlin": "Sabe quem é do mal (menos Mordred). Entra com o Assassino.",
	"assassino": "Do mal. No fim, tenta adivinhar Merlin.",
	"percival": "Do bem. Vê Merlin e Morgana, sem saber quem é quem.",
	"morgana": "Do mal. Aparece pro Percival como Merlin.",
	"mordred": "Do mal. Merlin não vê ele.",
	"oberon": "Do mal, mas sozinho: não vê os outros nem é visto.",
}
const REASONS := {
	"rejects": "5 times recusados seguidos: o mal venceu.",
	"quests": "3 missões decidiram o jogo.",
	"assassin_hit": "O Assassino acertou quem era Merlin!",
	"assassin_miss": "O Assassino errou: Merlin estava salvo.",
}

static var _tex := {}


static func role_name(r: String) -> String:
	return ROLES.get(r, {}).get("nome", r)


static func is_good(r: String) -> bool:
	return ROLES.get(r, {}).get("bem", true)


static func side_color(good: bool) -> Color:
	return BEM if good else MAL


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## Arte gerada fora (Nano Banana), em qualquer formato comum. base sem extensão.
## Os arquivos vão pro APK como estão (importer "keep", ver tools/sync_web_assets.sh), porque o
## WebGateway serve os mesmos pro navegador; aqui eles viram textura na hora.
static func art_file(base: String) -> Texture2D:
	for ext in [".png", ".jpg", ".webp"]:
		var path: String = ART + base + ext
		if _tex.has(path):
			if _tex[path]:
				return _tex[path]
			continue
		_tex[path] = _load_image(path)
		if _tex[path]:
			return _tex[path]
	return null


static func _load_image(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	var img := Image.new()
	var err: Error
	match path.get_extension():
		"png": err = img.load_png_from_buffer(bytes)
		"jpg": err = img.load_jpg_from_buffer(bytes)
		_: err = img.load_webp_from_buffer(bytes)
	if err != OK:
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Retrato do personagem, se já existir. variant escolhe entre servo_1..3 / lacaio_1..3
## (se a variação não existir, usa outra que exista).
static func portrait(r: String, variant := 0) -> Texture2D:
	var names: Array = [r]
	if r in ["servo", "lacaio"]:
		names = ["%s_%d" % [r, variant % 3 + 1], "%s_1" % r, "%s_2" % r, "%s_3" % r]
	for n in names:
		var t := art_file("roles/" + n)
		if t:
			return t
	return null


## Desenha a imagem preenchendo dest (cortando o que sobra), com um pouco de zoom no centro:
## os retratos têm bastante fundo em volta do personagem.
static func draw_cover(ci: CanvasItem, t: Texture2D, dest: Rect2, zoom := 1.12, center_y := 0.48) -> void:
	var ts := t.get_size()
	var a := dest.size.x / dest.size.y
	var src := Vector2(ts.y * a, ts.y) if ts.x / ts.y > a else Vector2(ts.x, ts.x / a)
	src /= zoom
	var pos := Vector2(ts.x / 2.0 - src.x / 2.0, clampf(ts.y * center_y - src.y / 2.0, 0.0, ts.y - src.y))
	ci.draw_texture_rect_region(t, dest, Rect2(pos, src))


static func emblem(r: String) -> Texture2D:
	return tex(ART + "emblems/%s.svg" % r)


## Imagem larga (capa) que ocupa a largura toda e mantém a proporção; crop_top corta o topo vazio.
class Banner extends Control:
	var texture: Texture2D
	var crop_top := 0.0

	func _init(p_texture: Texture2D, p_crop_top := 0.0) -> void:
		texture = p_texture
		crop_top = p_crop_top
		mouse_filter = MOUSE_FILTER_IGNORE
		texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		resized.connect(_fit)

	func _src() -> Rect2:
		var ts := texture.get_size()
		return Rect2(0, ts.y * crop_top, ts.x, ts.y * (1.0 - crop_top))

	func _fit() -> void:
		var h := size.x * _src().size.y / _src().size.x
		if absf(custom_minimum_size.y - h) > 1.0:
			custom_minimum_size.y = h

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_texture_rect_region(texture, r, _src())


## Retrato solto (ex: Dama do Lago) numa moldura de carta, sem nome.
class Picture extends Control:
	var texture: Texture2D
	var frame := Tokens.TINTA

	func _init(p_texture: Texture2D, p_size: Vector2, p_frame := Tokens.TINTA) -> void:
		texture = p_texture
		frame = p_frame
		mouse_filter = MOUSE_FILTER_IGNORE
		texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		custom_minimum_size = p_size
		size_flags_horizontal = SIZE_SHRINK_CENTER

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		AvalonArt.draw_cover(self, texture, r.grow(-4))
		draw_rect(r.grow(-2), frame, false, 4.0)


## Carta de papel: retrato (ou marcador) com o nome embaixo e a faixa do lado.
class RoleCard extends Control:
	var role := ""
	var variant := 0
	var face_down := false

	func _init(p_role := "", p_variant := 0) -> void:
		role = p_role
		variant = p_variant
		mouse_filter = MOUSE_FILTER_IGNORE
		texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		custom_minimum_size = Vector2(300, 450)

	func _draw() -> void:
		var w := minf(size.x, size.y / 1.5)
		var r := Rect2(Vector2((size.x - w) / 2.0, 0), Vector2(w, w * 1.5))
		var good := AvalonArt.is_good(role)
		var col := AvalonArt.side_color(good)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(w * 0.07))
		sb.border_color = Tokens.TINTA
		sb.set_border_width_all(4)
		sb.shadow_color = Color(Tokens.TINTA, 0.18)
		sb.shadow_size = 14
		sb.shadow_offset = Vector2(0, 6)
		sb.anti_aliasing = true
		if face_down:
			sb.bg_color = Tokens.TINTA
			draw_style_box(sb, r)
			var e := AvalonArt.tex("res://design/icons/avalon.svg")
			if e:
				var s := w * 0.5
				draw_texture_rect(e, Rect2(r.get_center() - Vector2(s, s) / 2.0, Vector2(s, s)), false, Color(1, 1, 1, 0.9))
			var f := Fonts.body_bold()
			var t := "Toque pra ver seu papel"
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_string(f, Vector2(r.get_center().x - tw / 2.0, r.end.y - 40), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Tokens.SUPERFICIE)
			return
		sb.bg_color = Tokens.tint(col, 0.22)
		draw_style_box(sb, r)
		var band_h := maxf(44.0, w * 0.22)
		var inset := maxf(6.0, w * 0.03)
		var art_r := Rect2(r.position + Vector2(inset, inset), Vector2(w - inset * 2.0, w * 1.5 - band_h - inset))
		var pic := AvalonArt.portrait(role, variant)
		if pic:
			AvalonArt.draw_cover(self, pic, art_r)
		else:
			var e := AvalonArt.emblem(role)
			if e:
				var s := w * 0.52
				draw_texture_rect(e, Rect2(art_r.get_center() - Vector2(s, s) / 2.0, Vector2(s, s)), false, col.darkened(0.1))
		# Faixa com o nome
		var band := Rect2(Vector2(r.position.x, r.end.y - band_h), Vector2(w, band_h))
		var bs := StyleBoxFlat.new()
		bs.bg_color = col
		bs.corner_radius_bottom_left = int(w * 0.07)
		bs.corner_radius_bottom_right = int(w * 0.07)
		bs.border_color = Tokens.TINTA
		bs.border_width_top = 3
		draw_style_box(bs, band)
		var sb2 := StyleBoxFlat.new()
		sb2.draw_center = false
		sb2.border_color = Tokens.TINTA
		sb2.set_border_width_all(4)
		sb2.set_corner_radius_all(int(w * 0.07))
		sb2.anti_aliasing = true
		draw_style_box(sb2, r)
		var font := Fonts.title_bold()
		var name := AvalonArt.role_name(role)
		# O nome cabe sempre: começa proporcional à carta e encolhe se passar da largura.
		var fs := int(w * 0.11)
		var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while tw > w * 0.9 and fs > 10:
			fs -= 1
			tw = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(band.get_center().x - tw / 2.0, band.get_center().y + fs * 0.35), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tokens.SUPERFICIE)


## Trilha das missões + recusas + líder (placar do topo e do tabuleiro).
class QuestTrack extends Control:
	var v := {}
	var big := false

	func _init(p_big := false) -> void:
		big = p_big
		mouse_filter = MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 270 if big else 150)

	func set_view(p_v: Dictionary) -> void:
		v = p_v
		queue_redraw()

	func _draw() -> void:
		if v.is_empty():
			return
		var sizes: Array = v.get("quest_sizes", [])
		var results: Array = v.get("results", [])
		var fails: Array = v.get("quest_fails", [])
		var n := 5
		var d := minf(size.x / 6.2, 150.0 if big else 78.0)
		var gap := (size.x - d * n) / (n + 1)
		var font := Fonts.title_bold()
		var body := Fonts.body_bold()
		for i in n:
			var c := Vector2(gap + d / 2.0 + i * (d + gap), d / 2.0 + 4)
			var fill := Tokens.SUPERFICIE
			var ink := Tokens.TINTA
			if i < results.size():
				fill = AvalonArt.BEM if results[i] == "ok" else AvalonArt.MAL
				ink = Tokens.SUPERFICIE
			draw_circle(c, d / 2.0, fill)
			var current: bool = i == int(v.get("quest", 0)) and i >= results.size()
			draw_arc(c, d / 2.0, 0, TAU, 48, Tokens.MOSTARDA if current else Tokens.TINTA, 6.0 if current else 3.0, true)
			var label := str(sizes[i]) if i < sizes.size() else ""
			if i < results.size():
				label = "✓" if results[i] == "ok" else "✗"
			var fs := int(d * 0.44)
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2(c.x - tw / 2.0, c.y + fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
			var sub := ""
			if i < results.size() and int(fails[i]) > 0:
				sub = "%d falha%s" % [fails[i], "" if int(fails[i]) == 1 else "s"]
			elif i == 3 and v.get("two_fails", false):
				sub = "2 falhas"
			if sub != "":
				var ss := int(d * 0.19)
				var sw := body.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
				draw_string(body, Vector2(c.x - sw / 2.0, c.y + d / 2.0 + ss + 6), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Tokens.TINTA_SUAVE)
		# Recusas, abaixo dos números das missões ("2 falhas")
		var rd := d * (0.16 if big else 0.2)
		var ry := d + 4 + d * 0.19 + 24 + rd
		var label2 := "Recusas"
		var lf := 24 if big else 16
		draw_string(body, Vector2(gap, ry + lf * 0.35), label2, HORIZONTAL_ALIGNMENT_LEFT, -1, lf, Tokens.TINTA_SUAVE)
		var lw := body.get_string_size(label2, HORIZONTAL_ALIGNMENT_LEFT, -1, lf).x
		for k in 5:
			var rc := Vector2(gap + lw + 24 + rd + k * (rd * 2.5), ry)
			var on: bool = k < int(v.get("rejects", 0))
			draw_circle(rc, rd, AvalonArt.MAL if on else Tokens.SUPERFICIE)
			draw_arc(rc, rd, 0, TAU, 32, Tokens.TINTA, 2.5, true)
