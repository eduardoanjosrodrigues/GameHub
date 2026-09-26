class_name ChapeuText
extends RefCounted
## Textos do Chapéu (regras das rodadas etc.).

const ROUNDS := {
	"descrever": {
		"nome": "Descrever",
		"regra": "Explique com quantas palavras quiser, só não pode dizer a palavra (nem parte dela).",
		"curta": "Explique sem dizer a palavra",
		"icone": "rodada_descrever",
		"cor": Tokens.AZUL,
	},
	"uma_palavra": {
		"nome": "Uma palavra",
		"regra": "Só pode dar UMA palavra de dica. Pense bem antes de falar!",
		"curta": "Só uma palavra de dica",
		"icone": "rodada_uma_palavra",
		"cor": Tokens.MOSTARDA,
	},
	"mimica": {
		"nome": "Mímica",
		"regra": "Só gestos, sem som nenhum. Vale apontar, dançar e fazer careta.",
		"curta": "Só mímica, sem som",
		"icone": "rodada_mimica",
		"cor": Tokens.SALVIA,
	},
}

const SOURCES := [["jogadores", "Jogadores"], ["lista", "Lista pronta"], ["mistura", "Mistura"]]

const CRITERIA := {
	"pontos": "Mais pontos no total.",
	"rodadas": "Empatou nos pontos: venceu quem ganhou mais rodadas.",
	"mimica": "Empatou nos pontos e nas rodadas: venceu quem fez mais na mímica.",
	"empate": "Empate em tudo: pontos, rodadas vencidas e mímica.",
}


static func round_info(key: String) -> Dictionary:
	return ROUNDS.get(key, ROUNDS.descrever)
