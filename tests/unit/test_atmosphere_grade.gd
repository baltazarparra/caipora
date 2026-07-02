extends GutTest

# Trava o parse do override de URL do grading (?grade=), o toggle de A/B em
# device da Frente B (PRD-performance-refactor-web). Núcleo puro — sem browser.

const AtmosphereScript := preload("res://scripts/ui/atmosphere.gd")


func test_grade_param_absent() -> void:
	assert_eq(AtmosphereScript._parse_grade_param(""), -1)
	assert_eq(AtmosphereScript._parse_grade_param("?perf=1"), -1)
	assert_eq(AtmosphereScript._parse_grade_param("?dpr=native&v=644"), -1)


func test_grade_param_on_off() -> void:
	assert_eq(AtmosphereScript._parse_grade_param("?grade=1"), 1)
	assert_eq(AtmosphereScript._parse_grade_param("?grade=0"), 0)
	assert_eq(AtmosphereScript._parse_grade_param("grade=0"), 0, "sem '?' também vale")


func test_grade_param_combined() -> void:
	assert_eq(AtmosphereScript._parse_grade_param("?perf=1&grade=0"), 0)
	assert_eq(AtmosphereScript._parse_grade_param("?grade=1&perf"), 1)
	assert_eq(AtmosphereScript._parse_grade_param("?perf&hd=0&grade=0&v=2"), 0)


func test_grade_param_malformed_is_ignored() -> void:
	assert_eq(AtmosphereScript._parse_grade_param("?grade="), -1)
	assert_eq(AtmosphereScript._parse_grade_param("?grade=2"), -1)
	assert_eq(AtmosphereScript._parse_grade_param("?grade"), -1)
	assert_eq(AtmosphereScript._parse_grade_param("?upgrade=1"), -1,
		"substring não conta — só o par exato")
