extends GutTest

# Flag HD (Quality): default por dispositivo, parse da URL, seams e persistência.
# Regra global: todo teste sensível a HD usa os seams — em CI linux o default
# do device é TRUE (desktop), nunca assumir false.

func after_each() -> void:
	Quality._reset_for_test()
	var cfg := ConfigFile.new()
	if cfg.load(Quality.SETTINGS_PATH) == OK and cfg.has_section(Quality.SETTINGS_SECTION):
		cfg.erase_section(Quality.SETTINGS_SECTION)
		cfg.save(Quality.SETTINGS_PATH)

# ── Default por dispositivo: desktop/Apple/teclado ligam, touch genérico não ──
func test_default_on_for_desktop_and_apple() -> void:
	assert_true(Quality._default_hd_for(["web_macos"], true), "Mac web (touch não desliga Apple)")
	assert_true(Quality._default_hd_for(["web_ios"], true), "iPhone/iPad web")
	assert_true(Quality._default_hd_for(["ios"], true), "iOS nativo")
	assert_true(Quality._default_hd_for(["web_windows"], false), "desktop Windows web")
	assert_true(Quality._default_hd_for(["linuxbsd"], false), "desktop nativo")

func test_default_on_for_keyboard_device() -> void:
	assert_true(Quality._default_hd_for([], false), "sem touchscreen = jogando com teclado")

func test_default_off_for_generic_touch() -> void:
	assert_false(Quality._default_hd_for([], true), "touch sem plataforma HD")
	assert_false(Quality._default_hd_for(["web_android"], true), "Android web")

# ── Parse do ?hd= na URL (autoridade do boot no web) ──
func test_url_param_parse() -> void:
	assert_eq(Quality._parse_hd_param("?hd=1"), 1, "hd=1 sozinho")
	assert_eq(Quality._parse_hd_param("?dpr=native&hd=0"), 0, "hd=0 preservando outros params")
	assert_eq(Quality._parse_hd_param("?perf"), -1, "sem hd = ausente")
	assert_eq(Quality._parse_hd_param("?hd=2"), -1, "valor inválido = ausente")
	assert_eq(Quality._parse_hd_param(""), -1, "query vazia")

# ── Seams controlam o cache sem tocar o disco ──
func test_seam_controls_cache() -> void:
	Quality._set_for_test(true)
	assert_true(Quality.hd_enabled(), "seam liga")
	Quality._set_for_test(false)
	assert_false(Quality.hd_enabled(), "seam desliga")

# ── Escolha explícita persiste no settings.cfg e vence o default do device ──
func test_set_hd_enabled_round_trips_through_cfg() -> void:
	Quality.set_hd_enabled(false)
	Quality._reset_for_test()
	assert_false(Quality.hd_enabled(), "hd=false relido do cfg (default linux seria true)")
	Quality.set_hd_enabled(true)
	Quality._reset_for_test()
	assert_true(Quality.hd_enabled(), "hd=true relido do cfg")
