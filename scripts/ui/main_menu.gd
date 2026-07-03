class_name MainMenu
extends CanvasLayer

## Porta de entrada do jogo. Inicia a run no Acampamento: a Caipora desperta,
## pode gastar Terra Rara e pisa no rastro para entrar na mata.

# ─── Constants ─────────────────────────────────────
const FADE_LAYER: int = 100
const FADE_IN_DURATION: float = 1.2
const LOGO_PATH: String = "res://assets/sprites/logo_title.png"
const LOGO_BLINK_PATH: String = "res://assets/sprites/logo_title_blink.png"
const LOGO_BASE_SIZE := Vector2(256.0, 96.0)
const LOGO_FIT_FRACTION_PORTRAIT := 0.85
const MENU_MAX_WIDTH_FRACTION := 0.30
# Alturas históricas do hero viram PISO; o alvo é o dobro, capado pelo espaço da tela.
const HERO_HEIGHT_PORTRAIT := 104.0
const HERO_HEIGHT_LANDSCAPE := 92.0
const HERO_HEIGHT_SCALE := 2.0
const OPTIONS_HEIGHT := 52.0
const FOOTER_HEIGHT := 48.0
# Respiros internos do bloco central (logo → hero → opções).
const STACK_GAP_LOGO := 36.0
const STACK_GAP_OPTIONS := 10.0
# Topo 30% maior que o histórico (66×44 / 40px): alvo de toque em phone retrato.
const FLAG_SIZE := Vector2(86.0, 57.0)
const SPEAKER_ICON_PX := 52.0
const UPDATE_BANNER_HEIGHT := 42.0
const GITHUB_URL := "https://github.com/baltazarparra/caipora"

# ─── State ─────────────────────────────────────────
var _fade: ColorRect
var _menu_stack: Control
var _logo: TextureRect
var _scrim: ColorRect
var _title: RichTextLabel
var _start_button: BrandButton
var _options_button: Button
var _options_panel: OptionsPanel
var _footer: MarginContainer
var _footer_row: HBoxContainer
var _version_label: Label
var _github_link: LinkButton
var _lang_row: HBoxContainer
var _btn_pt: Button
var _btn_en: Button
var _speaker_btn: SpeakerButton
var _update_banner: Button

func _ready() -> void:
	_title = $Ui/Title as RichTextLabel
	_scrim = $Scrim as ColorRect
	# Só o menu ergue a chama a ~90% do viewport; as arenas ficam no fogo baixo.
	($DoomFire as DoomFire).tall_flames = true
	_setup_fade()
	_setup_menu_stack()
	_setup_logo()
	_setup_start_button()
	_setup_options()
	_setup_top_bar()
	_setup_footer()
	_setup_update_banner()
	Lang.language_changed.connect(_on_language_changed)
	_relayout_menu()
	get_viewport().size_changed.connect(_relayout_menu)
	_start_button.grab_focus()

## Banner de balanceamento novo (RemoteConfig). Aparece no topo quando o servidor tem
## valores mais novos que os aplicados; clicar aplica e no web recarrega.
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
	# O banner é TOP_WIDE: o topo (bandeiras + speaker) precisa descer para não ficar sob ele.
	_relayout_menu()

## Versão a exibir: carimbo automático do build quando presente; senão config/version.
func _resolve_version() -> String:
	var path := "res://scripts/core/build_info.gd"
	if ResourceLoader.exists(path):
		var gd := load(path) as GDScript
		if gd != null and gd.get_script_constant_map().has("VERSION"):
			return String(gd.get_script_constant_map()["VERSION"])
	return str(ProjectSettings.get_setting("application/config/version", "dev"))

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

## Bloco central único: logo, Despertar e Opções moram no mesmo container,
## centralizado na altura do viewport pelo _relayout_menu. O Title da cena
## (fallback sem logo) é reparentado para dentro dele.
func _setup_menu_stack() -> void:
	_menu_stack = Control.new()
	_menu_stack.name = "MenuStack"
	_menu_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Ui.add_child(_menu_stack)
	$Ui.remove_child(_title)
	_menu_stack.add_child(_title)

func _setup_logo() -> void:
	if not ResourceLoader.exists(LOGO_PATH):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/title_fire.gdshader") as Shader
		_title.material = mat
		return
	_title.visible = false
	_logo = TextureRect.new()
	_logo.texture = load(LOGO_PATH)
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_stack.add_child(_logo)
	_schedule_blink()

