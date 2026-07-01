extends GutTest

# Cobre o seam puro do Cortejo "O Chamado": quais espíritos entram na barragem a partir
# das fases libertadas (ordem, corte no teto, crescimento), o nº de instâncias de dano
# (espíritos × CORTEJO_LINK_HITS) e o mapa de tiers do SEGURAR→SOLTAR (bandas, FRACO
# parcial × QUEIMA). Determinístico, sem arena.

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

func test_chamado_bands_ordered() -> void:
	# Ombro GOOD antes da banda dourada; banda com começo antes do fim.
	assert_lt(Constants.CHAMADO_GOOD_START, Constants.CHAMADO_RELEASE_START,
		"o ombro GOOD vem antes da banda PERFEITO")
	assert_lt(Constants.CHAMADO_RELEASE_START, Constants.CHAMADO_RELEASE_END,
		"a banda dourada tem começo antes do fim")
	assert_gte(Constants.CHAMADO_RELEASE_END - Constants.CHAMADO_RELEASE_START, 0.10,
		"a banda de soltar é larga (perdão), não frame-perfect")

func test_weak_is_early_release_only() -> void:
	# Soltar antes do ombro = FRACO (parcial); do ombro em diante (tardio/timeout) = QUEIMA.
	assert_true(Constants.chamado_miss_is_weak(0.30), "soltar cedo = FRACO")
	assert_true(Constants.chamado_miss_is_weak(Constants.CHAMADO_GOOD_START - 0.01))
	assert_false(Constants.chamado_miss_is_weak(Constants.CHAMADO_GOOD_START),
		"a partir do ombro não é FRACO")
	assert_false(Constants.chamado_miss_is_weak(1.0), "timeout/overcharge = QUEIMA, não FRACO")

func test_partial_count_scales_with_charge() -> void:
	# k ∝ fração carregada, mínimo 1, teto n. Soltar quase no ombro traz quase todos.
	assert_eq(Constants.chamado_partial_count(4, 0.05), 1, "soltar no início = 1 espírito")
	assert_eq(Constants.chamado_partial_count(4, 0.40), 2, "meio caminho = parcial")
	assert_eq(Constants.chamado_partial_count(4, Constants.CHAMADO_GOOD_START), 4,
		"soltar junto ao ombro já traz todos (mas sem crit)")
	assert_eq(Constants.chamado_partial_count(1, 0.30), 1, "1 liberto = sempre 1")
	assert_eq(Constants.chamado_partial_count(0, 0.5), 0, "sem espíritos = 0")

func test_chance_matches_double_attack() -> void:
	assert_eq(Constants.CORTEJO_CHANCE, Constants.TIMING_DOUBLE_CHANCE,
		"o Golpe Perfeito rola na mesma chance do ataque duplo")
