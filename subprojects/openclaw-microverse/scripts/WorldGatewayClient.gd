extends Node
class_name WorldGatewayClient

signal build_payload_ready(payload: Dictionary)
signal runtime_payload_ready(payload: Dictionary)
signal world_payload_ready(payload: Dictionary)
signal tasks_payload_ready(payload: Dictionary)
signal socket_payload(message: Dictionary)
signal request_failed(endpoint: String, status_code: int, body: String)
signal connection_changed(connected: bool)

@export var base_url := ""
@export var auto_bootstrap := true

var _socket := WebSocketPeer.new()
var _socket_connected := false
var _retry_seconds := 3.0
var _time_until_retry := 0.0
var _resolved_base_url := ""

func _ready() -> void:
	_resolved_base_url = _compute_base_url()
	set_process(true)
	if auto_bootstrap:
		call_deferred("bootstrap")

func bootstrap() -> void:
	await fetch_build()
	await fetch_runtime()
	await fetch_world_state()
	await fetch_tasks()
	connect_socket()

func request_json(endpoint: String, method: int = HTTPClient.METHOD_GET, payload: Variant = null) -> Dictionary:
	var request := HTTPRequest.new()
	add_child(request)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var body := ""
	if payload != null:
		body = JSON.stringify(payload)
	var err := request.request(_resolved_base_url + endpoint, headers, method, body)
	if err != OK:
		request.queue_free()
		emit_signal("request_failed", endpoint, err, "request-start-failed")
		return {"ok": false, "_status": err, "_body": ""}
	var result = await request.request_completed
	request.queue_free()
	var status_code: int = result[1]
	var response_body: String = PackedByteArray(result[3]).get_string_from_utf8()
	var parsed = JSON.parse_string(response_body)
	var response: Dictionary = parsed if parsed is Dictionary else {}
	response["_status"] = status_code
	response["_body"] = response_body
	if status_code < 200 or status_code >= 300:
		emit_signal("request_failed", endpoint, status_code, response_body)
	return response

func fetch_build() -> Dictionary:
	var response := await request_json("/api/build")
	emit_signal("build_payload_ready", response)
	return response

func fetch_runtime() -> Dictionary:
	var response := await request_json("/api/runtime")
	emit_signal("runtime_payload_ready", response)
	return response

func fetch_world_state() -> Dictionary:
	var response := await request_json("/api/world/state")
	emit_signal("world_payload_ready", response)
	return response

func fetch_tasks() -> Dictionary:
	var response := await request_json("/api/tasks")
	emit_signal("tasks_payload_ready", response)
	return response

func save_build_draft(build: Dictionary) -> Dictionary:
	var response := await request_json("/api/build", HTTPClient.METHOD_PUT, build)
	emit_signal("build_payload_ready", response)
	return response

func apply_build() -> Dictionary:
	var response := await request_json("/api/build/apply", HTTPClient.METHOD_POST, {})
	emit_signal("build_payload_ready", response)
	return response

func dispatch_task(prompt: String) -> Dictionary:
	var response := await request_json("/api/tasks", HTTPClient.METHOD_POST, {"prompt": prompt})
	emit_signal("tasks_payload_ready", response)
	return response

func set_station(station_id: String) -> Dictionary:
	return await request_json("/api/world/station", HTTPClient.METHOD_POST, {"stationId": station_id})

func set_scene(scene_id: String) -> Dictionary:
	return await request_json("/api/world/scene", HTTPClient.METHOD_POST, {"scene": scene_id})

func connect_socket() -> void:
	var ws_url := _resolved_base_url.replace("https://", "wss://").replace("http://", "ws://") + "/ws/world"
	_socket = WebSocketPeer.new()
	var err := _socket.connect_to_url(ws_url)
	if err != OK:
		_socket_connected = false
		_time_until_retry = _retry_seconds
		emit_signal("connection_changed", false)

func _process(delta: float) -> void:
	var ready_state := _socket.get_ready_state()
	if ready_state != WebSocketPeer.STATE_CLOSED:
		_socket.poll()
		ready_state = _socket.get_ready_state()
	if ready_state == WebSocketPeer.STATE_OPEN:
		if not _socket_connected:
			_socket_connected = true
			emit_signal("connection_changed", true)
		while _socket.get_available_packet_count() > 0:
			var raw := _socket.get_packet().get_string_from_utf8()
			var parsed = JSON.parse_string(raw)
			if parsed is Dictionary:
				emit_signal("socket_payload", parsed)
	elif ready_state == WebSocketPeer.STATE_CLOSED and _socket_connected:
		_socket_connected = false
		emit_signal("connection_changed", false)
		_time_until_retry = _retry_seconds
	elif ready_state == WebSocketPeer.STATE_CLOSED and _time_until_retry > 0.0:
		_time_until_retry -= delta
		if _time_until_retry <= 0.0:
			connect_socket()

func _compute_base_url() -> String:
	if base_url.strip_edges() != "":
		return base_url.strip_edges()

	var env_url := OS.get_environment("OPENCLAW_WORLD_BASE_URL").strip_edges()
	if env_url != "":
		return env_url

	if OS.has_feature("web"):
		var query_url := _eval_js_string("new URLSearchParams(window.location.search).get('gateway') || ''")
		if query_url != "":
			return query_url
		var global_url := _eval_js_string("window.OPENCLAW_WORLD_BASE_URL || ''")
		if global_url != "":
			return global_url
		var origin := _eval_js_string("window.location.origin || ''")
		if origin != "":
			return origin

	return "http://127.0.0.1:19200"

func _eval_js_string(script: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var value = JavaScriptBridge.eval(script, true)
	return String(value).strip_edges() if value != null else ""
