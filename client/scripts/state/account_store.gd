class_name AccountStore
extends RefCounted

# 账号级持久化 (R10 §8.13.3)
# 只存跨周目/跨角色永久字段，独立于 slot_N.json / auto.json。
# 路径: user://saves/account.json

const PATH := "user://saves/account.json"


static func load() -> Dictionary:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return _default()
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) == OK:
		var data = json.get_data()
		if data is Dictionary:
			return data
	return _default()


static func save(data: Dictionary) -> void:
	var json := JSON.new()
	var text := JSON.stringify(data, "\t")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()


static func get_default() -> Dictionary:
	return _default()


static func _default() -> Dictionary:
	return {
		"daodian": {
			"discovered_cards": [],
			"discovered_brands": [],
			"unique_artifacts_seen": [],
			"dao_fragments": [],
			"npc_first_met_days": {},
			"npc_milestones": [],
		},
		"completed_commissions": [],
		"divinity_cards": [],
	}
