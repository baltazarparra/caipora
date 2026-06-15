extends Node

# Persists meta-progression between runs: unlocks, stats, fragments, upgrades.
# Saved to user://savegame.json (platform-agnostic path).

var SAVE_PATH := "user://savegame.json"

# Versão do formato de save. Incrementar ao mudar o schema; migrar em load_progress().
const SAVE_VERSION: int = 4

# True se user:// é persistente (no Web = IndexedDB disponível; false em aba anônima/quota).
var is_persistent: bool = true

# Cada aprimoramento é uma ERVA que a Caipora põe no cachimbo para fumar. Duas trilhas:
# "furia" (dano) e "cura" (HP). As KEYS são imutáveis (compatibilidade de save); só os
# nomes/metadados de exibição mudam. Metadados de UI (line/tier/phase/icon) são lidos pelo
# Hub para montar os cards de forma data-driven.
#
# FONTE NUMÉRICA ÚNICA (PRD-economia-v2): o campo "dmg" (Fúria) ou "hp" (Cura) é a verdade
# da matemática; o texto do efeito é DERIVADO via effect_text() (mata a classe de bug do
# KI-006, em que o label desincronizava do bônus real). Curva de custo crescente:
# Fúria leva o dano de 1 a 5 no jogo principal, 9 no pós-clear (10 com a CHAMA);
# Cura leva o HP de 2 a 14 no jogo principal, 23 no pós-clear.
const UPGRADE_DEFS := {
	"forca":   { "name": "Folha-Brasa",      "max_level": 1, "fragment_cost": 5,  "line": "furia", "tier": 1, "phase": 1, "dmg": 1, "icon": "res://assets/sprites/erva_folha_brasa.png" },
	"forca_2": { "name": "Cinza-Viva",       "max_level": 1, "fragment_cost": 10, "line": "furia", "tier": 2, "phase": 2, "dmg": 1, "icon": "res://assets/sprites/erva_cinza_viva.png", "requires": "forca" },
	"forca_3": { "name": "Raiz-de-Ira",      "max_level": 1, "fragment_cost": 16, "line": "furia", "tier": 3, "phase": 3, "dmg": 1, "icon": "res://assets/sprites/erva_raiz_de_ira.png", "requires": "forca_2" },
	"forca_4": { "name": "Breu-Ancestral",   "max_level": 1, "fragment_cost": 24, "line": "furia", "tier": 4, "phase": 4, "dmg": 1, "icon": "res://assets/sprites/erva_breu_ancestral.png", "requires": "forca_3" },
	"forca_5": { "name": "Osso-Quebrado",    "max_level": 1, "fragment_cost": 36, "line": "furia", "tier": 5, "phase": 5, "dmg": 2, "icon": "res://assets/sprites/erva_osso_quebrado.png", "requires": "forca_4", "wins_required": 1 },
	"forca_6": { "name": "Chaga-da-Mata",    "max_level": 1, "fragment_cost": 50, "line": "furia", "tier": 6, "phase": 6, "dmg": 2, "icon": "res://assets/sprites/erva_chaga_da_mata.png", "requires": "forca_5", "wins_required": 3 },
	"saude":   { "name": "Seiva-Mãe",        "max_level": 1, "fragment_cost": 6,  "line": "cura",  "tier": 1, "phase": 1, "hp": 2,  "icon": "res://assets/sprites/erva_seiva_mae.png" },
	"saude_2": { "name": "Casca-Boa",        "max_level": 1, "fragment_cost": 12, "line": "cura",  "tier": 2, "phase": 2, "hp": 3,  "icon": "res://assets/sprites/erva_casca_boa.png" },
	"saude_3": { "name": "Folha-de-Sangue",  "max_level": 1, "fragment_cost": 20, "line": "cura",  "tier": 3, "phase": 3, "hp": 3,  "icon": "res://assets/sprites/erva_folha_de_sangue.png", "requires": "saude_2" },
	"saude_4": { "name": "Coração-de-Cerne", "max_level": 1, "fragment_cost": 30, "line": "cura",  "tier": 4, "phase": 4, "hp": 4,  "icon": "res://assets/sprites/erva_coracao_de_cerne.png", "requires": "saude_3" },
	"saude_5": { "name": "Rachadura-Viva",   "max_level": 1, "fragment_cost": 42, "line": "cura",  "tier": 5, "phase": 5, "hp": 4,  "icon": "res://assets/sprites/erva_rachadura_viva.png", "requires": "saude_4", "wins_required": 1 },
	"saude_6": { "name": "Pele-de-Defunto",  "max_level": 1, "fragment_cost": 58, "line": "cura",  "tier": 6, "phase": 6, "hp": 5,  "icon": "res://assets/sprites/erva_pele_de_defunto.png", "requires": "saude_5", "wins_required": 3 },
}

