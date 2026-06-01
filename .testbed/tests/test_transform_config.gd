extends GutTest

const ConfigUtils := preload("res://scripts/transform_config.gd")
const Paths := preload("res://scripts/testbed_paths.gd")

const TEMP_DIR := "user://sidecar_config_tests"

func after_each() -> void:
	_cleanup_temp_dir()

func test_sidecar_path_uses_asset_stem_and_yaml_suffix() -> void:
	assert_eq(
		Paths.sidecar_path_for("/tmp/assets/models/forest.glb"),
		"/tmp/assets/models/forest.config.yaml"
	)
	assert_eq(
		Paths.sidecar_path_for("/tmp/assets/splats/plaza.compressed.ply"),
		"/tmp/assets/splats/plaza.compressed.config.yaml"
	)

func test_media_config_yaml_roundtrip_normalizes_fit_mode() -> void:
	var path := _temp_file_path("image.config.yaml")
	var save_result := ConfigUtils.save_yaml(path, ConfigUtils.build_media_config("contain"))
	assert_true(save_result.get("ok", false), "Expected media YAML save to succeed")

	var load_result := ConfigUtils.load_yaml(path, "image")
	assert_true(load_result.get("ok", false), "Expected media YAML load to succeed")
	assert_true(load_result.get("has_config", false), "Expected saved media YAML to be treated as present")
	assert_eq(load_result.get("config", {}).get("media", {}).get("fit_mode", ""), "contain")

	var saved_text := FileAccess.get_file_as_string(path)
	assert_true(saved_text.contains("media:"), "Expected YAML to use nested media contract")
	assert_true(saved_text.contains("fit_mode: contain"), "Expected YAML to persist canonical fit_mode field")

func test_transform_config_yaml_roundtrip_uses_rotation_degrees_contract() -> void:
	var path := _temp_file_path("model.config.yaml")
	var payload := ConfigUtils.build_transform_config(Vector3(1, 2, 3), Vector3(4, 5, 6), Vector3(7, 8, 9))
	var save_result := ConfigUtils.save_yaml(path, payload)
	assert_true(save_result.get("ok", false), "Expected transform YAML save to succeed")

	var load_result := ConfigUtils.load_yaml(path, "glb")
	assert_true(load_result.get("ok", false), "Expected transform YAML load to succeed")
	var transform: Dictionary = load_result.get("config", {}).get("transform", {})
	assert_eq(transform.get("position"), [1.0, 2.0, 3.0])
	assert_eq(transform.get("rotation_degrees"), [4.0, 5.0, 6.0])
	assert_eq(transform.get("scale"), [7.0, 8.0, 9.0])
	assert_false(transform.has("rotation"), "Transform contract should not introduce transform.rotation")

	var saved_text := FileAccess.get_file_as_string(path)
	assert_true(saved_text.contains("rotation_degrees:"), "Expected YAML to store rotation_degrees")
	assert_false(saved_text.contains("rotation:"), "Expected YAML to avoid legacy rotation field")

func test_load_yaml_reports_truthful_missing_config() -> void:
	var path := _temp_file_path("missing.config.yaml")
	var load_result := ConfigUtils.load_yaml(path, "splat")
	assert_true(load_result.get("ok", false), "Missing sidecars should not be reported as parse failures")
	assert_false(load_result.get("has_config", true), "Missing sidecars should stay truthfully absent")
	assert_eq(load_result.get("config", {}), {})

func test_normalize_transform_config_accepts_legacy_shape_without_re_emitting_rotation() -> void:
	var normalized := ConfigUtils.normalize_transform_config({
		"center": [9, 8, 7],
		"rotation": [6, 5, 4],
		"scale": [3, 2, 1]
	})
	var transform: Dictionary = normalized.get("transform", {})
	assert_eq(transform.get("position"), [9.0, 8.0, 7.0])
	assert_eq(transform.get("rotation_degrees"), [6.0, 5.0, 4.0])
	assert_eq(transform.get("scale"), [3.0, 2.0, 1.0])
	assert_false(transform.has("rotation"), "Legacy input should normalize to rotation_degrees only")

func _temp_file_path(file_name: String) -> String:
	var dir_path := ProjectSettings.globalize_path(TEMP_DIR)
	DirAccess.make_dir_recursive_absolute(dir_path)
	return dir_path.path_join(file_name)

func _cleanup_temp_dir() -> void:
	var dir_path := ProjectSettings.globalize_path(TEMP_DIR)
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if dir.current_is_dir():
			continue
		DirAccess.remove_absolute(dir_path.path_join(entry))
	dir.list_dir_end()
	DirAccess.remove_absolute(dir_path)
