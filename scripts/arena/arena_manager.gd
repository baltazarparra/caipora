class_name ArenaManager
extends Node2D

@export var caipora_combat_scene: PackedScene
## Cena do inimigo. Default = Criatura; pode ser trocada por Boss (ou qualquer
## CombatActor com EnemyStateMachine) sem o ArenaManager conhecer a classe.
@export var enemy_scene: PackedScene

const BOSS_BUBBLE_COLOR := Constants.COLOR_BUBBLE_BOSS
const BOSS_BUBBLE_SPREAD_MIN: float = 90.0
const CORTEJO_UNLOCK_SCENE := preload("res://scenes/ui/cortejo_unlock_screen.tscn")

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
# Clímax do golpe final: a câmera empurra mais forte (fator base 2.0, teto 3.0 —
# acima do teto 2.0 de enquadramento) e reposiciona no peito do inimigo.
const KILLING_BLOW_ZOOM_FACTOR: float = 2.0
const KILLING_BLOW_ZOOM_CAP: float = 3.0
# Peito = acima do pé do sprite (offset -40 × escala): onde a garra esmaga o coração.
const FINISHER_CHEST_OFFSET_Y: float = -20.0
# Clímax EXCLUSIVO do Golpe Carregado (Cortejo): esquartejamento espectral. Slow-mo
# um pouco mais longo e profundo que o normal (0.35s de cena). INVARIANTE: HOLD ×
# TIME_SCALE ≥ frames/fps do VFX (FeedbackSystem: 6/14 ≈ 0.43s); aqui 2.0×0.22=0.44s.
const CORTEJO_FINISHER_TIME_SCALE: float = 0.22
const CORTEJO_FINISHER_HOLD: float = 2.0

@onready var _camera: Camera2D = $Camera2D
# D-pad é um autoload persistente (TouchControls), não mais um nó por cena.
@onready var _controls_hud: ControlsHud = TouchControls

var _caipora: CombatActor
var _enemy: Criatura
var _enemy_id: StringName = &""
var _timing_system: TimingSystem
var _timing_bubble: Node2D
var _timing_bubble_b: Node2D
var _apparition: CortejoApparition
var _feedback: FeedbackSystem
var _sfx: SfxSystem
var _active_enemy_pattern: AttackPattern
var _last_boss_bubble_pos: Vector2 = Vector2(-999.0, -999.0)
var _first_bubble_pos: Vector2 = Vector2.ZERO
var _is_double_attack: bool = false
# Marca que o golpe MORTAL veio da barragem do Cortejo: _on_actor_died troca o
# finisher-coração padrão pelo esquartejamento espectral. Setado em
# _apply_cortejo_hits (killing blow), zerado ao iniciar cada Cortejo.
var _killed_by_cortejo: bool = false
var _boss_special_hit_index: int = 0
# Encerramento de combate: a morte de um ator dispara teardown + transição UMA única vez.
# _combat_over barra qualquer reentrância de turno/timing após a morte; _screen_changed
# garante que a troca de cena ocorra exatamente uma vez (caminho normal OU watchdog).
var _combat_over: bool = false
var _screen_changed: bool = false
var _animator: ActorAnimator
var _backdrop: ArenaBackdrop
var _doom_fire: DoomFire
var _killing_blow_zoom_base: float = 0.0
var _killing_blow_cam_base: Vector2 = Vector2.ZERO

func _ready() -> void:
	_timing_system = $TimingSystem
	_timing_bubble = $TimingBubble
	_timing_bubble_b = $TimingBubbleB
	# Bolhas acima dos atores (z 0): a seta da tecla precisa ficar sempre visível.
	# Fica abaixo das CanvasLayer da HUD/D-pad, que desenham em camada própria.
	_timing_bubble.z_index = 10
	_timing_bubble_b.z_index = 10
	# Compensa o CanvasModulate escuro da fase para que os feedbacks de timing
	# fiquem legíveis sem clarear o fundo (identidade fora das fases escuras).
	var feedback_gain: Color = Constants.feedback_gain_for_phase(GameState.active_phase)
	_timing_bubble.set_color_gain(feedback_gain)
	_timing_bubble_b.set_color_gain(feedback_gain)
	_feedback = $FeedbackSystem
	_sfx = $SfxSystem
	_timing_bubble.vulnerable_entered.connect(_on_bubble_vulnerable)
	_timing_bubble_b.vulnerable_entered.connect(_on_bubble_vulnerable)
	_timing_bubble.approach_entered.connect(_on_bubble_approach)
	_timing_bubble_b.approach_entered.connect(_on_bubble_approach)
	# Cortejo dos Encantados (Golpe Perfeito): aparição dos espíritos da barragem.
	# Criada por código (nó de runtime) para não tocar os .tscn das 5 arenas — gotcha
	# #7. A janela única reusa _timing_system/_timing_bubble (o tap do ataque normal).
	_apparition = CortejoApparition.new()
	_apparition.set_color_gain(feedback_gain)
	add_child(_apparition)
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
		label.text = Lang.t(&"combat.call.1")
		label.modulate.a = 1.0
		AudioDirector.play_syllable_beat(0)
	)
	tween.tween_interval(COMBAT_LOADER_SYLLABLE_HOLD)
	tween.tween_callback(func() -> void:
		label.text = Lang.t(&"combat.call.2")
		AudioDirector.play_syllable_beat(1)
	)
	tween.tween_interval(COMBAT_LOADER_SYLLABLE_HOLD)
	tween.tween_callback(func() -> void:
		label.text = Lang.t(&"combat.call.3")
		AudioDirector.play_syllable_beat(2)
	)
	# Janela de transição GLOBAL (início → primeiro turno): default = FINAL_HOLD,
	# configurável no painel de sequências (RemotePatterns.__global__).
	tween.tween_interval(RemotePatterns.transition_window(COMBAT_LOADER_FINAL_HOLD))
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
	label.text = Lang.t(&"combat.victory")
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

