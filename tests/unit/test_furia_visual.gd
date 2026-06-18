class_name TestFuriaVisual
extends GutTest

## Cobre o componente reutilizável FuriaVisual: partículas ancoradas no cristal
## do cajado (glow T1+, fumaça, aura dourada, resíduos, fragmentos, espinhos).

func before_each() -> void:
	# Limpa todos os tiers de Fúria antes de cada teste
	for key in MetaProgression.FURIA_KEYS:
		MetaProgression.upgrades.erase(key)
	MetaProgression.has_chama = false

func after_each() -> void:
	for key in MetaProgression.FURIA_KEYS:
		MetaProgression.upgrades.erase(key)
	MetaProgression.has_chama = false

func _make_parent() -> AnimatedSprite2D:
	var parent := AnimatedSprite2D.new()
	add_child_autofree(parent)
	return parent

func test_no_furia_is_noop() -> void:
	var parent := _make_parent()
	FuriaVisual.attach_to(parent)
	assert_null(parent.get_node_or_null("FuriaVisual"), "sem nenhum tier de Fúria, não anexa nada")

func test_tier1_crystal_glow_only() -> void:
	MetaProgression.upgrades["forca"] = 1
	var parent := _make_parent()
	FuriaVisual.attach_to(parent)

	var furia := parent.get_node_or_null("FuriaVisual")
	assert_not_null(furia, "T1 anexa o anchor FuriaVisual")
	assert_null(parent.get_node_or_null("WeaponSprite"), "overlay de arma não existe mais (trava de regressão)")
	var glow := furia.get_node_or_null("CrystalGlow") as CPUParticles2D
	assert_not_null(glow, "T1 tem glow do cristal")
	assert_true(glow.emitting, "glow emitindo")
	var mat := glow.material as CanvasItemMaterial
	assert_not_null(mat, "glow tem material")
	assert_eq(mat.blend_mode, CanvasItemMaterial.BLEND_MODE_ADD, "glow usa blend aditivo")
	assert_null(furia.get_node_or_null("Smoke"), "T1 sem fumaça")
	assert_null(furia.get_node_or_null("GoldAura"), "T1 sem aura")

func test_tier2_adds_smoke() -> void:
	MetaProgression.upgrades["forca_2"] = 1
	var parent := _make_parent()
	FuriaVisual.attach_to(parent)

	var furia := parent.get_node_or_null("FuriaVisual")
	assert_not_null(furia, "T2 anexa o anchor")
	assert_not_null(furia.get_node_or_null("CrystalGlow"), "T2 mantém glow do cristal")
	var smoke := furia.get_node_or_null("Smoke") as CPUParticles2D
	assert_not_null(smoke, "T2 tem fumaça")
	assert_true(smoke.emitting, "fumaça emitindo")
	assert_eq(smoke.z_index, -1, "fumaça atrás do anchor")
	assert_null(furia.get_node_or_null("GoldAura"), "T2 sem aura dourada")

func test_tier3_adds_gold_aura() -> void:
	MetaProgression.upgrades["forca_3"] = 1
	var parent := _make_parent()
	FuriaVisual.attach_to(parent)

	var furia := parent.get_node_or_null("FuriaVisual")
	assert_not_null(furia, "T3 anexa o anchor")
	assert_not_null(furia.get_node_or_null("Smoke"), "T3 tem fumaça")
	var aura := furia.get_node_or_null("GoldAura") as CPUParticles2D
	assert_not_null(aura, "T3 tem aura dourada")
	assert_true(aura.emitting, "aura emitindo")
	var mat := aura.material as CanvasItemMaterial
	assert_not_null(mat, "aura tem material")
	assert_eq(mat.blend_mode, CanvasItemMaterial.BLEND_MODE_ADD, "aura usa blend aditivo")
	assert_null(furia.get_node_or_null("BreuResidue"), "T3 sem resíduos")

func test_tier4_adds_residue() -> void:
	MetaProgression.upgrades["forca_4"] = 1
	var parent := _make_parent()
	FuriaVisual.attach_to(parent)

	var furia := parent.get_node_or_null("FuriaVisual")
	assert_not_null(furia, "T4 anexa o anchor")
	assert_not_null(furia.get_node_or_null("Smoke"), "T4 tem fumaça")
	assert_not_null(furia.get_node_or_null("GoldAura"), "T4 tem aura")
	var residue := furia.get_node_or_null("BreuResidue") as CPUParticles2D
	assert_not_null(residue, "T4 tem resíduos de breu")
	assert_null(furia.get_node_or_null("BoneFragments"), "T4 sem fragmentos de osso")

func test_tier5_adds_bone_fragments() -> void:
	MetaProgression.upgrades["forca_5"] = 1
	var parent := _make_parent()
	FuriaVisual.attach_to(parent)

	var furia := parent.get_node_or_null("FuriaVisual")
	assert_not_null(furia, "T5 anexa o anchor")
	assert_not_null(furia.get_node_or_null("Smoke"), "T5 tem fumaça")
	assert_not_null(furia.get_node_or_null("GoldAura"), "T5 tem aura")
	assert_not_null(furia.get_node_or_null("BreuResidue"), "T5 tem resíduos")
	var bone := furia.get_node_or_null("BoneFragments") as CPUParticles2D
	assert_not_null(bone, "T5 tem fragmentos de osso")
	assert_null(furia.get_node_or_null("FleshSpines"), "T5 sem espinhos de carne")
	assert_null(furia.get_node_or_null("MaxFireFlame"), "T5 sem aura de fogo máximo")
	assert_null(furia.get_node_or_null("MaxFireEmbers"), "T5 sem brasas de fogo máximo")

