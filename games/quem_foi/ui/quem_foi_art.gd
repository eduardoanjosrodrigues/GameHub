class_name QuemFoiArt
extends RefCounted
## Arte do Quem Foi? (docs/PLANO_QUEM_FOI.md §6): as 6 imagens dos bichos (Nano Banana, em
## games/quem_foi/art/, lidas cruas como no Avalon) e a carta com a cor do dono desenhada pelo app.

const ART := "res://games/quem_foi/art/"
const NAMES := {"gato": "Gato", "peixe": "Peixe", "tartaruga": "Tartaruga", "coelho": "Coelho", "hamster": "Hamster", "papagaio": "Papagaio"}
## "Não foi o meu gato", "Não foi a minha tartaruga".
const MINE := {"gato": "o meu gato", "peixe": "o meu peixe", "tartaruga": "a minha tartaruga", "coelho": "o meu coelho", "hamster": "o meu hamster", "papagaio": "o meu papagaio"}
## Com artigo, pra frase da acusação ("o gato", "a tartaruga").
const WITH_ARTICLE := {"gato": "o gato", "peixe": "o peixe", "tartaruga": "a tartaruga", "coelho": "o coelho", "hamster": "o hamster", "papagaio": "o papagaio"}
## As 6 cores dos jogadores, fortes e diferentes entre si.
const COLORS := [Color("#2B59C3"), Color("#C8392B"), Color("#2F7D5B"), Color("#E0A21F"), Color("#6E3B93"), Color("#D9772B")]
const COLOR_NAMES := ["azul", "vermelho", "verde", "amarelo", "roxo", "laranja"]
const COCO := Color("#7A4A2A")

static var _tex := {}


static func color(i: int) -> Color:
	return COLORS[i % COLORS.size()]


static func animal_name(a: String) -> String:
	return NAMES.get(a, a)


## "o COELHO", "a TARTARUGA": o bicho acusado em destaque na frase.
static func shout(a: String) -> String:
	var parts: PackedStringArray = str(WITH_ARTICLE.get(a, a)).split(" ")
	return "%s %s" % [parts[0], parts[1].to_upper()] if parts.size() == 2 else a.to_upper()


static func art(base: String) -> Texture2D:
	if _tex.has(base):
		return _tex[base]
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
	_tex[base] = t
	return t


static func picture(base: String, side: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = art(base)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.custom_minimum_size = Vector2(side, side)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Carta de um bicho: moldura grossa e fundo na cor do dono, a imagem e o nome embaixo.
## owner_color: cor do dono (ou Tokens.LINHA pra um bicho "de ninguém", na acusação).
static func card(animal: String, owner_color: Color, side: float, with_name := true) -> TapPanel:
	var p := TapPanel.new(Tokens.tint(owner_color, 0.22), int(side * 0.06), owner_color, maxi(4, int(side * 0.045)))
	var v := UI.vbox(2)
	p.add_child(v)
	var img := picture(animal, side)
	if img.texture == null:
		# Sem a imagem ainda: o nome grande no lugar.
		var l := UI.label(animal_name(animal), int(side * 0.2), Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size = Vector2(side, side)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(l)
	else:
		v.add_child(img)
	if with_name:
		v.add_child(UI.label(animal_name(animal), maxi(14, int(side * 0.13)), Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	return p


## Fileira de cocôs (quantos a pessoa já levou).
static func poops(n: int, side: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in n:
		row.add_child(picture("coco", side))
	return row
