class_name ArenaManager
extends Node2D

@export var caipora_combat_scene: PackedScene
## Cena do inimigo. Default = Criatura; pode ser trocada por Boss (ou qualquer
## CombatActor com EnemyStateMachine) sem o ArenaManager conhecer a classe.
@export var enemy_scene: PackedScene

const BOSS_BUBBLE_COLOR := Constants.COLOR_BUBBLE_BOSS
const BOSS_BUBBLE_SPREAD_MIN: float = 90.0

# Enquadramento por orientação (palco, retângulo de ação e posição dos atores)
# vive em ArenaFraming (helper puro): retrato aproxima os atores e estreita o
# fit para o combate encher a tela do celular. FILL < 1 deixa um respiro para
# a HUD (topo) e o D-pad (base).
const STAGE_FILL: float = 0.92

# Em retrato a tela é alta: sem isto a ação fica no centro vertical e o D-pad sobra num vão
# morto embaixo. Levanta a ação para o meio do espaço ACIMA do D-pad. 1.0 = centra cheio
# nesse espaço; 0.5 = meio-termo (nudge suave). Sem D-pad (desktop) o efeito é nulo.
const ACTION_LIFT_FRACTION: float = 0.5
# Folga entre o topo do sprite do inimigo e o centro da bolha de timing
# (equivale ao -78 fixo da era 48px: 46px acima do canvas do inimigo).
const BUBBLE_HEAD_GAP: float = 46.0

# Folga extra (px de tela) somada ao raio da bolha ao testar contra o D-pad.
const DPAD_BUBBLE_PADDING: float = 12.0
const COMBAT_LOADER_LAYER: int = 30
const COMBAT_LOADER_FADE: float = 0.12
const COMBAT_LOADER_FLASH_IN: float = 0.06
const COMBAT_LOADER_FLASH_OUT: float = 0.10
const COMBAT_LOADER_SYLLABLE_HOLD: float = 0.28
const COMBAT_LOADER_FINAL_HOLD: float = 0.50
const VICTORY_OUTRO_FADE: float = 0.15
const VICTORY_OUTRO_TEXT_FADE: float = 0.20
const VICTORY_OUTRO_HOLD: float = 1.8

@onready var _camera: Camera2D = $Camera2D
# D-pad é um autoload persistente (TouchControls), não mais um nó por cena.
@onready var _controls_hud: ControlsHud = TouchControls

var _caipora: CombatActor
var _enemy: Criatura
var _timing_system: TimingSystem
var _timing_bubble: Node2D
var _timing_bubble_b: Node2D
var _feedback: FeedbackSystem
var _sfx: SfxSystem
var _active_enemy_pattern: AttackPattern
var _last_boss_bubble_pos: Vector2 = Vector2(-999.0, -999.0)
var _first_bubble_pos: Vector2 = Vector2.ZERO
var _is_double_attack: bool = false
var _boss_special_hit_index: int = 0
# Encerramento de combate: a morte de um ator dispara teardown + transição UMA única vez.
# _combat_over barra qualquer reentrância de turno/timing após a morte; _screen_changed
# garante que a troca de cena ocorra exatamente uma vez (caminho normal OU watchdog).
var _combat_over: bool = false
var _screen_changed: bool = false
var _animator: ActorAnimator
var _backdrop: ArenaBackdrop
var _doom_fire: DoomFire

func _ready() -> void:
	_timing_system = $TimingSystem
	_timing_bubble = $TimingBubble
	_timing_bubble_b = $TimingBubbleB
	# Bolhas acima dos atores (z 0): a seta da tecla precisa ficar sempre visível.
	# Fica abaixo das CanvasLayer da HUD/D-pad, que desenham em camada própria.
	_timing_bubble.z_index = 10
	_timing_bubble_b.z_index = 10
	_feedback = $FeedbackSystem
	_sfx = $SfxSystem
	_timing_bubble.vulnerable_entered.connect(_on_bubble_vulnerable)
	_timing_bubble_b.vulnerable_entered.connect(_on_bubble_vulnerable)
	# Feedback tátil a cada input na janela de combate (conectado uma única vez).
	_timing_system.input_registered.connect(_on_input_registered)
	_feedback.hit_stop_started.connect(_on_hit_stop_started)
	_feedback.hit_stop_ended.connect(_on_hit_stop_ended)
	# A CHAMA pode ser conquistada NO MEIO do combate (register_kill_for_chama):
	# incendeia a Caipora na hora — o pop "CHAMA!" e o corpo contam a mesma história.
	SignalBus.chama_gained.connect(_on_chama_gained)

	_update_camera_fit()
	get_viewport().size_changed.connect(_update_camera_fit)

	_backdrop = ArenaBackdrop.new()
	add_child(_backdrop)
	_doom_fire = get_node_or_null("DoomFire") as DoomFire
	var blood_decals := BloodDecals.new()
	add_child(blood_decals)
	_feedback.blood_spilled.connect(blood_decals.add_splat)
	_animator = ActorAnimator.new()
	add_child(_animator)
	add_child(Atmosphere.new())

	_spawn_caipora()
	_spawn_enemy()
	_run_combat_loader()


