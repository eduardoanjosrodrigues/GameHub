class_name CoupArt
extends RefCounted
## Arte e textos do Coup (docs/PLANO_COUP.md §6). Os retratos vêm do Nano Banana
## (games/coup/art/<personagem>_<n>.webp, lidos crus como no Avalon); enquanto não existem, a carta
## mostra o emblema em SVG na cor do personagem.

const ART := "res://games/coup/art/"
const VARIANTS := 2
const NAMES := {"duque": "Duque", "assassino": "Assassino", "capitao": "Capitão", "embaixador": "Embaixador", "inquisidor": "Inquisidor", "condessa": "Condessa"}
## "o Duque", "a Condessa".
const WITH_ARTICLE := {"duque": "o Duque", "assassino": "o Assassino", "capitao": "o Capitão", "embaixador": "o Embaixador", "inquisidor": "o Inquisidor", "condessa": "a Condessa"}
const COLORS := {"duque": Color("#6E3B93"), "assassino": Color("#2B2A33"), "capitao": Color("#2B59C3"), "embaixador": Color("#2F7D5B"), "inquisidor": Color("#D9772B"), "condessa": Color("#C8392B")}
const ACTION_NAMES := {"renda": "Renda", "ajuda": "Ajuda Externa", "golpe": "Golpe de Estado", "imposto": "Imposto", "assassinar": "Assassinar", "extorquir": "Extorquir", "trocar": "Trocar", "examinar": "Examinar"}
const ACTION_INFO := {
	"renda": "+1 moeda. Ninguém impede.",
	"ajuda": "+2 moedas. Quem diz ter o Duque bloqueia.",
	"golpe": "Paga 7: alguém perde uma carta. Ninguém impede.",
	"imposto": "+3 moedas com o Duque.",
	"assassinar": "Paga 3: alguém perde uma carta. A Condessa bloqueia.",
	"extorquir": "Pega 2 moedas de alguém. Capitão ou %s bloqueia.",
	"trocar": "Troca cartas com o baralho.",
	"examinar": "Olha uma carta de alguém e pode obrigar a trocar.",
}
const PLAYER_COLORS := [Color("#2B59C3"), Color("#C8392B"), Color("#2F7D5B"), Color("#E0A21F"), Color("#6E3B93"), Color("#D9772B")]

static var _tex := {}


static func role_name(r: String) -> String:
	return NAMES.get(r, r)


static func role_color(r: String) -> Color:
	return COLORS.get(r, Tokens.TINTA_SUAVE)


static func player_color(i: int) -> Color:
	return PLAYER_COLORS[i % PLAYER_COLORS.size()]


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## Imagem gerada fora (Nano Banana), lida crua. Tenta a variação pedida e depois as outras.
static func portrait(r: String, variant := 0) -> Texture2D:
	var names: Array = ["%s_%d" % [r, variant % VARIANTS + 1]]
	for k in VARIANTS:
		names.append("%s_%d" % [r, k + 1])
	names.append(r)
	for n in names:
		var t := art(n)
		if t:
			return t
	return null


static func art(base: String) -> Texture2D:
	var key := "raw:" + base
	if _tex.has(key):
		return _tex[key]
	var t: Texture2D = null
	for ext in [".webp", ".png", ".jpg"]:
		var path: String = ART + base + ext
		if not FileAccess.file_exists(path):
			continue
		var bytes := FileAccess.get_file_as_bytes(path)
		var img := Image.new()
		var err: Error
		match ext:
			".png": err = img.load_png_from_buffer(bytes)
			".jpg": err = img.load_jpg_from_buffer(bytes)
			_: err = img.load_webp_from_buffer(bytes)
		if err == OK:
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
			break
	_tex[key] = t
	return t


static func emblem(r: String, side: float) -> TextureRect:
	return _rect(tex(ART + "emblems/%s.svg" % r), side, side)


static func coin(side: float) -> TextureRect:
	return _rect(tex(ART + "emblems/moeda.svg"), side, side)


static func _rect(t: Texture2D, w: float, h: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.custom_minimum_size = Vector2(w, h)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Carta de personagem. role "" = virada pra baixo. up = já perdida (aparece apagada).
static func card(role: String, w: float, up := false, variant := 0) -> TapPanel:
	var col := role_color(role) if role != "" else Color("#2B2A33")
	var p := TapPanel.new(Tokens.SUPERFICIE if role != "" else Color("#2B2A33"), int(w * 0.05), col, maxi(3, int(w * 0.04)))
	var v := UI.vbox(2)
	p.add_child(v)
	var h := w * 1.3
	if role == "":
		v.add_child(_rect(tex(ART + "emblems/verso.svg"), w, h))
	else:
		var pic := portrait(role, variant)
		if pic:
			v.add_child(_rect(pic, w, h))
		else:
			var box := CenterContainer.new()
			box.custom_minimum_size = Vector2(w, h)
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(emblem(role, w * 0.6))
			v.add_child(box)
		# Nas miniaturas (mesa, fim) só a imagem; o nome não caberia.
		if w >= 80:
			var l := UI.label(role_name(role), maxi(12, int(w * 0.12)), Tokens.SUPERFICIE, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			l.clip_text = true
			var band := PanelContainer.new()
			band.mouse_filter = Control.MOUSE_FILTER_IGNORE
			band.add_theme_stylebox_override("panel", ThemeBuilder.solid_style(col, 8))
			band.add_child(l)
			v.add_child(band)
	if up:
		p.modulate = Color(1, 1, 1, 0.45)
	return p