# Dano base da Caipora (espelha Constants.DAMAGE_BASE) — usado para derivar os totais
# exibidos na trilha Fúria.
const BASE_DAMAGE: int = 1

# Ordem de exibição por trilha (o Hub itera sem hardcode de keys).
const FURIA_KEYS: Array[String] = ["forca", "forca_2", "forca_3", "forca_4", "forca_5", "forca_6"]
const CURA_KEYS: Array[String]  = ["saude", "saude_2", "saude_3", "saude_4", "saude_5", "saude_6"]

# ─── CHAMA (elemento fogo) ─────────────────────────
# Depois que a espada (forca_3, "Raiz-de-Ira" da Fase 3) já existe, a cada
# KILLS_PER_CHAMA_ROLL monstros comuns derrotados há UM sorteio: com CHAMA_DROP_CHANCE de
# chance, a espada ganha o elemento fogo (permanente) no lugar do fragmento daquela morte:
# +CHAMA_DAMAGE_BONUS de dano e visual de chama (na arena e na exploração).
const KILLS_PER_CHAMA_ROLL: int = 10
# `var` (não const) de propósito: ponto único de tuning e overridable nos testes (1.0/0.0).
var CHAMA_DROP_CHANCE: float = 0.5
# +1 de dano (teto da trilha Fúria: 9 → 10 com a CHAMA).
const CHAMA_DAMAGE_BONUS: int = 1

# ─── State ─────────────────────────────────────────
var unlocked_characters: Array[String] = ["caipora"]
var unlocked_modifiers: Array[String] = []
var total_runs: int = 0
var total_wins: int = 0
var upgrades: Dictionary = {}
var fragments: float = 0.0
var phase_reached: int = 1
var touch_controls_mode: String = "auto"
# CHAMA: elemento fogo desbloqueado (permanente) + contador acumulado rumo ao próximo sorteio.
var has_chama: bool = false
var kills_toward_chama: int = 0

# ─── Bolsa de fragmentos (souls-like / corpse run) ─────────────────────────────
# Ao morrer, a Caipora derruba TODOS os fragmentos numa BOLSA, no lugar exato da morte
# (fase + tile). A bolsa fica caída na mata até ser recuperada: ao pisar nela numa run
# futura, a Caipora reaver TODOS os fragmentos. Morrer de novo ANTES de chegar nela
# sobrescreve a bolsa antiga — ela e tudo que carregava se perdem na floresta (segue com
# zero). Persiste no save (é meta, atravessa o limite morte→nova run).
var frag_bag_active: bool = false
var frag_bag_phase: int = 0
var frag_bag_pos: Vector2i = Vector2i.ZERO
var frag_bag_amount: float = 0.0

# ─── Santuário dos Encantados (PRD-santuario-dos-encantados) ───────────────────
# A Caipora não mata os encantados — ela os LIBERTA. O boss libertado sai da fase para
# sempre (a toca vira passagem) e passa a viver em paz no acampamento. Meta-persistente
# e definitivo: só volta no reset_save(). Apenas P1–P4 — o Jesuíta (P5) não é encantado
# e nunca entra no santuário. `spirits_seen` marca os ritos de chegada já exibidos no
# acampamento (o reveal acontece UMA vez por encantado).
const FREEABLE_BOSS_PHASES: Array[int] = [1, 2, 3, 4]
var freed_bosses: Array[int] = []
var spirits_seen: Array[int] = []

