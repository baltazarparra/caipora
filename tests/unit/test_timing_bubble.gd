extends GutTest

## Flash verde-cristal da janela perfeita no TimingBubble. Testa a LÓGICA
## (timer + blend de cor) dirigindo _process manualmente, sem depender de render.

var _bubble: TimingBubble

func before_each() -> void:
	_bubble = TimingBubble.new()
	add_child_autofree(_bubble)
	_bubble.set_process(false)  # dirigimos _process na mão

func test_flash_fires_on_perfect_window_entry() -> void:
	_bubble.show_bubble(Vector2.ZERO, 1.0, 0.5, 0.7)
	_bubble._process(0.45)
	assert_eq(_bubble._flash_timer, 0.0, "antes da janela: sem flash")
	assert_gt(_bubble._color.r, _bubble._color.g, "antes da janela: anel vermelho (ataque)")

	_bubble._process(0.06)  # progress 0.51 — entrou na janela perfeita
	assert_gt(_bubble._flash_timer, 0.0, "entrada na janela liga o flash")
	assert_gt(_bubble._color.g, _bubble._color.r, "flash puxa o anel para o verde-cristal")

func test_flash_decays_back_to_mode_color() -> void:
	_bubble.show_bubble(Vector2.ZERO, 1.0, 0.5, 0.7)
	_bubble._process(0.51)
	assert_gt(_bubble._flash_timer, 0.0, "flash ativo na entrada")
	_bubble._process(0.15)  # > FLASH_S — flash esgotado, ainda na janela
	assert_eq(_bubble._flash_timer, 0.0, "flash decai em FLASH_S")
	assert_gt(_bubble._color.r, _bubble._color.g, "anel volta ao vermelho de ataque")

func test_flash_in_defense_mode_returns_to_blue() -> void:
	_bubble.show_bubble(Vector2.ZERO, 1.0, 0.5, 0.7, true)
	_bubble._process(0.51)
	assert_gt(_bubble._color.g, _bubble._color.r, "flash verde também na esquiva")
	_bubble._process(0.15)
	assert_gt(_bubble._color.b, _bubble._color.g, "anel volta ao azul de esquiva")

func test_frozen_holds_flash() -> void:
	_bubble.show_bubble(Vector2.ZERO, 1.0, 0.5, 0.7)
	_bubble._process(0.51)
	var held: float = _bubble._flash_timer
	assert_gt(held, 0.0, "flash ativo")
	_bubble.set_frozen(true)
	_bubble._process(0.2)
	assert_eq(_bubble._flash_timer, held, "hit-stop congela o flash junto")

func test_show_bubble_resets_stale_flash() -> void:
	_bubble.show_bubble(Vector2.ZERO, 1.0, 0.5, 0.7)
	_bubble._process(0.51)
	assert_gt(_bubble._flash_timer, 0.0, "flash ativo")
	_bubble.show_bubble(Vector2.ZERO, 1.0, 0.5, 0.7)
	assert_eq(_bubble._flash_timer, 0.0, "bolha re-mostrada não herda flash")

# ─── Faixa GOOD (bloqueio parcial) ─────────────────
# Cue de aproximação dispara ao ENTRAR na faixa GOOD (antes do perfeito) + halo âmbar.
func test_approach_cue_fires_on_good_band_entry() -> void:
	var fired: Array = [false]
	_bubble.approach_entered.connect(func(): fired[0] = true)
	_bubble.show_bubble(Vector2.ZERO, 1.0, 0.5, 0.7, false, Color.TRANSPARENT, "up", false, 0.3, 0.9)
	_bubble._process(0.2)   # progress 0.2 — antes do good
	assert_false(fired[0], "antes do good: sem cue")
	_bubble._process(0.15)  # progress 0.35 — entrou no good (antes do perfeito)
	assert_true(fired[0], "entrada no good dispara o cue de aproximação")
	assert_gt(_bubble._good_alpha, 0.0, "halo âmbar aceso no good")

# Sem faixa GOOD explícita (binário/Cortejo): good=perfect, sem cue antes do perfeito.
func test_no_approach_cue_without_good_band() -> void:
	var fired: Array = [false]
	_bubble.approach_entered.connect(func(): fired[0] = true)
	_bubble.show_bubble(Vector2.ZERO, 1.0, 0.5, 0.7)
	_bubble._process(0.35)  # antes do perfeito (= good, pois good=perfect)
	assert_false(fired[0], "sem good explícito, não há cue antes do perfeito")

func test_burst_good_is_amber_and_not_fail() -> void:
	_bubble.show_bubble(Vector2.ZERO, 1.0, 0.5, 0.7, false, Color.TRANSPARENT, "up", false, 0.3, 0.9)
	_bubble.burst_good()
	assert_true(_bubble._burst_good, "burst_good liga o estouro âmbar")
	assert_false(_bubble._burst_fail, "burst_good não é falha")
	assert_gt(_bubble._burst_timer, 0.0, "burst ativo")

# ─── Modo carga (Cortejo "O Chamado") ──────────────
func test_charge_stores_links() -> void:
	_bubble.show_bubble(Vector2.ZERO, 1.0, 0.80, 0.94, false, Color.TRANSPARENT, "up", true, 0.66, 0.94, 4)
	assert_eq(_bubble._charge_links, 4, "o medidor guarda o nº de espíritos para os notches")

# Carga: cue de aproximação ao entrar no ombro GOOD, depois SOLTE! ao entrar na banda.
func test_charge_approach_then_release_cues() -> void:
	var approach: Array = [false]
	var release: Array = [false]
	_bubble.approach_entered.connect(func(): approach[0] = true)
	_bubble.vulnerable_entered.connect(func(): release[0] = true)
	_bubble.show_bubble(Vector2.ZERO, 1.0, 0.80, 0.94, false, Color.TRANSPARENT, "up", true, 0.66, 0.94, 4)
	_bubble._process(0.70)   # progress 0.70 — ombro GOOD, antes da banda
	assert_true(approach[0], "entrada no ombro dispara o cue de aproximação")
	assert_false(release[0], "ainda não entrou na banda dourada")
	_bubble._process(0.12)   # progress 0.82 — banda dourada de SOLTAR
	assert_true(release[0], "entrada na banda dispara o cue SOLTE! + flash")
	assert_gt(_bubble._flash_timer, 0.0, "flash na banda de soltar")
