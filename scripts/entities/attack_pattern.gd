class_name AttackPattern
extends Resource

## Dado puro que descreve o ritmo de ataque de um inimigo.
## Salvo como .tres e consumido pela EnemyStateMachine — permite criar novos
## padrões (Criatura, Boss, futuros inimigos) sem tocar em código.

@export var idle_duration: float = 0.3
@export var wind_up_duration: float = 0.5
@export var attack_duration: float = 1.0
@export var cooldown_duration: float = 2.0
@export var damage_multiplier: float = 1.0
@export var is_special: bool = false

## Multi-strike (Boss): número de golpes consecutivos por pattern.
@export var strike_count: int = 1
## Telegraph mais curto usado entre golpes consecutivos (golpes 2..N).
## Fallback: usado quando strike_intervals está vazio (compat com .tres antigos).
@export var strike_delay: float = 0.4
## Intervalo INDEPENDENTE entre cada par de golpes (tamanho esperado: strike_count-1).
## Vazio = usa strike_delay para todos. Editável por sequência em site/sequence.html.
@export var strike_intervals: Array[float] = []
## Intervalo entre o ÚLTIMO golpe da sequência e o próximo turno.
## Sentinela < 0 = usa cooldown_duration (compat com .tres antigos).
@export var next_turn_delay: float = -1.0
## Janela de ação (tempo de reação) EXPLÍCITA por fase: { "1": s, ..., "5": s }.
## Vazio (ou fase ausente) = cai na fórmula Constants.timing_window_for_phase.
@export var action_windows: Dictionary = {}
## Se true, a Criatura executa pulo durante wind-up para sinalizar ataque duplo.
@export var jump_telegraph: bool = false
## Sequência de inputs para padrões especiais (is_special = true).
## Cada entrada é uma action do InputMap: "ui_up", "ui_down", "ui_left", "ui_right".
## Ignorado se is_special = false.
@export var input_sequence: Array[String] = []
