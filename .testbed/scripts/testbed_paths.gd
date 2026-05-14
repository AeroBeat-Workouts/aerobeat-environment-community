class_name EnvironmentTestbedPaths
extends RefCounted

const IMAGES_DIR := "res://assets/images"
const VIDEOS_DIR := "res://assets/videos"
const MODELS_DIR := "res://assets/models"
const SPLATS_DIR := "res://assets/splats"

static func global_dir_for_res(res_dir: String) -> String:
	return ProjectSettings.globalize_path(res_dir)

static func default_global_dir(kind: String) -> String:
	match kind:
		"images":
			return global_dir_for_res(IMAGES_DIR)
		"videos":
			return global_dir_for_res(VIDEOS_DIR)
		"models":
			return global_dir_for_res(MODELS_DIR)
		"splats":
			return global_dir_for_res(SPLATS_DIR)
		_:
			return ProjectSettings.globalize_path("res://")

static func sidecar_path_for(asset_path: String) -> String:
	var basename := asset_path.get_basename()
	return "%s.json" % basename

static func localize_if_possible(global_path: String) -> String:
	var localized := ProjectSettings.localize_path(global_path)
	if localized.begins_with("res://"):
		return localized
	return global_path