func _run_combat_loader() -> void:
	var loader := CanvasLayer.new()
	loader.layer = COMBAT_LOADER_LAYER
	add_child(loader)

	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 1.0, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_STOP
	loader.add_child(flash)

	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := Constants.COLOR_ARENA_BG
	bg.a = 0.0
	fade.color = bg
	loader.add_child(fade)

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Constants.FONT_TITLE)
	label.add_theme_color_override("font_color", Constants.COLOR_AMBER)
	label.text = ""
	label.modulate.a = 0.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.add_child(label)

	var tween := create_tween()
	tween.tween_property(flash, "color:a", 1.0, COMBAT_LOADER_FLASH_IN)
	tween.tween_property(flash, "color:a", 0.0, COMBAT_LOADER_FLASH_OUT)
	tween.tween_property(fade, "color:a", 0.94, COMBAT_LOADER_FADE)
	# Pausa efeitos de background assim que a tela cobre — libera CPU/GPU antes
	# da primeira janela de timing (o lag de entrada do Fase 2 no iPad mini).
	tween.tween_callback(_cull_visual_backdrop)
	tween.tween_callback(func() -> void:
		label.text = "Pe"
		label.modulate.a = 1.0
		AudioDirector.play_syllable_beat(0)
	)
	tween.tween_interval(COMBAT_LOADER_SYLLABLE_HOLD)
	tween.tween_callback(func() -> void:
		label.text = "Pele"
		AudioDirector.play_syllable_beat(1)
	)
	tween.tween_interval(COMBAT_LOADER_SYLLABLE_HOLD)
	tween.tween_callback(func() -> void:
		label.text = "Pelejar"
		AudioDirector.play_syllable_beat(2)
	)
	tween.tween_interval(COMBAT_LOADER_FINAL_HOLD)
	tween.tween_property(label, "modulate:a", 0.0, COMBAT_LOADER_FADE)
	tween.tween_property(fade, "color:a", 0.0, COMBAT_LOADER_FADE)
	await tween.finished

	if is_instance_valid(loader):
		loader.queue_free()
	if not _combat_over and _both_alive():
		_start_caipora_turn()


func _run_victory_outro() -> void:
	AudioDirector.play_combat_victory()

	var layer := CanvasLayer.new()
	layer.layer = COMBAT_LOADER_LAYER
	add_child(layer)

	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := Constants.COLOR_ARENA_BG
	bg.a = 0.0
	fade.color = bg
	layer.add_child(fade)

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Constants.FONT_MD)
	label.add_theme_color_override("font_color", Constants.COLOR_AMBER)
	label.text = "assim seguimos..."
	label.modulate.a = 0.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.add_child(label)

	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.85, VICTORY_OUTRO_FADE)
	tween.tween_property(label, "modulate:a", 1.0, VICTORY_OUTRO_TEXT_FADE)
	tween.tween_interval(VICTORY_OUTRO_HOLD)
	tween.tween_property(label, "modulate:a", 0.0, VICTORY_OUTRO_TEXT_FADE)
	tween.tween_property(fade, "color:a", 0.0, VICTORY_OUTRO_FADE)
	await tween.finished

	if is_instance_valid(layer):
		layer.queue_free()

func _update_camera_fit() -> void:
	# Zoom "contain": encaixa o retângulo de ação da orientação atual sem cortar
	# a ação. Em paisagem o limite é a altura (palco clássico 560x340); em
	# retrato o retângulo estreito (360) aproxima a câmera do combate.
	var vp := get_viewport().get_visible_rect().size
	var action := ArenaFraming.action_size(vp)
	var raw: float = minf(vp.x / action.x, vp.y / action.y)
	var z: float = clampf(raw * STAGE_FILL, 0.5, 2.0)
	# Texel inteiro: a arte escala em múltiplos exatos de device-pixel (pixel art
	# uniforme). A folga do STAGE_FILL absorve arredondar pra cima; o contain sem
	# FILL (e o teto 2.0 do tablet) é o limite duro que não corta a ação.
	z = PixelScale.snap_contain(z, PixelScale.device_scale(get_viewport()), minf(raw, 2.0))
	_camera.zoom = Vector2(z, z)

	# Em retrato o D-pad ocupa a base: levanta a ação para o espaço acima dele. Em
	# paisagem o D-pad fica na lateral direita, então a arena permanece centrada.
	var dpad_rect := _controls_hud.get_dpad_screen_rect()
	var y_offset: float = 0.0
	if dpad_rect.size.y > 0.0 and Constants.is_portrait(vp):
		y_offset = (vp.y - dpad_rect.position.y) * 0.5 * ACTION_LIFT_FRACTION / z
	_camera.position = ArenaFraming.STAGE_CENTER + Vector2(0.0, y_offset)

	# Orientação livre: girar o aparelho no meio do combate reaproxima/afasta
	# os atores junto com o enquadramento (bolhas vivas mantêm posição — vida
	# curta; os spawns seguintes usam o rect novo).
	_apply_actor_positions(vp)

