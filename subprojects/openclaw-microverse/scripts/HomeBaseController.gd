extends Control
class_name HomeBaseController

const BuildDraftAdapterScript = preload("res://scripts/BuildDraftAdapter.gd")
const AvatarControllerScript = preload("res://scripts/AvatarController.gd")

signal scene_change_requested(scene_id: String)

const STATION_ORDER := [
	"role-altar",
	"skill-shelf",
	"equipment-forge",
	"task-desk",
	"status-mirror",
	"world-portal",
]
const SLOT_ORDER := ["head", "amulet", "mainhand", "offhand", "chest", "belt", "boots"]

var _gateway
var _store
var _draft: Dictionary = {}
var _current_station := "role-altar"
var _station_buttons: Dictionary = {}
var _station_points: Dictionary = {}
var _avatar
var _panel_title: Label
var _summary_label: RichTextLabel
var _content_box: VBoxContainer
var _task_input: LineEdit
var _status_line: Label
var _online_badge: Label

func _ready() -> void:
	_gateway = get_parent().get_node("GatewayClient")
	_store = get_parent().get_node("WorldStateStore")
	_build_layout()

func set_gateway_online(online: bool) -> void:
	_online_badge.text = "Gateway Online" if online else "Gateway Offline"
	_online_badge.modulate = Color(0.58, 0.94, 0.68) if online else Color(0.93, 0.49, 0.49)

func refresh_from_store(store) -> void:
	if not store.build.is_empty() and (_draft.is_empty() or not bool(_draft.get("draftDirty", false))):
		_draft = BuildDraftAdapterScript.clone_build(store.build)
	var station_from_store := String(store.world.get("personaPanelStation", _current_station))
	if station_from_store != _current_station:
		_set_station_local(station_from_store)
	var runtime: Dictionary = store.runtime
	var role_id := String(_effective_build().get("roleId", "druid"))
	_avatar.set_role(role_id)
	_avatar.play_state(String(runtime.get("state", "idle")))
	_avatar.move_to_station(String(runtime.get("stationId", _current_station)))
	_render_summary(store)
	_render_station_panel()

func _effective_build() -> Dictionary:
	return _draft if not _draft.is_empty() else _store.build

func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var world_panel := PanelContainer.new()
	world_panel.position = Vector2(18, 18)
	world_panel.size = Vector2(980, 864)
	add_child(world_panel)

	var world := Control.new()
	world.custom_minimum_size = world_panel.size
	world_panel.add_child(world)

	var floor := TextureRect.new()
	floor.texture = _load_texture("res://assets/maps/interiors/Generic_Home_1_Layer_1_32x32.png")
	floor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor.stretch_mode = TextureRect.STRETCH_SCALE
	floor.set_anchors_preset(Control.PRESET_FULL_RECT)
	world.add_child(floor)

	var overlay := ColorRect.new()
	overlay.color = Color(0.07, 0.12, 0.18, 0.24)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	world.add_child(overlay)

	var header := Label.new()
	header.text = "OpenClaw Home Base"
	header.position = Vector2(30, 18)
	header.add_theme_font_size_override("font_size", 28)
	world.add_child(header)

	_online_badge = Label.new()
	_online_badge.position = Vector2(760, 24)
	world.add_child(_online_badge)
	set_gateway_online(false)

	_station_points = {
		"role-altar": Vector2(190, 255),
		"skill-shelf": Vector2(748, 230),
		"equipment-forge": Vector2(770, 610),
		"task-desk": Vector2(470, 440),
		"status-mirror": Vector2(260, 650),
		"world-portal": Vector2(470, 145),
	}

	for station_id in STATION_ORDER:
		var button := Button.new()
		button.text = _station_title(station_id)
		button.position = _station_button_position(station_id)
		button.size = Vector2(170, 60)
		button.toggle_mode = true
		button.pressed.connect(_on_station_button_pressed.bind(station_id))
		world.add_child(button)
		_station_buttons[station_id] = button

	_avatar = AvatarControllerScript.new()
	_avatar.position = Vector2(430, 615)
	_avatar.set_station_positions(_station_points)
	world.add_child(_avatar)

	var side_panel := PanelContainer.new()
	side_panel.position = Vector2(1016, 18)
	side_panel.size = Vector2(566, 864)
	add_child(side_panel)

	var side_margin := MarginContainer.new()
	side_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	side_margin.add_theme_constant_override("margin_left", 18)
	side_margin.add_theme_constant_override("margin_top", 16)
	side_margin.add_theme_constant_override("margin_right", 18)
	side_margin.add_theme_constant_override("margin_bottom", 16)
	side_panel.add_child(side_margin)

	var side_column := VBoxContainer.new()
	side_column.add_theme_constant_override("separation", 12)
	side_margin.add_child(side_column)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	side_column.add_child(top_row)

	_panel_title = Label.new()
	_panel_title.text = "职业台"
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_title.add_theme_font_size_override("font_size", 24)
	top_row.add_child(_panel_title)

	var save_button := Button.new()
	save_button.text = "保存草稿"
	save_button.pressed.connect(_save_draft)
	top_row.add_child(save_button)

	var apply_button := Button.new()
	apply_button.text = "应用到 OpenClaw"
	apply_button.pressed.connect(_apply_build)
	top_row.add_child(apply_button)

	_summary_label = RichTextLabel.new()
	_summary_label.custom_minimum_size = Vector2(0, 150)
	_summary_label.scroll_active = false
	_summary_label.fit_content = false
	_summary_label.bbcode_enabled = true
	side_column.add_child(_summary_label)

	_content_box = VBoxContainer.new()
	_content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 10)
	side_column.add_child(_content_box)

	_status_line = Label.new()
	_status_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_column.add_child(_status_line)

	_set_station_local(_current_station)

