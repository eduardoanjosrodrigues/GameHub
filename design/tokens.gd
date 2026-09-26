class_name Tokens
extends RefCounted
## Tokens do design system (docs/PLANO_FASE_1.md §7).

# Paleta
const AZUL := Color("#3A86FF")
const VERMELHO := Color("#FF3B4E")
const ROSA := Color("#FF4D8D")
const TURQUESA := Color("#06D6A0")
const LIMA := Color("#C6F432")
const GELO := Color("#F4F7FF")
const BRANCO := Color("#FFFFFF")
const TINTA := Color("#1B1F3B")
const TINTA_SUAVE := Color("#5A6080")
const AZUL_ESCURO := Color("#1F5FCC")
const VERMELHO_ESCURO := Color("#D42637")
const ROSA_ESCURO := Color("#D93672")
const TURQUESA_ESCURO := Color("#04A77D")
const DESABILITADO := Color("#D5D9E8")

const TEAM_COLORS := {"azul": AZUL, "vermelho": VERMELHO}
const TEAM_DARK := {"azul": AZUL_ESCURO, "vermelho": VERMELHO_ESCURO}
const TEAM_NAMES := {"azul": "Time Azul", "vermelho": "Time Vermelho"}

# Forma
const BORDER := 3
const SHADOW := 6
const PRESS_DEPTH := 4
const RADIUS_CARD := 20
const RADIUS_FIELD := 16
const SPACE := 8
const TOUCH_MIN := 56
const CONTENT_MAX_WIDTH := 600.0

# Tipografia (px na resolução base 720×1280)
const FS_WORD := 56
const FS_TITLE := 40
const FS_SUBTITLE := 28
const FS_BUTTON := 22
const FS_BODY := 18
const FS_CAPTION := 14


static func team_color(team: String) -> Color:
	return TEAM_COLORS.get(team, TINTA_SUAVE)


static func team_name(team: String) -> String:
	return TEAM_NAMES.get(team, "")