func _apply_actor_positions(vp: Vector2) -> void:
	if _caipora != null and is_instance_valid(_caipora):
		_caipora.position = ArenaFraming.caipora_pos(vp)
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.position = ArenaFraming.enemy_pos(vp)

func _spawn_caipora() -> void:
	if caipora_combat_scene == null:
		push_error("ArenaManager: caipora_combat_scene não atribuído")
		return
	_caipora = caipora_combat_scene.instantiate()
	_caipora.position = ArenaFraming.caipora_pos(get_viewport().get_visible_rect().size)
	add_child(_caipora)
	ActorContrast.add_ground_shadow(_caipora, Vector2(0.92, 0.34), Vector2(0.0, 2.0))
	ActorContrast.add_front_light(_caipora, Vector2(0.0, -20.0), 0.8, 1.6)
	CaiporaSkin.apply(_caipora.animated_sprite)
	# max_health é int; GameState.caipora_max_hp é float (carrega o meio-HP acumulado).
	_caipora.health.max_health = int(floor(GameState.caipora_max_hp))
	_caipora.health.current_health = clampf(GameState.caipora_current_hp, 0.0, GameState.caipora_max_hp)
	_caipora.attack_cooldown = Constants.ATTACK_COOLDOWN_SECONDS
	# Cada golpe parte da base fixa; as ervas de Fúria/CHAMA somam por cima.
	_caipora.base_attack_damage = Constants.caipora_base_damage_for_phase(GameState.active_phase) \
		+ MetaProgression.get_damage_bonus()
	_caipora.health.health_changed.connect(_on_caipora_health_changed)
	_caipora.health.died.connect(_on_actor_died.bind(_caipora))
	_caipora.health.died.connect(func(): SignalBus.caipora_died.emit())
	SignalBus.caipora_health_changed.emit(_caipora.health.current_health, _caipora.health.max_health)
	_apply_furia_visual()
	_animator.track(_caipora)

func _on_caipora_health_changed(new_health: float, max_health: float) -> void:
	SignalBus.caipora_health_changed.emit(new_health, max_health)

func _on_chama_gained() -> void:
	if _caipora != null and is_instance_valid(_caipora):
		CaiporaSkin.apply(_caipora.animated_sprite)
		# Re-attach idempotente: a ChamaFlame aparece no cristal em pleno combate.
		_apply_furia_visual()

func _apply_furia_visual() -> void:
	var animated_sprite := _caipora.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null:
		return
	FuriaVisual.attach_to(animated_sprite)

func _spawn_enemy() -> void:
	# Consome o flag volátil ANTES de qualquer early-return, para nunca vazar estado
	# para o próximo combate. Comuns (não-boss) têm HP uniforme por banda de fase;
	# bosses mantêm o HP da cena. Exceção (Fase 5): os chefes-monstro convertidos são
	# roteados como comuns mas mantêm o HP de chefe da própria cena (keeps_own_hp).
	var keeps_own_hp := GameState.active_combat_keeps_own_hp
	GameState.active_combat_keeps_own_hp = false
	var scene := enemy_scene
	if GameState.next_enemy_scene != null:
		scene = GameState.next_enemy_scene
		GameState.next_enemy_scene = null
	if scene == null:
		push_error("ArenaManager: enemy_scene não atribuído")
		return
	_enemy = scene.instantiate()
	_enemy.position = ArenaFraming.enemy_pos(get_viewport().get_visible_rect().size)
	add_child(_enemy)
	if not GameState.active_combat_is_boss and not keeps_own_hp:
		var hp: int = Constants.common_health_for_phase(GameState.active_phase)
		_enemy.health.max_health = hp
		_enemy.health.current_health = float(hp)
	_active_enemy_pattern = _enemy.attack_pattern
	_enemy.health.died.connect(_on_actor_died.bind(_enemy))
	_enemy.health.health_changed.connect(_on_enemy_health_changed)
	_enemy.state_machine.attack_started.connect(_on_enemy_attack_started)
	_enemy.state_machine.pattern_finished.connect(_on_enemy_pattern_finished)
	_animator.track(_enemy)
	SignalBus.enemy_health_changed.emit(_enemy.health.current_health, _enemy.health.max_health)

func _both_alive() -> bool:
	return _caipora.health.is_alive() and _enemy.health.is_alive()

