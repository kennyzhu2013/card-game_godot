class_name ChantButtonFactory
extends RefCounted

const SOCIAL_POLLUTION := {
	"identity_mask": 2,
	"borrow_name": 3,
	"forget_event": 3,
	"read_truth": 2,
	"modify_suspicion": 2,
	"extract_memory": 2,
	"extract_secret": 2,
	"influence_behavior": 3,
}

const SOCIAL_AWARENESS := {
	"identity_mask": 2,
	"borrow_name": 2,
	"forget_event": 2,
	"read_truth": 1,
	"modify_suspicion": 1,
	"extract_memory": 1,
	"extract_secret": 1,
	"influence_behavior": 2,
}

const WORLD_POLLUTION := {
	"alter_drop_table": 3,
	"spawn_event": 4,
	"attract_visitor": 2,
	"modify_node_atmosphere": 3,
	"reveal_hidden_lore": 3,
	"create_residual_identity": 3,
	"alter_npc_state": 4,
	"reveal_npc_relationships": 3,
}

const WORLD_AWARENESS := {
	"alter_drop_table": 3,
	"spawn_event": 3,
	"attract_visitor": 2,
	"modify_node_atmosphere": 2,
	"reveal_hidden_lore": 1,
	"create_residual_identity": 2,
	"alter_npc_state": 3,
	"reveal_npc_relationships": 2,
}

const SOCIAL_LABELS := {
	"identity_mask": "伪装身份",
	"borrow_name": "借名",
	"forget_event": "抹除记忆",
	"read_truth": "读取真话",
	"modify_suspicion": "调整怀疑",
	"extract_memory": "抽取记忆",
	"extract_secret": "抽取秘密",
	"influence_behavior": "影响行为",
}

const WORLD_LABELS := {
	"alter_drop_table": "改变掉落",
	"spawn_event": "引出后续事件",
	"attract_visitor": "吸引访客",
	"modify_node_atmosphere": "改变地点氛围",
	"reveal_hidden_lore": "揭示隐藏线索",
	"create_residual_identity": "创造残留身份",
	"alter_npc_state": "改写NPC状态",
	"reveal_npc_relationships": "揭示NPC关系",
}


const FIELD_HOOK_LABELS := {
	"read_truth": "\u573a\u5916\uff1a\u8bfb\u53d6\u771f\u8bdd\uff0c\u63ed\u5f00\u4e00\u6761\u5173\u7cfb\u95e8\u69db\u60c5\u62a5",
	"identity_mask": "\u573a\u5916\uff1a\u4f2a\u88c5\u8eab\u4efd\uff0c\u964d\u4f4e\u5f53\u524d NPC \u5bf9\u4f60\u7684\u6000\u7591",
	"premonition": "\u573a\u5916\uff1a\u9884\u793a\u4e00\u4e2a\u9690\u85cf\u57ce\u533a\u4e8b\u4ef6",
	"influence_behavior": "\u573a\u5916\uff1a\u5f71\u54cd\u884c\u4e3a\uff0c\u91cd\u63b7\u4e00\u6b21 NPC \u4eca\u65e5\u673a\u4f1a",
}


static func add_chant_buttons(parent: Node, game_state, target_npc_id: String, callback: Callable = Callable(), prefix: String = "R20ChantButton_") -> Array:
	var buttons: Array = []
	if parent == null or game_state == null or target_npc_id == "":
		return buttons
	clear_chant_buttons(parent, prefix)
	for card in owned_social_cards(game_state):
		if card == null or not card.has_method("can_use_socially") or not bool(card.can_use_socially()):
			continue
		var card_id := str(card.get("id"))
		if card_id == "":
			continue
		var button_name := "%s%s" % [prefix, card_id]
		var button := _new_button(parent, button_name, _button_text(card))
		button.disabled = _hub_mana_short(game_state, card)
		button.tooltip_text = _button_tooltip(card, game_state, button.disabled)
		if callback.is_valid():
			var captured_card_id := card_id
			button.pressed.connect(func(): callback.call(captured_card_id, target_npc_id))
		buttons.append(button)
	return buttons


static func clear_chant_buttons(parent: Node, prefix: String = "R20ChantButton_") -> void:
	if parent == null:
		return
	for child in parent.find_children("%s*" % prefix, "Button", true, false):
		if child is Button and str(child.name).begins_with(prefix):
			_remove_button(parent, child)


static func _new_button(parent: Node, button_name: String, button_text: String) -> Button:
	if parent is AcceptDialog:
		var button := (parent as AcceptDialog).add_button(button_text, false, button_name)
		button.name = button_name
		return button
	var button := Button.new()
	button.name = button_name
	button.text = button_text
	parent.add_child(button)
	return button


static func _remove_button(parent: Node, button: Button) -> void:
	var button_parent := button.get_parent()
	if parent is AcceptDialog and button_parent != parent:
		(parent as AcceptDialog).remove_button(button)
		if button.get_parent() != null:
			button.get_parent().remove_child(button)
	elif button_parent != null:
		button_parent.remove_child(button)
	button.queue_free()


static func owned_social_cards(game_state) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	if game_state == null:
		return result
	for card_id in _active_deck(game_state):
		var card = _card_from_active_deck_entry(game_state, card_id)
		_add_card_if_new(result, seen, card)
	return result