func test_tier6_adds_flesh_spines() -> void:
	MetaProgression.upgrades["forca_6"] = 1
	var parent := _make_parent()
	FuriaVisual.attach_to(parent)

	var furia := parent.get_node_or_null("FuriaVisual")
	assert_not_null(furia, "T6 anexa o anchor")
	assert_not_null(furia.get_node_or_null("Smoke"), "T6 tem fumaça")
	assert_not_null(furia.get_node_or_null("GoldAura"), "T6 tem aura")
	assert_not_null(furia.get_node_or_null("BreuResidue"), "T6 tem resíduos")
	assert_not_null(furia.get_node_or_null("BoneFragments"), "T6 tem fragmentos")
	var spines := furia.get_node_or_null("FleshSpines") as CPUParticles2D
	assert_not_null(spines, "T6 tem espinhos de carne")
	assert_true(spines.emitting, "espinhos emitindo")

	# Fúria máxima: aura de fogo envolvendo a silhueta (labareda + brasas).
	var flame := furia.get_node_or_null("MaxFireFlame") as CPUParticles2D
	assert_not_null(flame, "T6 tem labareda de fogo máximo")
	assert_true(flame.emitting, "labareda emitindo")
	assert_eq(flame.z_index, -1, "labareda atrás do corpo (silhueta legível por cima)")
	var flame_mat := flame.material as CanvasItemMaterial
	assert_not_null(flame_mat, "labareda tem material")
	assert_eq(flame_mat.blend_mode, CanvasItemMaterial.BLEND_MODE_ADD, "labareda usa blend aditivo")
	var embers := furia.get_node_or_null("MaxFireEmbers") as CPUParticles2D
	assert_not_null(embers, "T6 tem brasas de fogo máximo")
	assert_true(embers.emitting, "brasas emitindo")
	var ember_mat := embers.material as CanvasItemMaterial
	assert_not_null(ember_mat, "brasas têm material")
	assert_eq(ember_mat.blend_mode, CanvasItemMaterial.BLEND_MODE_ADD, "brasas usam blend aditivo")

func test_glow_escalates_with_tier() -> void:
	MetaProgression.upgrades["forca"] = 1
	var parent_t1 := _make_parent()
	FuriaVisual.attach_to(parent_t1)
	var glow_t1 := parent_t1.get_node("FuriaVisual").get_node("CrystalGlow") as CPUParticles2D

	MetaProgression.upgrades["forca_6"] = 1
	var parent_t6 := _make_parent()
	FuriaVisual.attach_to(parent_t6)
	var glow_t6 := parent_t6.get_node("FuriaVisual").get_node("CrystalGlow") as CPUParticles2D

	assert_gt(glow_t6.amount, glow_t1.amount, "glow do cristal escala com o tier")

func test_anchor_follows_sprite_offset() -> void:
	MetaProgression.upgrades["forca"] = 1
	var parent := _make_parent()
	parent.offset = Vector2(0, -30)
	FuriaVisual.attach_to(parent)

	var furia := parent.get_node_or_null("FuriaVisual") as Node2D
	assert_not_null(furia, "anexa o anchor")
	assert_eq(furia.position, FuriaVisual.CRYSTAL_ANCHOR + Vector2(0, -30), "anchor = cristal + offset do sprite")

func test_reattach_is_idempotent() -> void:
	MetaProgression.upgrades["forca"] = 1
	var parent := _make_parent()
	FuriaVisual.attach_to(parent)
	FuriaVisual.attach_to(parent)

	var count := 0
	for child in parent.get_children():
		if child.name.begins_with("FuriaVisual") or child.name.begins_with("@FuriaVisual"):
			count += 1
	assert_eq(count, 1, "re-attach substitui em vez de duplicar (refresh mid-run da CHAMA)")

func test_chama_adds_flame_to_tier3() -> void:
	MetaProgression.upgrades["forca_3"] = 1
	MetaProgression.has_chama = true
	var parent := _make_parent()
	FuriaVisual.attach_to(parent)

	var furia := parent.get_node_or_null("FuriaVisual")
	assert_not_null(furia, "anexa o anchor")
	var flame := furia.get_node_or_null("ChamaFlame") as CPUParticles2D
	assert_not_null(flame, "CHAMA adiciona partículas de chama")
	assert_true(flame.emitting, "chama emitindo")

func test_crystal_anchor_matches_sprite_pixels() -> void:
	# Trava de deriva: se gen_caipora.py mover o cajado, este teste avisa.
	# Sonda a região do cristal no PNG idle (CRYSTAL_ANCHOR + centro 48,48).
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/player_idle.png"))
	assert_false(image.is_empty(), "player_idle.png carrega")
	var probe := FuriaVisual.CRYSTAL_ANCHOR + Vector2(48, 48)
	var found_green := false
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var x := int(probe.x) + dx
			var y := int(probe.y) + dy
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var c := image.get_pixel(x, y)
			if c.a > 0.5 and c.g > c.r and c.g > c.b:
				found_green = true
	assert_true(found_green, "há pixels verdes (cristal) na região do CRYSTAL_ANCHOR")
