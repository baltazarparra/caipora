extends GutTest

# HealthBar substitui o HealthIcons. A LÓGICA (valor/máx/clamp) é o que importa para o
# jogo — testamos isso de forma determinística, sem depender de render/tween.
# Desde 2026-07: SÓ a barra, sem texto (decisão do dono) e altura padrão única (BAR_H).

var _bar: HealthBar

func before_each():
	_bar = HealthBar.new()
	add_child_autofree(_bar)

func test_setup_initializes_full():
	_bar.setup(10.0, Color.RED, Color.BLACK, Color.RED)
	assert_eq(_bar._max, 10.0)
	assert_eq(_bar._value, 10.0)

func test_set_value_clamps():
	_bar.setup(10.0, Color.RED, Color.BLACK, Color.RED)
	_bar.set_value(7.0)
	assert_eq(_bar._value, 7.0)
	_bar.set_value(-5.0)
	assert_eq(_bar._value, 0.0)
	_bar.set_value(999.0)
	assert_eq(_bar._value, 10.0)

func test_set_max_preserves_value():
	_bar.setup(10.0, Color.RED, Color.BLACK, Color.RED)
	_bar.set_value(4.0)
	_bar.set_max(20.0)
	assert_eq(_bar._max, 20.0)
	assert_eq(_bar._value, 4.0)

func test_set_max_clamps_value_when_shrinking():
	_bar.setup(10.0, Color.RED, Color.BLACK, Color.RED)
	_bar.set_value(8.0)
	_bar.set_max(5.0)
	assert_eq(_bar._max, 5.0)
	assert_eq(_bar._value, 5.0)

func test_configure_size_sets_width():
	_bar.setup(10.0, Color.RED, Color.BLACK, Color.RED)
	_bar.configure_size(300.0)
	assert_almost_eq(_bar.custom_minimum_size.x, 300.0, 0.01)

func test_bar_only_no_text():
	# A barra é SÓ a barra: sem nome, sem número — nenhum Label filho.
	_bar.setup(10.0, Color.RED, Color.BLACK, Color.RED)
	assert_false("_name_label" in _bar, "HealthBar nao tem rotulo de nome")
	assert_false("_value_label" in _bar, "HealthBar nao tem rotulo numerico de HP")
	for child in _bar.get_children():
		assert_false(child is Label, "nenhum Label dentro da barra")

func test_standard_height_uniform():
	# Padrão de altura único: boss não ganha barra mais alta.
	_bar.setup(36.0, Color.RED, Color.BLACK, Color.RED)
	_bar.configure_size(300.0)
	assert_almost_eq(_bar.total_height(), HealthBar.BAR_H, 0.01)
	assert_almost_eq(_bar.custom_minimum_size.y, HealthBar.BAR_H, 0.01)

func test_set_mirrored_preserves_value():
	# Espelhar (barra do inimigo) inverte a ancora do fill, nao a logica de valor.
	_bar.setup(10.0, Color.RED, Color.BLACK, Color.RED)
	_bar.set_value(7.0)
	_bar.set_mirrored(true)
	assert_eq(_bar._value, 7.0)
	assert_eq(_bar._max, 10.0)
	assert_true(_bar._mirrored)
