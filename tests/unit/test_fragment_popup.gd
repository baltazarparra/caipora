extends GutTest

# Popup de ganho de TERRA RARA (HUD). Regressão do bug em que "+%.4g ..." aparecia LITERAL na
# tela (o format do Godot não suporta "%g"), notado ao recuperar a bolsa souls-like. Cobre a
# função pura de formatação — o texto nunca pode conter especificadores de format crus.
# "Terra Rara" é incontável (minério): sem plural.

func test_inteiro_sem_casas_decimais():
	assert_eq(Hud.format_fragment_popup(3.0), "+3 Terra Rara")
	assert_eq(Hud.format_fragment_popup(12.0), "+12 Terra Rara")

func test_um_sem_plural():
	assert_eq(Hud.format_fragment_popup(1.0), "+1 Terra Rara")

func test_fracionario_uma_casa():
	# Drop de 1.5/kill na Fase 2: somas são múltiplos de 0.5.
	assert_eq(Hud.format_fragment_popup(1.5), "+1.5 Terra Rara")
	assert_eq(Hud.format_fragment_popup(12.5), "+12.5 Terra Rara")

func test_nunca_vaza_especificador_de_format():
	# O sintoma do bug: "%" cru sobrando no texto renderizado.
	for amount: float in [0.0, 1.0, 1.5, 2.0, 7.0, 12.5, 30.0]:
		var txt := Hud.format_fragment_popup(amount)
		assert_false(txt.contains("%"), "texto não pode conter '%%' cru: %s" % txt)