func _play_killing_blow_zoom(combo_step: int = 0) -> void:
	_killing_blow_zoom_base = _camera.zoom.x
	_killing_blow_cam_base = _camera.position
	# Streak alto aproxima mais a câmera no golpe final: o clímax escala com a escada.
	var zoom_factor := KILLING_BLOW_ZOOM_FACTOR + combo_step * Constants.COMBO_ZOOM_BONUS_PER_STEP
	var target_zoom := minf(_killing_blow_zoom_base * zoom_factor, KILLING_BLOW_ZOOM_CAP)
	# Empurra E reposiciona no peito do inimigo: o coração que será esmagado fica no centro.
	var target_pos := _camera.position
	if _enemy != null and is_instance_valid(_enemy):
		target_pos = _enemy.position + Vector2(0.0, FINISHER_CHEST_OFFSET_Y)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_camera, "zoom", Vector2(target_zoom, target_zoom), 0.18)
	tween.parallel().tween_property(_camera, "position", target_pos, 0.18)
	await tween.finished

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
	# Rim HD junto do refresh da Fúria: cobre o spawn e o re-attach da CHAMA.
	ParticleRim.attach_caipora(animated_sprite)

func _spawn_enemy() -> void:
	# Consome o flag volátil para nunca vazar estado para o próximo combate. O HP de
	# TODO inimigo vem agora da fonte única EnemyStats (boss = fixo, comum = banda de
	# fase, miniboss = fixo via tabela) — a cena .tscn não é mais consultada.
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
	_enemy_id = EnemyStats.id_for(_enemy)
	GameState.active_combat_name = Hud.resolve_enemy_name(_enemy_id)
	var hp: int = EnemyStats.max_hp_for(_enemy_id, GameState.active_phase)
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
	# Cortejo dos Encantados: só existe depois do 1º chefe libertado. Tem precedência
	# sobre o ataque duplo (mutuamente exclusivos no mesmo turno). Ver
	# docs/CONCEITO-corrente-encantados.md §3.1.
	if not MetaProgression.freed_bosses.is_empty() and randf() < Constants.CORTEJO_CHANCE:
		_start_cortejo_turn()
		return
	_is_double_attack = randf() < Constants.TIMING_DOUBLE_CHANCE
	# Identidade do golpe da Caipora (Garra Rubra / Açoite do Cipó): som + tag + VFX,
	# ancorados NELA (a bolha de timing fica no inimigo). Fallback ao attack_sound.
	var move: Dictionary = Constants.CAIPORA_MOVE_DOUBLE if _is_double_attack else Constants.CAIPORA_MOVE_NORMAL
	if not _sfx.play_named(move["audio"]):
		_sfx.play(_sfx.attack_sound)
	_feedback.spawn_move_name(Lang.t(move["name_key"]), _caipora.position + Vector2(0, -64.0), _move_name_rect())
	_feedback.spawn_attack_vfx(move["vfx"], _caipora.position + Vector2(0, -20.0))
	# Cipó armado enquanto a janela está aberta — antecipação do bote.
	_animator.play_pose(_caipora, &"windup")
	_first_bubble_pos = _enemy.position + Vector2(0, _enemy_head_top_y() - BUBBLE_HEAD_GAP)
	# Faixas absolutas (PERFEITO/GOOD) dentro da janela; piso garante que a banda caiba.
	var atk_window: float = maxf(_phase_window(Constants.TIMING_WINDOW_ATTACK), Constants.MIN_ACTION_DURATION)
	var band: Dictionary = Constants.band_fractions(atk_window)
	var ps: float = band["perfect_start"]
	var pe: float = band["perfect_end"]
	var gs: float = band["good_start"]
	var ge: float = band["good_end"]
	_timing_bubble.show_bubble(
		_first_bubble_pos,
		atk_window,
		ps, pe,
		false, Color.TRANSPARENT, "up", false, gs, ge
	)
	if _is_double_attack:
		var total: float = Constants.TIMING_DOUBLE_INTERVAL + atk_window
		var p1s: float = ps * atk_window / total
		var p1e: float = pe * atk_window / total
		var g1s: float = gs * atk_window / total
		var g1e: float = ge * atk_window / total
		var p2s: float = (Constants.TIMING_DOUBLE_INTERVAL + ps * atk_window) / total
		var p2e: float = (Constants.TIMING_DOUBLE_INTERVAL + pe * atk_window) / total
		var g2s: float = (Constants.TIMING_DOUBLE_INTERVAL + gs * atk_window) / total
		var g2e: float = (Constants.TIMING_DOUBLE_INTERVAL + ge * atk_window) / total
		_timing_system.open_window(total, p1s, p1e, true, p2s, p2e, "ui_up", "ui_right", false, g1s, g1e, g2s, g2e)
		_timing_system.timing_first_hit.connect(_on_double_first_hit)
		_timing_system.timing_result.connect(_on_double_final_result)
		get_tree().create_timer(Constants.TIMING_DOUBLE_INTERVAL).timeout.connect(_spawn_second_bubble)
	else:
		_timing_system.open_window(
			atk_window,
			ps, pe,
			false, 0.0, 0.0, "ui_up", "ui_right", false, gs, ge
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
	var win_b: float = maxf(_phase_window(Constants.TIMING_WINDOW_ATTACK), Constants.MIN_ACTION_DURATION)
	var band_b: Dictionary = Constants.band_fractions(win_b)
	_timing_bubble_b.show_bubble(
		spread,
		win_b,
		band_b["perfect_start"],
		band_b["perfect_end"],
		false, Color.TRANSPARENT, "right", false,
		band_b["good_start"], band_b["good_end"]
	)

func _on_double_first_hit() -> void:
	if _combat_over:
		return
	_timing_system.timing_first_hit.disconnect(_on_double_first_hit)
	_timing_bubble.burst_success()
	var damage := _caipora.execute_attack(false)
	var is_killing_blow := damage >= _enemy.health.current_health
	if is_killing_blow:
		_sfx.play_outcome(SfxSystem.Outcome.HIT)
		_feedback.spawn_bubble_burst(_timing_bubble.position, Constants.COLOR_TELEGRAPH_ENEMY)
		_animator.strike(_caipora)
		await _play_killing_blow_zoom()
	_enemy.take_damage(damage)
	if is_killing_blow:
		return
	_sfx.play_outcome(SfxSystem.Outcome.HIT)
	_feedback.trigger_screenshake(13.0, 0.3)
	_feedback.spawn_bubble_burst(_timing_bubble.position, Constants.COLOR_TELEGRAPH_ENEMY)
	_feedback.trigger_hit_stop(3)
	_animator.strike(_caipora)
	_caipora_step_forward()
	_enemy_recoil(16.0)

func _caipora_step_forward() -> void:
	var home_x := _caipora.position.x
	var step := create_tween()
	step.tween_property(_caipora, "position:x", home_x + 32.0, 0.08)
	step.tween_property(_caipora, "position:x", home_x, 0.12)

## Recuo do inimigo ao apanhar, na direcao OPOSTA a Caipora (empurra pra longe).
## A convergencia (Caipora avanca + inimigo recua) vende o peso do golpe.
func _enemy_recoil(px: float) -> void:
	if _enemy == null or _caipora == null:
		return
	var away := signf(_enemy.position.x - _caipora.position.x)
	if away == 0.0:
		away = 1.0
	_animator.recoil(_enemy, Vector2(away, 0.0), px)

## Recuo da Caipora ao apanhar: empurrada pra LONGE do inimigo (reacao ao dano).
func _caipora_recoil(px: float) -> void:
	if _enemy == null or _caipora == null:
		return
	var away := signf(_caipora.position.x - _enemy.position.x)
	if away == 0.0:
		away = -1.0
	_animator.recoil(_caipora, Vector2(away, 0.0), px)

var _zoom_punch_active: bool = false

## Zoom-punch: a camera "soca" pra dentro no critico e volta ao fit capturado.
## Guard evita empilhar; so no crit NAO-fatal (o killing-blow tem zoom proprio).
func _zoom_punch(factor: float = 1.07) -> void:
	if _zoom_punch_active or _camera == null:
		return
	_zoom_punch_active = true
	var base_zoom: Vector2 = _camera.zoom
	var tween := create_tween()
	tween.tween_property(_camera, "zoom", base_zoom * factor, 0.05).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.03)
	tween.tween_property(_camera, "zoom", base_zoom, 0.12).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _zoom_punch_active = false)

