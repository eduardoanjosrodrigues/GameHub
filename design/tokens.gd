class_name Tokens
extends RefCounted
## Tokens do design system — estética "jogo de tabuleiro de papelaria".
## Papel creme, tinta quase preta, cores de impressão (cobalto, tomate, mostarda, sálvia),
## cantos suaves e sombras difusas. Contrastes conferidos por script (WCAG AA).

# Base
const PAPEL := Color("#F5EFE3") # fundo das telas
const SUPERFICIE := Color("#FFFCF6") # cartões
const TINTA := Color("#1F1D1A") # texto principal (16:1 no cartão)
const TINTA_SUAVE := Color("#6B6358") # texto secundário (5,8:1 no cartão)
const LINHA := Color("#E3DACB") # contornos finos e divisórias
const DESABILITADO := Color("#E6DFD3")
const TEXTO_DESABILITADO := Color("#A39A8C")

# Cores de impressão
const AZUL := Color("#2B59C3") # Time Azul — branco por cima: 6,3:1
const VERMELHO := Color("#C8392B") # Time Vermelho — branco por cima: 5,2:1
const MOSTARDA := Color("#F2B233") # destaque — tinta por cima: 9:1
const SALVIA := Color("#2F7D5B") # sucesso/acerto — branco por cima: 5:1

# Tons escuros (texto colorido sobre papel e fundos tingidos)
const AZUL_ESCURO := Color("#1F4494")
const VERMELHO_ESCURO := Color("#9E2A1F")
const MOSTARDA_ESCURO := Color("#7A5200")
const SALVIA_ESCURO := Color("#1F5C42")

const TEAM_COLORS := {"azul": AZUL, "vermelho": VERMELHO}
const TEAM_DARK := {"azul": AZUL_ESCURO, "vermelho": VERMELHO_ESCURO}
const TEAM_NAMES := {"azul": "Time Azul", "vermelho": "Time Vermelho"}

# Forma
const RADIUS_CARD := 22
const RADIUS_BUTTON := 18
const RADIUS_FIELD := 14
const BORDER := 1.5
const SPACE := 8
const TOUCH_MIN := 56
const CONTENT_MAX_WIDTH := 720.0 # largura base do celular: no celular ocupa tudo, no tablet fica centralizado
const SHADOW_COLOR := Color(0.12, 0.10, 0.06, 0.10)

# Tipografia (px na resolução base 720×1280)
const FS_WORD := 60
const FS_TITLE := 40
const FS_SUBTITLE := 26
const FS_BUTTON := 20
const FS_BODY := 18
const FS_CAPTION := 14


static func team_color(team: String) -> Color:
	return TEAM_COLORS.get(team, TINTA_SUAVE)


static func team_dark(team: String) -> Color:
	return TEAM_DARK.get(team, TINTA)


static func team_name(team: String) -> String:
	return TEAM_NAMES.get(team, "")


## Fundo tingido (cor de impressão bem clarinha sobre o cartão).
static func tint(c: Color, amount := 0.14) -> Color:
	return SUPERFICIE.lerp(c, amount)


## Cor de texto legível sobre um fundo sólido.
static func on(bg: Color) -> Color:
	return TINTA if bg.get_luminance() > 0.5 else SUPERFICIE


## Tom escuro correspondente (pra texto colorido).
static func dark_of(c: Color) -> Color:
	if c == AZUL:
		return AZUL_ESCURO
	if c == VERMELHO:
		return VERMELHO_ESCURO
	if c == MOSTARDA:
		return MOSTARDA_ESCURO
	if c == SALVIA:
		return SALVIA_ESCURO
	return TINTA
