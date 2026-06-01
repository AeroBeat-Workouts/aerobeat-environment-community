class_name TestbedSidecarConfigUtils
extends RefCounted

const FIT_MODE_STRETCH := "stretch"
const FIT_MODE_CONTAIN := "contain"
const FIT_MODE_COVER := "cover"
const FIT_MODES := [FIT_MODE_STRETCH, FIT_MODE_CONTAIN, FIT_MODE_COVER]
const DEFAULT_FIT_MODE := FIT_MODE_COVER

static func build_media_config(fit_mode: Variant) -> Dictionary:
	return {
		"media": {
			"fit_mode": _normalize_fit_mode(fit_mode)
		}
	}

static func normalize_media_config(data: Dictionary) -> Dictionary:
	var media := _dictionary_or_empty(data.get("media", {}))
	if media.is_empty() and data.has("fit_mode"):
		media["fit_mode"] = data.get("fit_mode", DEFAULT_FIT_MODE)
	return build_media_config(media.get("fit_mode", DEFAULT_FIT_MODE))

static func build_transform_config(position: Vector3, rotation_degrees: Vector3, scale_value: Vector3) -> Dictionary:
	return {
		"transform": {
			"position": _vector3_to_array(position),
			"rotation_degrees": _vector3_to_array(rotation_degrees),
			"scale": _vector3_to_array(scale_value)
		}
	}

static func normalize_transform_config(data: Dictionary) -> Dictionary:
	var transform := _dictionary_or_empty(data.get("transform", {}))
	if transform.is_empty():
		if data.has("position"):
			transform["position"] = data.get("position")
		elif data.has("center"):
			transform["position"] = data.get("center")
		if data.has("rotation_degrees"):
			transform["rotation_degrees"] = data.get("rotation_degrees")
		elif data.has("rotation"):
			transform["rotation_degrees"] = data.get("rotation")
		if data.has("scale"):
			transform["scale"] = data.get("scale")
	if not transform.has("position") and data.has("center"):
		transform["position"] = data.get("center")
	if not transform.has("rotation_degrees"):
		if transform.has("rotation"):
			transform["rotation_degrees"] = transform.get("rotation")
		elif data.has("rotation"):
			transform["rotation_degrees"] = data.get("rotation")
	if not transform.has("scale") and data.has("scale"):
		transform["scale"] = data.get("scale")
	return build_transform_config(
		_vector3_from_variant(transform.get("position", Vector3.ZERO), Vector3.ZERO),
		_vector3_from_variant(transform.get("rotation_degrees", Vector3.ZERO), Vector3.ZERO),
		_vector3_from_variant(transform.get("scale", Vector3.ONE), Vector3.ONE)
	)

static func normalize_config(kind: String, data: Dictionary) -> Dictionary:
	match kind.strip_edges().to_lower():
		"image", "video":
			return normalize_media_config(data)
		"glb", "splat":
			return normalize_transform_config(data)
		_:
			return data.duplicate(true)

static func save_yaml(path: String, data: Dictionary) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Unable to open config for write: %s" % path, "path": path}
	file.store_string(_to_yaml(data))
	return {"ok": true, "path": path}

static func load_yaml(path: String, kind: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "has_config": false, "path": path, "config": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "Unable to open config: %s" % path, "path": path}
	var parsed := _parse_yaml(file.get_as_text())
	if not parsed.get("ok", false):
		parsed["path"] = path
		return parsed
	return {
		"ok": true,
		"has_config": true,
		"path": path,
		"config": normalize_config(kind, parsed.get("data", {}))
	}

static func save_sidecar(asset_path: String, kind: String, data: Dictionary) -> Dictionary:
	if asset_path.is_empty():
		return {"ok": false, "message": "Cannot save config without an asset path.", "path": ""}
	var sidecar_path := EnvironmentTestbedPaths.sidecar_path_for(asset_path)
	return save_yaml(sidecar_path, normalize_config(kind, data))

static func load_sidecar(asset_path: String, kind: String) -> Dictionary:
	if asset_path.is_empty():
		return {"ok": true, "has_config": false, "path": "", "config": {}}
	return load_yaml(EnvironmentTestbedPaths.sidecar_path_for(asset_path), kind)

static func _to_yaml(data: Dictionary) -> String:
	var lines: Array[String] = []
	_append_yaml_dictionary(lines, data, 0)
	return "\n".join(lines) + "\n"

static func _append_yaml_dictionary(lines: Array[String], data: Dictionary, indent: int) -> void:
	for key in data.keys():
		var value: Variant = data[key]
		var prefix := "%s%s:" % [" ".repeat(indent), String(key)]
		if value is Dictionary:
			lines.append(prefix)
			_append_yaml_dictionary(lines, value, indent + 2)
		else:
			lines.append("%s %s" % [prefix, _yaml_scalar_to_string(value)])

static func _yaml_scalar_to_string(value: Variant) -> String:
	if value is Array:
		var parts: Array[String] = []
		for entry in value:
			parts.append(_yaml_array_value_to_string(entry))
		return "[%s]" % ", ".join(parts)
	if value is String:
		var text := String(value)
		if text.is_empty() or text.contains(" ") or text.contains(":"):
			return JSON.stringify(text)
		return text
	return str(value)

static func _yaml_array_value_to_string(value: Variant) -> String:
	if value is String:
		return JSON.stringify(String(value))
	return str(value)

static func _parse_yaml(text: String) -> Dictionary:
	var root: Dictionary = {}
	var stack: Array = [root]
	var indents: Array[int] = [-1]
	for raw_line in text.split("\n"):
		var stripped := raw_line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		var indent := _leading_spaces(raw_line)
		while stack.size() > 1 and indent <= indents[indents.size() - 1]:
			stack.pop_back()
			indents.pop_back()
		var colon_index := stripped.find(":")
		if colon_index == -1:
			return {"ok": false, "message": "Invalid YAML line: %s" % stripped}
		var key := stripped.substr(0, colon_index).strip_edges()
		var value_text := stripped.substr(colon_index + 1).strip_edges()
		var current: Dictionary = stack[stack.size() - 1]
		if value_text.is_empty():
			var child: Dictionary = {}
			current[key] = child
			stack.append(child)
			indents.append(indent)
		else:
			current[key] = _parse_yaml_scalar(value_text)
	return {"ok": true, "data": root}

static func _parse_yaml_scalar(value_text: String) -> Variant:
	if value_text.begins_with("[") and value_text.ends_with("]"):
		return _parse_yaml_array(value_text)
	if value_text.begins_with("\"") and value_text.ends_with("\""):
		var parsed_string: Variant = JSON.parse_string(value_text)
		return String(parsed_string)
	if value_text == "true":
		return true
	if value_text == "false":
		return false
	if value_text.is_valid_float():
		return float(value_text)
	return value_text

static func _parse_yaml_array(value_text: String) -> Array:
	var body := value_text.substr(1, value_text.length() - 2).strip_edges()
	if body.is_empty():
		return []
	var values: Array = []
	for part in body.split(","):
		values.append(_parse_yaml_scalar(part.strip_edges()))
	return values

static func _leading_spaces(text: String) -> int:
	var count := 0
	while count < text.length() and text[count] == " ":
		count += 1
	return count

static func _vector3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _vector3_from_variant(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)), float(value.get("z", fallback.z)))
	return fallback

static func _normalize_fit_mode(value: Variant) -> String:
	var normalized := String(value).strip_edges().to_lower()
	return normalized if FIT_MODES.has(normalized) else DEFAULT_FIT_MODE

static func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return Dictionary(value).duplicate(true)
	return {}
