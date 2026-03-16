extends Control
class_name HomeUI

# 更新武将数量显示
func update_hero_count(count: int, total: int):
	# 直接遍历子节点找武将数量标签
	for child in get_children():
		if child.name == "HeroCount":
			child.text = "已收集武将：%d / %d" % [count, total]
			break