# ─── Turno da Caipora (Ataque) ─────────────────────
func _start_caipora_turn() -> void:
	if _combat_over or not _both_alive():
		return
	_is_double_attack = randf() < Constants.TIMING_DOUBLE_CHANCE
	_sfx.play(_sfx.attack_sound)
	# Cipó armado enquanto a janela está aberta — antecipação do bote.
	_animator.play_pose(_caipora, &"windup")
	_first_bubble_pos = _enemy.position + Vector2(0, _enemy_head_top_y() - BUBBLE_HEAD_GAP)
	var atk_window: float = _phase_window(Constants.TIMING_WINDOW_ATTACK)
	_timing_bubble.show_bubble(
		_first_bubble_pos,
		atk_window,
		Constants.TIMING_PERFECT_START,
		Constants.TIMING_PERFECT_END,
		false, Color.TRANSPARENT, "up"
	)
	if _is_double_attack:
		var total: float = Constants.TIMING_DOUBLE_INTERVAL + atk_window
		var p1s: float = Constants.TIMING_PERFECT_START * atk_window / total
		var p1e: float = Constants.TIMING_PERFECT_END * atk_window / total
		var p2s: float = (Constants.TIMING_DOUBLE_INTERVAL + Constants.TIMING_PERFECT_START * atk_window) / total
		var p2e: float = (Constants.TIMING_DOUBLE_INTERVAL + Constants.TIMING_PERFECT_END * atk_window) / total
		_timing_system.open_window(total, p1s, p1e, true, p2s, p2e, "ui_up", "ui_right")
		_timing_system.timing_first_hit.connect(_on_double_first_hit)
		_timing_system.timing_result.connect(_on_double_final_result)
		get_tree().create_timer(Constants.TIMING_DOUBLE_INTERVAL).timeout.connect(_spawn_second_bubble)
	else:
		_timing_system.open_window(
			atk_window,
			Constants.TIMING_PERFECT_START,
			Constants.TIMING_PERFECT_END,
			false, 0.0, 0.0, "ui_up"
		)
		_timing_system.timing_result.connect(_on_attack_timing_result)

## Topo do canvas do sprite do inimigo em y local (negativo). A bolha ancora
## acima da cabeça qualquer que seja o tamanho do inimigo (invasor 112px,
## boss legado 48px) — nada de offset absoluto que quebra ao trocar a arte.
## Fallback -32: o topo da era 48px (offset -8 - 24), que com BUBBLE_HEAD_GAP
## reproduz exatamente o -78 legado caso o sprite não carregue.
func _enemy_head_top_y() -> float:
	var spr := _enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr == null or spr.sprite_frames == null:
		return -32.0
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, 0)
	if tex == null:
		return -32.0
	return (spr.offset.y - tex.get_height() * 0.5) * spr.scale.y

func _spawn_second_bubble() -> void:
	if not _both_alive() or not _timing_system.is_open():
		return
	var spread: Vector2
	for _i in 20:
		var angle := randf() * TAU
		var dist := randf_range(Constants.TIMING_DOUBLE_BUBBLE_SPREAD_MIN, Constants.TIMING_DOUBLE_BUBBLE_SPREAD_MAX)
		spread = _first_bubble_pos + Vector2(cos(angle) * dist, sin(angle) * dist)
		if not _is_under_dpad(spread):
			break
	# Com o enquadramento fechado de retrato, o sorteio pode cair na borda:
	# garante a 2ª bolha inteira dentro do que a câmera vê.
	spread = ArenaFraming.clamp_to_bubble_rect(spread, ArenaFraming.bubble_rect(
		_camera.position, get_viewport().get_visible_rect().size, _camera.zoom.x))
	_timing_bubble_b.show_bubble(
		spread,
		_phase_window(Constants.TIMING_WINDOW_ATTACK),
		Constants.TIMING_PERFECT_START,
		Constants.TIMING_PERFECT_END,
		false, Color.TRANSPARENT, "right"
	)

func _on_double_first_hit() -> void:
	if _combat_over:
		return
	_timing_system.timing_first_hit.disconnect(_on_double_first_hit)
	_timing_bubble.burst_success()
	var damage := _caipora.execute_attack(false)
	_enemy.take_damage(damage)
	_sfx.play(_sfx.hit_sound)
	_feedback.trigger_screenshake(13.0, 0.3)
	_feedback.spawn_bubble_burst(_timing_bubble.position, Constants.COLOR_TELEGRAPH_ENEMY)
	_feedback.trigger_hit_stop(3)
	_animator.strike(_caipora)
	_caipora_step_forward()

func _caipora_step_forward() -> void:
	var home_x := _caipora.position.x
	var step := create_tween()
	step.tween_property(_caipora, "position:x", home_x + 32.0, 0.08)
	step.tween_property(_caipora, "position:x", home_x, 0.12)

