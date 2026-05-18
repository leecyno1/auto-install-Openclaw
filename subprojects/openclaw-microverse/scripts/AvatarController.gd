extends Node2D
class_name AvatarController

const FRAME_WIDTH := 32
const FRAME_HEIGHT := 64
const IDLE_ROW_Y := 64
const RUN_ROW_Y := 128
const RIGHT_START_X := 0
const LEFT_START_X := 384
const DOWN_START_X := 576
const UP_START_X := 192

var _sprite: AnimatedSprite2D
var _label: Label
var _body_texture: Texture2D
var _stations: Dictionary = {}
var _role_textures := {
	"druid": "res://assets/characters/body/Jackx32.png",
	"assassin": "res://assets/characters/body/Joex32.png",
	"mage": "res://assets/characters/body/Stephenx32.png",
	"summoner": "res://assets/characters/body/Monicax32.png",
	"warrior": "res://assets/characters/body/Tomx32.png",
	"paladin": "res://assets/characters/body/Gracex32.png",
	"designer": "res://assets/characters/body/Alicex32.png",
}

func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.scale = Vector2(3.0, 3.0)
	add_child(_sprite)
	_label = Label.new()
	_label.position = Vector2(-58, -126)
	_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66))
	add_child(_label)
	set_role("druid")
	play_state("idle")

func set_station_positions(stations: Dictionary) -> void:
	_stations = stations

func set_role(role_id: String) -> void:
	var texture_path := String(_role_textures.get(role_id, _role_textures["druid"]))
	_body_texture = _load_texture(texture_path)
	_sprite.sprite_frames = _build_frames(_body_texture)
	_sprite.play("idle_down")

func play_state(state_id: String) -> void:
	match state_id:
		"researching":
			_sprite.play("run_left")
			_label.text = "研究中"
		"executing":
			_sprite.play("run_down")
			_label.text = "执行中"
		"syncing":
			_sprite.play("idle_up")
			_label.text = "同步中"
		"error":
			_sprite.play("idle_right")
			_label.text = "告警"
		_:
			_sprite.play("idle_down")
			_label.text = "待命"

func move_to_station(station_id: String) -> void:
	if not _stations.has(station_id):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", _stations[station_id], 0.6)

func _build_frames(texture: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	_add_row(frames, texture, "idle_right", RIGHT_START_X, IDLE_ROW_Y, 5.0)
	_add_row(frames, texture, "idle_left", LEFT_START_X, IDLE_ROW_Y, 5.0)
	_add_row(frames, texture, "idle_down", DOWN_START_X, IDLE_ROW_Y, 5.0)
	_add_row(frames, texture, "idle_up", UP_START_X, IDLE_ROW_Y, 5.0)
	_add_row(frames, texture, "run_right", RIGHT_START_X, RUN_ROW_Y, 9.0)
	_add_row(frames, texture, "run_left", LEFT_START_X, RUN_ROW_Y, 9.0)
	_add_row(frames, texture, "run_down", DOWN_START_X, RUN_ROW_Y, 9.0)
	_add_row(frames, texture, "run_up", UP_START_X, RUN_ROW_Y, 9.0)
	return frames

func _add_row(frames: SpriteFrames, texture: Texture2D, animation_name: String, start_x: int, start_y: int, fps: float) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, true)
	frames.set_animation_speed(animation_name, fps)
	for frame_index in 6:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(start_x + frame_index * FRAME_WIDTH, start_y, FRAME_WIDTH, FRAME_HEIGHT)
		frames.add_frame(animation_name, atlas)

func _load_texture(resource_path: String) -> Texture2D:
	var image := Image.load_from_file(ProjectSettings.globalize_path(resource_path))
	if image == null or image.is_empty():
		var fallback := Image.create(FRAME_WIDTH, FRAME_HEIGHT, false, Image.FORMAT_RGBA8)
		fallback.fill(Color(1, 0, 1, 1))
		return ImageTexture.create_from_image(fallback)
	return ImageTexture.create_from_image(image)
