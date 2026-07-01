extends GutTest

# F4c — nome real do inimigo no HUD: resolve por id (boss.<id>.name → enemy.<id>.name →
# fallback hud.enemy). Lang.t devolve a própria chave quando ausente.

func test_boss_name_resolves() -> void:
	assert_eq(Hud.resolve_enemy_name(&"curupira"), Lang.t(&"boss.curupira.name"))
	assert_eq(Hud.resolve_enemy_name(&"jesuita"), Lang.t(&"boss.jesuita.name"))

func test_common_enemy_name_resolves() -> void:
	assert_eq(Hud.resolve_enemy_name(&"cacador"), Lang.t(&"enemy.cacador.name"))
	assert_eq(Hud.resolve_enemy_name(&"bruxo"), Lang.t(&"enemy.bruxo.name"))

func test_unknown_id_falls_back_to_generic() -> void:
	assert_eq(Hud.resolve_enemy_name(&"nonexistent_zzz"), Lang.t(&"hud.enemy"))
	assert_ne(Hud.resolve_enemy_name(&"nonexistent_zzz"), "nonexistent_zzz", "não vaza a chave crua")
