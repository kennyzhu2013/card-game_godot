class_name ForgeChartCompiler
extends RefCounted

const ELEMENT_TO_TEMPLATES := {
	"影": ["WHISPER", "WHISPER", "WEAVE"],
	"明": ["MIRROR", "WEAVE", "WHISPER"],
	"离": ["WEAVE", "WEAVE", "MIRROR"],
	"坎": ["BREATH", "WHISPER", "WEAVE"],
	"震": ["WEAVE", "MIRROR", "BREATH"],
	"灵": ["WHISPER", "MIRROR", "WEAVE"],
	"火": ["WEAVE", "BREATH", "WHISPER"],
	"水": ["BREATH", "WHISPER", "BREATH"],
	"牵": ["WHISPER", "WEAVE", "WEAVE"],
	"知": ["MIRROR", "WHISPER", "MIRROR"],
	"恐": ["BREATH", "BREATH", "WEAVE"],
	"像": ["MIRROR", "MIRROR", "WHISPER"],
	"失": ["WHISPER", "BREATH", "WEAVE"],
	"福": ["WEAVE", "WEAVE", "MIRROR"],
	"直": ["BREATH", "WEAVE", "BREATH"],
	"称": ["MIRROR", "WHISPER", "WEAVE"],
	"笑": ["WEAVE", "WHISPER", "MIRROR"],
	"现": ["MIRROR", "MIRROR", "BREATH"],
	"坚": ["BREATH", "WEAVE", "WEAVE"],
	"灼": ["WEAVE", "MIRROR", "BREATH"],
	"柔": ["BREATH", "WHISPER", "BREATH"],
	"治": ["BREATH", "BREATH", "WHISPER"],
	"形": ["MIRROR", "WEAVE", "MIRROR"],
	"远": ["WEAVE", "BREATH", "WEAVE"],
	"近": ["BREATH", "WEAVE", "WHISPER"],
}

const SHAPE_DURATION_MS := {3: 30000, 4: 45000, 6: 60000}
const SHAPE_BASE_DENSITY := {3: 30, 4: 50, 6: 75}
const DEFAULT_TEMPLATE := "WHISPER"
const CHART_LEAD_IN_MS := 2000

const SYMBOL_ID_TO_ASPECTS := {
	"shadow": ["影", "恐", "失"],
	"thread": ["牵", "缘", "誓"],
	"jester": ["失", "转", "笑"],
	"mirror": ["像", "伪", "碎"],
	"inquiry": ["知", "惑", "启"],
	"name": ["称", "属", "夺"],
	"fortune": ["福", "祸", "转"],
	"face": ["现", "隐", "换"],
	"arrow": ["形", "直", "远"],
	"touch": ["形", "近", "直"],
	"flame": ["火", "灼", "毁"],
	"water": ["水", "柔", "治"],
}


static func compile(arrangement, reactions: Array) -> Dictionary:
	var aspect_counts := _count_aspects(arrangement)
	var dominant_aspect := _dominant_aspect(aspect_counts)
	if dominant_aspect == "":
		return _empty_params()

	var template_id := _roll_template(dominant_aspect)
	var reaction_count := reactions.size()
	var duration_ms: int = SHAPE_DURATION_MS[arrangement.capacity] + reaction_count * 2000
	var base_density: int = SHAPE_BASE_DENSITY[arrangement.capacity]
	var total_notes: int = base_density + reaction_count * 6
	var bpm: int = 90 + reaction_count * 4

	return {
		"template_id": template_id,
		"duration_ms": duration_ms,
		"total_notes": total_notes,
		"bpm": bpm,
		"params": _template_params_for(template_id, total_notes, duration_ms, bpm, reaction_count),
		"momentum": reaction_count * 15,
	}


static func _count_aspects(arrangement) -> Dictionary:
	var counts := {}
	for i in range(arrangement.capacity):
		var symbol_id: String = arrangement.get_at(i)
		if symbol_id == "":
			continue
		var aspects: Array = SYMBOL_ID_TO_ASPECTS.get(symbol_id, [])
		for aspect in aspects:
			counts[aspect] = int(counts.get(aspect, 0)) + 1
	return counts


static func _dominant_aspect(counts: Dictionary) -> String:
	var best := ""
	var best_n := 0
	for aspect in counts:
		var n: int = int(counts[aspect])
		if n > best_n:
			best = aspect
			best_n = n
	return best


static func _roll_template(element: String) -> String:
	var options: Array = ELEMENT_TO_TEMPLATES.get(element, [DEFAULT_TEMPLATE])
	return String(options[0])


static func _template_params_for(template_id: String, total_notes: int, duration_ms: int, bpm: int, reaction_count: int) -> Dictionary:
	var interval_ms := int(duration_ms / maxi(1, total_notes))
	var lane_a := randi() % 3
	var lane_b := clampi(lane_a + 1 + randi() % 2, 1, 3)

	var params := {
		"start_ms": CHART_LEAD_IN_MS,
		"note_count": total_notes,
		"interval_ms": interval_ms,
		"lane": 1,
		"bpm": bpm,
	}

	match template_id:
		"BREATH":
			params["hold_count"] = maxi(2, total_notes / 4)
			params["hold_duration_ms"] = maxi(400, interval_ms * 2)
			params["gap_ms"] = maxi(100, interval_ms / 3)
		"WEAVE":
			params["lane_a"] = lane_a
			params["lane_b"] = lane_b
		"MIRROR":
			params["outer_lane"] = 0 if randi() % 2 == 0 else 1
			params["inner_lane"] = 2 if params["outer_lane"] == 0 else 3

	return params


static func _empty_params() -> Dictionary:
	return {
		"template_id": "",
		"duration_ms": 0,
		"total_notes": 0,
		"bpm": 0,
		"params": {},
		"momentum": 0,
	}
