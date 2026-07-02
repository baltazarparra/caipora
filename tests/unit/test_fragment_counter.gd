extends GutTest

# FragmentCounter substitui o antigo "+".repeat(n) (que estourava a tela). A propriedade
# essencial: a largura cresce só com o nº de dígitos, nunca proporcional à contagem.

var _fc: FragmentCounter

func before_each():
	_fc = FragmentCounter.new()
	add_child_autofree(_fc)

func test_set_count_updates_label():
	_fc.set_count(23)
	assert_eq(_fc._count, 23)
	assert_eq(_fc._label.text, "23")

func test_set_count_clamps_negative():
	_fc.set_count(-4)
	assert_eq(_fc._count, 0)

func test_width_stays_bounded_with_huge_count():
	_fc.configure_size(18)
	_fc.set_count(9)
	var small: float = _fc.custom_minimum_size.x
	_fc.set_count(999999)
	var big: float = _fc.custom_minimum_size.x
	# largura cresce só com dígitos — diferença minúscula, não explode linearmente.
	assert_lt(big, small + 200.0)

func test_width_is_standard_up_to_reserve_digits():
	# Padrão de largura do header: reserva RESERVE_DIGITS dígitos, então a placa
	# não muda de tamanho quando a contagem sobe de 1 para 999.
	_fc.configure_size(18)
	_fc.set_count(1)
	var one_digit: float = _fc.custom_minimum_size.x
	_fc.set_count(999)
	assert_almost_eq(_fc.custom_minimum_size.x, one_digit, 0.01,
		"largura estável de 0 a 999 (reserva de %d dígitos)" % FragmentCounter.RESERVE_DIGITS)
