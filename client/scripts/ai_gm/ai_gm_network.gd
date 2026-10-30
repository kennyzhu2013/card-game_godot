class_name AIGMNetwork
extends RefCounted

# AI GM 网络层 (R09 §4.7.2)
#
# 默认 force_offline=true：保持单测 / 离线运行不触发真 HTTP；
# 把 force_offline 置为 false 并提供 api_key 后，对 Anthropic provider 走 Messages API
# (https://api.anthropic.com/v1/messages)，返回 {success, text, error, status_code, latency_ms}.
#
# 其他 provider (DeepSeek / Gemini / Qwen) 在本切片暂返回 provider_not_implemented，
# Slice 5 T6 服务器代理上线后会改 base_url 到代理网关、由后端分发到具体厂商。
#
# 网络调用走 HTTPClient 同步轮询：service.call_ai_gm() 是非 async 接口，
# 必须在不引入 await 的前提下完成 connect / request / poll / read body。

const DEFAULT_TIMEOUT_SEC := 30.0
const DEFAULT_RETRY_COUNT := 2

const ANTHROPIC_HOST := "api.anthropic.com"
const ANTHROPIC_PATH := "/v1/messages"
const ANTHROPIC_VERSION := "2023-06-01"
const ANTHROPIC_PORT := 443
const POLL_SLEEP_SEC := 0.05
const DEFAULT_MAX_TOKENS := 600

var timeout_sec: float = DEFAULT_TIMEOUT_SEC
var retry_count: int = DEFAULT_RETRY_COUNT
var force_offline: bool = true

# Slice 5 T6：base_url 改为服务器代理时，host/path/port/use_ssl 由代理覆盖。
var anthropic_host: String = ANTHROPIC_HOST
var anthropic_path: String = ANTHROPIC_PATH
var anthropic_port: int = ANTHROPIC_PORT
var anthropic_use_ssl: bool = true

# 注入点：单测可以替换 _client_factory 来注入 mock client；保持产线无副作用。
var _client_factory: Callable = Callable()


func is_online() -> bool:
	return not force_offline


func request(ctx, provider, system_prompt: String = "", api_key: String = "") -> Dictionary:
	if not is_online():
		return _failure("offline")
	if api_key.strip_edges() == "":
		return _failure("missing_api_key")
	if ctx == null:
		return _failure("missing_context")
	if provider == null:
		return _failure("missing_provider")

	var provider_id := str(provider.id) if "id" in provider else ""
	var provider_name := str(provider.provider_name) if "provider_name" in provider else ""
	if provider_name != "Anthropic":
		# 其他厂商在 Slice 5 T6 由服务器代理统一接管；这里直返失败让上层走兜底。
		return _failure("provider_not_implemented:%s" % provider_id)

	var payload := _build_anthropic_payload(ctx, provider, system_prompt)
	var attempts: int = int(max(1, retry_count + 1))
	var last_error := ""
	var last_status := 0
	for attempt_index in range(attempts):
		var started_us := Time.get_ticks_usec()
		var result := _do_anthropic_request(payload, api_key)
		var latency_ms := int(round((Time.get_ticks_usec() - started_us) / 1000.0))
		result["latency_ms"] = latency_ms
		if bool(result.get("success", false)):
			return result
		last_error = str(result.get("error", ""))
		last_status = int(result.get("status_code", 0))
		# 只对 5xx / transport 错误重试；4xx 直接返回让上层兜底。
		if last_status != 0 and last_status < 500:
			return result
		# 最后一次直接返回带 latency 的失败。
		if attempt_index == attempts - 1:
			return result
	return {
		"success": false,
		"error": last_error if last_error != "" else "unknown_error",
		"status_code": last_status,
	}


func _build_anthropic_payload(ctx, provider, system_prompt: String) -> Dictionary:
	var ctx_dict: Dictionary = {}
	if ctx is Object and ctx.has_method("to_dict"):
		ctx_dict = ctx.to_dict()
	elif ctx is Dictionary:
		ctx_dict = (ctx as Dictionary).duplicate(true)
	var user_text := JSON.stringify(ctx_dict)
	var model := str(provider.model) if "model" in provider else "claude-haiku"
	var body := {
		"model": model,
		"max_tokens": DEFAULT_MAX_TOKENS,
		"messages": [
			{
				"role": "user",
				"content": user_text,
			},
		],
	}
	if system_prompt.strip_edges() != "":
		body["system"] = system_prompt
	return body


