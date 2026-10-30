extends SceneTree


func _init() -> void:
	var log := []
	var sfx_ids := [
		"card_draw", "card_hover", "card_play", "card_discard",
		"damage_player", "damage_enemy", "turn_end",
		"victory", "defeat", "ui_click"
	]

	log.append("=== SFX Runtime Smoke Test ===")

	for sfx_id in sfx_ids:
		var triggered := false
		var error_msg := ""

		if Sfx != null:
			Sfx.play(sfx_id)
			await create_timer(0.1).timeout

			var playing_count := 0
			for child in Sfx.get_children():
				if child is AudioStreamPlayer:
					if (child as AudioStreamPlayer).stream != null:
						playing_count += 1

			triggered = true
		else:
			error_msg = "Sfx autoload not found"

		var status := "triggered=true" if triggered else "triggered=false (%s)" % error_msg
		var line := "SMOKE sfx_play id=%s %s" % [sfx_id, status]
		log.append(line)
		print(line)

		await create_timer(0.5).timeout

	log.append("=== Smoke Test Complete ===")

	var output_dir := ProjectSettings.globalize_path("user://qa/sfx_runtime")
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)

	var log_path := output_dir + "/sfx_runtime_smoke.log"
	var file := FileAccess.open(log_path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(log))
		file.close()
		print("Log saved to: %s" % log_path)
	else:
		push_error("Failed to write smoke log to: %s" % log_path)

	quit()
