extends GutTest

const ConfigUtils := preload("res://scripts/transform_config.gd")
const GlbSceneScript := preload("res://scripts/glb_test_scene.gd")
const SplatSceneScript := preload("res://scripts/splat_test_scene.gd")
const RotationGizmoScript = preload("res://scripts/rotation_gizmo.gd")

const GLB_SCENE_PATH := "res://scripts/glb_test_scene.gd"
const SPLAT_SCENE_PATH := "res://scripts/splat_test_scene.gd"
const CAMERA_SCRIPT_PATH := "res://scripts/free_look_camera.gd"
const TEMP_DIR := "user://glb_splat_transform_ui_tests"

func after_each() -> void:
	_cleanup_temp_dir()

func test_glb_scene_routes_loading_through_public_loader_contract() -> void:
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(GLB_SCENE_PATH))
	assert_true(text.contains("AeroGLTFLoaderScript"), "GLB scene should preload the public AeroGLTFLoader facade")
	assert_true(text.contains("load_scene_instance_from_path("), "GLB scene should load through the public scene-instance API")
	assert_true(text.contains("RotationGizmoScript"), "GLB scene should use the shared rotation gizmo control")
	assert_true(text.contains("_apply_live_transform_delta("), "GLB scene should expose live transform helpers for keyboard manipulation")
	assert_true(text.contains("Save Config"), "GLB scene should expose Save Config beside the live transform controls")
	assert_false(text.contains("ResourceLoader.load("), "GLB scene should not use direct ResourceLoader.load as the primary load path")
	assert_false(text.contains("resource is PackedScene"), "GLB scene should not branch on locally loaded PackedScene resources anymore")

func test_splat_scene_routes_loading_through_public_loader_contract() -> void:
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(SPLAT_SCENE_PATH))
	assert_true(text.contains("SplatManagerScript"), "Splat scene should preload the public AeroGaussianSplatManager facade")
	assert_true(text.contains("begin_create_splat_node_from_path("), "Splat scene should begin async loads through the public wrapper API")
	assert_true(text.contains("create_splat_node_from_path("), "Splat scene should use the public synchronous compatibility API")
	assert_true(text.contains("RotationGizmoScript"), "Splat scene should use the shared rotation gizmo control")
	assert_true(text.contains("_apply_live_transform_delta("), "Splat scene should expose live transform helpers for keyboard manipulation")
	assert_false(text.contains("addons/aerobeat-vendor-gdgs"), "Splat scene should not reach into vendor GDGS paths directly")

func test_free_look_camera_only_moves_when_mouse_is_captured() -> void:
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(CAMERA_SCRIPT_PATH))
	assert_true(text.contains("if not _mouse_captured:"), "Camera movement should require explicit mouse capture so object manipulation keys stay free")

func test_glb_scene_defaults_and_sidecar_transform_roundtrip() -> void:
	var scene = GlbSceneScript.new()
	scene._ready()
	scene._current_asset_path = _temp_asset_path("models", "roundtrip.glb")

	assert_eq(scene.get_current_config_payload().get("transform", {}), {
		"position": [0.0, 0.0, 0.0],
		"rotation_degrees": [0.0, 0.0, 0.0],
		"scale": [1.0, 1.0, 1.0]
	})

	scene._set_line_edits(scene._position_edits, Vector3(1.0, 2.0, 3.0))
	scene._set_line_edits(scene._rotation_edits, Vector3(4.0, 5.0, 6.0))
	scene._set_line_edits(scene._scale_edits, Vector3(7.0, 8.0, 9.0))
	var save_result := scene.save_current_config()
	assert_true(save_result.get("ok", false), "Expected GLB sidecar save to succeed")
	assert_true(FileAccess.get_file_as_string(save_result.get("path", "")).contains("rotation_degrees:"), "GLB sidecar should persist the canonical transform YAML contract")

	var load_result := ConfigUtils.load_sidecar(scene._current_asset_path, "glb")
	assert_eq(load_result.get("config", {}).get("transform", {}), {
		"position": [1.0, 2.0, 3.0],
		"rotation_degrees": [4.0, 5.0, 6.0],
		"scale": [7.0, 8.0, 9.0]
	})

	scene._reset_transform_ui_to_defaults()
	scene._apply_loaded_config_result(load_result)
	assert_eq(scene.get_current_config_payload().get("transform", {}), {
		"position": [1.0, 2.0, 3.0],
		"rotation_degrees": [4.0, 5.0, 6.0],
		"scale": [7.0, 8.0, 9.0]
	})
	_free_node(scene)