func _setup_start_button() -> void:
	_start_button = BrandButton.new()
	_start_button.variant = BrandButton.Variant.HERO
	_start_button.label = Lang.t(&"menu.start")
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.focus_entered.connect(AudioDirector.play_ui_hover)
	_start_button.mouse_entered.connect(AudioDirector.play_ui_hover)
	_menu_stack.add_child(_start_button)

func _setup_options() -> void:
	_options_panel = OptionsPanel.new()
	add_child(_options_panel)
	_options_button = Button.new()
	_options_button.text = Lang.t(&"options.title")
	_options_button.add_theme_font_size_override("font_size", Constants.FONT_SM)
	_options_button.pressed.connect(_options_panel.open)
	_options_button.focus_entered.connect(AudioDirector.play_ui_hover)
	_options_button.mouse_entered.connect(AudioDirector.play_ui_hover)
	_apply_options_style(false)
	_options_button.focus_entered.connect(_apply_options_style.bind(true))
	_options_button.focus_exited.connect(_apply_options_style.bind(false))
	_options_button.mouse_entered.connect(_apply_options_style.bind(true))
	_options_button.mouse_exited.connect(_apply_options_style.bind(false))
	_menu_stack.add_child(_options_button)

## Topo da tela: bandeiras de idioma à esquerda, alto-falante (mute geral) à direita.
## O seletor de idioma morava escondido no rodapé — aqui ele é a primeira coisa que
## um jogador de fora enxerga.
func _setup_top_bar() -> void:
	_lang_row = HBoxContainer.new()
	_lang_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_lang_row.add_theme_constant_override("separation", 8)
	$Ui.add_child(_lang_row)
	_btn_pt = _make_flag_btn("res://assets/sprites/flag_br.png")
	_btn_en = _make_flag_btn("res://assets/sprites/flag_us.png")
	_lang_row.add_child(_btn_pt)
	_lang_row.add_child(_btn_en)
	_btn_pt.pressed.connect(_on_select_pt)
	_btn_en.pressed.connect(_on_select_en)
	_refresh_lang_flags()

	_speaker_btn = SpeakerButton.new()
	_speaker_btn.icon_color = Constants.COLOR_AMBER
	_speaker_btn.configure_size(SPEAKER_ICON_PX)
	_speaker_btn.set_muted(AudioDirector.is_master_muted())
	_speaker_btn.pressed.connect(_on_speaker_pressed)
	$Ui.add_child(_speaker_btn)

## Mute GERAL (bus Master): silencia música, ambiência E sfx — difere do speaker
## do HUD in-game, que alterna só música+ambiência.
func _on_speaker_pressed() -> void:
	AudioDirector.play_ui_hover()
	AudioDirector.toggle_master_mute()
	_speaker_btn.set_muted(AudioDirector.is_master_muted())