# ─── Estado de run persistido ───────────────────────
# Inimigos derrotados na run em curso. Espelha GameState.defeated_enemy_ids, mas sobrevive
# ao fechamento do navegador. Limpo em start_run(); restaurado para GameState em load_progress().
var current_run_defeated_enemies: Array[String] = []

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	# No Web, a engine sincroniza IndexedDB→memfs antes do main loop, então user://
	# já está disponível aqui. Carregar no autoload torna o save independente da cena de boot.
	is_persistent = OS.is_userfs_persistent()
	if not is_persistent:
		push_warning("MetaProgression: user:// não é persistente (aba anônima/quota?); o save não vai colar.")
	load_progress()

# ─── Fragments ─────────────────────────────────────
func add_fragments(amount: float) -> void:
	fragments += amount
	save_progress()
	SignalBus.fragment_gained.emit(fragments, amount)

func add_fragment() -> void:
	add_fragments(1.0)

# ─── Bolsa de fragmentos (corpse run) ──────────────
## Derruba TODOS os fragmentos atuais numa bolsa em `phase`/`pos` (lugar da morte) e zera o
## saldo. SOBRESCREVE qualquer bolsa anterior ainda não recuperada — ela se perde (regra
## souls-like: morrer de novo antes de chegar lá custa tudo). Só marca bolsa nova se havia
## fragmento a derrubar; morrer com saldo zero apenas apaga a bolsa antiga (segue com zero).
func drop_fragment_bag(phase: int, pos: Vector2i) -> void:
	var dropped := fragments
	frag_bag_amount = dropped
	frag_bag_phase = phase
	frag_bag_pos = pos
	frag_bag_active = dropped > 0.0
	fragments = 0.0
	save_progress()
	# Só quando algo caiu de fato: morrer de bolso vazio não tem som de perda.
	if frag_bag_active:
		SignalBus.fragment_bag_dropped.emit(dropped)

## Há uma bolsa caída para recuperar nesta fase?
func has_bag_in_phase(phase: int) -> bool:
	return frag_bag_active and frag_bag_phase == phase

## Recupera a bolsa: devolve todos os fragmentos ao saldo e limpa o estado. Retorna o valor
## recuperado (0.0 se não havia bolsa). Emite fragment_gained para a HUD pulsar o ganho.
func recover_fragment_bag() -> float:
	if not frag_bag_active:
		return 0.0
	var amount := frag_bag_amount
	fragments += amount
	frag_bag_active = false
	frag_bag_amount = 0.0
	save_progress()
	SignalBus.fragment_gained.emit(fragments, amount)
	SignalBus.fragment_bag_recovered.emit(amount)
	return amount

# ─── Santuário dos Encantados ──────────────────────
## Liberta o encantado da fase: registra e persiste. Idempotente. O Jesuíta (P5) e fases
## inválidas são ignorados. Chamado pelo ArenaManager na morte de boss (junto do bounty e
## do phase_reached — chamada direta, NÃO listener de SignalBus.boss_died: testes emitem
## esse sinal cru e um listener persistiria save como efeito colateral).
func free_boss(phase: int) -> void:
	if phase not in FREEABLE_BOSS_PHASES or is_boss_freed(phase):
		return
	freed_bosses.append(phase)
	freed_bosses.sort()
	save_progress()

func is_boss_freed(phase: int) -> bool:
	return phase in freed_bosses

## O rito de chegada do encantado desta fase já foi exibido no acampamento?
func has_seen_spirit(phase: int) -> bool:
	return phase in spirits_seen

## Marca o rito como exibido (exige o encantado libertado). Idempotente; persiste.
func mark_spirit_seen(phase: int) -> void:
	if not is_boss_freed(phase) or has_seen_spirit(phase):
		return
	spirits_seen.append(phase)
	spirits_seen.sort()
	save_progress()

# ─── Upgrades ──────────────────────────────────────
func get_upgrade_level(key: String) -> int:
	return int(upgrades.get(key, 0))

