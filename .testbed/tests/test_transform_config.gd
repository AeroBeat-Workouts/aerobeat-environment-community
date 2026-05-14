extends GutTest

const ConfigUtils := preload("res://scripts/transform_config.gd")

func test_build_and_parse_config_roundtrip() -> void:
	var original := ConfigUtils.build_config(Vector3(1, 2, 3), Vector3(4, 5, 6), Vector3(7, 8, 9))
	var parsed := ConfigUtils.parse_config(original)
	assert_eq(parsed["center"], Vector3(1, 2, 3))
	assert_eq(parsed["scale"], Vector3(4, 5, 6))
	assert_eq(parsed["rotation"], Vector3(7, 8, 9))