func _on_double_final_result(result: TimingSystem.TimingResult) -> void:
	if _combat_over:
		return
	_timing_system.timing_result.disconnect(_on_double_final_result)
	if _timing_system.timing_first_hit.is_connected(_on_double_first_hit):
		_timing_system.timing_first_hit.disconnect(_on_double_first_hit)
	if result == TimingSystem.TimingResult.PERFECT:
		_timing_bubble_b.burst_success()
		var damage := _caipora.execute_attack(false)
		_enemy.take_damage(damage)
		_sfx.play(_sfx.timing_perfect_sound, -4.0)
		_sfx.play(_sfx.hit_sound)
		AudioDirector.duck(AudioDirector.PERFECT_DUCK_DB, AudioDirector.PERFECT_DUCK_SECS)
		_feedback.trigger_screenshake(22.0, 0.5)
		_feedback.spawn_bubble_burst(_timing_bubble_b.position, Constants.COLOR_TELEGRAPH_ENEMY)
		_feedback.spawn_critical_particles(_enemy.position)
		_feedback.trigger_hit_stop(4)
		_animator.strike(_caipora)
	else:
		_timing_bubble.burst_fail()
		_timing_bubble_b.burst_fail()
		_feedback.spawn_fail_particles(_timing_bubble_b.position)
		_feedback.trigger_screenshake(6.0, 0.18)
		_sfx.play(_sfx.ui_click_sound, -6.0)
		_animator.settle(_caipora)
	if _enemy.health.is_alive():
		await get_tree().create_timer(_caipora.attack_cooldown).timeout
		_start_enemy_turn()

func _on_attack_timing_result(result: TimingSystem.TimingResult) -> void:
	if _combat_over:
		return
	_timing_system.timing_result.disconnect(_on_attack_timing_result)
	if result == TimingSystem.TimingResult.PERFECT:
		_timing_bubble.burst_success()
		var damage := _caipora.execute_attack(true)
		_enemy.take_damage(damage)
		_sfx.play(_sfx.timing_perfect_sound, -4.0)
		_sfx.play(_sfx.hit_sound)
		AudioDirector.duck(AudioDirector.PERFECT_DUCK_DB, AudioDirector.PERFECT_DUCK_SECS)
		_feedback.trigger_screenshake(26.0, 0.55)
		_feedback.spawn_bubble_burst(_timing_bubble.position, Constants.COLOR_TELEGRAPH_ENEMY)
		_feedback.spawn_critical_particles(_enemy.position)
		_feedback.trigger_hit_stop(6)
		_animator.strike(_caipora)
		_feedback.spawn_result_label(&"critico", _timing_bubble.position + Vector2(0, -55))
		_feedback.track_perfect(true)
	else:
		_timing_bubble.burst_fail()
		_feedback.spawn_fail_particles(_timing_bubble.position)
		_feedback.trigger_screenshake(6.0, 0.18)
		_sfx.play(_sfx.ui_click_sound, -6.0)
		_animator.settle(_caipora)
		_feedback.spawn_result_label(&"errou", _timing_bubble.position + Vector2(0, -55))
		_feedback.track_perfect(false)
	if _enemy.health.is_alive():
		await get_tree().create_timer(_caipora.attack_cooldown).timeout
		_start_enemy_turn()

# ─── Turno do Inimigo (Defesa) ─────────────────────
func _start_enemy_turn() -> void:
	if _combat_over or not _both_alive():
		return
	_boss_special_hit_index = 0
	_last_boss_bubble_pos = Vector2(-999.0, -999.0)
	_active_enemy_pattern = _enemy.get_attack_pattern()
	_enemy.state_machine.start_pattern(_active_enemy_pattern)

func _on_enemy_attack_started() -> void:
	if not _both_alive():
		return
	# S9 (experimental, atrás de AudioDirector.BEAT_SYNC_ENABLED — hoje OFF): o
	# wind-up de inimigo COMUM espera o próximo beat (máx. 1 beat). A janela de
	# timing não muda; bosses ficam fora. Com a flag desligada, wait = 0.0 sempre.
	if not GameState.active_combat_is_boss:
		var wait := AudioDirector.time_to_next_beat()
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
			if not _both_alive() or _combat_over:
				return
	# Pose de telegrafia (espingarda na pontaria / machados içados) junto do tint.
	_animator.play_pose(_enemy, &"windup")
	var window: float = _phase_window(_active_enemy_pattern.attack_duration)
	if _timing_system.timing_result.is_connected(_on_defense_timing_result):
		_timing_system.timing_result.disconnect(_on_defense_timing_result)
	_timing_system.timing_result.connect(_on_defense_timing_result)
	var is_special: bool = _active_enemy_pattern.is_special
	var action: String
	var hint: String
	if is_special:
		var seq: Array[String] = _active_enemy_pattern.input_sequence
		var hint_map: Dictionary = {
			"ui_right": "right", "ui_left": "left",
			"ui_up": "up", "ui_down": "down"
		}
		var idx := clampi(_boss_special_hit_index, 0, seq.size() - 1)
		action = seq[idx] if not seq.is_empty() else "ui_down"
		hint = hint_map.get(action, "down")
		_boss_special_hit_index += 1
	else:
		action = "ui_down"
		hint = "down"
	var bubble_pos: Vector2 = _boss_spread_pos() if is_special else _caipora.position + Vector2(0, -70)
	var vuln: Color = BOSS_BUBBLE_COLOR if is_special else Color.TRANSPARENT
	_timing_bubble.show_bubble(bubble_pos, window, Constants.TIMING_PERFECT_START, Constants.TIMING_PERFECT_END, true, vuln, hint)
	_timing_system.open_window(window, Constants.TIMING_PERFECT_START, Constants.TIMING_PERFECT_END, false, 0.0, 0.0, action)
	SignalBus.defense_window_opened.emit(action)

