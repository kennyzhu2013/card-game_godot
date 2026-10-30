# Cards Data Directory

> Per design/2026-05-24-tower-deck-combat-redesign.md §5.1
> 锻造产出的 Card JSON 与从设计圣经 (design/cards/*-pathway.md) 提取的 MVP 卡数据放此目录。

## 现状（2026-05-25）

- 空目录，等待切片 1 实施期填充。
- 兼容期：`card_library.gd` 在该目录为空时回退读取 `data/skills/` 旧 Skill JSON 并包装为 Card。

## MVP 填充计划

1. 从 `design/cards/fool-pathway.md` 提取 sequence 9-7 共 19 张卡（命途旁观者 8 + 影替师 6 + 命运织匠 5）
2. 加 6 张通用卡（无途径限制）
3. 加 8 张塔内拾取卡（pathway = "tower_only"，不可锻造）
4. 跨途径敌方法术卡 30 张（priestess / emperor / chariot / hermit / death / darkness 各 5 张）

总计 MVP 卡数：63 张（玩家可用 33 + 敌方 30）。
