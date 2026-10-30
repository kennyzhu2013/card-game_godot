# client/scripts/battle/phigros/stage/skill_intro_animator.gd
class_name SkillIntroAnimator
extends RefCounted

signal finished

const ProjectileScript = preload("res://scripts/battle/phigros/stage/projectile.gd")

const STAGE_POSE_MS := 300
const STAGE_FLY_OUT_MS := 300
const STAGE_HIT_MS := 200
const STAGE_RETURN_MS := 200

var _playing: bool = false


func total_duration_ms() -> int:
	return STAGE_POSE_MS + STAGE_FLY_OUT_MS + STAGE_HIT_MS + STAGE_RETURN_MS


func is_playing() -> bool:
	return _playing


# attacker_character: PokemonCharacter (in attacker view)
# defender_judge_line: ColorRect (in defender view)
# projectile_layer: Node2D (top-level scene container so projectile can fly across views)
# attacker_world_pos / defender_world_pos: scene-root world coordinates for the projectile path
func play(scene_tree: SceneTree,
		attacker_character,
		attacker_judge_line,
		defender_judge_line,
		projectile_layer: Node2D,
		attacker_world_pos: Vector2,
		defender_world_pos: Vector2) -> Signal:
	if _playing:
		return finished
	_playing = true
	if attacker_character != null and attacker_character.has_method("play_attack_pose"):
		attacker_character.play_attack_pose()
	# 攻击方判定线蓄力弹动（弹弓发射动作）
	if attacker_judge_line != null:
		var pre_tw: Tween = attacker_judge_line.create_tween()
		pre_tw.tween_property(attacker_judge_line, "scale:y", 1.6, 0.12)
		pre_tw.tween_property(attacker_judge_line, "scale:y", 1.0, 0.18)
	if scene_tree == null:
		_playing = false
		_emit_finished_deferred()
		return finished
	await scene_tree.create_timer(float(STAGE_POSE_MS) / 1000.0).timeout
	var projectile = ProjectileScript.new()
	projectile_layer.add_child(projectile)
	projectile.setup(attacker_world_pos, defender_world_pos, attacker_world_pos)
	await scene_tree.create_timer(float(STAGE_FLY_OUT_MS) / 1000.0).timeout
	# 防守方判定线被光块击中
	if defender_judge_line != null:
		var hit_tw: Tween = defender_judge_line.create_tween()
		hit_tw.tween_property(defender_judge_line, "rotation_degrees", 5.0, 0.08)
		hit_tw.tween_property(defender_judge_line, "rotation_degrees", -5.0, 0.08)
		hit_tw.tween_property(defender_judge_line, "rotation_degrees", 0.0, 0.04)
	await scene_tree.create_timer(float(STAGE_HIT_MS) / 1000.0).timeout
	await scene_tree.create_timer(float(STAGE_RETURN_MS) / 1000.0).timeout
	_playing = false
	finished.emit()
	return finished


func _emit_finished_deferred() -> void:
	# 测试场景下没有 SceneTree，直接同步 emit
	finished.emit()
