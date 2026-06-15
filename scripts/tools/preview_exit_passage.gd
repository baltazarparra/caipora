extends SceneTree

## Captura dev-only do novo marcador de saída (MapObject.EXIT_PASSAGE): a passagem ritual
## ampliada sobre fundo de noite, ao lado da toca (BURROW) e da chama (FIRE) pra comparar a
## leitura. Gate visual da arte chapada isolada (silhueta laranja/âmbar + vazio preto +
## osso/sangue), sem depender de gerar uma fase inteira.
## Uso: godot --path . --resolution 480x320 -s scripts/tools/preview_exit_passage.gd \
##     -- --out=/tmp/exit_passage.png

const MapObject := preload("res://scripts/exploration/map_object.gd")

var _out: String = "/tmp/exit_passage.png"
var _frames: int = 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())

var _vp: SubViewport

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		# SubViewport de tamanho exato: contorna o stretch do projeto (resolução base fixa).
		_vp = SubViewport.new()
		_vp.size = Vector2i(540, 200)
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(_vp)
		var bg := ColorRect.new()
		bg.color = Constants.COLOR_NIGHT
		bg.size = Vector2(540, 200)
		_vp.add_child(bg)
		var labels := ["EXIT_PASSAGE", "BURROW", "FIRE"]
		var types := [MapObject.Type.EXIT_PASSAGE, MapObject.Type.BURROW, MapObject.Type.FIRE]
		for i: int in types.size():
			var holder := Node2D.new()
			holder.position = Vector2(90 + i * 180, 110)
			holder.scale = Vector2(5, 5)
			_vp.add_child(holder)
			var obj := MapObject.new()
			holder.add_child(obj)
			obj.setup(types[i], Vector2i.ZERO, true)
			obj.position = Vector2(-16, -16)   # centra o tile (o _draw usa 0..32)
			var lbl := Label.new()
			lbl.text = labels[i]
			lbl.position = Vector2(30 + i * 180, 14)
			_vp.add_child(lbl)
	if _frames >= 16:
		_vp.get_texture().get_image().save_png(_out)
		print("[preview] saved ", _out)
		return true
	return false