## True se a erva pode ser comprada AGORA: fase alcançada, requisito (se houver) já fumado,
## wins_required atendido (se houver) e ainda não no nível máximo. NÃO checa fragmentos —
## affordability é estado de UI, separado da elegibilidade. Fonte única do gate do Hub (cards)
## e dos testes.
func is_available(key: String) -> bool:
	if not UPGRADE_DEFS.has(key):
		return false
	var def: Dictionary = UPGRADE_DEFS[key]
	if phase_reached < int(def.get("phase", 1)):
		return false
	var wins_req: int = int(def.get("wins_required", 0))
	if wins_req > 0 and total_wins < wins_req:
		return false
	var req: String = String(def.get("requires", ""))
	if req != "" and get_upgrade_level(req) < 1:
		return false
	return get_upgrade_level(key) < int(def.get("max_level", 1))

## Ervas de `keys` compráveis agora, na ordem dada (preserva a ordem da trilha).
func available_keys(keys: Array) -> Array[String]:
	var out: Array[String] = []
	for key: String in keys:
		if is_available(key):
			out.append(key)
	return out

## Primeira erva PENDENTE de `keys` (nível < máx.), comprada ou não. "" se a trilha está
## completa. Usada pelo Hub para explicar o que vem a seguir numa trilha sem card disponível.
func next_pending_key(keys: Array) -> String:
	for key: String in keys:
		var def: Dictionary = UPGRADE_DEFS[key]
		if get_upgrade_level(key) < int(def.get("max_level", 1)):
			return key
	return ""

## Custo de fragmentos do aprimoramento. Override remoto (painel admin) tem prioridade.
func upgrade_cost(key: String) -> int:
	if RemoteUpgrades.has_override(key):
		return RemoteUpgrades.cost_override(key)
	return int(UPGRADE_DEFS[key].get("fragment_cost", 0))

## Valor do atributo (dmg ou hp). Override remoto tem prioridade.
func _upgrade_attr(key: String) -> int:
	if RemoteUpgrades.has_override(key):
		return RemoteUpgrades.attr_override(key)
	var def: Dictionary = UPGRADE_DEFS[key]
	return int(def.get("dmg", def.get("hp", 0)))

func get_damage_bonus() -> int:
	# Soma o "dmg" de cada erva de Fúria comprada (fonte numérica única). Tiers 1-4 somam
	# +1 cada; tiers 5-6 somam +2 cada (teto +8 → dano 9). A CHAMA soma +CHAMA_DAMAGE_BONUS.
	var bonus := 0
	for key in FURIA_KEYS:
		bonus += get_upgrade_level(key) * _upgrade_attr(key)
	if has_chama:
		bonus += CHAMA_DAMAGE_BONUS
	return bonus

## Registra uma morte de monstro comum para o sistema da CHAMA. Só conta se a espada
## (forca_3) já existe e a CHAMA ainda não foi obtida. A cada KILLS_PER_CHAMA_ROLL mortes
## faz UM sorteio. Retorna true se a CHAMA foi conquistada NESTA morte (recompensa = CHAMA
## no lugar do fragmento).
func register_kill_for_chama() -> bool:
	# CHAMA desbloqueada a partir do T3 (forca_3) ou superior.
	if has_chama or (get_upgrade_level("forca_3") < 1 and get_upgrade_level("forca_4") < 1 and get_upgrade_level("forca_5") < 1 and get_upgrade_level("forca_6") < 1):
		return false
	kills_toward_chama += 1
	if kills_toward_chama < KILLS_PER_CHAMA_ROLL:
		save_progress()
		return false
	kills_toward_chama = 0
	if randf() < CHAMA_DROP_CHANCE:
		has_chama = true
		save_progress()
		SignalBus.chama_gained.emit()
		return true
	save_progress()
	return false

func get_health_bonus() -> int:
	# Soma o "hp" de cada erva de Cura comprada (fonte numérica única). Incrementos
	# crescentes 2/3/3/4/4/5 (teto +21 → HP máx. 23).
	var bonus := 0
	for key in CURA_KEYS:
		bonus += get_upgrade_level(key) * _upgrade_attr(key)
	return bonus

