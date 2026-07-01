class_name BrandFrame
extends RefCounted

# "Chrome da Mata" v2 — vocabulário de desenho compartilhado da UI: placa com crista
# de juba (dentes irregulares em ritmo fixo, degraus de pixel), borda em camadas
# (aro quase-preto + traço de juba), garras-chevron e brasa âmbar. Funções estáticas
# chamadas no _draw() de qualquer CanvasItem (BrandButton, BrandPanel, HudHeader...).
# A geometria escalar vive em Constants.CHROME_*; o ritmo da crista é vocabulário daqui.

const EMBER_ROWS := 3
const CLAW_STRING := ">>"
const CLAW_STRING_R := "<<"

## Ritmo fixo da crista (largura, altura) — determinístico como a juba do sprite,
## nunca aleatório. O dente mais alto tem h == Constants.CHROME_CREST_H; os tufos
## são largos (mecha de juba), não picote fino.
const CREST_TEETH: Array[Vector2] = [
	Vector2(18.0, 10.0), Vector2(12.0, 6.0), Vector2(24.0, 12.0),
	Vector2(14.0, 8.0), Vector2(10.0, 4.0), Vector2(20.0, 8.0),
]

## Altura da faixa da crista (o quanto os dentes ocupam do topo/base do body).
## Snap em 2px — degraus de pixel, nunca subpixel.
static func crest_clearance(crest_scale: float = 1.0) -> float:
	return maxf(4.0, snappedf(Constants.CHROME_CREST_H * crest_scale, 2.0))

static func _tooth(index: int, crest_scale: float) -> Vector2:
	var t: Vector2 = CREST_TEETH[index % CREST_TEETH.size()]
	return Vector2(
		maxf(4.0, snappedf(t.x * crest_scale, 2.0)),
		maxf(2.0, snappedf(t.y * crest_scale, 2.0))
	)

