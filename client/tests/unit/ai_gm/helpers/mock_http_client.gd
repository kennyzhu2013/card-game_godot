extends RefCounted

# 模拟 Godot HTTPClient 接口，用于 AIGMNetwork 单测。
# 状态机简化为：
#   DISCONNECTED(0) → connect_to_host → CONNECTED(5)
#   request → BODY(7)
#   read_response_body_chunk 第二次调用 → CONNECTED(5) (退出 while 循环)
#   close → DISCONNECTED(0)

const STATUS_DISCONNECTED := 0
const STATUS_CONNECTED := 5
const STATUS_BODY := 7

var scripted_status_code: int = 200
var scripted_body: String = ""
var shared_log: Array = []

var last_host: String = ""
var last_port: int = 0
var last_method: int = -1
var last_path: String = ""
var last_headers: PackedStringArray = PackedStringArray()
var last_body: String = ""

var _status: int = STATUS_DISCONNECTED
var _has_response: bool = false
var _body_emitted: bool = false


func connect_to_host(host: String, port: int, _tls = null) -> int:
	last_host = host
	last_port = port
	_status = STATUS_CONNECTED
	return 0  # OK


func get_status() -> int:
	return _status


func poll() -> int:
	return 0


func request(method: int, path: String, headers: PackedStringArray, body: String) -> int:
	last_method = method
	last_path = path
	last_headers = headers
	last_body = body
	_has_response = true
	_body_emitted = false
	_status = STATUS_BODY
	return 0  # OK


func has_response() -> bool:
	return _has_response


func get_response_code() -> int:
	return scripted_status_code


func read_response_body_chunk() -> PackedByteArray:
	if _body_emitted:
		_status = STATUS_CONNECTED  # 退出 STATUS_BODY 循环
		return PackedByteArray()
	_body_emitted = true
	return scripted_body.to_utf8_buffer()


func close() -> void:
	_status = STATUS_DISCONNECTED
	_has_response = false