func _do_anthropic_request(payload: Dictionary, api_key: String) -> Dictionary:
	var client = _make_client()
	if client == null:
		return _failure("client_init_failed")

	var connect_err: int = int(client.connect_to_host(anthropic_host, anthropic_port, _tls_options()))
	if connect_err != OK:
		return _failure("connect_failed:%d" % connect_err)

	if not _wait_until_connected(client):
		client.close()
		return _failure("connect_timeout")

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"x-api-key: %s" % api_key,
		"anthropic-version: %s" % ANTHROPIC_VERSION,
	])
	var body_text := JSON.stringify(payload)
	var request_err: int = int(client.request(HTTPClient.METHOD_POST, anthropic_path, headers, body_text))
	if request_err != OK:
		client.close()
		return _failure("request_failed:%d" % request_err)

	if not _wait_until_response(client):
		client.close()
		return _failure("response_timeout")

	if not client.has_response():
		client.close()
		return _failure("no_response")

	var status_code: int = client.get_response_code()
	var body_buffer := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk: PackedByteArray = client.read_response_body_chunk()
		if chunk.is_empty():
			OS.delay_msec(int(POLL_SLEEP_SEC * 1000.0))
		else:
			body_buffer.append_array(chunk)
	client.close()

	var body_text_response := body_buffer.get_string_from_utf8()
	if status_code < 200 or status_code >= 300:
		return {
			"success": false,
			"error": "http_status:%d" % status_code,
			"status_code": status_code,
			"raw_body": body_text_response,
		}
	var parsed = JSON.parse_string(body_text_response)
	if not parsed is Dictionary:
		return {
			"success": false,
			"error": "parse_failed",
			"status_code": status_code,
			"raw_body": body_text_response,
		}
	var text := _extract_anthropic_text(parsed as Dictionary)
	if text == "":
		return {
			"success": false,
			"error": "empty_text",
			"status_code": status_code,
			"raw_body": body_text_response,
		}
	return {
		"success": true,
		"text": text,
		"status_code": status_code,
		"usage": (parsed as Dictionary).get("usage", {}),
	}


func _make_client():
	if _client_factory.is_valid():
		return _client_factory.call()
	return HTTPClient.new()


func _tls_options():
	if not anthropic_use_ssl:
		return null
	if ClassDB.class_exists("TLSOptions"):
		return TLSOptions.client()
	return null


func _wait_until_connected(client) -> bool:
	var deadline := _deadline_usec()
	while true:
		var status: int = client.get_status()
		if status == HTTPClient.STATUS_CONNECTED:
			return true
		if status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CANT_RESOLVE \
				or status == HTTPClient.STATUS_DISCONNECTED or status == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			return false
		if Time.get_ticks_usec() > deadline:
			return false
		client.poll()
		OS.delay_msec(int(POLL_SLEEP_SEC * 1000.0))
	return false


func _wait_until_response(client) -> bool:
	var deadline := _deadline_usec()
	while true:
		var status: int = client.get_status()
		if status == HTTPClient.STATUS_BODY or status == HTTPClient.STATUS_CONNECTED:
			return true
		if status == HTTPClient.STATUS_DISCONNECTED or status == HTTPClient.STATUS_CONNECTION_ERROR \
				or status == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			return false
		if Time.get_ticks_usec() > deadline:
			return false
		client.poll()
		OS.delay_msec(int(POLL_SLEEP_SEC * 1000.0))
	return false


func _deadline_usec() -> int:
	return Time.get_ticks_usec() + int(timeout_sec * 1_000_000.0)


func _extract_anthropic_text(parsed: Dictionary) -> String:
	var content_value: Variant = parsed.get("content", [])
	if not content_value is Array:
		return ""
	var pieces: Array[String] = []
	for entry in (content_value as Array):
		if entry is Dictionary:
			var entry_dict: Dictionary = entry
			if str(entry_dict.get("type", "")) == "text":
				var piece := str(entry_dict.get("text", ""))
				if piece != "":
					pieces.append(piece)
	if pieces.is_empty():
		return ""
	return "\n".join(pieces)


func _failure(error_code: String) -> Dictionary:
	return {
		"success": false,
		"error": error_code,
		"status_code": 0,
	}