func _on_double_final_result(result: TimingSystem.TimingResult) -> void:
	if _combat_over:
		return
	_timing_system.timing_result.disconnect(_on_double_final_result)
	if _timing_system.timing_first_hit.is_connected(_on_double_first_hit):
		_timing_system.timing_first_hit.disconnect(_on_double_first_hit)
	if result == TimingSystem.TimingResult.PERFECT:
		_timing_bubble_b.burst_success()
		_feedback.track_perfect(true)
		var step := _feedback.combo_step()
		SignalBus.attack_result_perfect.emit()
		var damage := _caipora.execute_attack(false)
		var is_killing_blow := damage >= _enemy.health.current_health
		if is_killing_blow:
			_sfx.play_outcome(SfxSystem.Outcome.CRIT, step)
			_feedback.spawn_bubble_burst(_timing_bubble_b.position, Constants.COLOR_TELEGRAPH_ENEMY)
			_feedback.spawn_critical_particles(_enemy.position)
			_animator.strike(_caipora)
			await _play_killing_blow_zoom(step)
		_animator.flash_hold(_enemy)
		_enemy.take_damage(damage)
		if is_killing_blow:
			return
		_sfx.play_outcome(SfxSystem.Outcome.CRIT, step)
		_feedback.trigger_screenshake(22.0 * Constants.combo_scale(step), 0.5)
		_feedback.spawn_bubble_burst(_timing_bubble_b.position, Constants.COLOR_TELEGRAPH_ENEMY)
		_feedback.spawn_critical_particles(_enemy.position)
		_feedback.trigger_hit_stop(4 + Constants.combo_hitstop_bonus(step))
		_animator.strike(_caipora)
		_caipora_step_forward()
		_enemy_recoil(22.0)
		_zoom_punch()
	elif result == TimingSystem.TimingResult.GOOD:
		# 2º golpe do duplo na faixa GOOD: golpe normal (sem crítico), combo preservado.
		_timing_bubble_b.burst_good()
		_feedback.track_good()
		SignalBus.attack_result_good.emit()
		var damage := _caipora.execute_attack(false)
		_enemy.take_damage(damage)
		if _enemy.health.is_alive():
			_sfx.play_outcome(SfxSystem.Outcome.HIT)
			_feedback.trigger_screenshake(10.0, 0.25)
			_feedback.spawn_bubble_burst(_timing_bubble_b.position, Constants.COLOR_GOOD)
			_feedback.trigger_hit_stop(2)
			_animator.strike(_caipora)
	else:
		_timing_bubble.burst_fail()
		_timing_bubble_b.burst_fail()
		_feedback.spawn_fail_particles(_timing_bubble_b.position)
		_feedback.trigger_screenshake(6.0, 0.18)
		_sfx.play_outcome(SfxSystem.Outcome.MISS)
		_animator.settle(_caipora)
		_feedback.track_perfect(false)
		SignalBus.attack_result_miss.emit()
	if _enemy.health.is_alive():
		await get_tree().create_timer(_caipora.attack_cooldown).timeout
		_start_enemy_turn()