func _render_summary(store) -> void:
	var build := _effective_build()
	var runtime: Dictionary = store.runtime
	var metrics := runtime.get("metrics", {}) as Dictionary
	var build_skills := build.get("skills", {}) as Dictionary
	var disabled := build_skills.get("disabled", []) as Array
	var installed := build_skills.get("installed", []) as Array
	_summary_label.text = "[b]角色[/b] %s\n[b]状态[/b] %s\n[b]规则[/b] %s / %s\n[b]技能[/b] %s 已装 / %s 停用\n[b]任务[/b] %s 完成，成功率 %s%%\n[b]经验[/b] Lv.%s · XP %s · 在线 %s 分钟" % [
		_role_title(String(build.get("roleId", "druid"))),
		String(runtime.get("detail", "基地待命中")),
		String((build.get("routing", {}) as Dictionary).get("modelRoute", "balanced")),
		String((build.get("routing", {}) as Dictionary).get("advancedModel", "未配置")),
		installed.size(),
		disabled.size(),
		String(metrics.get("tasksCompleted", 0)),
		String(metrics.get("taskSuccessRate", 0)),
		String(metrics.get("level", 1)),
		String(metrics.get("xp", 0)),
		String(metrics.get("onlineMinutes", 0)),
	]

func _render_station_panel() -> void:
	for child in _content_box.get_children():
		child.queue_free()
	_panel_title.text = _station_title(_current_station)
	match _current_station:
		"role-altar":
			_render_role_station()
		"skill-shelf":
			_render_skill_station()
		"equipment-forge":
			_render_equipment_station()
		"task-desk":
			_render_task_station()
		"status-mirror":
			_render_status_station()
		"world-portal":
			_render_world_station()
		_:
			_render_status_station()

