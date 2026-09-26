class_name TextNorm
extends RefCounted
## Normalização pra comparar palavras: minúsculas, sem acento, espaços simples.

const _MAP := {
	"á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a",
	"é": "e", "è": "e", "ê": "e", "ë": "e",
	"í": "i", "ì": "i", "î": "i", "ï": "i",
	"ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o",
	"ú": "u", "ù": "u", "û": "u", "ü": "u",
	"ç": "c", "ñ": "n",
}


static func normalize(s: String) -> String:
	var low := s.strip_edges().to_lower()
	var out := ""
	var prev_space := false
	for ch in low:
		if ch == " " or ch == "\t":
			if not prev_space:
				out += " "
			prev_space = true
			continue
		prev_space = false
		out += _MAP.get(ch, ch)
	return out


## Limpa o que a pessoa digitou (tira espaços extras), mantendo acentos e maiúsculas.
static func clean(s: String) -> String:
	var parts := s.strip_edges().split(" ", false)
	return " ".join(parts)
