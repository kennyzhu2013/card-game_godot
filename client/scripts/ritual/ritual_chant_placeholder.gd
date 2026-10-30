extends Control

@onready var _info_label: Label = $InfoLabel

var _arrangement = null


func set_arrangement(arrangement) -> void:
	_arrangement = arrangement
	if _info_label == null:
		await ready
	var lines: Array = ["（吟唱阶段占位 — Phase 2 接 Phigros）", "", "已摆放符号："]
	for i in range(arrangement.capacity):
		var sym_id: String = arrangement.get_at(i)
		lines.append("  Slot %d: %s" % [i, sym_id if sym_id != "" else "（空）"])
	_info_label.text = "\n".join(lines)
