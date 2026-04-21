extends Node
class_name WorldStateStore

signal changed(kind: String)
signal connection_changed(online: bool)

var build: Dictionary = {}
var roles: Array = []
var skills: Dictionary = {"installed": [], "reserve": []}
var equipment: Dictionary = {"equipped": [], "inventory": []}
var runtime: Dictionary = {}
var world: Dictionary = {}
var tasks: Array = []
var online := false

func set_build_payload(payload: Dictionary) -> void:
	build = payload.get("build", {}) as Dictionary
	roles = payload.get("roles", roles) as Array
	skills = payload.get("skills", skills) as Dictionary
	equipment = payload.get("equipment", equipment) as Dictionary
	emit_signal("changed", "build")

func set_runtime_payload(payload: Dictionary) -> void:
	runtime = payload.get("runtime", payload) as Dictionary
	emit_signal("changed", "runtime")

func set_world_payload(payload: Dictionary) -> void:
	world = payload.get("world", payload) as Dictionary
	emit_signal("changed", "world")

func set_tasks_payload(payload: Variant) -> void:
	if payload is Dictionary:
		tasks = payload.get("tasks", []) as Array
	elif payload is Array:
		tasks = payload as Array
	else:
		tasks = []
	emit_signal("changed", "tasks")

func apply_socket_message(message: Dictionary) -> void:
	if message.has("build"):
		build = message.get("build", build)
	if message.has("runtime"):
		runtime = message.get("runtime", runtime)
	if message.has("world"):
		world = message.get("world", world)
	if message.has("tasks"):
		tasks = message.get("tasks", tasks)
	emit_signal("changed", String(message.get("reason", message.get("type", "socket"))))

func set_online(value: bool) -> void:
	if online == value:
		return
	online = value
	emit_signal("connection_changed", online)
