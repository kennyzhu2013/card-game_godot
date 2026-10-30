class_name SequencePromotionGate
extends RefCounted

# 序列晋升门 (R07 §3.1)
# 每个途径每个序列跃迁一条记录，定义晋升仪式塔的准入条件。

var from_sequence: int = 9
var to_sequence: int = 8
var sequence_exp_required: int = 100
var reactions_required: int = 8
var pollution_max: int = 50
var story_node_id: String = ""
var ritual_tower_id: String = ""
var contract_rules_required: int = 3


func can_promote(gs: Dictionary) -> bool:
	if gs.get("sequence", 0) != from_sequence:
		return false
	if gs.get("sequence_exp", 0) < sequence_exp_required:
		return false
	var reactions: Array = gs.get("known_reactions", [])
	if reactions.size() < reactions_required:
		return false
	if gs.get("pollution", 0) > pollution_max:
		return false
	var contract: Array = gs.get("active_contract", [])
	if contract.size() < contract_rules_required:
		return false
	if story_node_id != "":
		var daodian: Dictionary = gs.get("daodian", {})
		var completed_nodes: Array = daodian.get("completed_main_story_nodes", [])
		if not story_node_id in completed_nodes:
			return false
	return true


static func from_json(d: Dictionary) -> SequencePromotionGate:
	var gate := SequencePromotionGate.new()
	gate.from_sequence = int(d.get("from_sequence", 9))
	gate.to_sequence = int(d.get("to_sequence", 8))
	gate.sequence_exp_required = int(d.get("sequence_exp_required", 100))
	gate.reactions_required = int(d.get("reactions_required", 8))
	gate.pollution_max = int(d.get("pollution_max", 50))
	gate.story_node_id = d.get("story_node_id", "")
	gate.ritual_tower_id = d.get("ritual_tower_id", "")
	gate.contract_rules_required = int(d.get("contract_rules_required", 3))
	return gate


func to_dict() -> Dictionary:
	return {
		"from_sequence": from_sequence,
		"to_sequence": to_sequence,
		"sequence_exp_required": sequence_exp_required,
		"reactions_required": reactions_required,
		"pollution_max": pollution_max,
		"story_node_id": story_node_id,
		"ritual_tower_id": ritual_tower_id,
		"contract_rules_required": contract_rules_required,
	}
