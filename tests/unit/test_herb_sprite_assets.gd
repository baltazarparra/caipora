extends GutTest

# Contrato dos sprites da Erva da Vida: uma erva premium por fase (1–5), 48×48,
# carregável. Gerador canônico: scripts/tools/gen_ervas_vida.py. Espelha o padrão
# de test_caipora_sprite_assets.gd / test_inimigos_sprite_assets.gd.

const HERB_SIZE := Vector2(48, 48)

func test_herb_sprite_per_phase_loads_and_is_48x48() -> void:
	for phase: int in [1, 2, 3, 4, 5]:
		var path := "res://assets/sprites/erva_vida_p%d.png" % phase
		var texture := load(path) as Texture2D
		assert_not_null(texture, "%s carrega" % path)
		if texture == null:
			continue
		assert_eq(texture.get_size(), HERB_SIZE, "%s mantém contrato 48x48" % path)
