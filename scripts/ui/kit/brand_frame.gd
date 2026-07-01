class_name BrandFrame
extends RefCounted

# "Chrome da Mata" — vocabulário de desenho compartilhado da UI: placa serrilhada,
# borda dura, garras-chevron e brasa âmbar. Funções estáticas chamadas no _draw() de
# qualquer CanvasItem (BrandButton, BrandPanel, HudHeader...). A geometria vive em
# Constants.CHROME_*.

const EMBER_ROWS := 3
const CLAW_STRING := ">>"
const CLAW_STRING_R := "<<"

## Polígono da placa com topo e base em dente de serra (fechado).
static func saw_plate(body: Rect2) -> PackedVector2Array:
	var step: float = Constants.CHROME_SAW_STEP
	var depth: float = Constants.CHROME_SAW_DEPTH
	var pts := PackedVector2Array()
	pts.append(Vector2(body.position.x, body.position.y + depth))
	var x: float = body.position.x
	while x < body.end.x:
		pts.append(Vector2(minf(x + step * 0.5, body.end.x), body.position.y))
		pts.append(Vector2(minf(x + step, body.end.x), body.position.y + depth))
		x += step
	pts.append(Vector2(body.end.x, body.end.y - depth))
	x = body.end.x
	while x > body.position.x:
		pts.append(Vector2(maxf(x - step * 0.5, body.position.x), body.end.y))
		pts.append(Vector2(maxf(x - step, body.position.x), body.end.y - depth))
		x -= step
	return pts

## Contorno fechado de um polígono (linha a linha, sem antialias — pixel-art chapada).
static func draw_polyline_closed(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	for i: int in range(points.size()):
		ci.draw_line(points[i], points[(i + 1) % points.size()], color, width, false)

## Placa preenchida + contorno serrilhado.
static func draw_plate(ci: CanvasItem, body: Rect2, bg: Color, border: Color, outline_w: float = float(Constants.UI_BORDER_WIDTH)) -> void:
	var plate := saw_plate(body)
	if bg.a > 0.0:
		ci.draw_colored_polygon(plate, bg)
	draw_polyline_closed(ci, plate, border, outline_w)

## Garras-chevron (>> ... <<) nas laterais internas — ornamento de marca.
static func draw_claws(ci: CanvasItem, font: Font, inner: Rect2, color: Color) -> void:
	var fs: int = int(clampf(inner.size.y * 0.24, 18.0, 28.0))
	var y: float = inner.position.y + inner.size.y * 0.57
	var inset: float = Constants.CHROME_CLAW_INSET
	ci.draw_string(font, Vector2(inner.position.x + inset, y), CLAW_STRING, HORIZONTAL_ALIGNMENT_LEFT, 70.0, fs, color)
	ci.draw_string(font, Vector2(inner.end.x - 76.0, y), CLAW_STRING_R, HORIZONTAL_ALIGNMENT_RIGHT, 70.0, fs, color)

## Borda dura reta (4 retângulos) — para painéis/cards que não usam serrilhado.
static func draw_hard_border(ci: CanvasItem, r: Rect2, color: Color, width: int = Constants.UI_BORDER_WIDTH) -> void:
	var w: float = float(width)
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, w), color)
	ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y - w, r.size.x, w), color)
	ci.draw_rect(Rect2(r.position.x, r.position.y, w, r.size.y), color)
	ci.draw_rect(Rect2(r.position.x + r.size.x - w, r.position.y, w, r.size.y), color)

## Fileiras de brasa âmbar subindo da base da placa (identidade "fogo da mata").
static func draw_embers(ci: CanvasItem, body: Rect2, color: Color, alpha: float) -> void:
	var col := color
	col.a = clampf(alpha, 0.0, 0.86)
	var y: float = body.end.y - Constants.CHROME_SAW_DEPTH - 3.0
	var center: float = body.position.x + body.size.x * 0.5
	var max_half: float = body.size.x * 0.34
	for row: int in range(EMBER_ROWS):
		var half: float = max_half * (1.0 - float(row) * 0.23)
		var yy: float = y + float(row) * 3.0
		var x: float = center - half
		while x < center + half:
			var w: float = 3.0 + fmod(floorf(x + row * 11.0), 4.0)
			ci.draw_rect(Rect2(Vector2(x, yy), Vector2(w, 2.0)), col)
			x += 10.0
