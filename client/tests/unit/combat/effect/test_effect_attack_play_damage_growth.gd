extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_attack_play_damage_growth.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("dummy", 50, 0, 0)
	var primer_a = _attack_card("primer_attack_a")
	var primer_b = _attack_card("primer_attack_b")
	var primer_c = _attack_card("primer_attack_c")
	var air_bullet = _effect_card("air_bullet", [{"id": "attack_play_damage_growth", "magnitude": 2, "cap": 6}], 8)
	air_bullet.tags.assign(["attack"])
	var battle = _start_battle([primer_a, primer_b, primer_c, air_bullet], player, enemy)
	battle.hand.clear()
	battle.hand.append(primer_a)
	battle.hand.append(primer_b)
	battle.hand.append(primer_c)
	battle.hand.append(air_bullet)

	assert_true(battle.play_card(primer_a, enemy), "first attack primer can be played")
	assert_true(battle.play_card(primer_b, enemy), "second attack primer can be played")
	assert_true(battle.play_card(primer_c, enemy), "third attack primer can be played")
	assert_true(battle.play_card(air_bullet, enemy), "growth card can be played after three attack cards")
	assert_eq(enemy.hp, 36, "attack_play_damage_growth adds +6 after three attack-card plays")
	return _result()


func _attack_card(id: String) -> Card:
	var card = _effect_card(id, [], 0)
	card.tags.assign(["attack"])
	return card