func _on_defense_timing_result(result: TimingSystem.TimingResult) -> void:
	if _combat_over:
		return
	_timing_system.timing_result.disconnect(_on_defense_timing_result)
	SignalBus.defense_window_closed.emit()
	if result == TimingSystem.TimingResult.PERFECT:
		SignalBus.defense_result_perfect.emit()
	else:
		SignalBus.defense_result_miss.emit()

	_animator.play_pose(_enemy, &"idle")
	if result == TimingSystem.TimingResult.PERFECT:
		_timing_bubble.burst_success()
		_caipora.dodge_performed.emit()
		_sfx.play(_sfx.dodge_sound)
		_sfx.play(_sfx.timing_perfect_sound, -4.0)
		AudioDirector.duck(AudioDirector.PERFECT_DUCK_DB, AudioDirector.PERFECT_DUCK_SECS)
		_feedback.trigger_screenshake(22.0, 0.5)
		_feedback.spawn_bubble_burst(_timing_bubble.position, Constants.COLOR_PARTICLE_DODGE)
		_feedback.spawn_dodge_particles(_caipora.position)
		_feedback.trigger_hit_stop(5)
		_animator.perfect_dodge(_caipora)
		_feedback.spawn_result_label(&"perfeito", _timing_bubble.position + Vector2(0, -55))
		_feedback.track_perfect(true)
	else:
		_timing_bubble.burst_fail()
		var damage := _enemy.execute_attack(false, _active_enemy_pattern.damage_multiplier)
		# Inimigos mais fortes (ex.: Bruxo) batem um tanto a mais por golpe.
		damage += _enemy.extra_hit_damage
		# Fase 2/4: cada golpe de inimigo bate 1 a mais — a floresta é mais hostil.
		# Fase 5: bônus NEGATIVO (rebalance 2026-06), com piso de 1 — golpe que
		# acerta sempre sangra (vale para os 4 chefes-monstro E para o Jesuíta).
		if GameState.active_phase == 2:
			damage += Constants.PHASE2_ENEMY_DAMAGE_BONUS
		elif GameState.active_phase == 4:
			damage += Constants.PHASE4_ENEMY_DAMAGE_BONUS
		elif GameState.active_phase == 5:
			damage = maxf(damage + Constants.PHASE5_ENEMY_DAMAGE_BONUS, 1.0)
		_caipora.take_damage(damage)
		# A guardiã sangrando tem voz própria — hit_sound é o impacto NO inimigo.
		if not _sfx.play_named("hurt_caipora"):
			_sfx.play(_sfx.hit_sound)
		_feedback.trigger_screenshake(14.0, 0.35)
		_feedback.spawn_fail_particles(_timing_bubble.position)
		_feedback.spawn_blood_particles(_caipora.position)
		_feedback.trigger_hit_stop(2)

func _on_enemy_pattern_finished() -> void:
	if not _combat_over and _both_alive():
		_start_caipora_turn()

func _boss_spread_pos() -> Vector2:
	# Spawna dentro do que a câmera vê (∩ palco, com margem do raio da bolha):
	# com o zoom de retrato as antigas faixas absolutas vazariam da tela.
	var rect := ArenaFraming.bubble_rect(
		_camera.position, get_viewport().get_visible_rect().size, _camera.zoom.x)
	var pos: Vector2
	for _i in 20:
		pos = Vector2(
			randf_range(rect.position.x, rect.end.x),
			randf_range(rect.position.y, rect.end.y)
		)
		if _last_boss_bubble_pos.distance_to(pos) >= BOSS_BUBBLE_SPREAD_MIN and not _is_under_dpad(pos):
			break
	_last_boss_bubble_pos = pos
	return pos

func _phase_window(base: float) -> float:
	return Constants.timing_window_for_phase(base, GameState.active_phase)

