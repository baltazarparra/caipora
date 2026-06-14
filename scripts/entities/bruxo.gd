class_name Bruxo
extends Cacador

## Monstro comum: o bruxo dos machados (antigo boss-caçador, agora recuperado como
## inimigo de fase). Herda o MOVESET do Caçador (mesmos padrões/telegraph), mas é
## mais forte: +1 de dano por golpe (EnemyStats.STATS["bruxo"].bonus_damage).
## Troca as brasas de tocha do Caçador pela aura sombria do feiticeiro amaldiçoado.

# Override do "spawn de partículas" do Caçador: em vez das brasas de tocha, o Bruxo
# emana uma aura de sombra (o mesmo tom do antigo boss de onde ele veio).
func _spawn_torch_embers() -> void:
	var aura := CPUParticles2D.new()
	aura.amount = 18
	aura.lifetime = 1.4
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 22.0
	aura.gravity = Vector2(0, -16)
	aura.initial_velocity_min = 4.0
	aura.initial_velocity_max = 12.0
	aura.scale_amount_min = 2.0
	aura.scale_amount_max = 4.0
	aura.color = Constants.COLOR_AURA_BOSS
	aura.z_index = -1
	add_child(aura)
