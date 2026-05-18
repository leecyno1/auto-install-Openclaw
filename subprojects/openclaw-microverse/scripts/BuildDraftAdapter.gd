extends RefCounted
class_name BuildDraftAdapter

static func clone_value(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

static func clone_build(build: Dictionary) -> Dictionary:
	var cloned: Variant = clone_value(build)
	return cloned if cloned is Dictionary else {}

static func _mark_dirty(build: Dictionary) -> Dictionary:
	build["draftDirty"] = true
	build["updatedAt"] = Time.get_datetime_string_from_system(false, true)
	return build

static func _ensure_array(container: Dictionary, key: String) -> Array:
	var value = container.get(key, [])
	return value if value is Array else []

static func _remove_value(values: Array, target: String) -> Array:
	var result: Array = []
	for entry in values:
		if String(entry) != target:
			result.append(entry)
	return result

static func set_role(build: Dictionary, role_id: String) -> Dictionary:
	var next := clone_build(build)
	next["roleId"] = role_id
	return _mark_dirty(next)

static func install_skill(build: Dictionary, skill_id: String) -> Dictionary:
	var next := clone_build(build)
	var skills := next.get("skills", {}) as Dictionary
	var installed := _ensure_array(skills, "installed")
	var disabled := _remove_value(_ensure_array(skills, "disabled"), skill_id)
	var reserve := _remove_value(_ensure_array(skills, "reserve"), skill_id)
	if not installed.has(skill_id):
		installed.append(skill_id)
	skills["installed"] = installed
	skills["disabled"] = disabled
	skills["reserve"] = reserve
	next["skills"] = skills
	return _mark_dirty(next)

static func set_skill_enabled(build: Dictionary, skill_id: String, enabled: bool) -> Dictionary:
	var next := install_skill(build, skill_id)
	var skills := next.get("skills", {}) as Dictionary
	var disabled := _ensure_array(skills, "disabled")
	if enabled:
		disabled = _remove_value(disabled, skill_id)
	else:
		if not disabled.has(skill_id):
			disabled.append(skill_id)
	skills["disabled"] = disabled
	next["skills"] = skills
	return _mark_dirty(next)

static func remove_skill(build: Dictionary, skill_id: String) -> Dictionary:
	var next := clone_build(build)
	var skills := next.get("skills", {}) as Dictionary
	var installed := _remove_value(_ensure_array(skills, "installed"), skill_id)
	var disabled := _remove_value(_ensure_array(skills, "disabled"), skill_id)
	var reserve := _ensure_array(skills, "reserve")
	if not reserve.has(skill_id):
		reserve.append(skill_id)
	skills["installed"] = installed
	skills["disabled"] = disabled
	skills["reserve"] = reserve
	next["skills"] = skills
	return _mark_dirty(next)

static func equip_item(build: Dictionary, slot_id: String, item_id: String) -> Dictionary:
	var next := clone_build(build)
	var equipment := next.get("equipment", {}) as Dictionary
	var slots := equipment.get("slots", {}) as Dictionary
	var inventory := _ensure_array(equipment, "inventory")
	var previous = String(slots.get(slot_id, ""))
	slots[slot_id] = item_id
	inventory = _remove_value(inventory, item_id)
	if previous != "" and previous != item_id and not inventory.has(previous):
		inventory.append(previous)
	equipment["slots"] = slots
	equipment["inventory"] = inventory
	next["equipment"] = equipment
	return _mark_dirty(next)
