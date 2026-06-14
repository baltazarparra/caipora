class_name MainMenu
extends CanvasLayer

## Porta de entrada do jogo. Inicia a run e abre o Acampamento de aprimoramentos ANTES da
## Fase 1: a Caipora desperta no acampamento, pode gastar os fragmentos acumulados de runs
## anteriores e pisa no rastro para entrar na mata (Exploração da Fase 1). O save é carregado
## pelo autoload MetaProgression.
## A abertura "Horizonte Infernal" (fogo, treelines, brasas, Caipora andando) é
## montada na cena; aqui cuidamos do fade-in/out e da vida do título.

# ─── Constants ─────────────────────────────────────
const FADE_LAYER: int = 100
const FADE_IN_DURATION: float = 1.2
const LOGO_PATH: String = "res://assets/sprites/logo_title.png"
const LOGO_BLINK_PATH: String = "res://assets/sprites/logo_title_blink.png"
const LOGO_BASE_SIZE := Vector2(256.0, 96.0)
# Retrato (primário): o logo domina a tela alta. Paisagem (tablet/desktop): logo e
# botões ficam em no máximo 30% da largura, pra não engolir o horizonte da abertura.
const LOGO_FIT_FRACTION_PORTRAIT := 0.85
const MENU_MAX_WIDTH_FRACTION := 0.30

# ─── State ─────────────────────────────────────────
@onready var _start_button: Button = $Center/VBox/StartButton
@onready var _quit_button: Button = $Center/VBox/QuitButton

var _fade: ColorRect
var _logo: TextureRect

func _ready() -> void:
	# O save é carregado no _ready() do autoload MetaProgression (independente da cena de boot).
	_start_button.text = Lang.t(&"menu.start")
	_quit_button.text = Lang.t(&"menu.quit")
	$Center/VBox/StartButton.pressed.connect(_on_start_pressed)
	$Center/VBox/QuitButton.pressed.connect(_on_quit_pressed)
	$Center/VBox/GithubLink.pressed.connect(_on_github_pressed)
	_setup_fade()
	_setup_logo()
	_setup_version_label()
	_setup_update_banner()
	_relayout_buttons()
	get_viewport().size_changed.connect(_relayout_buttons)
	# Foco inicial ANTES de ligar o hover: abrir o menu não dá tick, navegar dá.
	_start_button.grab_focus()
	# BaseButton, não Button: GithubLink é LinkButton (irmão de Button) — tipar Button
	# faz o array tipado rejeitá-lo (vira null) e o hover do link morre em silêncio.
	for button: BaseButton in [$Center/VBox/StartButton, $Center/VBox/QuitButton, $Center/VBox/GithubLink]:
		button.focus_entered.connect(AudioDirector.play_ui_hover)
		button.mouse_entered.connect(AudioDirector.play_ui_hover)

## Versão atual (canto inferior direito).
func _setup_version_label() -> void:
	var label := Label.new()
	label.text = _resolve_version()
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.494, 0.514, 0.541, 0.7))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.position -= Vector2(12, 10)
	add_child(label)

## Banner de balanceamento novo (RemoteConfig). Aparece no topo quando o servidor tem
## valores de inimigo mais novos que os aplicados; clicar aplica e (no web) recarrega.
## Trata a corrida: se o fetch já chegou antes deste _ready, o pending já está pronto.
var _update_banner: Button
func _setup_update_banner() -> void:
	SignalBus.remote_config_update_available.connect(_on_update_available)
	SignalBus.remote_patterns_update_available.connect(_on_update_available)
	SignalBus.remote_upgrades_update_available.connect(_on_update_available)
	if RemoteConfig.has_pending() or RemotePatterns.has_pending() or RemoteUpgrades.has_pending():
		_show_update_banner()

func _on_update_available(_version: int) -> void:
	_show_update_banner()

func _show_update_banner() -> void:
	if is_instance_valid(_update_banner):
		return
	_update_banner = Button.new()
	_update_banner.text = Lang.t(&"menu.update")
	_update_banner.add_theme_font_size_override("font_size", 14)
	_update_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_update_banner.focus_mode = Control.FOCUS_NONE
	_update_banner.pressed.connect(func() -> void:
		AudioDirector.play_ui_hover()
		RemoteUpgrades.apply_pending()
		RemotePatterns.apply_pending()
		RemoteConfig.apply_pending())
	add_child(_update_banner)

