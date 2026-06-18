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

func test_chance_matches_double_attack() -> void:
	assert_eq(Constants.CORTEJO_CHANCE, Constants.TIMING_DOUBLE_CHANCE,
		"o Golpe Perfeito rola na mesma chance do ataque duplo")