## Texto de efeito DERIVADO da matemática (não há string solta a desincronizar — KI-006).
## Fúria: "Dano +N/hit (total T)"; Cura: "+N HP (total T)". T é o valor acumulado da trilha
## somando todas as ervas até esta (inclusive), partindo do base (dano 1 / HP base 2).
func effect_text(key: String) -> String:
	if not UPGRADE_DEFS.has(key):
		return ""
	var def: Dictionary = UPGRADE_DEFS[key]
	var line: String = String(def.get("line", ""))
	if line == "furia":
		var inc: int = _upgrade_attr(key)
		var total := BASE_DAMAGE + _cumulative(FURIA_KEYS, key)
		return Lang.tf(&"card.effect.dmg", [inc, total])
	var inc_hp: int = _upgrade_attr(key)
	var total_hp := Constants.CAIPORA_MAX_HEALTH + _cumulative(CURA_KEYS, key)
	return Lang.tf(&"card.effect.hp", [inc_hp, total_hp])

## Versão curta do efeito para o card compacto: só o incremento ("+N dano" / "+N HP"),
## sem o total. Mesma fonte (a matemática de _upgrade_attr — KI-006).
func effect_short(key: String) -> String:
	if not UPGRADE_DEFS.has(key):
		return ""
	var def: Dictionary = UPGRADE_DEFS[key]
	var inc: int = _upgrade_attr(key)
	if String(def.get("line", "")) == "furia":
		return Lang.tf(&"card.effect.dmg.short", [inc])
	return Lang.tf(&"card.effect.hp.short", [inc])

## Soma o atributo de todas as ervas de `order` até `key` (inclusive).
func _cumulative(order: Array[String], key: String) -> int:
	var sum := 0
	for k in order:
		sum += _upgrade_attr(k)
		if k == key:
			break
	return sum

func get_touch_controls_mode() -> String:
	return touch_controls_mode

func set_touch_controls_mode(mode: String) -> void:
	if mode in ["auto", "always", "never"]:
		touch_controls_mode = mode
		save_progress()

## Consome fragmentos e incrementa o nível. Retorna false se não puder comprar.
func purchase_upgrade(key: String) -> bool:
	if not UPGRADE_DEFS.has(key):
		return false
	var def: Dictionary = UPGRADE_DEFS[key]
	var req: String = def.get("requires", "")
	if req != "" and get_upgrade_level(req) < 1:
		return false
	var cost: int = upgrade_cost(key)
	var level := get_upgrade_level(key)
	if level >= int(def["max_level"]) or fragments < cost:
		return false
	fragments -= cost
	upgrades[key] = level + 1
	save_progress()
	return true