func _is_under_dpad(world_pos: Vector2) -> bool:
	var rect := _controls_hud.get_dpad_screen_rect()
	if rect.size == Vector2.ZERO:
		return false
	# Mundo -> tela (a transform do canvas embute a Camera2D).
	var screen_pos := get_viewport().get_canvas_transform() * world_pos
	# Expande pelo raio da bolha em px de tela + folga, para que nem a borda encoste no D-pad.
	var grow := TimingBubble.RADIUS_MAX * _camera.zoom.x + DPAD_BUBBLE_PADDING
	return rect.grow(grow).has_point(screen_pos)

func _on_enemy_health_changed(new_health: float, max_health: float) -> void:
	SignalBus.enemy_health_changed.emit(new_health, max_health)

# ─── Bolha ─────────────────────────────────────────
func _on_bubble_vulnerable() -> void:
	_sfx.play(_sfx.timing_alert_sound)

# ─── Feedback por input ────────────────────────────
## Resposta tátil imediata a qualquer ação na janela (mesmo fora da zona perfeita).
## O feedback forte do acerto (crítico/esquiva) é empilhado por cima nos handlers.
func _on_input_registered() -> void:
	_feedback.trigger_screenshake(2.5, 0.08)
	_sfx.play(_sfx.ui_click_sound, -6.0)

func _on_hit_stop_started(_duration: float) -> void:
	_timing_bubble.set_frozen(true)
	_timing_bubble_b.set_frozen(true)
	if _caipora != null and is_instance_valid(_caipora):
		_caipora.animated_sprite.speed_scale = 0.0
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.animated_sprite.speed_scale = 0.0

func _on_hit_stop_ended() -> void:
	_timing_bubble.set_frozen(false)
	_timing_bubble_b.set_frozen(false)
	if _caipora != null and is_instance_valid(_caipora):
		_caipora.animated_sprite.speed_scale = 1.0
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.animated_sprite.speed_scale = 1.0

# ─── Morte ─────────────────────────────────────────
func _on_actor_died(actor: CombatActor) -> void:
	# Idempotente: a morte encerra o combate exatamente uma vez. Qualquer segundo `died`
	# (ou reentrância) é ignorado.
	if _combat_over:
		return
	_combat_over = true
	var caipora_won := actor == _enemy
	# Derruba TODO o estado de combate ANTES de qualquer await: fecha a janela de timing,
	# desconecta os handlers (impede que o ataque duplo reentre e toque o _enemy já
	# liberado pelo tween de morte) e restaura os sprites congelados pelo hit-stop.
	_teardown_combat()
	if caipora_won:
		# Cicatriz sonora: cada chefe morre com stinger próprio (AudioDirector resolve
		# pela fase). Antes dos awaits — a emissão não pode se perder no teardown.
		if GameState.active_combat_is_boss:
			SignalBus.boss_died.emit(GameState.active_phase)
		# Snowball pela metade (PRD-economia-v2): boss é marco (+1 HP máx., cura 2);
		# comum dá meio HP máx. (acumulado em caipora_max_hp, materializa +1 a cada 2) e
		# cura 1. GameState.caipora_max_hp (float) é a verdade; a componente usa floori.
		if GameState.active_combat_is_boss:
			GameState.caipora_max_hp += Constants.BOSS_KILL_HP_GROWTH
			_caipora.health.max_health = int(floor(GameState.caipora_max_hp))
			_caipora.health.heal(Constants.BOSS_KILL_HEAL)
			# Boss bounty: bolada de fragmentos que financia as ervas caras (antes boss = 0).
			MetaProgression.add_fragments(float(Constants.BOSS_FRAGMENT_BOUNTY.get(GameState.active_phase, 0)))
			# Santuário dos Encantados: o golpe final LIBERTA o espírito do guardião (P1–P4).
			# Ele sai da fase para sempre e passa a viver em paz no acampamento; o Jesuíta
			# (P5) não é encantado — free_boss o ignora.
			MetaProgression.free_boss(GameState.active_phase)
		else:
			GameState.caipora_max_hp += Constants.COMMON_KILL_HP_GROWTH
			_caipora.health.max_health = int(floor(GameState.caipora_max_hp))
			_caipora.health.heal(Constants.COMMON_KILL_HEAL)
			# A cada 10 monstros (após a espada/forca_3) há um sorteio de CHAMA; se ganhar,
			# a recompensa é a CHAMA no lugar do fragmento desta morte.
			if not MetaProgression.register_kill_for_chama():
				MetaProgression.add_fragments(float(Constants.COMMON_FRAGMENT_REWARD.get(GameState.active_phase, 1)))
		if GameState.active_combat_is_boss and GameState.active_phase == 2:
			if MetaProgression.phase_reached < 3:
				MetaProgression.phase_reached = 3
				MetaProgression.save_progress()
		if GameState.active_combat_is_boss and GameState.active_phase == 3:
			if MetaProgression.phase_reached < 4:
				MetaProgression.phase_reached = 4
				MetaProgression.save_progress()
		if GameState.active_combat_is_boss and GameState.active_phase == 4:
			if MetaProgression.phase_reached < 5:
				MetaProgression.phase_reached = 5
				MetaProgression.save_progress()
		if GameState.active_combat_is_boss and GameState.active_phase == 5:
			if MetaProgression.phase_reached < 6:
				MetaProgression.phase_reached = 6
				MetaProgression.save_progress()
	else:
		# Souls-like: a Caipora tomba e derruba TODOS os fragmentos numa bolsa, no tile onde
		# o combate começou (lugar da morte). Recupera-os voltando ali numa run futura; morrer
		# de novo antes custa tudo (drop_fragment_bag sobrescreve a bolsa anterior).
		MetaProgression.drop_fragment_bag(GameState.active_phase, GameState.player_map_pos)
	GameState.caipora_current_hp = maxf(0.0, _caipora.health.current_health)
	_sfx.play(_sfx.death_sound)
	_feedback.spawn_death_particles(actor.position)
	_feedback.trigger_screenshake(26.0, 0.7)

	SignalBus.arena_exited.emit(caipora_won)
	var next_screen := _resolve_next_screen(caipora_won)
	# Watchdog: rede de segurança que garante a transição caso o caminho normal abaixo
	# seja preemptado por algum motivo. _do_screen_change é idempotente, então o primeiro
	# a disparar vence. (NÃO cobre engine-halt — ver plano.)
	# 4.0s: outro de vitória (~2.5s) + 0.6s wait + margem de segurança.
	get_tree().create_timer(4.0, true).timeout.connect(_do_screen_change.bind(next_screen, caipora_won))
	if caipora_won:
		await _run_victory_outro()
	await get_tree().create_timer(0.6).timeout
	_do_screen_change(next_screen, caipora_won)

