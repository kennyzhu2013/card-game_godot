class_name PhigrosBattleBridge
extends RefCounted

signal chart_request(chart, target: String, direction: int)
signal chart_result(summary: Dictionary, target: String)

const BattleLogicScript = preload("res://scripts/battle_logic.gd")

var battle_logic: RefCounted = null
var _pending_target := ""


func connect_battle_logic(bl) -> void:
	battle_logic = bl
	if bl != null and not bl.chart_request_emitted.is_connected(_on_chart_request):
		bl.chart_request_emitted.connect(_on_chart_request)


func _on_chart_request(chart, target: String) -> void:
	var direction := 1 if target == BattleLogicScript.PLAYER else -1
	_pending_target = target
	chart_request.emit(chart, target, direction)


func submit_chart_result(summary: Dictionary) -> void:
	if battle_logic != null and battle_logic.has_method("resolve_phigros_chart"):
		battle_logic.resolve_phigros_chart(summary)
	chart_result.emit(summary, _pending_target)
	_pending_target = ""
