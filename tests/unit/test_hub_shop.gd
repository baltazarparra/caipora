extends GutTest

## Interface de aprimoramentos do Hub (cards clicáveis). O conjunto de cards segue o gate da
## economia (phase_reached + requires + não-comprada, fonte: MetaProgression.available_keys) e
## clicar num card compra via purchase_upgrade — debitando fragmentos e persistindo. Card caro
## não compra. Comprar NÃO faz a próxima da cadeia aparecer nesta fogueira (pacing). Headless.

var _hub: Node2D
var _save_path: String

func before_each() -> void:
	_save_path = MetaProgression.SAVE_PATH
	MetaProgression.SAVE_PATH = "user://test_hub_shop_savegame.json"
	MetaProgression.upgrades = {}
	MetaProgression.fragments = 0.0
	MetaProgression.phase_reached = 1

func after_each() -> void:
	if is_instance_valid(_hub):
		_hub.queue_free()
	if FileAccess.file_exists(MetaProgression.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MetaProgression.SAVE_PATH))
	MetaProgression.SAVE_PATH = _save_path
	MetaProgression.upgrades = {}
	MetaProgression.fragments = 0.0
	MetaProgression.phase_reached = 1
	AudioDirector.set_master_muted(false)

# O conjunto de cards é montado no _ready do HubShop a partir do estado do MetaProgression,
# então cada teste prepara o estado ANTES de instanciar a cena.
func _instantiate() -> void:
	_hub = load("res://scenes/hub/hub.tscn").instantiate()
	add_child_autofree(_hub)
	await wait_frames(1)

func _shop() -> HubShop:
	return _hub._shop

# ── Fase 1 fresca: só os cards tier 1 de cada trilha ──
func test_phase1_shows_only_tier1_cards() -> void:
	MetaProgression.phase_reached = 1
	await _instantiate()
	var keys := _shop().available_card_keys()
	assert_true("forca" in keys, "Folha-Brasa (forca) disponível")
	assert_true("saude" in keys, "Seiva-Mãe (saude) disponível")
	assert_false("forca_2" in keys, "cards de fase 2 não aparecem na fase 1")
	assert_false("saude_2" in keys, "Casca-Boa (saude_2, fase 2) travada na fase 1")
	assert_eq(keys.size(), 2, "só dois cards na fase 1 fresca")

# ── requires trava a cadeia da Fúria; a Cura (saude_2 sem requires) libera dois cards ──
func test_requires_gate_excludes_locked_chain() -> void:
	MetaProgression.phase_reached = 4
	MetaProgression.upgrades = {}
	await _instantiate()
	var keys := _shop().available_card_keys()
	assert_true("forca" in keys, "forca (sem requisito) aparece na fase 4")
	assert_false("forca_2" in keys, "forca_2 travada: requer forca ainda não comprada")
	assert_false("forca_3" in keys, "forca_3 travada na cadeia")
	# saude e saude_2 NÃO têm requires: ambas elegíveis com fase >= 2.
	assert_true("saude" in keys, "saude elegível na fase 4")
	assert_true("saude_2" in keys, "saude_2 (sem requires) elegível na fase 4")

# ── Comprar a forca libera a forca_2 no conjunto elegível (próxima visita) ──
func test_available_unlocks_next_when_requirement_owned() -> void:
	MetaProgression.phase_reached = 4
	MetaProgression.upgrades = {"forca": 1}
	var avail := MetaProgression.available_keys(MetaProgression.FURIA_KEYS)
	assert_false("forca" in avail, "forca já fumada não reaparece")
	assert_true("forca_2" in avail, "forca_2 elegível com forca no cachimbo")

# ── Clicar num card acessível compra, debita e some ──
func test_click_buys_affordable_card() -> void:
	MetaProgression.phase_reached = 1
	MetaProgression.fragments = 100.0
	await _instantiate()
	assert_true("forca" in _shop().available_card_keys(), "forca disponível antes da compra")
	var bought := _shop().attempt_buy("forca")
	assert_true(bought, "compra bem-sucedida")
	assert_eq(MetaProgression.get_upgrade_level("forca"), 1, "forca comprada ao clicar")
	assert_eq(MetaProgression.fragments, 95.0, "5 fragmentos debitados (custo da forca)")
	assert_false("forca" in _shop().available_card_keys(), "card some após a compra")
	assert_eq(MetaProgression.get_damage_bonus(), 1, "bônus de dano reflete a compra")

# ── Clicar num card caro não compra e ele permanece ──
func test_click_on_unaffordable_card_does_not_buy() -> void:
	MetaProgression.phase_reached = 1
	MetaProgression.fragments = 1.0  # < custo 5 da forca
	await _instantiate()
	var bought := _shop().attempt_buy("forca")
	assert_false(bought, "sem fragmento suficiente não compra")
	assert_eq(MetaProgression.get_upgrade_level("forca"), 0, "nível intacto")
	assert_eq(MetaProgression.fragments, 1.0, "fragmentos intactos")
	assert_true("forca" in _shop().available_card_keys(), "card caro permanece")

# ── Pacing: comprar não faz a próxima da cadeia nascer nesta fogueira ──
func test_buying_does_not_unlock_next_this_visit() -> void:
	MetaProgression.phase_reached = 4
	MetaProgression.upgrades = {}
	MetaProgression.fragments = 100.0
	await _instantiate()
	assert_false("forca_2" in _shop().available_card_keys(), "forca_2 ausente antes da compra")
	_shop().attempt_buy("forca")
	assert_false("forca_2" in _shop().available_card_keys(),
		"forca_2 não aparece nesta fogueira (nasce na próxima)")

# ── next_pending_key: primeira erva ainda não no máximo (ou "" se completa) ──
func test_next_pending_key() -> void:
	MetaProgression.upgrades = {}
	assert_eq(MetaProgression.next_pending_key(MetaProgression.FURIA_KEYS), "forca",
		"trilha vazia: pendente é a primeira")
	MetaProgression.upgrades = {"forca": 1, "forca_2": 1, "forca_3": 1, "forca_4": 1, "forca_5": 1, "forca_6": 1}
	assert_eq(MetaProgression.next_pending_key(MetaProgression.FURIA_KEYS), "",
		"trilha completa: sem pendente")

func test_header_sound_button_toggles_master_mute() -> void:
	MetaProgression.phase_reached = 1
	AudioDirector.set_master_muted(false)
	await _instantiate()
	assert_true(_shop()._sound_button is SpeakerButton, "Hub usa icone de som, nao painel de opcoes")
	assert_false(_shop()._sound_button.muted, "icone reflete Master audivel")
	_shop()._on_sound_pressed()
	assert_true(AudioDirector.is_master_muted(), "toque muta todo o audio")
	assert_true(_shop()._sound_button.muted, "icone reflete Master mutado")
