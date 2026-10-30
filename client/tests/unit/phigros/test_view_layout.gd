# client/tests/unit/phigros/test_view_layout.gd
extends RefCounted

const ViewLayout = preload("res://scripts/battle/phigros/stage/view_layout.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_view_layout.gd --")
	test_initial_player_is_main()
	test_initial_main_transform_is_identity()
	test_initial_sub_transform_is_topright()
	test_swap_flips_player_is_main()
	test_swap_swaps_target_transforms()
	test_double_swap_returns_to_initial()
	test_initial_alpha_main_is_one_sub_is_dim()
	return {"passed": _passed, "failed": _failed}


func test_initial_player_is_main() -> void:
	var layout = ViewLayout.new()
	assert_true(layout.player_is_main, "player_is_main starts true")


func test_initial_main_transform_is_identity() -> void:
	var layout = ViewLayout.new()
	var main_t: Transform2D = layout.target_main_transform()
	assert_true(main_t.origin == Vector2.ZERO, "main origin is zero")
	assert_true(is_equal_approx(main_t.get_scale().x, 1.0), "main scale x = 1.0")


func test_initial_sub_transform_is_topright() -> void:
	var layout = ViewLayout.new()
	var sub_t: Transform2D = layout.target_sub_transform()
	assert_true(sub_t.origin == Vector2(460.0, 20.0), "sub origin is (460,20)")
	assert_true(is_equal_approx(sub_t.get_scale().x, 0.5), "sub scale x = 0.5")


func test_swap_flips_player_is_main() -> void:
	var layout = ViewLayout.new()
	layout.swap()
	assert_true(not layout.player_is_main, "player_is_main false after swap")


func test_swap_swaps_target_transforms() -> void:
	var layout = ViewLayout.new()
	var before_main: Transform2D = layout.target_main_transform()
	var before_sub: Transform2D = layout.target_sub_transform()
	layout.swap()
	var after_main: Transform2D = layout.target_main_transform()
	var after_sub: Transform2D = layout.target_sub_transform()
	assert_true(after_main.origin == before_sub.origin, "main now sits in old sub origin")
	assert_true(after_sub.origin == before_main.origin, "sub now sits in old main origin")


func test_double_swap_returns_to_initial() -> void:
	var layout = ViewLayout.new()
	layout.swap()
	layout.swap()
	assert_true(layout.player_is_main, "double swap restores player_is_main")
	var main_t: Transform2D = layout.target_main_transform()
	assert_true(main_t.origin == Vector2.ZERO, "main origin restored to zero")


func test_initial_alpha_main_is_one_sub_is_dim() -> void:
	var layout = ViewLayout.new()
	assert_true(is_equal_approx(layout.target_main_alpha(), 1.0), "main alpha = 1.0")
	assert_true(is_equal_approx(layout.target_sub_alpha(), 0.6), "sub alpha = 0.6")


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  PASS: %s" % msg)
	else:
		_failed += 1
		print("  FAIL: %s" % msg)
