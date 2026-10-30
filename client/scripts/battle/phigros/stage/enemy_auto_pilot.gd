class_name EnemyAutoPilot
extends RefCounted

signal auto_judged(note_part, verdict: String, offset_ms: int)


func judge_chart_notes(note_parts: Array) -> Dictionary:
	var summary := {"perfect": 0, "good": 0, "bad": 0, "miss": 0}
	for np in note_parts:
		if np == null or np.judged:
			continue
		var verdict: String = np.judge_at(int(np.note_time_ms), false)
		if verdict == "":
			continue
		summary[verdict] = int(summary.get(verdict, 0)) + 1
		auto_judged.emit(np, verdict, 0)
	return summary
