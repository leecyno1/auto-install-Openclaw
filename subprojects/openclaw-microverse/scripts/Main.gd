extends Control

@export var home_base_scene: PackedScene
@export var shared_world_scene: PackedScene

var gateway
var store
var home_base
var shared_world
var toast: Label

func _ready() -> void:
	gateway = load("res://scripts/WorldGatewayClient.gd").new()
	gateway.name = "GatewayClient"
	add_child(gateway)

	store = load("res://scripts/WorldStateStore.gd").new()
	store.name = "WorldStateStore"
	add_child(store)

	home_base = home_base_scene.instantiate()
	shared_world = shared_world_scene.instantiate()
	add_child(home_base)
	add_child(shared_world)
	shared_world.visible = false

	toast = Label.new()
	toast.position = Vector2(18, 14)
	toast.add_theme_color_override("font_color", Color(0.95, 0.82, 0.56))
	add_child(toast)

	gateway.build_payload_ready.connect(_on_build_payload)
	gateway.runtime_payload_ready.connect(_on_runtime_payload)
	gateway.world_payload_ready.connect(_on_world_payload)
	gateway.tasks_payload_ready.connect(_on_tasks_payload)
	gateway.socket_payload.connect(_on_socket_payload)
	gateway.request_failed.connect(_on_request_failed)
	gateway.connection_changed.connect(_on_connection_changed)
	store.changed.connect(_on_store_changed)
	store.connection_changed.connect(_on_store_connection_changed)
	home_base.scene_change_requested.connect(_on_scene_change_requested)
	shared_world.return_requested.connect(_on_return_to_home)

	toast.text = "正在连接 world-gateway..."
	gateway.bootstrap()

func _on_build_payload(payload: Dictionary) -> void:
	store.set_build_payload(payload)

func _on_runtime_payload(payload: Dictionary) -> void:
	store.set_runtime_payload(payload)

func _on_world_payload(payload: Dictionary) -> void:
	store.set_world_payload(payload)

func _on_tasks_payload(payload: Dictionary) -> void:
	store.set_tasks_payload(payload)

func _on_socket_payload(message: Dictionary) -> void:
	if String(message.get("type", "")) == "world:init":
		if message.has("build"):
			store.set_build_payload({
				"build": message.get("build", {}),
				"roles": store.roles,
				"skills": store.skills,
				"equipment": store.equipment,
			})
		if message.has("runtime"):
			store.set_runtime_payload(message.get("runtime", {}))
		if message.has("world"):
			store.set_world_payload(message.get("world", {}))
		if message.has("tasks"):
			store.set_tasks_payload(message.get("tasks", []))
		return
	store.apply_socket_message(message)

func _on_request_failed(endpoint: String, status_code: int, _body: String) -> void:
	toast.text = "请求失败 %s (%s)" % [endpoint, status_code]

func _on_connection_changed(connected: bool) -> void:
	store.set_online(connected)
	toast.text = "网关在线" if connected else "网关离线，重连中..."

func _on_store_connection_changed(online: bool) -> void:
	home_base.set_gateway_online(online)

func _on_store_changed(_kind: String) -> void:
	home_base.refresh_from_store(store)
	shared_world.update_world(store.world)
	var scene_id := String(store.world.get("scene", "home-base"))
	home_base.visible = scene_id != "shared-world"
	shared_world.visible = scene_id == "shared-world"

func _on_scene_change_requested(scene_id: String) -> void:
	await gateway.set_scene(scene_id)
	await gateway.fetch_world_state()

func _on_return_to_home() -> void:
	await _on_scene_change_requested("home-base")