## Versão a exibir: o carimbo automático do build (scripts/core/build_info.gd, alpha-X.Y.Z
## com Z = contagem de commits do git, gerado em `make export` — gitignored) quando
## presente; senão o config/version do projeto ("alpha-X.Y (dev)", rodando do editor,
## onde o carimbo ainda não foi gerado).
func _resolve_version() -> String:
	var path := "res://scripts/core/build_info.gd"
	if ResourceLoader.exists(path):
		var gd := load(path) as GDScript
		if gd != null and gd.get_script_constant_map().has("VERSION"):
			return String(gd.get_script_constant_map()["VERSION"])
	return str(ProjectSettings.get_setting("application/config/version", "dev"))

## Overlay preto para o fade-in de abertura (handoff do boot splash). O fade-out
## de Iniciar NÃO vive aqui: toda saída de cena é mascarada pelo SceneTransition
## (uma linguagem de transição só).
func _setup_fade() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = FADE_LAYER
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)
	add_child(fade_layer)
	create_tween().tween_property(_fade, "color:a", 0.0, FADE_IN_DURATION)

## Troca o título em fonte pelo wordmark da marca (gen_brand.py: letras na rampa
## da juba, "O" como rosto-vazio), com os olhos do "O" piscando. Montado por
## código no lugar do Title (sem editar a cena); se o asset faltar, o título em
## fonte continua como fallback.
func _setup_logo() -> void:
	var title := $Center/VBox/Title as RichTextLabel
	if not ResourceLoader.exists(LOGO_PATH):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/title_fire.gdshader") as Shader
		title.material = mat
		return
	title.visible = false
	_logo = TextureRect.new()
	_logo.texture = load(LOGO_PATH)
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vbox := $Center/VBox
	vbox.add_child(_logo)
	vbox.move_child(_logo, title.get_index())
	_fit_logo()
	get_viewport().size_changed.connect(_fit_logo)
	_schedule_blink()

## Escala INTEIRA do logo (texel uniforme, mesma regra do PixelScale): a maior que
## couber na fração da largura do viewport — ~85% em retrato, 30% em paisagem.
func _fit_logo() -> void:
	if _logo == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var fit: float = LOGO_FIT_FRACTION_PORTRAIT if Constants.is_portrait(vp) \
		else MENU_MAX_WIDTH_FRACTION
	var scale_i: float = maxf(1.0, floorf(vp.x * fit / LOGO_BASE_SIZE.x))
	_logo.custom_minimum_size = LOGO_BASE_SIZE * scale_i

## Em paisagem Iniciar/Sair não esticam até a largura do logo: ficam em no máximo 30%
## da largura do viewport, centralizados (e o link do github acompanha o centro). Em
## retrato preenchem o VBox (comportamento original, intocado).
func _relayout_buttons() -> void:
	var vp := get_viewport().get_visible_rect().size
	var portrait := Constants.is_portrait(vp)
	for button: Button in [_start_button, _quit_button]:
		if portrait:
			button.size_flags_horizontal = Control.SIZE_FILL
			button.custom_minimum_size.x = 0.0
		else:
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.custom_minimum_size.x = vp.x * MENU_MAX_WIDTH_FRACTION
	var link: LinkButton = $Center/VBox/GithubLink
	link.size_flags_horizontal = Control.SIZE_FILL if portrait else Control.SIZE_SHRINK_CENTER

## Os olhos no "O" piscam em intervalos irregulares — a mata olha de volta.
func _schedule_blink() -> void:
	get_tree().create_timer(randf_range(2.2, 5.5)).timeout.connect(func() -> void:
		if not is_instance_valid(_logo):
			return
		_logo.texture = load(LOGO_BLINK_PATH)
		get_tree().create_timer(0.13).timeout.connect(func() -> void:
			if is_instance_valid(_logo):
				_logo.texture = load(LOGO_PATH)
			_schedule_blink()))

func _on_start_pressed() -> void:
	AudioDirector.unlock_audio()
	_start_button.disabled = true
	# A run começa pelo acampamento; o SceneTransition mascara a troca com o
	# flavor do camp — sem fade duplicado aqui.
	_begin_run()

## Inicia a run e abre o Acampamento (HUB) antes da Fase 1. start_run() já define
## pending_exploration = EXPLORATION, então o rastro de saída do hub leva direto à
## Exploração da Fase 1.
func _begin_run() -> void:
	GameState.start_run()
	GameState.change_screen(SignalBus.Screen.HUB)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_github_pressed() -> void:
	OS.shell_open("https://github.com/baltazarparra")