func _on_attack_timing_result(result: TimingSystem.TimingResult) -> void:
	if _combat_over:
		return
	_timing_system.timing_result.disconnect(_on_attack_timing_result)
	if result == TimingSystem.TimingResult.PERFECT:
		_timing_bubble.burst_success()
		# Conta o golpe atual ANTES de ler o passo: a escada já reflete este perfeito.
		_feedback.track_perfect(true)
		var step := _feedback.combo_step()
		SignalBus.attack_result_perfect.emit()
		var damage := _caipora.execute_attack(true)
		var is_killing_blow := damage >= _enemy.health.current_health
		if is_killing_blow:
			_sfx.play_outcome(SfxSystem.Outcome.CRIT, step)
			_feedback.spawn_bubble_burst(_timing_bubble.position, Constants.COLOR_TELEGRAPH_ENEMY)
			_feedback.spawn_critical_particles(_enemy.position)
			_animator.strike(_caipora)
			await _play_killing_blow_zoom(step)
		_animator.flash_hold(_enemy)
		_enemy.take_damage(damage)
		if is_killing_blow:
			return
		_sfx.play_outcome(SfxSystem.Outcome.CRIT, step)
		_feedback.trigger_screenshake(26.0 * Constants.combo_scale(step), 0.55)
		_feedback.spawn_bubble_burst(_timing_bubble.position, Constants.COLOR_TELEGRAPH_ENEMY)
		_feedback.spawn_critical_particles(_enemy.position)
		_feedback.trigger_hit_stop(6 + Constants.combo_hitstop_bonus(step))
		_animator.strike(_caipora)
		_caipora_step_forward()
		_enemy_recoil(24.0)
		_zoom_punch()
		_feedback.spawn_result_label(&"critico", _timing_bubble.position + Vector2(0, -55))
	elif result == TimingSystem.TimingResult.GOOD:
		# Golpe normal (sem crítico): hoje o ERRO whiffa, então o GOOD ainda fere — o combo
		# sobrevive mas não sobe. Sem clímax/zoom de killing-blow (a morte dispara via died).
		_timing_bubble.burst_good()
		_feedback.track_good()
		SignalBus.attack_result_good.emit()
		var damage := _caipora.execute_attack(false)
		_enemy.take_damage(damage)
		if _enemy.health.is_alive():
			_sfx.play_outcome(SfxSystem.Outcome.HIT)
			_feedback.trigger_screenshake(10.0, 0.25)
			_feedback.spawn_bubble_burst(_timing_bubble.position, Constants.COLOR_GOOD)
			_feedback.trigger_hit_stop(2)
			_animator.strike(_caipora)
			_feedback.spawn_move_name(Lang.t(&"combat.timing.good"), _timing_bubble.position + Vector2(0, -55), _move_name_rect())
			_enemy_recoil(14.0)
	else:
		_timing_bubble.burst_fail()
		_feedback.spawn_fail_particles(_timing_bubble.position)
		_feedback.trigger_screenshake(6.0, 0.18)
		_sfx.play_outcome(SfxSystem.Outcome.MISS)
		_animator.settle(_caipora)
		_feedback.spawn_result_label(&"errou", _timing_bubble.position + Vector2(0, -55))
		_feedback.track_perfect(false)
		SignalBus.attack_result_miss.emit()
	if _enemy.health.is_alive():
		await get_tree().create_timer(_caipora.attack_cooldown).timeout
		_start_enemy_turn()

