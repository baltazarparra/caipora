extends GutTest

# Trava o modelo "faixas absolutas sobre a janela existente" (PRD §5): a PRECISÃO do acerto
# (largura perfect/good em segundos) é constante entre fases; só o lead-in muda com D.

func _perfect_width_secs(d: float) -> float:
    var b: Dictionary = Constants.band_fractions(d)
    return (float(b["perfect_end"]) - float(b["perfect_start"])) * d

func _good_width_secs(d: float) -> float:
    var b: Dictionary = Constants.band_fractions(d)
    return (float(b["good_end"]) - float(b["good_start"])) * d

# A largura perfeita em segundos é a mesma p/ janelas de fases diferentes (F1≈1.0, F4≈0.7).
func test_perfect_width_constant_across_phases():
    var w1: float = _perfect_width_secs(1.0)
    var w4: float = _perfect_width_secs(0.7)
    assert_almost_eq(w1, w4, 0.001, "precisão do PERFEITO é constante entre fases")
    # 2*PERFECT_HALF_SPAN + LATE_GRACE
    assert_almost_eq(w1, 2.0 * Constants.PERFECT_HALF_SPAN + Constants.LATE_GRACE, 0.001)

# Idem para a faixa GOOD.
func test_good_width_constant_across_phases():
    var g1: float = _good_width_secs(1.0)
    var g4: float = _good_width_secs(0.7)
    assert_almost_eq(g1, g4, 0.001, "largura do GOOD é constante entre fases")
    assert_almost_eq(g1, 2.0 * Constants.GOOD_HALF_SPAN + Constants.LATE_GRACE, 0.001)

# A faixa GOOD envolve a faixa perfeita (perfeito é subconjunto do good).
func test_good_envelops_perfect():
    var b: Dictionary = Constants.band_fractions(1.0)
    assert_lt(float(b["good_start"]), float(b["perfect_start"]), "good começa antes do perfeito")
    assert_gt(float(b["good_end"]), float(b["perfect_end"]), "good termina depois do perfeito")

# Todas as frações ficam dentro de [0,1] em toda a faixa útil de durações.
func test_fractions_in_unit_range():
    for d: float in [0.55, 0.7, 1.0, 1.5, 2.0]:
        var b: Dictionary = Constants.band_fractions(d)
        for key: String in ["perfect_start", "perfect_end", "good_start", "good_end"]:
            var v: float = float(b[key])
            assert_between(v, 0.0, 1.0, "%s @ d=%s dentro de [0,1]" % [key, d])

# Durações abaixo de MIN_ACTION_DURATION usam o piso (banda absoluta sempre cabe).
func test_min_action_duration_floor():
    var below: Dictionary = Constants.band_fractions(0.3)
    var floored: Dictionary = Constants.band_fractions(Constants.MIN_ACTION_DURATION)
    for key: String in ["perfect_start", "perfect_end", "good_start", "good_end"]:
        assert_almost_eq(float(below[key]), float(floored[key]), 0.0001,
            "%s clampeia no piso MIN_ACTION_DURATION" % key)

# A faixa fica no fim da janela (lead-in antes do perfeito), com o LATE_GRACE no lado tardio.
func test_late_grace_only_on_late_side():
    var d: float = 1.0
    var b: Dictionary = Constants.band_fractions(d)
    var center: float = d - Constants.ACTION_TAIL - Constants.GOOD_HALF_SPAN
    var early: float = center - float(b["perfect_start"]) * d
    var late: float = float(b["perfect_end"]) * d - center
    assert_almost_eq(early, Constants.PERFECT_HALF_SPAN, 0.001, "lado cedo = half span puro")
    assert_almost_eq(late, Constants.PERFECT_HALF_SPAN + Constants.LATE_GRACE, 0.001,
        "lado tardio = half span + grace")