# ─── Public API ────────────────────────────────────
func save_progress() -> void:
	var data := {
		"version": SAVE_VERSION,
		"unlocked_characters": unlocked_characters,
		"unlocked_modifiers": unlocked_modifiers,
		"total_runs": total_runs,
		"total_wins": total_wins,
		"upgrades": upgrades,
		"fragments": fragments,
		"phase_reached": phase_reached,
		"touch_controls_mode": touch_controls_mode,
		"has_chama": has_chama,
		"kills_toward_chama": kills_toward_chama,
		"frag_bag_active": frag_bag_active,
		"frag_bag_phase": frag_bag_phase,
		"frag_bag_x": frag_bag_pos.x,
		"frag_bag_y": frag_bag_pos.y,
		"frag_bag_amount": frag_bag_amount,
		"freed_bosses": freed_bosses,
		"spirits_seen": spirits_seen,
		"current_run_defeated_enemies": current_run_defeated_enemies,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("MetaProgression: failed to open save file for writing")
		return
	file.store_string(JSON.stringify(data))
	file.flush()  # garante que o buffer foi gravado antes do close (sincronização do IndexedDB no Web)
	file.close()

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("MetaProgression: failed to open save file for reading")
		return
	var text := file.get_as_text()
	file.close()
	# JSON.parse() (instância) retorna código de erro sem logar no console — diferente de
	# JSON.parse_string(), que emite um erro de engine em texto inválido.
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK or not (json.data is Dictionary):
		# Save corrompido/truncado: mantém os defaults em memória. Não sobrescreve o
		# arquivo — o próximo save_progress() válido regrava o conteúdo correto.
		push_warning("MetaProgression: save corrompido em %s; usando defaults." % SAVE_PATH)
		return
	var data: Dictionary = json.data
	# Gancho de migração: saves sem "version" (v0) carregam com defaults nos campos ausentes,
	# então v0→v1 é no-op. v1→v2 também é no-op: novas keys de upgrade (forca_5/6, saude_5/6)
	# não existem no save antigo (upgrades{} não as contém → nível 0), e total_wins já existia.
	# v2→v3 também é no-op: a bolsa de fragmentos (frag_bag_*) ausente assume defaults (sem bolsa).
	var _version := int(data.get("version", 0))
	unlocked_characters = _to_string_array(data.get("unlocked_characters", ["caipora"]))
	unlocked_modifiers = _to_string_array(data.get("unlocked_modifiers", []))
	total_runs = data.get("total_runs", 0)
	total_wins = data.get("total_wins", 0)
	upgrades = _to_int_dict(data.get("upgrades", {}))
	fragments = float(data.get("fragments", 0.0))
	phase_reached = int(data.get("phase_reached", 1))
	touch_controls_mode = data.get("touch_controls_mode", "auto")
	has_chama = bool(data.get("has_chama", false))
	kills_toward_chama = int(data.get("kills_toward_chama", 0))
	frag_bag_active = bool(data.get("frag_bag_active", false))
	frag_bag_phase = int(data.get("frag_bag_phase", 0))
	frag_bag_pos = Vector2i(int(data.get("frag_bag_x", 0)), int(data.get("frag_bag_y", 0)))
	frag_bag_amount = float(data.get("frag_bag_amount", 0.0))
	freed_bosses = _to_phase_array(data.get("freed_bosses", []))
	spirits_seen = _to_phase_array(data.get("spirits_seen", []))
	current_run_defeated_enemies = _to_string_array(data.get("current_run_defeated_enemies", []))
	GameState.defeated_enemy_ids.assign(current_run_defeated_enemies)
	if _version < 4:
		# v3→v4 (Santuário dos Encantados): saves veteranos derivam os libertados de
		# phase_reached (derrotar o boss da fase N grava phase_reached = N+1) e já entram
		# com o rito visto — sem 4 ritos de chegada em fila na primeira visita pós-update.
		# Trade-off aceito (PRD §7): P1/P2 têm tile de saída, então phase_reached pode ter
		# avançado SEM derrotar Mula/Boitatá — a derivação é generosa com quem pulou o boss.
		for phase: int in FREEABLE_BOSS_PHASES:
			if phase_reached >= phase + 1 and phase not in freed_bosses:
				freed_bosses.append(phase)
		freed_bosses.sort()
		spirits_seen = freed_bosses.duplicate()

func mark_enemy_defeated(id: String) -> void:
	if id not in current_run_defeated_enemies:
		current_run_defeated_enemies.append(id)
	save_progress()

## Zera todo o progresso e apaga o arquivo de save. Não toca em user://settings.cfg (áudio).
func reset_save() -> void:
	unlocked_characters = ["caipora"]
	unlocked_modifiers = []
	total_runs = 0
	total_wins = 0
	upgrades = {}
	fragments = 0.0
	phase_reached = 1
	touch_controls_mode = "auto"
	has_chama = false
	kills_toward_chama = 0
	frag_bag_active = false
	frag_bag_phase = 0
	frag_bag_pos = Vector2i.ZERO
	frag_bag_amount = 0.0
	# Resetar devolve os guardiões às fases: o santuário se desfaz junto do progresso.
	freed_bosses = []
	spirits_seen = []
	current_run_defeated_enemies = []
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _to_int_dict(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for key in value:
			if key is String and UPGRADE_DEFS.has(key):
				result[key] = int(value[key])
	return result

# Saneia uma lista de fases vinda do JSON (floats → int, só P1–P4, sem duplicata, ordenada).
func _to_phase_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for item in value:
			var phase := int(item)
			if phase in FREEABLE_BOSS_PHASES and phase not in result:
				result.append(phase)
	result.sort()
	return result

func _to_string_array(value: Variant) -> Array[String]:
	if value is Array:
		var result: Array[String] = []
		for item in value:
			if item is String:
				result.append(item)
		return result
	return []