# ─── Cortejo dos Encantados ("O Chamado" — SEGURAR → SOLTAR) ───────
## Turno especial da Caipora. SEGURA ui_up: o medidor de carga enche e os espíritos
## libertados coalescem; SOLTAR define o tier reusando o hold 3-tier do TimingSystem:
##   PERFEITO (banda dourada) → BARRAGEM completa + FEVER (último espírito crita);
##   GOOD (ombro)             → BARRAGEM completa, sem florição;
##   FRACO (soltou cedo)      → BARRAGEM parcial (k espíritos ∝ fração), sem punição;
##   QUEIMA (segurou demais / timeout) → CONTRA-ATAQUE (custo souls, _cortejo_whiff).
## Lead-in com slow-mo telegrafa. Mata no meio reusa o killing-blow zoom. Fonte:
## docs/PRD-cortejo-o-chamado.md.
func _start_cortejo_turn() -> void:
	if _combat_over or not _both_alive():
		return
	var spirits: Array[int] = Constants.cortejo_spirits_for(MetaProgression.freed_bosses)
	if spirits.is_empty():
		_start_enemy_turn()  # defensivo: o roll exige freed_bosses não vazio
		return
	_killed_by_cortejo = false  # reset por defesa antes da barragem
	AudioDirector.set_cortejo_active(true)
	# 1. Lead-in telegrafado (slow-mo + cue): avisa que vem algo grande.
	await _cortejo_lead_in()
	if _combat_over or not _both_alive():
		_end_cortejo()
		return
	# 2. Medidor de CARGA: SEGURAR ui_up enche (fase NÃO encurta — promessa tátil
	#    estável); SOLTAR avalia o tier. Mesmo primitivo de hold do TimingSystem
	#    (perfect = banda dourada, good = ombro). O fogo do wedge de CIMA acende via
	#    cortejo_charge_opened (ControlsHud, dormente até aqui).
	var pos: Vector2 = _enemy.position + Vector2(0, _enemy_head_top_y() - BUBBLE_HEAD_GAP)
	SignalBus.cortejo_charge_opened.emit("ui_up", Constants.CHAMADO_CHARGE_SEC)
	AudioDirector.play_cortejo_charge()   # assobio subindo de pitch enquanto segura
	_timing_bubble.show_bubble(pos, Constants.CHAMADO_CHARGE_SEC, Constants.CHAMADO_RELEASE_START, Constants.CHAMADO_RELEASE_END, false, Constants.COLOR_CHAMA_HOT, "up", true, Constants.CHAMADO_GOOD_START, Constants.CHAMADO_RELEASE_END, spirits.size())
	_timing_system.open_window(Constants.CHAMADO_CHARGE_SEC, Constants.CHAMADO_RELEASE_START, Constants.CHAMADO_RELEASE_END, false, 0.0, 0.0, "ui_up", "ui_right", true, Constants.CHAMADO_GOOD_START, Constants.CHAMADO_RELEASE_END)
	var result: int = await _timing_system.timing_result
	if _combat_over or not _both_alive():
		_timing_bubble.hide_bubble()
		_end_cortejo()
		return
	var n: int = spirits.size()
	if result == TimingSystem.TimingResult.PERFECT:
		_timing_bubble.burst_success()
		SignalBus.attack_result_perfect.emit()  # haptic de recompensa (ControlsHud)
		await _cortejo_barrage(spirits, pos, true)
	elif result == TimingSystem.TimingResult.GOOD:
		_timing_bubble.burst_good()
		SignalBus.attack_result_good.emit()
		await _cortejo_barrage(spirits, pos, false)
	elif Constants.chamado_miss_is_weak(_timing_system.window_progress()):
		# FRACO: soltou cedo. BARRAGEM parcial (k ∝ fração da carga), sem contra-ataque.
		_timing_bubble.burst_fail()
		SignalBus.attack_result_miss.emit()
		var k: int = Constants.chamado_partial_count(n, _timing_system.window_progress())
		await _cortejo_barrage(spirits, pos, false, k)
	else:
		# QUEIMA: segurou além da banda (overcharge) ou timeout → inimigo contra-ataca.
		_timing_bubble.burst_fail()
		SignalBus.attack_result_miss.emit()
		await _cortejo_whiff(pos)
	_end_cortejo()
	if not _combat_over and _enemy.health.is_alive():
		await get_tree().create_timer(_caipora.attack_cooldown).timeout
		_start_enemy_turn()

func _end_cortejo() -> void:
	_apparition.finish()
	SignalBus.cortejo_charge_closed.emit()  # apaga o fogo do wedge de CIMA (ControlsHud)
	AudioDirector.set_cortejo_active(false)
	Engine.time_scale = 1.0

## Lead-in: slow-mo curto + cue de convocação. Os timers IGNORAM o time_scale (senão a
## slow-mo estica a telegrafia — mesmo padrão do _play_killing_blow_zoom).
func _cortejo_lead_in() -> void:
	_sfx.play(_sfx.attack_sound)
	# Identidade do Cortejo: tag + VFX de espíritos (o som é o Batuque/summon próprio).
	_feedback.spawn_move_name(Lang.t(Constants.CAIPORA_MOVE_CORTEJO["name_key"]), _caipora.position + Vector2(0, -64.0), _move_name_rect())
	_feedback.spawn_attack_vfx(Constants.CAIPORA_MOVE_CORTEJO["vfx"], _caipora.position + Vector2(0, -20.0))
	_animator.play_pose(_caipora, &"windup")
	_apparition.begin()
	AudioDirector.play_cortejo_summon()
	Engine.time_scale = 0.45
	await get_tree().create_timer(0.5, true, false, true).timeout
	Engine.time_scale = 1.0

## BARRAGEM: os espíritos desabam em rajada; cada um = CORTEJO_LINK_HITS golpes. No
## FEVER (release perfeito) o último floresce em crítico e a corrente ganha o acento
## de maracatu. `limit` < 0 = todos (PERFEITO/GOOD); k espíritos no FRACO (parcial).
## Killing-blow no meio reusa o zoom. Mata no meio encerra (restantes não disparam).
func _cortejo_barrage(spirits: Array[int], pos: Vector2, fever: bool, limit: int = -1) -> void:
	# O clímax do Cortejo é o esquartejamento espectral no GOLPE MORTAL
	# (_on_actor_died via _killed_by_cortejo); a barragem não abre mais com o
	# finisher-coração (era o finisher errado). As aparições dão a leitura visual.
	var count: int = spirits.size() if limit < 0 else clampi(limit, 1, spirits.size())
	for i: int in range(count):
		if _combat_over or not _enemy.health.is_alive():
			return
		var crit: bool = fever and i == count - 1   # florição no último só no FEVER
		# Antecipação curta por espírito: invoca e deixa a aparição investir ANTES de
		# bater (cada elo lê individualmente, em vez de virar um borrão de hits).
		_apparition.strike(spirits[i], _enemy.position, i % 2 == 0)
		AudioDirector.play_cortejo_link(spirits[i], true)
		await get_tree().create_timer(Constants.CORTEJO_SPIRIT_TELEGRAPH).timeout
		if _combat_over or not _enemy.health.is_alive():
			return
		await _apply_cortejo_hits(pos, crit, i)
		if _combat_over or not _enemy.health.is_alive():
			return
		await get_tree().create_timer(Constants.CORTEJO_SPIRIT_GAP).timeout
	if fever:
		AudioDirector.play_cortejo_full_chain()  # acento de maracatu = recompensa do FEVER

