class_name GlyphAtlas
extends RefCounted

## Fonte ÚNICA do glifo Garra Tribal 16×16 + máscaras por papel/orientação.
##
## Antes o glifo era desenhado célula-a-célula (~50 draw_rect por widget POR
## FRAME durante a janela de timing) e a matriz vivia triplicada em
## CombatArrowButton, TimingBubble e FloatingDpad. Agora cada widget desenha
## 3 draw_texture_rect sobre máscaras cacheadas (PRD-performance-refactor-web,
## Frente C).
##
## Modelo de cor: cada papel ('O' juba clara, 'D' juba escura, 'K' outline)
## é recolorido de forma INDEPENDENTE pelos widgets (lerps de press/janela,
## ganho de fase, alphas distintos — a bolha usa dark×0.7, o botão dark×1.0).
## Por isso as máscaras são 100% BRANCO-OPACO onde o papel existe: texel ×
## modulate == modulate, ou seja, a cor final é exatamente a Color que o
## código immediate-mode calculava — identidade tonal por construção. BODY
## (O∪D) existe para o medidor de carga do Cortejo, onde o miolo colapsa em
## fill/dim por linha e só o outline difere.
##
## Rotações: 4 variantes pré-rotacionadas por papel (mesma tabela inteira do
## antigo _rotated_cell — exata por construção, sem transform 2D por frame).
##
## Classe PURA de propósito (sem autoloads, nem Constants): carregável por
## scripts -s/preview e GUT headless (gotcha #14).

const GRID: int = 16
# Garra Tribal da Mata — ponta afiada 2px, corpo simétrico com D-pixels de
# profundidade, base V-aberta. Desenhada apontando para CIMA.
# '.'=vazio  'K'=outline preto  'O'=juba clara  'D'=juba escura.
const GLYPH: PackedStringArray = [
	"................",   # 0
	".......KK.......",   # 1 — ponta 2 px
	"......KOOK......",   # 2
	"....KKOOOOKK....",   # 3
	"...KKOOOOOOKK...",   # 4
	"..KKOOODDOOOKK..",   # 5
	".KKOOODDDDOOOKK.",   # 6
	"KKOOODDKKDDOOOKK",   # 7 — ombros totais
	"KKKK.KOOODK.KKKK",   # 8 — entalhe tribal (arrowhead → shaft)
	".....KOOODK.....",   # 9 — shaft
	".....KOOODK.....",   # 10
	".....KOOODK.....",   # 11
	".....KOOODK.....",   # 12
	".....KDDDDK.....",   # 13 — base com sombra
	".....KKKKKK.....",   # 14 — base fechada
	"................",   # 15
]

enum Role { BRIGHT, DARK, OUTLINE, BODY }
## Valores 0..3 coincidem com _ORIENTATIONS do CombatArrowButton.
enum Orientation { UP, RIGHT, DOWN, LEFT }

# Parâmetros de papel/orientação tipados como int (não como o enum): o GDScript
# 4.6 não reconhece "GlyphAtlas.Orientation" externo == "Orientation" interno
# quando a classe resolve via cache global — enum tipado em parâmetro quebra o
# parse dos CONSUMIDORES. Enums seguem sendo o vocabulário dos call sites.
static var _textures: Dictionary = {}


## Máscara cacheada (lazy) do papel na orientação: branco-opaco onde o papel
## existe, transparente no resto. 16 combinações × 1KB — custo fixo desprezível.
static func mask(role: int, orientation: int) -> ImageTexture:
	var key: int = role * 4 + orientation
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(mask_image(role, orientation))
	return _textures[key] as ImageTexture


## Image crua da máscara (sem cache de GPU) — base de mask() e dos testes.
static func mask_image(role: int, orientation: int) -> Image:
	var img := Image.create(GRID, GRID, false, Image.FORMAT_RGBA8)
	for r: int in GRID:
		var row: String = GLYPH[r]
		for c: int in GRID:
			if _role_matches(row[c], role):
				var p: Vector2i = _rotated_xy(r, c, orientation)
				img.set_pixel(p.x, p.y, Color(1.0, 1.0, 1.0, 1.0))
	return img


static func orientation_for_action(action: String) -> int:
	match action:
		"ui_right": return Orientation.RIGHT
		"ui_down": return Orientation.DOWN
		"ui_left": return Orientation.LEFT
		_: return Orientation.UP


static func orientation_for_hint(hint: String) -> int:
	match hint:
		"right": return Orientation.RIGHT
		"down": return Orientation.DOWN
		"left": return Orientation.LEFT
		_: return Orientation.UP


static func _role_matches(ch: String, role: int) -> bool:
	match role:
		Role.BRIGHT: return ch == "O"
		Role.DARK: return ch == "D"
		Role.OUTLINE: return ch == "K"
		_: return ch == "O" or ch == "D"  # BODY


## Célula (r, c) do glifo UP → posição (x, y) na orientação dada. Mesma tabela
## do antigo _rotated_cell/_glyph_rotated_cell dos widgets, travada por teste.
static func _rotated_xy(r: int, c: int, orientation: int) -> Vector2i:
	var g: int = GRID - 1
	match orientation:
		Orientation.RIGHT: return Vector2i(g - r, c)
		Orientation.DOWN: return Vector2i(g - c, g - r)
		Orientation.LEFT: return Vector2i(r, g - c)
		_: return Vector2i(c, r)  # UP
