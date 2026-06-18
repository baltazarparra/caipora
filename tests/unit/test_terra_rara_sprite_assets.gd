extends GutTest

# Contrato dos sprites da TERRA RARA (a economia do jogo). Minério bruto cristalino:
# matriz de rocha escura + facetas âmbar. Gerador canônico: scripts/tools/gen_terra_rara.py.
# Trava de marca: usa o âmbar/laranja da identidade e NÃO usa o verde (reservado à Fúria).
# Espelha o padrão de test_caipora_sprite_assets.gd (lê o PNG cru via Image.load_from_file).

const SIZE := Vector2i(32, 32)
const ASSETS := [
	"res://assets/sprites/terra_rara_icon.png",
	"res://assets/sprites/terra_rara_node.png",
]

func test_assets_load_and_are_32x32() -> void:
	for path: String in ASSETS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_not_null(image, "%s carrega" % path)
		if image == null:
			continue
		assert_eq(image.get_size(), SIZE, "%s mantém o contrato 32x32" % path)

func test_has_amber_and_no_furia_green() -> void:
	for path: String in ASSETS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null:
			continue
		var amber := 0
		var green := 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				var c := image.get_pixel(x, y)
				if c.a < 0.5:
					continue
				# âmbar/laranja: vermelho forte, verde médio, azul baixo
				if c.r > 0.6 and c.g > 0.2 and c.g < 0.78 and c.b < 0.35:
					amber += 1
				# verde da Fúria: verde dominante sobre vermelho — proibido na economia
				if c.g > 0.55 and c.r < 0.5 and c.b < 0.6:
					green += 1
		assert_gt(amber, 10, "%s tem facetas âmbar (identidade da marca)" % path)
		assert_eq(green, 0, "%s não usa o verde da Fúria" % path)