## ERRO: a Caipora se expõe e o inimigo CONTRA-ATACA (custo souls), reusando a fórmula
## canônica de dano do inimigo.
func _cortejo_whiff(pos: Vector2) -> void:
	_feedback.spawn_fail_particles(pos)
	_feedback.trigger_screenshake(6.0, 0.18)
	_sfx.play_outcome(SfxSystem.Outcome.MISS)
	AudioDirector.play_cortejo_miss()
	_animator.settle(_caipora)
	await get_tree().create_timer(0.22).timeout
	if _combat_over or not _both_alive():
		return
	var counter: float = _enemy_counter_damage() * Constants.CORTEJO_MISS_COUNTER_MULT
	_caipora.take_damage(counter)
	_sfx.play_outcome(SfxSystem.Outcome.HURT)
	_feedback.trigger_screenshake(14.0, 0.35)
	_feedback.spawn_blood_particles(_caipora.position)
	_feedback.trigger_hit_stop(2)
	_feedback.track_perfect(false)

## Dano canônico de um golpe do inimigo (mesma fórmula do erro de defesa). DRY.
func _enemy_counter_damage() -> float:
	var damage: float = _enemy.execute_attack(false, _active_enemy_pattern.damage_multiplier)
	damage += EnemyStats.bonus_damage_for(_enemy_id, GameState.active_phase)
	if GameState.active_phase == 5:
		damage = maxf(damage, EnemyStats.DAMAGE_FLOOR)
	return damage

## Um espírito da barragem aplica CORTEJO_LINK_HITS golpes; `crit` (último) floresce em
## crítico. `index` faz o shake crescer (escada de clímax). Reaproveita o pipeline.
func _apply_cortejo_hits(pos: Vector2, crit: bool, index: int) -> void:
	for h: int in range(Constants.CORTEJO_LINK_HITS):
		if _combat_over or not _enemy.health.is_alive():
			return
		# Dano FIXO por hit (1): a barragem fere pela quantidade de golpes, não pela
		# magnitude. `crit` segue valendo só para o visual (florição do último espírito).
		var damage: float = Constants.CORTEJO_HIT_DAMAGE
		var is_killing_blow: bool = damage >= _enemy.health.current_health
		var outcome: int = SfxSystem.Outcome.CRIT if crit else SfxSystem.Outcome.HIT
		if is_killing_blow:
			_killed_by_cortejo = true  # _on_actor_died usa o esquartejamento espectral
			_sfx.play_outcome(outcome)
			_feedback.spawn_bubble_burst(pos, Constants.COLOR_TELEGRAPH_ENEMY)
			_feedback.spawn_critical_particles(_enemy.position)
			_animator.strike(_caipora)
			await _play_killing_blow_zoom()
		_enemy.take_damage(damage)
		if is_killing_blow:
			return
		_sfx.play_outcome(outcome)
		_feedback.trigger_screenshake(12.0 + index * 4.0, 0.3)
		_feedback.spawn_bubble_burst(pos, Constants.COLOR_TELEGRAPH_ENEMY)
		if crit:
			_feedback.spawn_critical_particles(_enemy.position)
		# Hit-stop cresce com o índice do espírito (escada de clímax até a florição).
		_feedback.trigger_hit_stop(3 + index)
		_animator.strike(_caipora)
		_caipora_step_forward()
		if h < Constants.CORTEJO_LINK_HITS - 1:
			await get_tree().create_timer(Constants.CORTEJO_HIT_GAP).timeout

# ─── Turno do Inimigo (Defesa) ─────────────────────
func _start_enemy_turn() -> void:
	if _combat_over or not _both_alive():
		return
	_boss_special_hit_index = 0
	_last_boss_bubble_pos = Vector2(-999.0, -999.0)
	_active_enemy_pattern = RemotePatterns.apply(_enemy.get_attack_pattern())
	# Identidade do golpe (1x por turno, não por hit): tag sutil + som próprio. NÃO
	# substitui o tell de timing (timing_alert segue por hit) — é leitura, não interrupção.
	if not _active_enemy_pattern.display_name.is_empty():
		_feedback.spawn_move_name(
			_active_enemy_pattern.display_name,
			_enemy.position + Vector2(0, _enemy_head_top_y() - 6.0),
			_move_name_rect()
		)
	if not _active_enemy_pattern.audio_event.is_empty():
		_sfx.play_named(_active_enemy_pattern.audio_event)
	if not _active_enemy_pattern.vfx_id.is_empty():
		_feedback.spawn_attack_vfx(_active_enemy_pattern.vfx_id, _enemy.position + Vector2(0, -20.0))
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
	var window: float = _defense_window(_active_enemy_pattern)
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
	var win: float = maxf(window, Constants.MIN_ACTION_DURATION)
	var band: Dictionary = Constants.band_fractions(win)
	var ps: float = band["perfect_start"]
	var pe: float = band["perfect_end"]
	_timing_bubble.show_bubble(bubble_pos, win, ps, pe, true, vuln, hint, false, band["good_start"], band["good_end"])
	_timing_system.open_window(win, ps, pe, false, 0.0, 0.0, action, "ui_right", false, band["good_start"], band["good_end"])
	SignalBus.defense_window_opened.emit(action)

