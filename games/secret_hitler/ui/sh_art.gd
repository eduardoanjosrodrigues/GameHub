class_name ShArt
extends RefCounted
## Textos dos papéis e desenho das peças do Secret Hitler (docs/PLANO_SECRET_HITLER.md §6).
## Retratos: games/secret_hitler/art/roles/<nome>.jpg, gerados no Nano Banana
## (docs/secret_hitler_prompts.md). Enquanto não existem, a carta mostra um marcador:
## cor do partido + emblema + nome.

const ART := "res://games/secret_hitler/art/"
const LIBERAL := Color("#2B59C3")
const FASCISTA := Color("#C8392B")
const LIBERAL_ESCURO := Color("#1F4494")
const FASCISTA_ESCURO := Color("#9E2A1F")

const ROLES := {
	"liberal": {"nome": "Liberal", "texto": "Você não sabe quem é quem. Aprove 5 leis liberais ou descubra e execute o Hitler."},
	"fascista": {"nome": "Fascista", "texto": "Você conhece seus parceiros e sabe quem é o Hitler. Aprove 6 leis fascistas ou, depois de 3, coloque o Hitler como chanceler. Sem se entregar."},
	"hitler": {"nome": "Hitler", "texto": "Seu time é o fascista. Pareça liberal, ganhe a confiança da mesa e, depois de 3 leis fascistas, seja eleito chanceler."},
}
## Variações de retrato por papel (liberal_1..4, fascista_1..3).
const VARIANTS := {"liberal": 4, "fascista": 3, "hitler": 1}
const POWER_NAMES := {
	"investigate": "Investigar",
	"peek": "Espiar o baralho",
	"special_election": "Eleição especial",
	"execution": "Execução",
}
const POWER_INFO := {
	"investigate": "O presidente vê, só no celular dele, o partido de alguém.",
	"peek": "O presidente vê, só no celular dele, as 3 leis do topo do baralho.",
	"special_election": "O presidente escolhe quem é o próximo candidato a presidente.",
	"execution": "O presidente executa alguém. Se for o Hitler, os liberais vencem.",
}
const REASONS := {
	"liberal_policies": "5 leis liberais aprovadas.",
	"hitler_executed": "O Hitler foi executado!",
	"fascist_policies": "6 leis fascistas aprovadas.",
	"hitler_chancellor": "O Hitler foi eleito chanceler!",
}

static var _tex := {}


static func role_name(r: String) -> String:
	return ROLES.get(r, {}).get("nome", r)


static func is_liberal(r: String) -> bool:
	return r == "liberal"


static func party_color(liberal: bool) -> Color:
	return LIBERAL if liberal else FASCISTA


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## Arte gerada fora (Nano Banana), em qualquer formato comum, lida crua (importer "keep").
static func art_file(base: String) -> Texture2D:
	for ext in [".webp", ".jpg", ".png"]:
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


## Retrato do papel, se já existir. variant escolhe a variação (se não existir, usa outra).
static func portrait(r: String, variant := 0) -> Texture2D:
	var count: int = VARIANTS.get(r, 1)
	var names: Array = [r]
	if count > 1:
		names = ["%s_%d" % [r, variant % count + 1]]
		for k in count:
			names.append("%s_%d" % [r, k + 1])
	for n in names:
		var t := art_file("roles/" + n)
		if t:
			return t
	return null


static func emblem(name: String) -> Texture2D:
	return tex(ART + "emblems/%s.svg" % name)


static func policy_tex(policy: String) -> Texture2D:
	return tex(ART + ("lei_liberal.svg" if policy == "L" else "lei_fascista.svg"))


## Carta de papel: retrato (ou marcador) com o nome embaixo, na cor do partido.
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
		var col := ShArt.party_color(ShArt.is_liberal(role))
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
			var e := ShArt.tex("res://design/icons/secret_hitler.svg")
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
		var pic := ShArt.portrait(role, variant)
		if pic:
			AvalonArt.draw_cover(self, pic, art_r)
		else:
			var e := ShArt.emblem(role)
			if e:
				var s := w * 0.56
				draw_texture_rect(e, Rect2(art_r.get_center() - Vector2(s, s) / 2.0, Vector2(s, s)), false, col.darkened(0.1))
		var band := Rect2(Vector2(r.position.x, r.end.y - band_h), Vector2(w, band_h))
		var bs := StyleBoxFlat.new()
		bs.bg_color = col if role != "hitler" else Tokens.TINTA
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
		var name := ShArt.role_name(role)
		var fs := int(w * 0.11)
		var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while tw > w * 0.9 and fs > 10:
			fs -= 1
			tw = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(band.get_center().x - tw / 2.0, band.get_center().y + fs * 0.35), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tokens.SUPERFICIE)


