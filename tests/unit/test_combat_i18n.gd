extends GutTest

# F5 (parte) — a chamada de luta e o outro de vitória deixam de vazar pt-BR fixo:
# passam por Lang. Aqui garantimos que as chaves resolvem (não vazam a chave crua).

func test_combat_loader_strings_are_localized() -> void:
	for k: StringName in [&"combat.call.1", &"combat.call.2", &"combat.call.3", &"combat.victory"]:
		assert_ne(Lang.t(k), String(k), "%s deve resolver (i18n), não vazar a chave" % k)