func _setup_footer() -> void:
	_footer = MarginContainer.new()
	_footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_footer)

	_footer_row = HBoxContainer.new()
	_footer_row.add_theme_constant_override("separation", Constants.SPACE_SM)
	_footer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_child(_footer_row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer_row.add_child(spacer)

	_github_link = LinkButton.new()
	_github_link.text = "github"
	_github_link.add_theme_font_size_override("font_size", Constants.FONT_SM)
	_github_link.pressed.connect(_on_github_pressed)
	_github_link.focus_entered.connect(AudioDirector.play_ui_hover)
	_github_link.mouse_entered.connect(AudioDirector.play_ui_hover)
	_footer_row.add_child(_github_link)

	_version_label = Label.new()
	_version_label.text = _resolve_version()
	_version_label.add_theme_font_size_override("font_size", Constants.FONT_SM)
	_version_label.add_theme_color_override("font_color", Color(0.494, 0.514, 0.541, 0.72))
	_version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer_row.add_child(_version_label)

func _relayout_menu() -> void:
	var vp := get_viewport().get_visible_rect().size
	var portrait := Constants.is_portrait(vp)
	var side := clampf(minf(vp.x, vp.y) * 0.055, 24.0, 80.0)
	var bottom := clampf(minf(vp.x, vp.y) * 0.04, 18.0, 56.0)
	var logo_size := _logo_size(vp)
	var hero_w := clampf(vp.x - side * 2.0, 280.0, 560.0) if portrait \
		else clampf(vp.x * MENU_MAX_WIDTH_FRACTION, 260.0, 420.0)
	var hero_h := _hero_height(vp, portrait, logo_size, bottom)
	var stack_size := Vector2(maxf(logo_size.x, hero_w),
		logo_size.y + STACK_GAP_LOGO + hero_h + STACK_GAP_OPTIONS + OPTIONS_HEIGHT)
	var stack_pos := ((vp - stack_size) * 0.5).floor()
	_layout_control(_menu_stack, stack_pos, stack_size)
	var hero_y := logo_size.y + STACK_GAP_LOGO
	if is_instance_valid(_options_button):
		_options_button.add_theme_font_size_override("font_size",
			BrandButton.hero_label_font_size(hero_h))
	_layout_logo(stack_size.x, logo_size)
	_layout_control(_start_button, Vector2((stack_size.x - hero_w) * 0.5, hero_y),
		Vector2(hero_w, hero_h))
	_layout_control(_options_button,
		Vector2((stack_size.x - hero_w) * 0.5, hero_y + hero_h + STACK_GAP_OPTIONS),
		Vector2(hero_w, OPTIONS_HEIGHT))
	_layout_top_bar(vp)
	_layout_scrim(vp, stack_pos, stack_size)
	_layout_footer(side, bottom)
	if is_instance_valid(_update_banner):
		_update_banner.custom_minimum_size.y = UPDATE_BANNER_HEIGHT

## Altura do hero: o dobro do piso histórico onde o espaço permitir. Com o bloco
## central centralizado na altura do viewport, o espaço útil desconta dos DOIS
## lados a maior zona reservada (topo: bandeiras/speaker/banner; base: rodapé) —
## sem isso o bloco centrado invade o header em telas curtas (phone paisagem).
func _hero_height(vp: Vector2, portrait: bool, logo_size: Vector2, bottom: float) -> float:
	var floor_h := HERO_HEIGHT_PORTRAIT if portrait else HERO_HEIGHT_LANDSCAPE
	var insets := Constants.safe_insets(vp)
	var top_push := (UPDATE_BANNER_HEIGHT + 8.0) if is_instance_valid(_update_banner) else 0.0
	var header_h := insets.y + top_push \
		+ (_speaker_btn.size.y if _speaker_btn != null else FLAG_SIZE.y)
	var reserved := maxf(header_h, bottom + FOOTER_HEIGHT) + 12.0
	var avail := vp.y - reserved * 2.0 \
		- (logo_size.y + STACK_GAP_LOGO + STACK_GAP_OPTIONS + OPTIONS_HEIGHT)
	return floorf(clampf(avail, floor_h, floor_h * HERO_HEIGHT_SCALE))

## Bandeiras à esquerda, speaker à direita, centros alinhados; o banner "Atualizar"
## (TOP_WIDE) empurra os dois para baixo quando presente.
func _layout_top_bar(vp: Vector2) -> void:
	if _speaker_btn == null or _lang_row == null:
		return
	var insets := Constants.safe_insets(vp)
	var top_push := (UPDATE_BANNER_HEIGHT + 8.0) if is_instance_valid(_update_banner) else 0.0
	_speaker_btn.position = Vector2(vp.x - insets.x - _speaker_btn.size.x, insets.y + top_push)
	_lang_row.position = Vector2(insets.x,
		insets.y + top_push + (_speaker_btn.size.y - FLAG_SIZE.y) * 0.5)

func _logo_size(vp: Vector2) -> Vector2:
	var fit: float = LOGO_FIT_FRACTION_PORTRAIT if Constants.is_portrait(vp) \
		else MENU_MAX_WIDTH_FRACTION
	var scale_i: float = maxf(1.0, floorf(vp.x * fit / LOGO_BASE_SIZE.x))
	return LOGO_BASE_SIZE * scale_i

## Posições locais ao bloco central: o logo (ou o Title fallback) abre o stack.
func _layout_logo(stack_w: float, logo_size: Vector2) -> void:
	var target: Control = _logo if _logo != null else _title
	_layout_control(target, Vector2((stack_w - logo_size.x) * 0.5, 0.0), logo_size)

func _layout_control(control: Control, pos: Vector2, new_size: Vector2) -> void:
	if control == null:
		return
	control.position = pos.floor()
	control.size = new_size.floor()
	control.custom_minimum_size = new_size.floor()

func _layout_scrim(vp: Vector2, stack_pos: Vector2, stack_size: Vector2) -> void:
	if _scrim == null:
		return
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.offset_left = 0.0
	_scrim.offset_right = 0.0
	_scrim.offset_top = maxf(0.0, stack_pos.y - 24.0)
	_scrim.offset_bottom = -(vp.y - minf(vp.y, stack_pos.y + stack_size.y + 38.0))
	_scrim.color = Color(0.0, 0.0, 0.0, 0.34)

func _layout_footer(side: float, bottom: float) -> void:
	if _footer == null:
		return
	_footer.add_theme_constant_override("margin_left", int(side))
	_footer.add_theme_constant_override("margin_right", int(side))
	_footer.add_theme_constant_override("margin_bottom", int(bottom))
	_footer.custom_minimum_size.y = FOOTER_HEIGHT

func _apply_options_style(lit: bool) -> void:
	if _options_button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Constants.COLOR_AMBER if lit else Constants.COLOR_JUBA_DARK
	normal.set_border_width(SIDE_BOTTOM, 1)
	normal.set_content_margin_all(8)
	_options_button.add_theme_stylebox_override("normal", normal)
	_options_button.add_theme_stylebox_override("hover", normal)
	_options_button.add_theme_stylebox_override("focus", normal)
	_options_button.add_theme_color_override("font_color", Constants.COLOR_AMBER if lit else Constants.COLOR_TEXT)

func _schedule_blink() -> void:
	get_tree().create_timer(randf_range(2.2, 5.5)).timeout.connect(func() -> void:
		if not is_instance_valid(_logo):
			return
		_logo.texture = load(LOGO_BLINK_PATH)
		get_tree().create_timer(0.13).timeout.connect(func() -> void:
			if is_instance_valid(_logo):
				_logo.texture = load(LOGO_PATH)
			_schedule_blink()))

## Autoplay do browser: o áudio só pode nascer num handler de gesto. _input roda
## ANTES da GUI, então o 1º clique/toque/tecla em QUALQUER lugar do menu (inclusive
## nos botões, que consomem o evento) acorda a fogueira + música — não só o
## "Despertar". Um gesto basta: depois dele o processamento de input desliga.
func _input(event: InputEvent) -> void:
	var is_gesture: bool = (event is InputEventMouseButton or event is InputEventScreenTouch \
		or event is InputEventKey) and event.is_pressed()
	if is_gesture:
		AudioDirector.unlock_audio()
		set_process_input(false)

func _on_start_pressed() -> void:
	AudioDirector.unlock_audio()
	_pulse_press_haptic()
	_start_button.disabled = true
	_begin_run()

func _begin_run() -> void:
	GameState.start_run()
	GameState.change_screen(SignalBus.Screen.HUB)

func _make_flag_btn(texture_path: String) -> Button:
	var btn := Button.new()
	var tex := load(texture_path) as Texture2D
	if tex:
		btn.icon = tex
		btn.expand_icon = true
	btn.text = ""
	btn.custom_minimum_size = FLAG_SIZE
	btn.focus_entered.connect(AudioDirector.play_ui_hover)
	btn.mouse_entered.connect(AudioDirector.play_ui_hover)
	return btn

func _on_select_pt() -> void:
	AudioDirector.play_ui_hover()
	Lang.set_language(Lang.LANG_PT)

func _on_select_en() -> void:
	AudioDirector.play_ui_hover()
	Lang.set_language(Lang.LANG_EN)

func _on_language_changed(_lang: StringName) -> void:
	if is_instance_valid(_start_button):
		_start_button.label = Lang.t(&"menu.start")
	if is_instance_valid(_options_button):
		_options_button.text = Lang.t(&"options.title")
	if is_instance_valid(_update_banner):
		_update_banner.text = Lang.t(&"menu.update")
	_refresh_lang_flags()

func _refresh_lang_flags() -> void:
	if not is_instance_valid(_btn_pt):
		return
	var is_pt := Lang.current() == Lang.LANG_PT
	_apply_flag_style(_btn_pt, is_pt)
	_apply_flag_style(_btn_en, not is_pt)

func _apply_flag_style(btn: Button, active: bool) -> void:
	btn.modulate.a = 1.0 if active else 0.4
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.set_border_width_all(1 if active else 0)
	s.border_color = Constants.COLOR_BLOOD
	s.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.set_border_width_all(1)
	btn.add_theme_stylebox_override("hover", h)

func _pulse_press_haptic() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (navigator.vibrate) navigator.vibrate(18);", true)
	else:
		Input.vibrate_handheld(18)

func _on_github_pressed() -> void:
	OS.shell_open(GITHUB_URL)
