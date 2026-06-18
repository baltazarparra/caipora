extends GutTest

# Cobre o seam puro do Golpe Perfeito: quais espíritos entram na barragem a partir das
# fases libertadas (ordem, corte no teto, crescimento) e o nº de instâncias de dano
# (espíritos × CORTEJO_LINK_HITS). Determinístico, sem arena.

func test_spirits_in_phase_order() -> void:
	assert_eq(Constants.cortejo_spirits_for([1, 2, 3, 4]), [1, 2, 3, 4] as Array[int])

func test_spirits_sorted_regardless_of_freed_order() -> void:
	assert_eq(Constants.cortejo_spirits_for([3, 1]), [1, 3] as Array[int],
		"a barragem segue a ordem das fases, não a ordem de libertação")

func test_spirits_grow_with_freed_count() -> void:
	assert_eq(Constants.cortejo_spirits_for([1]), [1] as Array[int])
	assert_eq(Constants.cortejo_spirits_for([1, 2]), [1, 2] as Array[int])

func test_spirits_capped_at_max_links() -> void:
	var spirits := Constants.cortejo_spirits_for([1, 2, 3, 4])
	assert_lte(spirits.size(), Constants.CORTEJO_MAX_LINKS,
		"a barragem nunca passa do teto de espíritos")

func test_barrage_damage_instances_scale_with_spirits() -> void:
	# Dano total da barragem = nº de espíritos × hits por espírito.
	var one := Constants.cortejo_spirits_for([1]).size() * Constants.CORTEJO_LINK_HITS
	var four := Constants.cortejo_spirits_for([1, 2, 3, 4]).size() * Constants.CORTEJO_LINK_HITS
	assert_eq(one, Constants.CORTEJO_LINK_HITS, "1 espírito = LINK_HITS instâncias")
	assert_eq(four, 4 * Constants.CORTEJO_LINK_HITS, "4 espíritos = 4×LINK_HITS instâncias")
	assert_gt(four, one, "mais bosses libertados = barragem maior")

func test_each_hit_deals_one_damage() -> void:
	# Cada hit da barragem é fixo em 1: a força vem do nº de hits, não da magnitude.
	assert_eq(Constants.CORTEJO_HIT_DAMAGE, 1.0,
		"cada hit do Golpe Perfeito sangra exatamente 1, sem escalar com dano/crit")

func test_charge_release_window_is_comfortable() -> void:
	# Golpe Carregado: a zona de SOLTAR é larga de propósito (golpe-recompensa).
	assert_lt(Constants.CORTEJO_CHARGE_FULL, Constants.CORTEJO_OVERCHARGE,
		"carga cheia vem antes do overcharge")
	assert_gte(Constants.CORTEJO_OVERCHARGE - Constants.CORTEJO_CHARGE_FULL, 0.35,
		"a janela de soltar é confortável (>= 35% da janela)")

func test_charge_window_respects_floor_every_phase() -> void:
	# O piso de conforto vale em TODA fase (nunca vira frame-perfect nas fases altas).
	for phase: int in [1, 2, 3, 4, 5]:
		assert_gte(Constants.cortejo_window_for_phase(phase), Constants.CORTEJO_WINDOW_FLOOR,
			"fase %d respeita o piso confortável" % phase)

func test_chance_matches_double_attack() -> void:
	assert_eq(Constants.CORTEJO_CHANCE, Constants.TIMING_DOUBLE_CHANCE,
		"o Golpe Perfeito rola na mesma chance do ataque duplo")
