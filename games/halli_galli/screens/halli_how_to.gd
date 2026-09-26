extends Screen
## Como jogar Halli Galli: as regras em cartões, com cartas de exemplo.


func _ready() -> void:
	var col := make_column()
	make_header(col, "Como jogar")
	col.add_child(_step("1. Cada um com seu monte", "As cartas são divididas entre todos, viradas pra baixo. Ninguém olha o próprio monte.", _cards([])))
	col.add_child(_step("2. Vire na sua vez", "Na sua vez, vire a carta de cima do seu monte na sua frente. Só a carta de cima de cada um vale. Entre uma virada e outra tem sempre pelo menos meio segundo.", _cards([HalliRules.make_card(0, 3)])))
	col.add_child(_step("3. Cinco de uma fruta? Sino!", "Quando as cartas visíveis somam exatamente 5 de uma mesma fruta, bata o sino. Quem bater primeiro leva todas as cartas abertas pro fundo do monte.", _cards([HalliRules.make_card(0, 2), HalliRules.make_card(1, 4), HalliRules.make_card(0, 3)])))
	col.add_child(_step("Bateu errado?", "As cartas abertas voltam pro fundo do monte de cada dono, e quem bateu dá uma carta do seu monte pra cada um dos outros.", null, Tokens.tint(Tokens.VERMELHO, 0.18)))
	col.add_child(_step("Sem cartas no monte", "Você continua enquanto tiver carta aberta na mesa (e pode voltar ganhando um sino). Se chegar a sua vez e não tiver o que virar, você sai.", null))
	col.add_child(_step("Quem vence", "O último que sobrar com cartas.", null, Tokens.MOSTARDA))
	col.add_child(UI.label("No Wi-Fi", 24, Tokens.TINTA, Fonts.title()))
	col.add_child(_step("O celular é a sua carta", "Deixe o celular deitado na mesa, na sua frente. Ele mostra só a sua carta; os outros olham pra ele como olhariam pra carta de verdade. Quando for sua vez, a borda acende e o celular vibra.", null))
	col.add_child(_step("Gestos", "Arraste em qualquer lugar da tela pra virar. Toque duas vezes em qualquer lugar pra bater o sino. Vale o instante exato do toque, medido no seu celular: sinal de rede lento não faz você perder.", null, Tokens.tint(Tokens.SALVIA, 0.18)))


func _step(title_text: String, body: String, art: Control, color := Tokens.SUPERFICIE) -> Control:
	var c := UI.card(color, 20)
	var v := UI.vbox(10)
	c.add_child(v)
	v.add_child(UI.label(title_text, 22, Tokens.TINTA, Fonts.title()))
	v.add_child(UI.label(body, 17, Tokens.TINTA, Fonts.body()))
	if art:
		v.add_child(art)
	return c


func _cards(cards: Array) -> Control:
	var row := CardRow.new()
	row.cards = cards
	row.custom_minimum_size = Vector2(0, 170)
	return row


## Fileira de cartas de exemplo (vazia = um monte fechado).
class CardRow extends Control:
	var cards: Array = []

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := size.y - 10
		var w := h / HalliArt.CARD_RATIO
		if cards.is_empty():
			HalliArt.draw_pile(self, Rect2(Vector2((size.x - w) / 2.0, 6), Vector2(w, h)), 18, 22)
			return
		var gap := 18.0
		var total := cards.size() * w + (cards.size() - 1) * gap
		var x := (size.x - total) / 2.0
		for c in cards:
			HalliArt.draw_face(self, Rect2(Vector2(x, 4), Vector2(w, h)), c)
			x += w + gap