func _on_defense_timing_result(result: TimingSystem.TimingResult) -> void:
	if _combat_over:
		return
	_timing_system.timing_result.disconnect(_on_defense_timing_result)
	SignalBus.defense_window_closed.emit()
	if result == TimingSystem.TimingResult.PERFECT:
		SignalBus.defense_result_perfect.emit()
	elif result == TimingSystem.TimingResult.GOOD:
		SignalBus.defense_result_good.emit()
	else:
		SignalBus.defense_result_miss.emit()

	_animator.strike_or_idle(_enemy)
	if result == TimingSystem.TimingResult.PERFECT:
		_timing_bubble.burst_success()
		_feedback.track_perfect(true)
		var step := _feedback.combo_step()
		_caipora.dodge_performed.emit()
		_sfx.play_outcome(SfxSystem.Outcome.DODGE, step)
		_feedback.trigger_screenshake(22.0 * Constants.combo_scale(step), 0.5)
		_feedback.spawn_bubble_burst(_timing_bubble.position, Constants.COLOR_PARTICLE_DODGE)
		_feedback.spawn_dodge_particles(_caipora.position)
		_feedback.trigger_hit_stop(5 + Constants.combo_hitstop_bonus(step))
		_animator.perfect_dodge(_caipora)
		_feedback.spawn_result_label(&"perfeito", _timing_bubble.position + Vector2(0, -55))
	elif result == TimingSystem.TimingResult.GOOD:
		# Bloqueio parcial: toma ~50% do dano, SEM contra-ataque; o combo SOBREVIVE.
		# Reusa _enemy_counter_damage() (mesma fórmula canônica do erro: execute_attack +
		# bonus de fase + piso F5).
		_timing_bubble.burst_good()
		_caipora.take_damage(_enemy_counter_damage() * Constants.GOOD_BLOCK_MULT)
		_caipora_recoil(9.0)
		_sfx.play_outcome(SfxSystem.Outcome.BLOCK)
		_feedback.trigger_screenshake(10.0, 0.25)
		_feedback.spawn_bubble_burst(_timing_bubble.position, Constants.COLOR_GOOD)
		_feedback.trigger_hit_stop(2)
		_feedback.spawn_result_label(&"bloqueio", _timing_bubble.position + Vector2(0, -55))
		_feedback.track_good()
	else:
		_timing_bubble.burst_fail()
		var damage := _enemy.execute_attack(false, _active_enemy_pattern.damage_multiplier)
		# Dano do inimigo: EnemyStats (com override remoto do painel admin por inimigo×fase).
		# bonus_damage_for já soma o fixo da criatura + o delta de fase. Fase 5: piso
		# DAMAGE_FLOOR pós-soma — golpe que acerta sempre sangra.
		damage += EnemyStats.bonus_damage_for(_enemy_id, GameState.active_phase)
		if GameState.active_phase == 5:
			damage = maxf(damage, EnemyStats.DAMAGE_FLOOR)
		_caipora.take_damage(damage)
		_caipora_recoil(16.0)
		# A guardiã sangrando tem voz própria — hit_sound é o impacto NO inimigo.
		_sfx.play_outcome(SfxSystem.Outcome.HURT)
		_feedback.trigger_screenshake(14.0, 0.35)
		_feedback.spawn_fail_particles(_timing_bubble.position)
		_feedback.spawn_blood_particles(_caipora.position)
		_feedback.trigger_hit_stop(2)
		# Levar dano quebra a sequência de perfeitos: o streak é "sem sangrar".
		_feedback.track_perfect(false)

func _on_enemy_pattern_finished() -> void:
	if not _combat_over and _both_alive():
		_start_caipora_turn()

## Rect (world-space) onde os nomes de golpe podem viver: o que a câmera vê ∩ palco
## (mesma geometria já validada pelo clamp das bolhas). Nome 100% dentro da tela.
func _move_name_rect() -> Rect2:
	return ArenaFraming.bubble_rect(
		_camera.position, get_viewport().get_visible_rect().size, _camera.zoom.x)

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

## Janela de ação (defesa) do inimigo na fase ativa. Override explícito por fase
## (editado em site/sequence.html) vence; sem ele, cai na fórmula por attack_duration.
func _defense_window(pattern: AttackPattern) -> float:
	var key := str(GameState.active_phase)
	if pattern.action_windows.has(key):
		return float(pattern.action_windows[key])
	return _phase_window(pattern.attack_duration)

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

