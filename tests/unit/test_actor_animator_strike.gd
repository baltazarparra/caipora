extends GutTest

# Poses de combate por frames (Mula v3+): strike_or_idle na resolução da
# janela de defesa, flinch de hurt no dano e colapso de death na morte — os
# atores SEM esses frames preservam o contrato antigo por construção.

const MULA_SCENE := "res://scenes/arena/mula.tscn"
const BOITATA_SCENE := "res://scenes/arena/boitata.tscn"
const CURUPIRA_SCENE := "res://scenes/arena/curupira.tscn"

var _animator: ActorAnimator

func before_each() -> void:
	_animator = ActorAnimator.new()
	add_child_autofree(_animator)

func _spawn(scene_path: String) -> CombatActor:
	var actor := (load(scene_path) as PackedScene).instantiate() as CombatActor
	add_child_autofree(actor)
	_animator.track(actor)
	return actor

func test_mula_plays_strike_chain() -> void:
	var mula := _spawn(MULA_SCENE)
	_animator.strike_or_idle(mula)
	assert_eq(mula.animated_sprite.animation, &"strike",
		"Mula tem frames de strike e toca o coice-atropelo")

func test_boitata_plays_strike_chain() -> void:
	# O hook genérico pega o 2º boss redesenhado sem NENHUMA mudança de runtime.
	var boitata := _spawn(BOITATA_SCENE)
	_animator.strike_or_idle(boitata)
	assert_eq(boitata.animated_sprite.animation, &"strike",
		"Boitatá tem frames de strike e toca o bote")

func test_boss_sem_strike_volta_ao_idle() -> void:
	var curupira := _spawn(CURUPIRA_SCENE)
	_animator.strike_or_idle(curupira)
	assert_eq(curupira.animated_sprite.animation, &"idle",
		"boss sem frames de strike mantém o contrato antigo (idle)")

func test_mula_flinches_on_damage() -> void:
	var mula := _spawn(MULA_SCENE)
	mula.health.take_damage(1.0)
	assert_eq(mula.animated_sprite.animation, &"hurt",
		"dano não-letal toca o flinch de hurt")

func test_mula_collapses_on_death() -> void:
	var mula := _spawn(MULA_SCENE)
	mula.health.take_damage(9999.0)
	assert_eq(mula.animated_sprite.animation, &"death",
		"golpe letal toca o colapso (death), não o flinch")

func test_boss_sem_hurt_ignora_flinch() -> void:
	var curupira := _spawn(CURUPIRA_SCENE)
	curupira.animated_sprite.play(&"idle")
	curupira.health.take_damage(1.0)
	assert_eq(curupira.animated_sprite.animation, &"idle",
		"boss sem frames de hurt segue no idle (flinch é no-op)")
