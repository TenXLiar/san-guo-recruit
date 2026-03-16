extends Control
class_name LibraryUI

# 更新武将列表
func update_hero_list(owned_heroes: Dictionary, rarity_names: Array):
	var stats_label = get_node_or_null("Stats")
	var scroll = get_node_or_null("ScrollContainer")
	var hero_list = null
	
	if scroll:
		hero_list = scroll.get_node_or_null("HeroList")
	
	# 清空现有列表
	if hero_list:
		for child in hero_list.get_children():
			child.queue_free()
	
	var total = 22  # 总武将数量
	if stats_label:
		stats_label.text = "已收集武将：%d / %d" % [owned_heroes.size(), total]
	
	if owned_heroes.size() == 0:
		if hero_list:
			var empty_label = Label.new()
			empty_label.text = "还没有武将，快去招募吧！"
			empty_label.add_theme_font_size_override("font_size", 16)
			empty_label.modulate = Color(0.6, 0.6, 0.6)
			hero_list.add_child(empty_label)
		return
	
	# 按稀有度排序
	var sorted_heroes = []
	for hero in owned_heroes.values():
		sorted_heroes.append(hero)
	
	# 排序：稀有度从高到低
	for i in range(sorted_heroes.size()):
		for j in range(i + 1, sorted_heroes.size()):
			if sorted_heroes[j].rarity > sorted_heroes[i].rarity:
				var temp = sorted_heroes[i]
				sorted_heroes[i] = sorted_heroes[j]
				sorted_heroes[j] = temp
	
	# 添加到列表
	if hero_list:
		for hero in sorted_heroes:
			var item = HBoxContainer.new()
			item.add_theme_constant_override("spacing", 15)
			item.custom_minimum_size = Vector2(0, 30)
			
			# 稀有度颜色标记
			var rarity_icon = Label.new()
			rarity_icon.text = "■"
			rarity_icon.modulate = get_rarity_color(hero.rarity)
			rarity_icon.add_theme_font_size_override("font_size", 20)
			item.add_child(rarity_icon)
			
			# 武将名称
			var name_label = Label.new()
			name_label.text = hero.name
			name_label.custom_minimum_size = Vector2(100, 0)
			name_label.add_theme_font_size_override("font_size", 18)
			item.add_child(name_label)
			
			# 势力
			var faction_label = Label.new()
			faction_label.text = "【%s】" % hero.faction
			faction_label.custom_minimum_size = Vector2(40, 0)
			faction_label.modulate = Color(0.7, 0.7, 0.7)
			faction_label.add_theme_font_size_override("font_size", 16)
			item.add_child(faction_label)
			
			# 技能
			var skill_label = Label.new()
			skill_label.text = "技能：" + hero.skill
			skill_label.modulate = Color(0.8, 0.8, 0.8)
			skill_label.add_theme_font_size_override("font_size", 16)
			item.add_child(skill_label)
			
			hero_list.add_child(item)

# 获取稀有度颜色
func get_rarity_color(rarity: int) -> Color:
	var colors = [Color(1,1,1), Color(0,1,0), Color(0,0.5,1), Color(0.8,0,0.8), Color(1,0.5,0)]
	return colors[rarity-1]