## Placar: trilha liberal (5), trilha fascista (6, com os poderes), marcador de eleições e baralho.
class PolicyTrack extends Control:
	const SHORT := {"investigate": "Investigar", "peek": "Espiar", "special_election": "Eleição", "execution": "Execução"}
	var v := {}
	var big := false

	func _init(p_big := false) -> void:
		big = p_big
		mouse_filter = MOUSE_FILTER_IGNORE
		texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		custom_minimum_size = Vector2(0, 560 if big else 370)
		resized.connect(_fit)

	func set_view(p_v: Dictionary) -> void:
		v = p_v
		queue_redraw()

	## Altura certa pra largura atual (as casas crescem com a largura).
	func _fit() -> void:
		var fs_label := 26 if big else 17
		var fs_small := 18 if big else 12
		var gap := 8.0 if not big else 16.0
		var cw := minf((size.x - gap * 5.0) / 6.0, 150.0 if big else 100.0)
		var ch := cw * 1.3
		var h := (fs_label + 10) * 2 + ch * 2 + 16 + fs_small + 12 + fs_small + (26 if not big else 40) + (20.0 if big else 14.0) + 8
		if absf(custom_minimum_size.y - h) > 1.0:
			custom_minimum_size.y = h

	func _draw() -> void:
		if v.is_empty():
			return
		var body := Fonts.body_bold()
		var fs_label := 26 if big else 17
		var fs_small := 18 if big else 12
		# Largura de uma casa: 6 casas na trilha fascista.
		var gap := 8.0 if not big else 16.0
		var cw := minf((size.x - gap * 5.0) / 6.0, 150.0 if big else 100.0)
		var ch := cw * 1.3
		var x0 := (size.x - (cw * 6.0 + gap * 5.0)) / 2.0
		var y := 0.0
		_row_label("Leis liberais  %d de 5" % int(v.liberal), Vector2(x0, y + fs_label), fs_label, ShArt.LIBERAL_ESCURO)
		y += fs_label + 10
		var lx0 := (size.x - (cw * 5.0 + gap * 4.0)) / 2.0
		for i in 5:
			var r := Rect2(Vector2(lx0 + i * (cw + gap), y), Vector2(cw, ch))
			_slot(r, i < int(v.liberal), "L", "")
		y += ch + 16
		_row_label("Leis fascistas  %d de 6" % int(v.fascist), Vector2(x0, y + fs_label), fs_label, ShArt.FASCISTA_ESCURO)
		y += fs_label + 10
		var powers: Dictionary = v.get("powers", {})
		for i in 6:
			var r := Rect2(Vector2(x0 + i * (cw + gap), y), Vector2(cw, ch))
			var pw: String = str(powers.get(i + 1, powers.get(str(i + 1), "")))
			_slot(r, i < int(v.fascist), "F", pw if i < 5 else "win")
			# Nome do poder embaixo de cada casa
			var nm: String = SHORT.get(pw, "") if i < 5 else "Vitória"
			if nm != "":
				var nw := body.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small).x
				draw_string(body, Vector2(r.get_center().x - nw / 2.0, r.end.y + fs_small + 4), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, ShArt.FASCISTA_ESCURO)
		y += ch + fs_small + 12
		var rule := "Da 3ª em diante, o Hitler eleito chanceler vence  ·  Na 5ª, o governo pode vetar"
		var rw := body.get_string_size(rule, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small).x
		draw_string(body, Vector2(size.x / 2.0 - minf(rw, size.x) / 2.0, y + fs_small), rule, HORIZONTAL_ALIGNMENT_LEFT, size.x, fs_small, Tokens.TINTA_SUAVE)
		y += fs_small + (26 if not big else 40)
		# Marcador de eleições + baralho
		var rd := 13.0 if not big else 20.0
		var fs_line := 20 if big else 14
		var lbl := "Eleições fracassadas"
		draw_string(body, Vector2(x0, y + fs_line * 0.35), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_line, Tokens.TINTA_SUAVE)
		var lw := body.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_line).x
		for k in 3:
			var c := Vector2(x0 + lw + 14 + rd + k * rd * 2.6, y)
			draw_circle(c, rd, Tokens.MOSTARDA if k < int(v.tracker) else Tokens.SUPERFICIE)
			draw_arc(c, rd, 0, TAU, 32, Tokens.TINTA, 2.5, true)
		var deck_txt := "Baralho %d · Descarte %d" % [int(v.deck_count), int(v.discard_count)]
		var dw := body.get_string_size(deck_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_line).x
		draw_string(body, Vector2(size.x - x0 - dw, y + fs_line * 0.35), deck_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_line, Tokens.TINTA_SUAVE)

	func _row_label(t: String, p: Vector2, fs: int, col: Color) -> void:
		draw_string(Fonts.title_bold(), p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, col)

	func _slot(r: Rect2, filled: bool, kind: String, pw: String) -> void:
		if filled:
			var t := ShArt.policy_tex(kind)
			if t:
				draw_texture_rect(t, r, false)
			return
		var sb := StyleBoxFlat.new()
		sb.bg_color = Tokens.tint(ShArt.party_color(kind == "L"), 0.12)
		sb.border_color = Color(Tokens.TINTA, 0.35)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(int(r.size.x * 0.12))
		draw_style_box(sb, r.grow(-r.size.x * 0.05))
		var icon: Texture2D = null
		if pw == "win":
			icon = ShArt.emblem("fascista")
		elif pw != "":
			icon = ShArt.emblem("poder_" + pw)
		if icon:
			var s := r.size.x * 0.5
			draw_texture_rect(icon, Rect2(r.get_center() - Vector2(s, s) / 2.0, Vector2(s, s)), false, Color(ShArt.FASCISTA_ESCURO, 0.55))
