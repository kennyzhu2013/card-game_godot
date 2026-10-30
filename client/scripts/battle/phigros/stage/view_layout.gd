# client/scripts/battle/phigros/stage/view_layout.gd
class_name ViewLayout
extends RefCounted

const MAIN_POSITION := Vector2.ZERO
const MAIN_SCALE := Vector2(1.0, 1.0)
const MAIN_ALPHA := 1.0
const SUB_POSITION := Vector2(460.0, 20.0)
const SUB_SCALE := Vector2(0.5, 0.5)
const SUB_ALPHA := 0.6

var player_is_main: bool = true


func swap() -> void:
	player_is_main = not player_is_main


func target_main_transform() -> Transform2D:
	# main 容器始终承载"当前主屏"内容；当 player_is_main=false 时，main 容器装的是
	# enemy 视图，但仍然位于主屏位置/缩放，所以 transform 不依赖 player_is_main。
	# swap() 会改变两个容器装载的内容，由 phigros_battle_scene 在 swap 时交换子节点。
	# 但本 ViewLayout 不持有节点，所以提供"player 视图应该在哪里"的视角更直接：
	if player_is_main:
		return Transform2D(0.0, MAIN_SCALE, 0.0, MAIN_POSITION)
	return Transform2D(0.0, SUB_SCALE, 0.0, SUB_POSITION)


func target_sub_transform() -> Transform2D:
	if player_is_main:
		return Transform2D(0.0, SUB_SCALE, 0.0, SUB_POSITION)
	return Transform2D(0.0, MAIN_SCALE, 0.0, MAIN_POSITION)


func target_main_alpha() -> float:
	return MAIN_ALPHA if player_is_main else SUB_ALPHA


func target_sub_alpha() -> float:
	return SUB_ALPHA if player_is_main else MAIN_ALPHA
