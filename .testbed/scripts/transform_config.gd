class_name TransformConfigUtils
extends RefCounted

static func build_config(center: Vector3, scale_value: Vector3, rotation_value: Vector3) -> Dictionary:
	return {
		"center": _vector3_to_array(center),
		"scale": _vector3_to_array(scale_value),
		"rotation": _vector3_to_array(rotation_value)
	}

static func parse_config(data: Dictionary) -> Dictionary:
	return {
		"center": _vector3_from_variant(data.get("center", [0.0, 0.0, 0.0]), Vector3.ZERO),
		"scale": _vector3_from_variant(data.get("scale", [1.0, 1.0, 1.0]), Vector3.ONE),
		"rotation": _vector3_from_variant(data.get("rotation", [0.0, 0.0, 0.0]), Vector3.ZERO)
	}

static func save_json(path: String, data: Dictionary) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Unable to open config for write: %s" % path}
	file.store_string(JSON.stringify(data, "	") + "
")
	return {"ok": true, "path": path}

static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "message": "Config file does not exist: %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "Unable to open config: %s" % path}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "message": "Config JSON must decode to a dictionary"}
	return {"ok": true, "config": parse_config(parsed)}

static func _vector3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _vector3_from_variant(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)), float(value.get("z", fallback.z)))
	return fallback
