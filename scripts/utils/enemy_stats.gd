class_name EnemyStats
extends RefCounted

## ── FONTE ÚNICA de HP e dano de TODOS os inimigos ──────────────────────────
## Edite o balanceamento de inimigo AQUI e em nenhum outro lugar. As cenas .tscn
## NÃO são mais consultadas em jogo: o ArenaManager aplica estes números no spawn
## de TODO inimigo (comum, miniboss e boss), chaveando pelo nome do script da
## criatura (mula.gd -> "mula"). O `max_health`/`base_attack_damage` que ainda
## existem nas cenas são defaults de editor mortos — não têm efeito no jogo.
##
## Comuns têm HP UNIFORME por banda de fase (5 nas fases 1-2, 8 nas 3-5): deixe
## "hp" = HP_PHASE_SCALED para herdar a banda; ponha um número fixo para travar.
## O dano da Caipora NÃO vive aqui (não é inimigo) — fica em Constants.

const HP_PHASE_SCALED := 0           # sentinela: comum herda a banda de fase
const COMMON_HP_EARLY := 5           # comuns das fases 1-2
const COMMON_HP_LATE := 8            # comuns das fases 3-5
const DAMAGE_FLOOR := 1.0            # piso da Fase 5: golpe que acerta sempre sangra

## Bônus de dano do INIMIGO por fase — a floresta fica mais hostil. A Fase 5 foi
## rebalanceada em 2026-06 para -1 (com piso DAMAGE_FLOOR aplicado na arena).
## Fases ausentes = 0. Vale para os 4 chefes-monstro convertidos E para o Jesuíta.
const PHASE_DAMAGE_BONUS := { 2: 1.0, 4: 1.0, 5: -1.0 }

## Stats por criatura. Chave = nome do script (sem .gd).
##   hp           : HP máx.; HP_PHASE_SCALED herda a banda de fase do comum.
##   bonus_damage : dano fixo somado a CADA golpe (ex.: Bruxo +1 — antes vivia na cena).
const STATS := {
	# Bosses — HP fixo, escalando por fase.
	"mula":     { "hp": 12, "bonus_damage": 0.0 },  # P1 Mula sem Cabeça
	"boitata":  { "hp": 22, "bonus_damage": 0.0 },  # P2 Boitatá
	"curupira": { "hp": 30, "bonus_damage": 0.0 },  # P3 Curupira
	"saci":     { "hp": 36, "bonus_damage": 0.0 },  # P4 Saci
	"jesuita":  { "hp": 44, "bonus_damage": 0.0 },  # P5 Jesuíta Bandeirante Catequizador
	# Comuns / minibosses — HP pela banda de fase (HP_PHASE_SCALED).
	"criatura":    { "hp": HP_PHASE_SCALED, "bonus_damage": 0.0 },
	"cacador":     { "hp": HP_PHASE_SCALED, "bonus_damage": 0.0 },
	"assombracao": { "hp": HP_PHASE_SCALED, "bonus_damage": 0.0 },
	"bruxo":       { "hp": HP_PHASE_SCALED, "bonus_damage": 1.0 },  # +1 de dano por golpe
}

## Identidade da criatura para a tabela: nome do script, ex.: mula.gd -> "mula".
static func id_for(enemy: Node) -> StringName:
	var scr: Script = enemy.get_script()
	if scr == null:
		return &""
	return StringName(scr.resource_path.get_file().get_basename())

## HP uniforme do comum para a fase dada (5 nas fases 1-2, 8 nas 3-5).
static func common_hp_for_phase(phase: int) -> int:
	return COMMON_HP_LATE if phase >= 3 else COMMON_HP_EARLY

## HP máx. resolvido de um inimigo. Override remoto (painel admin) tem prioridade;
## senão bosses/minibosses usam o número fixo da tabela, e comuns/ids desconhecidos
## caem na banda de fase. HP de override <= 0 é ignorado (cai no default).
static func max_hp_for(enemy_id: StringName, phase: int) -> int:
	if RemoteConfig.has_override(enemy_id, phase):
		var ov: int = RemoteConfig.hp_override(enemy_id, phase)
		if ov > 0:
			return ov
	var entry: Dictionary = STATS.get(enemy_id, {})
	var hp: int = int(entry.get("hp", HP_PHASE_SCALED))
	return hp if hp > 0 else common_hp_for_phase(phase)

## Bônus aditivo TOTAL de dano por golpe (fixo do inimigo + delta de fase). Override
## remoto tem prioridade e já é o total. O piso de dano fica no ArenaManager, pós-soma.
static func bonus_damage_for(enemy_id: StringName, phase: int) -> float:
	if RemoteConfig.has_override(enemy_id, phase):
		return RemoteConfig.damage_override(enemy_id, phase)
	var entry: Dictionary = STATS.get(enemy_id, {})
	return float(entry.get("bonus_damage", 0.0)) + phase_damage_bonus(phase)

## Drop de fragmentos do inimigo. Override remoto tem prioridade; -1.0 = usar
## fallback de Constants (COMMON_FRAGMENT_REWARD ou BOSS_FRAGMENT_BOUNTY).
static func fragment_drop_for(enemy_id: StringName, phase: int) -> float:
	if RemoteConfig.has_fragment_drop_override(enemy_id, phase):
		return RemoteConfig.fragment_drop_override(enemy_id, phase)
	return -1.0

## Delta de dano da fase, somado ao golpe. Fases sem entrada = 0.
static func phase_damage_bonus(phase: int) -> float:
	return float(PHASE_DAMAGE_BONUS.get(phase, 0.0))