## Polígono da placa com crista de juba no topo e na base (fechado, 100% axis-aligned:
## todo segmento é horizontal ou vertical — lei da pixel-art chapada, sem diagonal).
static func plate_points(body: Rect2, crest_scale: float = 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var band := crest_clearance(crest_scale)
	# Placa baixa demais para duas cristas: encolhe a faixa (nunca inverte o corpo).
	band = minf(band, maxf(2.0, snappedf((body.size.y - 4.0) * 0.5, 2.0)))
	var top_shoulder := body.position.y + band
	var bot_shoulder := body.end.y - band
	# Topo: skyline esquerda→direita.
	var x := body.position.x
	var i := 0
	while x < body.end.x - 0.01:
		var tooth := _tooth(i, crest_scale)
		var x1 := minf(x + tooth.x, body.end.x)
		var ty := top_shoulder - minf(tooth.y, band)
		pts.append(Vector2(x, ty))
		pts.append(Vector2(x1, ty))
		x = x1
		i += 1
	# Base: skyline direita→esquerda (mesmo ritmo, sentido invertido — assimetria viva).
	x = body.end.x
	i = 0
	while x > body.position.x + 0.01:
		var tooth := _tooth(i, crest_scale)
		var x0 := maxf(x - tooth.x, body.position.x)
		var by := bot_shoulder + minf(tooth.y, band)
		pts.append(Vector2(x, by))
		pts.append(Vector2(x0, by))
		x = x0
		i += 1
	return pts

## Centro do topo dos dentes mais altos — pontas onde a brasa acende (elementos-herói).
static func crest_peaks(body: Rect2, crest_scale: float = 1.0) -> PackedVector2Array:
	var peaks := PackedVector2Array()
	var band := crest_clearance(crest_scale)
	var top_shoulder := body.position.y + band
	var x := body.position.x
	var i := 0
	while x < body.end.x - 0.01:
		var tooth := _tooth(i, crest_scale)
		var x1 := minf(x + tooth.x, body.end.x)
		if tooth.y >= band * 0.7:
			peaks.append(Vector2((x + x1) * 0.5, top_shoulder - minf(tooth.y, band)))
		x = x1
		i += 1
	return peaks

## Contorno fechado por retângulos (um por segmento, estendido meia-largura nos
## cantos para fechar as juntas). draw_line com butt cap deixa mossa em cada degrau.
static func stroke_polyline_closed(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	var half := width * 0.5
	for i: int in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var mn := a.min(b) - Vector2(half, half)
		var sz := b.max(a) - a.min(b) + Vector2(width, width)
		ci.draw_rect(Rect2(mn, sz), color)

## Colunas (Rect2) da crista de um dos lados: do topo do dente ao ombro do body.
static func _crest_columns(body: Rect2, crest_scale: float, top: bool) -> Array[Rect2]:
	var cols: Array[Rect2] = []
	var band := crest_clearance(crest_scale)
	band = minf(band, maxf(2.0, snappedf((body.size.y - 4.0) * 0.5, 2.0)))
	var i := 0
	if top:
		var shoulder := body.position.y + band
		var x := body.position.x
		while x < body.end.x - 0.01:
			var tooth := _tooth(i, crest_scale)
			var x1 := minf(x + tooth.x, body.end.x)
			var h := minf(tooth.y, band)
			cols.append(Rect2(x, shoulder - h, x1 - x, h))
			x = x1
			i += 1
	else:
		var shoulder := body.end.y - band
		var x := body.end.x
		while x > body.position.x + 0.01:
			var tooth := _tooth(i, crest_scale)
			var x0 := maxf(x - tooth.x, body.position.x)
			var h := minf(tooth.y, band)
			cols.append(Rect2(x0, shoulder, x - x0, h))
			x = x0
			i += 1
	return cols

## Placa preenchida + crista SÓLIDA de juba + borda em camadas (selout): a mecha é
## material da juba (tufo cheio, tom escuro + cap no tom da borda), não picote vazado.
## `border` já vem lit/apagado do chamador.
static func draw_plate(ci: CanvasItem, body: Rect2, bg: Color, border: Color, outline_w: float = float(Constants.UI_BORDER_WIDTH), crest_scale: float = 1.0) -> void:
	var plate := plate_points(body, crest_scale)
	if bg.a > 0.0:
		ci.draw_colored_polygon(plate, bg)
	# Tufos sólidos: preenchem a faixa da crista no tom escuro da juba.
	var tuft := Constants.COLOR_JUBA_DARK
	var cap_h := maxf(2.0, snappedf(2.0 * crest_scale, 2.0))
	for side_top: bool in [true, false]:
		for col: Rect2 in _crest_columns(body, crest_scale, side_top):
			if col.size.y <= 0.5:
				continue
			ci.draw_rect(col, tuft)
			# Cap de selout na ponta do tufo (o realce da mecha).
			var cap := Rect2(col.position, Vector2(col.size.x, minf(cap_h, col.size.y))) if side_top \
				else Rect2(Vector2(col.position.x, col.end.y - minf(cap_h, col.size.y)), Vector2(col.size.x, minf(cap_h, col.size.y)))
			ci.draw_rect(cap, border)
	stroke_polyline_closed(ci, plate, Constants.COLOR_CHROME_OUTLINE, outline_w + 2.0)
	stroke_polyline_closed(ci, plate, border, outline_w)

## Garras-chevron (>> ... <<) nas laterais internas — ornamento de marca.
static func draw_claws(ci: CanvasItem, font: Font, inner: Rect2, color: Color) -> void:
	var fs: int = int(clampf(inner.size.y * 0.24, 18.0, 28.0))
	var y: float = inner.position.y + inner.size.y * 0.57
	var inset: float = Constants.CHROME_CLAW_INSET
	ci.draw_string(font, Vector2(inner.position.x + inset, y), CLAW_STRING, HORIZONTAL_ALIGNMENT_LEFT, 70.0, fs, color)
	ci.draw_string(font, Vector2(inner.end.x - 76.0, y), CLAW_STRING_R, HORIZONTAL_ALIGNMENT_RIGHT, 70.0, fs, color)

## Fileiras de brasa âmbar subindo da base da placa (identidade "fogo da mata").
static func draw_embers(ci: CanvasItem, body: Rect2, color: Color, alpha: float, crest_scale: float = 1.0) -> void:
	var col := color
	col.a = clampf(alpha, 0.0, 0.86)
	var y: float = body.end.y - crest_clearance(crest_scale) - 3.0
	var center: float = body.position.x + body.size.x * 0.5
	var max_half: float = body.size.x * 0.34
	for row: int in range(EMBER_ROWS):
		var half: float = max_half * (1.0 - float(row) * 0.23)
		# Fileiras sobem (afunilando) a partir do ombro — brasa nunca invade a crista.
		var yy: float = y - float(row) * 3.0
		var x: float = center - half
		while x < center + half:
			var w: float = 3.0 + fmod(floorf(x + row * 11.0), 4.0)
			ci.draw_rect(Rect2(Vector2(x, yy), Vector2(w, 2.0)), col)
			x += 10.0

## Pontas da crista em brasa (só elementos-herói/lit): pixels âmbar nos picos altos.
static func draw_crest_embers(ci: CanvasItem, body: Rect2, color: Color, alpha: float, crest_scale: float = 1.0) -> void:
	var col := color
	col.a = clampf(alpha, 0.0, 0.9)
	for p: Vector2 in crest_peaks(body, crest_scale):
		ci.draw_rect(Rect2(p - Vector2(2.0, 0.0), Vector2(4.0, 2.0)), col)