func test_splat_scene_defaults_and_sidecar_transform_roundtrip() -> void:
	var scene = SplatSceneScript.new()
	scene._ready()
	scene._current_asset_path = _temp_asset_path("splats", "roundtrip.compressed.ply")

	assert_eq(scene.get_current_config_payload().get("transform", {}), {
		"position": [0.0, 0.0, 0.0],
		"rotation_degrees": [0.0, 0.0, 0.0],
		"scale": [1.0, 1.0, 1.0]
	})

	scene._set_line_edits(scene._position_edits, Vector3(9.0, 8.0, 7.0))
	scene._set_line_edits(scene._rotation_edits, Vector3(6.0, 5.0, 4.0))
	scene._set_line_edits(scene._scale_edits, Vector3(3.0, 2.0, 1.0))
	var save_result := scene.save_current_config()
	assert_true(save_result.get("ok", false), "Expected splat sidecar save to succeed")
	assert_true(FileAccess.get_file_as_string(save_result.get("path", "")).contains("rotation_degrees:"), "Splat sidecar should persist the canonical transform YAML contract")

	var load_result := ConfigUtils.load_sidecar(scene._current_asset_path, "splat")
	assert_eq(load_result.get("config", {}).get("transform", {}), {
		"position": [9.0, 8.0, 7.0],
		"rotation_degrees": [6.0, 5.0, 4.0],
		"scale": [3.0, 2.0, 1.0]
	})

	scene._reset_transform_ui_to_defaults()
	scene._apply_loaded_config_result(load_result)
	assert_eq(scene.get_current_config_payload().get("transform", {}), {
		"position": [9.0, 8.0, 7.0],
		"rotation_degrees": [6.0, 5.0, 4.0],
		"scale": [3.0, 2.0, 1.0]
	})
	_free_node(scene)

func test_glb_live_keyboard_transform_updates_visible_state() -> void:
	var scene = GlbSceneScript.new()
	scene._ready()
	var target := Node3D.new()
	scene._display_root.add_child(target)
	scene._loaded_instance = target

	assert_true(scene._apply_live_transform_delta(Vector3(1.0, 1.0, -1.0), 1.0, 0.5, true))
	_assert_vector3_approx(target.position, Vector3(2.309401, 2.309401, -2.309401), "GLB live move should update the target position")
	_assert_vector3_approx(target.scale, Vector3(2.5, 2.5, 2.5), "GLB live scale should update the target scale")
	_assert_vector3_approx(scene._vector3_from_edits(scene._position_edits), target.position, "GLB live move should update the visible position fields")
	_assert_vector3_approx(scene._vector3_from_edits(scene._scale_edits), target.scale, "GLB live scale should update the visible scale fields")
	_assert_vector3_approx(scene._rotation_gizmo.call("get_gizmo_rotation_degrees"), Vector3.ZERO, "GLB live transform should keep gizmo state in sync")
	_free_node(scene)

func test_splat_live_keyboard_transform_updates_visible_state() -> void:
	var scene = SplatSceneScript.new()
	scene._ready()
	var target := Node3D.new()
	scene._display_root.add_child(target)
	scene._splat_node = target

	assert_true(scene._apply_live_transform_delta(Vector3(-1.0, 1.0, 0.0), -1.0, 0.25, false))
	_assert_vector3_approx(target.position, Vector3(-0.353553, 0.353553, 0.0), "Splat live move should update the target position")
	_assert_vector3_approx(target.scale, Vector3(0.8125, 0.8125, 0.8125), "Splat live scale should update the target scale")
	_assert_vector3_approx(scene._vector3_from_edits(scene._position_edits), target.position, "Splat live move should update the visible position fields")
	_assert_vector3_approx(scene._vector3_from_edits(scene._scale_edits), target.scale, "Splat live scale should update the visible scale fields")
	_assert_vector3_approx(scene._rotation_gizmo.call("get_gizmo_rotation_degrees"), Vector3.ZERO, "Splat live transform should keep gizmo state in sync")
	_free_node(scene)

