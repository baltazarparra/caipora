extends Node

# Manages high-level game state: current screen and pause.
# Emits changes through SignalBus so UI and scenes react.

# ─── State ─────────────────────────────────────────
var current_screen: SignalBus.Screen = SignalBus.Screen.MAIN_MENU
var is_paused: bool = false

# Inimigo do próximo combate. Se != null, o ArenaManager o usa e reseta.
# Ponto único para a Fase 4 (hub) escolher encontros (ex: Boss).
var next_enemy_scene: PackedScene = null
var active_phase: int = 1

# Exploração que o acampamento (HUB) deve abrir ao sair. Definida por advance_phase_via_hub()
# em todo avanço de fase; o hub a consome ao pisar no tile de saída. Volátil (não vai ao save).
var pending_exploration: SignalBus.Screen = SignalBus.Screen.EXPLORATION

# ─── Estado de Run (volátil; HP não vai para o save) ──
var run_active: bool = false
var caipora_max_hp: float = Constants.CAIPORA_MAX_HEALTH
var caipora_current_hp: float = Constants.CAIPORA_MAX_HEALTH

# Seed da run: define os mapas procedurais. Sorteado por run → mapa novo a cada vez.
# Determinístico por fase: a volta da arena regenera o MESMO mapa (mix run_seed+fase).
var run_seed: int = 0

# Cronômetro da run: gravado em start_run(), diferença calculada em end_run(won=true).
# Disponível para InitialsScreen ler após o fim da run. Unidade: segundos inteiros.
var run_start_time: float = 0.0
var run_elapsed_seconds: int = 0

# ─── Exploration State ─────────────────────────────
var defeated_enemy_ids: Array[String] = []
var active_map_enemy_id: String = ""
var active_combat_is_boss: bool = false
# Fase 5: os "monstros" são os 4 chefes convertidos, roteados como COMUNS (sem
# cerimonial), mas devem manter o HP de chefe da própria cena. Quando true, o
# ArenaManager NÃO sobrescreve o HP pelo uniforme da banda de fase. Volátil.
var active_combat_keeps_own_hp: bool = false
var has_key: bool = false
var chest_opened: bool = false
var player_map_pos: Vector2i = Vector2i(-1, -1)

# Snapshot das posições dos inimigos sobreviventes no instante do combate
# ({ enemy_id: Vector2i }). Restaura a exploração IDÊNTICA na volta da arena —
# inimigos e jogador ficam exatamente onde estavam. Limpo a cada run/avanço de fase.
var map_enemy_positions: Dictionary = {}

## Inicia uma nova run: HP cheio.
func start_run() -> void:
	run_active = true
	active_phase = 1
	defeated_enemy_ids.assign(MetaProgression.permanently_defeated_enemies)
	active_map_enemy_id = ""
	active_combat_is_boss = false
	active_combat_keeps_own_hp = false
	has_key = false
	chest_opened = false
	player_map_pos = Vector2i(-1, -1)
	map_enemy_positions.clear()
	pending_exploration = SignalBus.Screen.EXPLORATION
	run_seed = randi()
	run_start_time = Time.get_unix_time_from_system()
	caipora_max_hp = Constants.CAIPORA_MAX_HEALTH + MetaProgression.get_health_bonus()
	caipora_current_hp = caipora_max_hp

## Avança de fase passando OBRIGATORIAMENTE pelo acampamento (HUB). Guarda a próxima
## exploração em pending_exploration (o hub a abre ao sair) e zera a continuidade da
## exploração — a fase nova começa fresca (jogador no spawn, inimigos no spawn), como já
## fazia o tile de saída. Não toca em defeated_enemy_ids (ids são por-fase).
func advance_phase_via_hub(next_exploration: SignalBus.Screen) -> void:
	pending_exploration = next_exploration
	player_map_pos = Vector2i(-1, -1)
	map_enemy_positions.clear()
	# Cada fase tem seu próprio baú + chave: zera a posse para a fase nova spawnar
	# e abrir o baú de novo (sem isso os flags ficariam presos em true).
	has_key = false
	chest_opened = false
	change_screen(SignalBus.Screen.HUB)