func _render_role_station() -> void:
	var label := Label.new()
	label.text = "确认转职前只改草稿，不直接写入 OpenClaw。"
	_content_box.add_child(label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content_box.add_child(grid)
	for role in _store.roles:
		var role_dict := role as Dictionary
		var button := Button.new()
		button.text = "%s\n%s" % [String(role_dict.get("title", "未知职业")), String(role_dict.get("className", ""))]
		button.custom_minimum_size = Vector2(0, 92)
		button.toggle_mode = true
		button.button_pressed = String(_effective_build().get("roleId", "druid")) == String(role_dict.get("id", ""))
		button.pressed.connect(_on_role_selected.bind(String(role_dict.get("id", "druid"))))
		grid.add_child(button)

func _render_skill_station() -> void:
	var build := _effective_build()
	var build_skills := build.get("skills", {}) as Dictionary
	var draft_installed_ids := build_skills.get("installed", []) as Array
	var disabled := build_skills.get("disabled", []) as Array
	var catalog: Dictionary = {}
	for item in (_store.skills.get("installed", []) as Array):
		catalog[String((item as Dictionary).get("id", ""))] = item
	for item in (_store.skills.get("reserve", []) as Array):
		catalog[String((item as Dictionary).get("id", ""))] = item

	var installed_label := Label.new()
	installed_label.text = "已装技能"
	_content_box.add_child(installed_label)
	var installed_box := VBoxContainer.new()
	installed_box.add_theme_constant_override("separation", 6)
	_content_box.add_child(installed_box)
	for skill_id_value in draft_installed_ids:
		var skill_id := String(skill_id_value)
		var skill := catalog.get(skill_id, {"id": skill_id, "name": skill_id, "description": "本地技能"}) as Dictionary
		var row := HBoxContainer.new()
		var name := Label.new()
		name.text = "%s: %s" % [String(skill.get("name", skill_id)), String(skill.get("description", ""))]
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var toggle := Button.new()
		var currently_disabled := disabled.has(skill_id)
		toggle.text = "已停用" if currently_disabled else "已启用"
		toggle.modulate = Color(0.92, 0.47, 0.47) if currently_disabled else Color(0.44, 0.9, 0.58)
		toggle.pressed.connect(_on_skill_toggle_pressed.bind(skill_id, currently_disabled))
		var remove_button := Button.new()
		remove_button.text = "移除"
		remove_button.pressed.connect(_on_skill_remove_pressed.bind(skill_id))
		row.add_child(name)
		row.add_child(toggle)
		row.add_child(remove_button)
		installed_box.add_child(row)

	var reserve_label := Label.new()
	reserve_label.text = "备选技能库"
	_content_box.add_child(reserve_label)
	var reserve_grid := GridContainer.new()
	reserve_grid.columns = 2
	reserve_grid.add_theme_constant_override("h_separation", 6)
	reserve_grid.add_theme_constant_override("v_separation", 6)
	_content_box.add_child(reserve_grid)
	for item in (_store.skills.get("reserve", []) as Array):
		var skill := item as Dictionary
		var skill_id := String(skill.get("id", ""))
		if draft_installed_ids.has(skill_id):
			continue
		var card := VBoxContainer.new()
		var title := Label.new()
		title.text = String(skill.get("name", skill_id))
		var desc := Label.new()
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.text = String(skill.get("description", ""))
		var add_button := Button.new()
		add_button.text = "添加"
		add_button.pressed.connect(_on_skill_add_pressed.bind(skill_id))
		card.add_child(title)
		card.add_child(desc)
		card.add_child(add_button)
		reserve_grid.add_child(card)

func _render_equipment_station() -> void:
	var info := Label.new()
	info.text = "装备只改草稿。保存后才回写到 OpenClaw。"
	_content_box.add_child(info)
	var all_items: Array = []
	all_items.append_array(_store.equipment.get("equipped", []) as Array)
	all_items.append_array(_store.equipment.get("inventory", []) as Array)
	var grouped := {}
	for item in all_items:
		var item_dict := item as Dictionary
		var slot_id := String(item_dict.get("slot", ""))
		if not grouped.has(slot_id):
			grouped[slot_id] = []
		(grouped[slot_id] as Array).append(item_dict)
	var slots := (_effective_build().get("equipment", {}).get("slots", {}) as Dictionary)
	for slot_id in SLOT_ORDER:
		var row := HBoxContainer.new()
		var name := Label.new()
		name.text = slot_id
		name.custom_minimum_size = Vector2(72, 0)
		var options := OptionButton.new()
		options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot_items := grouped.get(slot_id, []) as Array
		var current_item := String(slots.get(slot_id, ""))
		var selected_index := 0
		for index in slot_items.size():
			var item := slot_items[index] as Dictionary
			options.add_item(String(item.get("name", item.get("id", "未知"))), index)
			options.set_item_metadata(index, item.get("id", ""))
			if String(item.get("id", "")) == current_item:
				selected_index = index
		options.selected = selected_index
		options.item_selected.connect(_on_equipment_selected.bind(slot_id, options))
		row.add_child(name)
		row.add_child(options)
		_content_box.add_child(row)

func _render_task_station() -> void:
	var title := Label.new()
	title.text = "派单会直接走 world-gateway -> OpenClaw 适配层。"
	_content_box.add_child(title)
	_task_input = LineEdit.new()
	_task_input.placeholder_text = "例如：整理本周投研纪要并生成执行建议"
	_content_box.add_child(_task_input)
	var submit := Button.new()
	submit.text = "派发任务"
	submit.pressed.connect(_dispatch_task)
	_content_box.add_child(submit)
	var latest := Label.new()
	latest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	latest.text = "最近结果: %s" % String(_store.runtime.get("lastResult", "暂无任务结果"))
	_content_box.add_child(latest)

func _render_status_station() -> void:
	var metrics := _store.runtime.get("metrics", {}) as Dictionary
	for line in [
		"当前状态: %s" % String(_store.runtime.get("detail", "基地待命中")),
		"Token 消耗: %s" % String(metrics.get("tokenConsumption", 0)),
		"技能使用率: %s%%" % String(metrics.get("skillUsageRate", 0)),
		"任务成功数: %s" % String(metrics.get("tasksSucceeded", 0)),
		"总完成数: %s" % String(metrics.get("tasksCompleted", 0)),
		"在线分钟: %s" % String(metrics.get("onlineMinutes", 0)),
	]:
		var label := Label.new()
		label.text = line
		_content_box.add_child(label)

func _render_world_station() -> void:
	var message := Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.text = String((_store.world.get("sharedWorld", {}) as Dictionary).get("message", "公共世界壳体已准备。"))
	_content_box.add_child(message)
	var button := Button.new()
	button.text = "进入 Shared World"
	button.pressed.connect(_on_shared_world_pressed)
	_content_box.add_child(button)

func _set_station_local(station_id: String) -> void:
	_current_station = station_id
	for key in _station_buttons.keys():
		(_station_buttons[key] as Button).button_pressed = key == station_id
	_status_line.text = _station_hint(station_id)
	_render_station_panel()

func _open_station(station_id: String, notify_gateway: bool = true) -> void:
	_set_station_local(station_id)
	if notify_gateway:
		await _gateway.set_station(station_id)

func _save_draft() -> void:
	if _draft.is_empty():
		return
	var response: Dictionary = await _gateway.save_build_draft(_draft)
	if response.get("ok", false):
		_status_line.text = "草稿已保存到 world-gateway。"
		if response.has("build"):
			_draft = BuildDraftAdapterScript.clone_build(response.get("build", {}))
	else:
		_status_line.text = "草稿保存失败。"

func _apply_build() -> void:
	var response: Dictionary = await _gateway.apply_build()
	if response.get("ok", false):
		_status_line.text = "构筑已应用到 OpenClaw。"
	else:
		_status_line.text = "应用失败。"

func _dispatch_task() -> void:
	var prompt := _task_input.text.strip_edges()
	if prompt == "":
		_status_line.text = "请输入任务内容。"
		return
	var response: Dictionary = await _gateway.dispatch_task(prompt)
	if response.get("ok", false):
		_task_input.text = ""
		_status_line.text = "任务已进入派发队列。"
	else:
		_status_line.text = "派发失败。"

func _station_title(station_id: String) -> String:
	match station_id:
		"role-altar": return "职业台"
		"skill-shelf": return "技能书架"
		"equipment-forge": return "装备工坊"
		"task-desk": return "任务桌"
		"status-mirror": return "状态镜"
		"world-portal": return "世界传送门"
		_: return station_id

func _station_hint(station_id: String) -> String:
	match station_id:
		"role-altar": return "查看七个职业并确认转职。"
		"skill-shelf": return "启停、移除或补装技能。"
		"equipment-forge": return "切换模型、API、MCP 和工具位。"
		"task-desk": return "派单并观察角色动作反馈。"
		"status-mirror": return "查看成长、任务和运行指标。"
		"world-portal": return "公共世界当前只保留场景壳。"
		_: return ""

func _station_button_position(station_id: String) -> Vector2:
	match station_id:
		"role-altar": return Vector2(86, 198)
		"skill-shelf": return Vector2(720, 176)
		"equipment-forge": return Vector2(694, 560)
		"task-desk": return Vector2(380, 392)
		"status-mirror": return Vector2(144, 602)
		"world-portal": return Vector2(382, 78)
		_: return Vector2.ZERO

func _role_title(role_id: String) -> String:
	for role in _store.roles:
		var role_dict := role as Dictionary
		if String(role_dict.get("id", "")) == role_id:
			return String(role_dict.get("title", role_id))
	return role_id

func _on_station_button_pressed(station_id: String) -> void:
	await _open_station(station_id)

func _on_role_selected(role_id: String) -> void:
	_draft = BuildDraftAdapterScript.set_role(_effective_build(), role_id)
	_render_summary(_store)
	_render_station_panel()

func _on_skill_toggle_pressed(skill_id: String, currently_disabled: bool) -> void:
	_draft = BuildDraftAdapterScript.set_skill_enabled(_effective_build(), skill_id, currently_disabled)
	_render_summary(_store)
	_render_station_panel()

func _on_skill_remove_pressed(skill_id: String) -> void:
	_draft = BuildDraftAdapterScript.remove_skill(_effective_build(), skill_id)
	_render_summary(_store)
	_render_station_panel()

func _on_skill_add_pressed(skill_id: String) -> void:
	_draft = BuildDraftAdapterScript.install_skill(_effective_build(), skill_id)
	_render_summary(_store)
	_render_station_panel()

func _on_equipment_selected(index: int, slot_id: String, options: OptionButton) -> void:
	_draft = BuildDraftAdapterScript.equip_item(_effective_build(), slot_id, String(options.get_item_metadata(index)))
	_render_summary(_store)

func _on_shared_world_pressed() -> void:
	emit_signal("scene_change_requested", "shared-world")

func _load_texture(resource_path: String) -> Texture2D:
	var image := Image.load_from_file(ProjectSettings.globalize_path(resource_path))
	if image == null or image.is_empty():
		var fallback := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		fallback.fill(Color(0.4, 0.1, 0.1, 1))
		return ImageTexture.create_from_image(fallback)
	return ImageTexture.create_from_image(image)