func test_glb_rotation_gizmo_updates_target_and_visible_rotation_state() -> void:
	var scene = GlbSceneScript.new()
	scene._ready()
	var target := Node3D.new()
	scene._display_root.add_child(target)
	scene._loaded_instance = target
	scene._on_rotation_gizmo_changed(Vector3(15.0, 30.0, 45.0))

	_assert_vector3_approx(target.rotation_degrees, Vector3(15.0, 30.0, 45.0), "GLB gizmo drag should update target rotation")
	_assert_vector3_approx(scene._vector3_from_edits(scene._rotation_edits), Vector3(15.0, 30.0, 45.0), "GLB gizmo drag should update visible rotation fields")
	_assert_vector3_approx(scene._rotation_gizmo.call("get_gizmo_rotation_degrees"), Vector3(15.0, 30.0, 45.0), "GLB gizmo drag should update gizmo state")
	_free_node(scene)

func test_splat_rotation_gizmo_updates_target_and_visible_rotation_state() -> void:
	var scene = SplatSceneScript.new()
	scene._ready()
	var target := Node3D.new()
	scene._display_root.add_child(target)
	scene._splat_node = target
	scene._on_rotation_gizmo_changed(Vector3(-10.0, 25.0, 90.0))

	_assert_vector3_approx(target.rotation_degrees, Vector3(-10.0, 25.0, 90.0), "Splat gizmo drag should update target rotation")
	_assert_vector3_approx(scene._vector3_from_edits(scene._rotation_edits), Vector3(-10.0, 25.0, 90.0), "Splat gizmo drag should update visible rotation fields")
	_assert_vector3_approx(scene._rotation_gizmo.call("get_gizmo_rotation_degrees"), Vector3(-10.0, 25.0, 90.0), "Splat gizmo drag should update gizmo state")
	_free_node(scene)

func test_rotation_gizmo_drag_emits_wrapped_rotation() -> void:
	var gizmo_script: Variant = RotationGizmoScript
	assert_true(gizmo_script is GDScript, "Rotation gizmo preload should resolve to a GDScript resource")
	var gizmo: Control = gizmo_script.new()
	gizmo.size = Vector2(220.0, 220.0)
	gizmo._ready()
	gizmo.call("set_gizmo_rotation_degrees", Vector3(179.0, 0.0, 0.0))

	var start := _gizmo_ring_point(gizmo, 0.82, -90.0)
	var end := _gizmo_ring_point(gizmo, 0.82, 95.0)
	gizmo._gui_input(_mouse_button_event(start, true))
	gizmo._gui_input(_mouse_motion_event(end))
	gizmo._gui_input(_mouse_button_event(end, false))

	assert_lt((gizmo.call("get_gizmo_rotation_degrees") as Vector3).x, 0.0, "Rotation gizmo should wrap through the signed degree range")
	assert_eq(gizmo.call("is_dragging"), false)
	_free_node(gizmo)

func _assert_vector3_approx(actual: Variant, expected: Vector3, message: String) -> void:
	var actual_vec: Vector3 = actual
	assert_almost_eq(actual_vec.x, expected.x, 0.0001, "%s (x)" % message)
	assert_almost_eq(actual_vec.y, expected.y, 0.0001, "%s (y)" % message)
	assert_almost_eq(actual_vec.z, expected.z, 0.0001, "%s (z)" % message)

func _mouse_button_event(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	return event

func _mouse_motion_event(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event

func _gizmo_ring_point(gizmo: Control, radius_factor: float, angle_degrees: float) -> Vector2:
	var center := gizmo.size * 0.5
	var radius := (minf(gizmo.size.x, gizmo.size.y) * 0.5 - 14.0) * radius_factor
	var angle := deg_to_rad(angle_degrees)
	return center + Vector2(cos(angle), sin(angle)) * radius

func _free_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.free()

func _temp_asset_path(bucket: String, file_name: String) -> String:
	var dir_path := ProjectSettings.globalize_path(TEMP_DIR.path_join(bucket))
	DirAccess.make_dir_recursive_absolute(dir_path)
	return dir_path.path_join(file_name)

func _cleanup_temp_dir() -> void:
	var root_path := ProjectSettings.globalize_path(TEMP_DIR)
	if not DirAccess.dir_exists_absolute(root_path):
		return
	_cleanup_dir(root_path)

func _cleanup_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry in [".", ".."]:
			continue
		var child_path := path.path_join(entry)
		if dir.current_is_dir():
			_cleanup_dir(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