## Encerra o combate de forma síncrona: fecha a janela de timing, desconecta todos os
## handlers de resultado/primeiro-hit, para a state machine do inimigo e limpa o hit-stop
## (restaurando speed_scale). Chamado uma vez, no início de _on_actor_died, antes de awaits.
func _teardown_combat() -> void:
	SignalBus.defense_window_closed.emit()
	_timing_system.close_window()
	_disconnect_timing(_on_attack_timing_result)
	_disconnect_timing(_on_double_final_result)
	_disconnect_timing(_on_defense_timing_result)
	if _timing_system.timing_first_hit.is_connected(_on_double_first_hit):
		_timing_system.timing_first_hit.disconnect(_on_double_first_hit)
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.state_machine.stop()
	_feedback.force_clear_hit_stop()
	if _caipora != null and is_instance_valid(_caipora):
		_caipora.animated_sprite.speed_scale = 1.0
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.animated_sprite.speed_scale = 1.0

func _disconnect_timing(callable: Callable) -> void:
	if _timing_system.timing_result.is_connected(callable):
		_timing_system.timing_result.disconnect(callable)

## Tela-alvo após o combate (puro, sem efeitos colaterais). Vitória NUNCA avança a
## fase: boss ou comum, volta à exploração da MESMA fase — avançar é pisar no tile
## de saída (ExplorationManager). Exceção única: o boss FINAL (Jesuíta, P5) →
## FINAL_CHOICE (a cena da escolha "Poupar ele?", que roteia para um dos dois finais).
func _resolve_next_screen(caipora_won: bool) -> SignalBus.Screen:
	if not caipora_won:
		return SignalBus.Screen.GAME_OVER
	if GameState.active_combat_is_boss and GameState.active_phase == 5:
		return SignalBus.Screen.FINAL_CHOICE
	match GameState.active_phase:
		5: return SignalBus.Screen.EXPLORATION_PHASE5
		4: return SignalBus.Screen.EXPLORATION_PHASE4
		3: return SignalBus.Screen.EXPLORATION_PHASE3
		2: return SignalBus.Screen.EXPLORATION_PHASE2
		_: return SignalBus.Screen.EXPLORATION

## Executa a troca de tela uma única vez (caminho normal OU watchdog). Registra o inimigo
## derrotado apenas em vitórias que voltam à exploração (não no caminho terminal
## FINAL_CHOICE → finais).
func _do_screen_change(screen: SignalBus.Screen, caipora_won: bool) -> void:
	if _screen_changed:
		return
	_screen_changed = true
	if caipora_won and screen != SignalBus.Screen.FINAL_CHOICE:
		GameState.defeated_enemy_ids.append(GameState.active_map_enemy_id)
	GameState.change_screen(screen)

## Pausa efeitos visuais de background imediatamente após o fade de entrada cobrir
## a tela — libera CPU/GPU antes da primeira janela de timing. Idempotente.
func _cull_visual_backdrop() -> void:
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.set_combat_mode(true)
	if _doom_fire != null and is_instance_valid(_doom_fire):
		_doom_fire.set_combat_mode(true)