static func _card_from_active_deck_entry(game_state, active_entry):
	if active_entry != null and active_entry is Object and active_entry.has_method("get"):
		return active_entry
	var card_id := str(active_entry)
	if card_id == "":
		return null
	if game_state.has_method("get_card"):
		return game_state.get_card(card_id)
	for card in _cards_inventory(game_state):
		if card != null and card.has_method("get") and str(card.get("id")) == card_id:
			return card
	return null


static func _add_card_if_new(result: Array, seen: Dictionary, card) -> void:
	if card == null or not card.has_method("get"):
		return
	var card_id := str(card.get("id"))
	if card_id == "" or seen.has(card_id):
		return
	seen[card_id] = true
	result.append(card)


static func _active_deck(game_state) -> Array:
	var value = game_state.get("active_deck")
	return value if value is Array else []


static func _cards_inventory(game_state) -> Array:
	var value = game_state.get("cards_inventory")
	return value if value is Array else []


static func _button_text(card) -> String:
	return "%s %s - %s %d" % [
		"咒念",
		str(card.get_display_name()),
		"洞府",
		_card_cost(card),
	]


static func _button_tooltip(card, game_state, is_disabled: bool) -> String:
	var lines: Array[String] = []
	var cost := _card_cost(card)
	var current_mana := int(game_state.get("hub_mana"))
	var max_mana := int(game_state.get("hub_mana_max"))
	if max_mana <= 0:
		max_mana = maxi(current_mana, cost)
	lines.append("%s: %d/%d; %s %d" % ["洞府能量", current_mana, max_mana, "消耗", cost])
	var social := _effect_dict(card.get("social_effect"))
	var world := _effect_dict(card.get("world_effect"))
	var social_summary := _effect_summary(social, SOCIAL_LABELS)
	if social_summary != "":
		lines.append("%s: %s" % ["社交", social_summary])
	var world_summary := _effect_summary(world, WORLD_LABELS)
	if world_summary != "":
		lines.append("%s: %s" % ["世界", world_summary])
	var pollution_delta := _pollution_delta(social, SOCIAL_POLLUTION) + _pollution_delta(world, WORLD_POLLUTION)
	var awareness_delta := _awareness_delta(social, SOCIAL_AWARENESS) + _awareness_delta(world, WORLD_AWARENESS)
	lines.append("%s: %s %s; %s %s" % [
		"副作用",
		"污染",
		_signed_number_text(pollution_delta),
		"教会查觉",
		_signed_number_text(awareness_delta),
	])
	if is_disabled:
		lines.append("%s: %s %d, %s %d" % [
			"洞府能量不足",
			"当前",
			current_mana,
			"需要",
			cost,
		])
	return "\n".join(lines)


static func _effect_summary(effect: Dictionary, labels: Dictionary) -> String:
	var effect_type := _effect_type(effect)
	if effect_type == "":
		return ""
	var parts: Array[String] = []
	parts.append(str(FIELD_HOOK_LABELS.get(effect_type, labels.get(effect_type, "特殊效果"))))
	var duration_days := int(effect.get("duration_days", 0))
	if duration_days > 0:
		parts.append("%s%d%s" % ["持续", duration_days, "天"])
	var suspicion_delta := int(effect.get("suspicion_delta", 0))
	if suspicion_delta != 0:
		parts.append("%s %s" % ["怀疑", _signed_number_text(suspicion_delta)])
	var reveal_layer := int(effect.get("reveal_layer", 0))
	if reveal_layer > 0:
		parts.append("%s%d" % ["揭示层级", reveal_layer])
	var clean_note := _clean_optional_text(effect.get("notes", ""))
	if clean_note != "":
		parts.append(clean_note)
	if effect_type == "create_residual_identity" and int(effect.get("uses_remaining", 0)) > 0:
		parts.append("%s%d%s" % ["可用", int(effect.get("uses_remaining", 0)), "次"])
	return "；".join(parts)


static func _hub_mana_short(game_state, card) -> bool:
	return int(game_state.get("hub_mana")) < _card_cost(card)


static func _card_cost(card) -> int:
	if card == null or not card.has_method("get"):
		return 0
	return maxi(0, int(card.get("energy_cost")))


static func _effect_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


static func _effect_type(effect: Dictionary) -> String:
	return str(effect.get("type", ""))


static func _pollution_delta(effect: Dictionary, defaults: Dictionary) -> int:
	var effect_type := _effect_type(effect)
	if effect_type == "":
		return 0
	return int(effect.get("pollution_delta", defaults.get(effect_type, 0)))


static func _awareness_delta(effect: Dictionary, defaults: Dictionary) -> int:
	var effect_type := _effect_type(effect)
	if effect_type == "":
		return 0
	return int(effect.get("church_awareness_delta", defaults.get(effect_type, 0)))


static func _signed_number_text(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return "%d" % value


static func _clean_optional_text(value: Variant) -> String:
	var text := str(value).strip_edges()
	if text == "" or text.contains("_") or text.contains("{") or text.contains("}") or text.contains("[") or text.contains("]"):
		return ""
	return text
