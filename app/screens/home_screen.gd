extends Screen
## Início do hub: logo, grade de jogos, Histórico e Configurações.

const ChapeuMenu := preload("res://games/chapeu/screens/chapeu_menu.gd")
const HalliMenu := preload("res://games/halli_galli/screens/halli_menu.gd")
const AvalonMenu := preload("res://games/avalon/screens/avalon_menu.gd")
const ShMenu := preload("res://games/secret_hitler/screens/sh_menu.gd")
const ItoMenu := preload("res://games/ito/screens/ito_menu.gd")
const SintoniaMenu := preload("res://games/sintonia/screens/sintonia_menu.gd")
const QuemFoiMenu := preload("res://games/quem_foi/screens/quem_foi_menu.gd")
const CoupMenu := preload("res://games/coup/screens/coup_menu.gd")
const WordleMenu := preload("res://games/wordle/screens/wordle_menu.gd")
const SenhaMenu := preload("res://games/senha/screens/senha_menu.gd")
const GeniusMenu := preload("res://games/genius/screens/genius_menu.gd")
const SettingsScreen := preload("res://app/screens/settings_screen.gd")
const HistoryScreen := preload("res://app/screens/history_screen.gd")
const JoinScreen := preload("res://app/screens/join_screen.gd")

## Catálogo de jogos. Os próximos entram aqui.
const GAMES := [
	{"id": "chapeu", "nome": "Chapéu", "desc": "Explique, resuma e faça mímica. Festa garantida!", "icone": "chapeu", "cor": Tokens.AZUL, "botao": AppButton.Variant.ACCENT, "pronto": true},
	{"id": "halli", "nome": "Halli Galli", "desc": "Cinco frutas iguais? Bata o sino primeiro!", "icone": "halli_galli", "cor": Tokens.MOSTARDA, "botao": AppButton.Variant.PRIMARY, "pronto": true},
	{"id": "avalon", "nome": "Avalon", "desc": "Servos de Arthur contra lacaios de Mordred. Em quem confiar?", "icone": "avalon", "cor": Tokens.SALVIA, "botao": AppButton.Variant.PRIMARY, "pronto": true},
	{"id": "secret_hitler", "nome": "Secret Hitler", "desc": "Liberais contra fascistas. Quem é o Hitler?", "icone": "secret_hitler", "cor": Tokens.VERMELHO, "botao": AppButton.Variant.PRIMARY, "pronto": true},
	{"id": "sintonia", "nome": "Sintonia", "desc": "Uma dica, dois extremos. Acerte a agulha no alvo!", "icone": "sintonia", "cor": Tokens.AZUL, "botao": AppButton.Variant.PRIMARY, "pronto": true},
	{"id": "ito", "nome": "Ito", "desc": "Números secretos e uma fila em ordem, sem dizer os números.", "icone": "ito", "cor": Tokens.VERMELHO, "botao": AppButton.Variant.PRIMARY, "pronto": true},
	{"id": "quem_foi", "nome": "Quem Foi?", "desc": "Um cocô no meio da sala! Passe a culpa pro bicho de alguém.", "icone": "quem_foi", "cor": Tokens.MOSTARDA, "botao": AppButton.Variant.PRIMARY, "pronto": true},
	{"id": "coup", "nome": "Coup", "desc": "Blefe na corte: diga que é o Duque e torça pra ninguém desafiar.", "icone": "coup", "cor": Color("#6E3B93"), "botao": AppButton.Variant.PRIMARY, "pronto": true},
	{"id": "wordle", "nome": "Wordle", "desc": "Uma palavra por dia, seis tentativas. Ou corrida no Wi-Fi!", "icone": "wordle", "cor": Tokens.SALVIA, "botao": AppButton.Variant.PRIMARY, "pronto": true},
	{"id": "senha", "nome": "Senha", "desc": "Quebre a sequência secreta de cores. Sozinho ou em duelo.", "icone": "senha", "cor": Color("#1E7F86"), "botao": AppButton.Variant.PRIMARY, "pronto": true},
	{"id": "genius", "nome": "Genius", "desc": "Olhe as cores, escute os sons e repita. Uma cor a mais a cada acerto!", "icone": "genius", "cor": Tokens.SALVIA, "botao": AppButton.Variant.SUCCESS, "pronto": true},
	{"id": "em_breve_2", "nome": "Em breve", "desc": "Novo jogo chegando", "icone": "em_breve", "cor": Tokens.SUPERFICIE, "pronto": false},
]


func _ready() -> void:
	_build()
	App.deep_link.connect(_on_deep_link)
	# Aberto por um QR antes da tela existir.
	var pending := App.take_pending_link()
	if pending != "":
		_on_deep_link.call_deferred(pending)
	# Voltando pra cá, o jogo que acabou de ser aberto sobe pro topo.
	visibility_changed.connect(func(): if visible: _build())


## Ordem dos jogos: primeiro os abertos mais recentemente; os outros (e empates) em ordem alfabética.
static func ordered(games: Array, last_played: Dictionary) -> Array:
	var out := games.duplicate()
	out.sort_custom(func(a, b):
		var ta := int(last_played.get(a.id, 0))
		var tb := int(last_played.get(b.id, 0))
		if ta != tb:
			return ta > tb
		return TextNorm.normalize(a.nome) < TextNorm.normalize(b.nome))
	return out


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	var col := make_column(true, 20, 22)
	var top := UI.hbox(12)
	top.add_child(UI.spacer(0, true))
	top.add_child(UI.icon_button("history", func(): App.push(HistoryScreen.new())))
	top.add_child(UI.icon_button("settings", func(): App.push(SettingsScreen.new())))
	col.add_child(top)
	col.add_child(Logo.new(80))
	col.add_child(UI.caption("Joguinhos pra jogar junto"))
	col.add_child(UI.spacer(4))

	for g in ordered(GAMES.filter(func(x): return x.pronto), Settings.last_played):
		col.add_child(_featured_card(g))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	for g in GAMES:
		if not g.pronto:
			grid.add_child(_small_card(g))
	col.add_child(grid)


func _on_deep_link(code: String) -> void:
	if App.current() == self:
		App.take_pending_link()
		App.push(JoinScreen.new(code, App.take_pending_seat()))


func _featured_card(g: Dictionary) -> Control:
	var c := UI.card(g.cor, 24)
	var v := UI.vbox(14)
	c.add_child(v)
	var row := UI.hbox(16)
	var ic := UI.texture(g.icone, 150)
	row.add_child(ic)
	var tv := UI.vbox(6)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_child(UI.label(g.nome, 44, Tokens.TINTA, Fonts.title_bold()))
	tv.add_child(UI.label(g.desc, 18, Tokens.TINTA, Fonts.body_bold()))
	row.add_child(tv)
	v.add_child(row)
	var menu: Script = {"halli": HalliMenu, "avalon": AvalonMenu, "secret_hitler": ShMenu, "sintonia": SintoniaMenu, "ito": ItoMenu, "quem_foi": QuemFoiMenu, "coup": CoupMenu, "wordle": WordleMenu, "senha": SenhaMenu, "genius": GeniusMenu}.get(g.id, ChapeuMenu)
	var play := UI.button("Jogar", g.botao, func():
		Settings.mark_played(g.id)
		App.push(menu.new()), "play")
	v.add_child(play)
	return c


func _small_card(g: Dictionary) -> Control:
	var c := UI.card(g.cor, 18)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	var ic := UI.texture(g.icone, 84)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(UI.label(g.nome, 22, Tokens.TINTA, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(g.desc, 14, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
	if not g.pronto:
		c.modulate = Color(1, 1, 1, 0.7)
	return c
