extends GutTest

# ActorAnimator.strike_or_idle: o inimigo com frames de strike (Mula v3+)
# toca a cadeia strike→recover→idle; os demais voltam ao idle (contrato antigo
# do arena_manager preservado por construção).

const MULA_SCENE := "res://scenes/arena/mula.tscn"
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

func test_boss_sem_strike_volta_ao_idle() -> void:
	var curupira := _spawn(CURUPIRA_SCENE)
	_animator.strike_or_idle(curupira)
	assert_eq(curupira.animated_sprite.animation, &"idle",
		"boss sem frames de strike mantém o contrato antigo (idle)")