## Seed determinística do mapa de uma fase nesta run. Mesma run+fase → mesmo mapa,
## então voltar da arena para a exploração regenera o mapa idêntico.
func map_seed_for_phase(phase: int) -> int:
	return (run_seed * 1000003) ^ (phase * 2654435761 + 12345)

## Recupera HP cheio (chamado ao entrar no Hub).
func heal_to_full() -> void:
	var meta_max_hp := float(Constants.CAIPORA_MAX_HEALTH + MetaProgression.get_health_bonus())
	caipora_max_hp = maxf(caipora_max_hp, meta_max_hp)
	caipora_current_hp = caipora_max_hp

## Encerra a run, registra estatísticas e persiste.
func end_run(won: bool) -> void:
	run_active = false
	MetaProgression.total_runs += 1
	if won:
		run_elapsed_seconds = int(Time.get_unix_time_from_system() - run_start_time)
		MetaProgression.total_wins += 1
		if MetaProgression.phase_reached < 6:
			MetaProgression.phase_reached = 6
	MetaProgression.save_progress()

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	SignalBus.screen_changed.connect(_on_screen_changed)

# ─── Public API ────────────────────────────────────
func change_screen(new_screen: SignalBus.Screen) -> void:
	current_screen = new_screen
	SignalBus.screen_changed.emit(new_screen)

func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused

# ─── Private ───────────────────────────────────────
func _on_screen_changed(new_screen: SignalBus.Screen) -> void:
	# Toda troca passa pelo SceneTransition (fade + flavor de fase). O autoload
	# sobrevive ao swap e mascara o hard-cut do change_scene_to_file.
	var path := _scene_path_for(new_screen)
	if path.is_empty():
		return
	SceneTransition.transition_to(path, new_screen)

## Mapeia cada tela para sua cena. Ponto único de roteamento — vazio = tela sem
## cena (não deveria ocorrer; coberto por teste).
func _scene_path_for(new_screen: SignalBus.Screen) -> String:
	match new_screen:
		SignalBus.Screen.MAIN_MENU:
			return "res://scenes/ui/main_menu.tscn"
		SignalBus.Screen.HUB:
			return "res://scenes/hub/hub.tscn"
		SignalBus.Screen.ARENA:
			return "res://scenes/arena/arena.tscn"
		SignalBus.Screen.EXPLORATION:
			return "res://scenes/exploration/exploration.tscn"
		SignalBus.Screen.WIN:
			return "res://scenes/ui/win.tscn"
		SignalBus.Screen.GAME_OVER:
			return "res://scenes/ui/game_over.tscn"
		SignalBus.Screen.EXPLORATION_PHASE2:
			return "res://scenes/exploration/exploration_phase2.tscn"
		SignalBus.Screen.ARENA_PHASE2:
			return "res://scenes/arena/arena_phase2.tscn"
		SignalBus.Screen.EXPLORATION_PHASE3:
			return "res://scenes/exploration/exploration_phase3.tscn"
		SignalBus.Screen.ARENA_PHASE3:
			return "res://scenes/arena/arena_phase3.tscn"
		SignalBus.Screen.EXPLORATION_PHASE4:
			return "res://scenes/exploration/exploration_phase4.tscn"
		SignalBus.Screen.ARENA_PHASE4:
			return "res://scenes/arena/arena_phase4.tscn"
		SignalBus.Screen.EXPLORATION_PHASE5:
			return "res://scenes/exploration/exploration_phase5.tscn"
		SignalBus.Screen.ARENA_PHASE5:
			return "res://scenes/arena/arena_phase5.tscn"
		SignalBus.Screen.ENDING:
			return "res://scenes/ui/ending_screen.tscn"
		SignalBus.Screen.FINAL_CHOICE:
			return "res://scenes/ui/final_choice_screen.tscn"
		SignalBus.Screen.ENDING_SACRIFICE:
			return "res://scenes/ui/ending_sacrifice_screen.tscn"
		SignalBus.Screen.INITIALS:
			return "res://scenes/ui/initials_screen.tscn"
	return ""