## Cue de aproximação (faixa GOOD): tique sutil de som + háptico ("prepare → AGORA").
func _on_bubble_approach() -> void:
	AudioDirector.play_approach_tick()
	SignalBus.combat_approach_cue.emit()

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
		# Snowball pela metade (PRD-economia-v2): boss é marco (+1 HP máx.); comum dá
		# meio HP máx. (acumulado em caipora_max_hp, materializa +1 a cada 2).
		# GameState.caipora_max_hp (float) é a verdade; a componente usa floor. Conceito:
		# ao vencer, o HP volta SEMPRE ao máximo (full_heal) — depois de crescer o teto.
		if GameState.active_combat_is_boss:
			GameState.caipora_max_hp += Constants.BOSS_KILL_HP_GROWTH
			_caipora.health.max_health = int(floor(GameState.caipora_max_hp))
			_caipora.health.full_heal()
			# Boss bounty: bolada de fragmentos que financia as ervas caras (antes boss = 0).
			var _drop_boss := EnemyStats.fragment_drop_for(EnemyStats.id_for(_enemy), GameState.active_phase)
			MetaProgression.add_fragments(_drop_boss if _drop_boss >= 0.0 else float(Constants.BOSS_FRAGMENT_BOUNTY.get(GameState.active_phase, 0)))
			# Santuário dos Encantados: o golpe final LIBERTA o espírito do guardião (P1–P4).
			# Ele sai da fase para sempre e passa a viver em paz no acampamento; o Jesuíta
			# (P5) não é encantado — free_boss o ignora.
			MetaProgression.free_boss(GameState.active_phase)
		else:
			GameState.caipora_max_hp += Constants.COMMON_KILL_HP_GROWTH
			_caipora.health.max_health = int(floor(GameState.caipora_max_hp))
			_caipora.health.full_heal()
			# A cada 10 monstros (após a espada/forca_3) há um sorteio de CHAMA; se ganhar,
			# a recompensa é a CHAMA no lugar do fragmento desta morte.
			if not MetaProgression.register_kill_for_chama():
				var _drop_common := EnemyStats.fragment_drop_for(EnemyStats.id_for(_enemy), GameState.active_phase)
				MetaProgression.add_fragments(_drop_common if _drop_common >= 0.0 else float(Constants.COMMON_FRAGMENT_REWARD.get(GameState.active_phase, 1)))
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
	if caipora_won and _killing_blow_zoom_base > 0.0:
		# Golpe final em câmera lenta: o VFX herda o time_scale (a animação avança
		# pelo clock da cena) — slow-mo de graça. Dois finishers:
		#   • Cortejo (Golpe Carregado): ESQUARTEJAMENTO espectral + som próprio,
		#     slow-mo mais longo/profundo (o golpe mais raro e ritualístico).
		#   • Normal/crítico: a garra esmaga o coração sobre o peito.
		var chest_pos := actor.position + Vector2(0.0, FINISHER_CHEST_OFFSET_Y)
		if _killed_by_cortejo:
			Engine.time_scale = CORTEJO_FINISHER_TIME_SCALE
			AudioDirector.duck(AudioDirector.PERFECT_DUCK_DB, AudioDirector.PERFECT_DUCK_SECS)
			_sfx.play_named("finisher_cortejo")
			_feedback.spawn_cortejo_finisher_vfx(chest_pos)
			await get_tree().create_timer(CORTEJO_FINISHER_HOLD, true, false, true).timeout
		else:
			Engine.time_scale = 0.25
			_feedback.spawn_finisher_vfx(chest_pos)
			await get_tree().create_timer(1.4, true, false, true).timeout
		Engine.time_scale = 1.0
		var zoom_tween := create_tween()
		zoom_tween.set_ease(Tween.EASE_IN_OUT)
		zoom_tween.set_trans(Tween.TRANS_SINE)
		zoom_tween.parallel().tween_property(_camera, "zoom",
			Vector2(_killing_blow_zoom_base, _killing_blow_zoom_base), 0.25)
		zoom_tween.parallel().tween_property(_camera, "position",
			_killing_blow_cam_base, 0.25)
	_sfx.play(_sfx.death_sound)
	_feedback.spawn_death_particles(actor.position)
	_feedback.trigger_screenshake(26.0, 0.7)

	SignalBus.arena_exited.emit(caipora_won)
	var next_screen := _resolve_next_screen(caipora_won)
	# Watchdog: rede de segurança que garante a transição caso o caminho normal abaixo
	# seja preemptado por algum motivo. _do_screen_change é idempotente, então o primeiro
	# a disparar vence. (NÃO cobre engine-halt — ver plano.)
	# Bosses P1–P4 mostram a tela de unlock do Cortejo (aguarda input do jogador): 60s.
	# Demais casos: 4.0s (outro de vitória ~2.5s + 0.6s wait + margem).
	var _watchdog_delay: float = 60.0 if (caipora_won and GameState.active_combat_is_boss and GameState.active_phase in MetaProgression.FREEABLE_BOSS_PHASES) else 4.0
	get_tree().create_timer(_watchdog_delay, true).timeout.connect(_do_screen_change.bind(next_screen, caipora_won))
	if caipora_won:
		await _run_victory_outro()
		# Tela de unlock do Cortejo: apenas encantados P1–P4 (Jesuíta não é freeable).
		if GameState.active_combat_is_boss and GameState.active_phase in MetaProgression.FREEABLE_BOSS_PHASES:
			var unlock: CortejoUnlockScreen = CORTEJO_UNLOCK_SCENE.instantiate()
			get_tree().root.add_child(unlock)
			unlock.start(MetaProgression.freed_bosses.size())
			await unlock.dismissed
			unlock.queue_free()
	await get_tree().create_timer(0.6).timeout
	_do_screen_change(next_screen, caipora_won)

## Encerra o combate de forma síncrona: fecha a janela de timing, desconecta todos os
## handlers de resultado/primeiro-hit, para a state machine do inimigo e limpa o hit-stop
## (restaurando speed_scale). Chamado uma vez, no início de _on_actor_died, antes de awaits.
func _teardown_combat() -> void:
	SignalBus.defense_window_closed.emit()
	_disconnect_timing(_on_attack_timing_result)
	_disconnect_timing(_on_double_final_result)
	_disconnect_timing(_on_defense_timing_result)
	if _timing_system.timing_first_hit.is_connected(_on_double_first_hit):
		_timing_system.timing_first_hit.disconnect(_on_double_first_hit)
	# Cortejo (Golpe Perfeito): cancela a janela aberta. cancel_window emite
	# timing_result(MISS) uma vez → desbloqueia o `await` pendente em _start_cortejo_turn
	# (sem corrotina pendurada). Vem DEPOIS dos disconnects acima: assim o emit não
	# atinge handler de ataque/defesa, só a corrotina do Cortejo. Restaura time_scale
	# (caso a morte caia no lead-in em slow-mo) e some com a aparição/STEM_TOP.
	_timing_system.cancel_window()
	if _apparition != null:
		_apparition.finish()
	SignalBus.cortejo_charge_closed.emit()  # apaga o fogo do wedge se a morte caiu na carga
	AudioDirector.set_cortejo_active(false)
	Engine.time_scale = 1.0
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.state_machine.stop()
	_feedback.force_clear_hit_stop()
	if _caipora != null and is_instance_valid(_caipora):
		_caipora.animated_sprite.speed_scale = 1.0
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.animated_sprite.speed_scale = 1.0
	Engine.time_scale = 1.0

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
		GameState.last_defeated_enemy_id = GameState.active_map_enemy_id
	GameState.change_screen(screen)

## Pausa efeitos visuais de background imediatamente após o fade de entrada cobrir
## a tela — libera CPU/GPU antes da primeira janela de timing. Idempotente.
func _cull_visual_backdrop() -> void:
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.set_combat_mode(true)
	if _doom_fire != null and is_instance_valid(_doom_fire):
		_doom_fire.set_combat_mode(true)
