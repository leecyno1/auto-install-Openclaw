extends Control
class_name SharedWorldController

signal return_requested

var _message_label: RichTextLabel

func _ready() -> void:
	layout_mode = 3
	anchors_preset = 15
	anchor_right = 1.0
	anchor_bottom = 1.0
	var background := ColorRect.new()
	background.color = Color(0.05, 0.08, 0.12)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var panel := PanelContainer.new()
	panel.size = Vector2(720, 380)
	panel.position = Vector2(440, 180)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Shared World"
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)

	_message_label = RichTextLabel.new()
	_message_label.fit_content = true
	_message_label.bbcode_enabled = true
	_message_label.scroll_active = false
	_message_label.text = "公共世界正在搭骨架。当前阶段只保留入口与返回闭环。"
	column.add_child(_message_label)

	var return_button := Button.new()
	return_button.text = "返回 Home Base"
	return_button.pressed.connect(_on_return_pressed)
	column.add_child(return_button)

func update_world(world: Dictionary) -> void:
	var shared := world.get("sharedWorld", {}) as Dictionary
	_message_label.text = String(shared.get("message", "公共世界入口已准备。"))

func _on_return_pressed() -> void:
	emit_signal("return_requested")
