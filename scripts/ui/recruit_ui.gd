extends Control

# 信号
signal recruit_requested      # 点击单抽按钮时发送信号
signal recruit_ten_requested  # 点击十连按钮时发送信号
signal back_requested         # 点击返回按钮时发送信号

# 九宫格格子数组
var grid_slots: Array[TextureRect] = []
var last_results: Array[Dictionary] = []

func _ready():
	# 让根节点接收鼠标点击
	mouse_filter = MOUSE_FILTER_STOP
	
	# 收集九宫格格子
	grid_slots.clear()
	var grid = get_node_or_null("GridContainer")
	if grid:
		for i in range(9):
			var slot = grid.get_node_or_null("Slot%d" % i)
			if slot:
				grid_slots.append(slot)
				# 初始清空
				slot.texture = null
				slot.modulate = Color(0.3, 0.3, 0.3)
	
	# 安全绑定单抽按钮信号
	var btn = get_node_or_null("ButtonsContainer/RecruitButton")
	if btn:
		if not btn.is_connected("pressed", _on_recruit_clicked):
			btn.mouse_filter = MOUSE_FILTER_STOP
			btn.connect("pressed", _on_recruit_clicked)
	
	# 安全绑定十连按钮信号
	var btn_ten = get_node_or_null("ButtonsContainer/RecruitTenButton")
	if btn_ten:
		if not btn_ten.is_connected("pressed", _on_recruit_ten_clicked):
			btn_ten.mouse_filter = MOUSE_FILTER_STOP
			btn_ten.connect("pressed", _on_recruit_ten_clicked)
	
	# 绑定返回按钮信号
	var back_btn = get_node_or_null("BackButton")
	if back_btn:
		if not back_btn.is_connected("pressed", _on_back_clicked):
			back_btn.connect("pressed", _on_back_clicked)

# 快捷键：F单抽，R十连，ESC返回
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_back_clicked()
		elif event.keycode == KEY_F:
			_on_recruit_clicked()
		elif event.keycode == KEY_R:
			_on_recruit_ten_clicked()

# 清空九宫格
func clear_grid():
	for i in range(grid_slots.size()):
		if i < grid_slots.size():
			var slot = grid_slots[i]
			slot.texture = null
			slot.modulate = Color(0.3, 0.3, 0.3)
	last_results.clear()

# 显示国运不足提示
func show_gdp_not_enough(cost: int = 100):
	var result_label = get_node_or_null("ResultLabel")
	if result_label:
		result_label.text = "❌ 国运点不足，需要 %d 点才能招募" % [cost]
		result_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))

# 显示单次抽卡结果（单抽）
func show_result(hero_data: Dictionary, is_new: bool, rarity_name: String, rarity_color: Color, fragments: int = 0):
	# 清空九宫格，只在中心显示这个武将
	clear_grid()
	
	var result_label = get_node_or_null("ResultLabel")
	var center_slot = grid_slots[4]  # 中心位置 (第5个，索引4)
	
	if result_label:
		result_label.add_theme_color_override("font_color", rarity_color)
		if is_new:
			var name = hero_data.get("name", "无名")
			var attack = int(hero_data.get("attack", 0))
			var defense = int(hero_data.get("defense", 0))
			var text = "🎉 获得新武将：%s (%s)\n💪 勇武：%d  |  智略：%d" % [name, rarity_name, attack, defense]
			result_label.text = text
		else:
			var name = hero_data.get("name", "无名")
			var text = "📦 重复获得：%s\n已经转换为 %d 个碎片" % [name, fragments]
			result_label.text = text
			result_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
	
	# 显示武将头像在中心格子
	if center_slot and hero_data.has("image_path"):
		var tex = load(hero_data.image_path)
		if tex:
			center_slot.texture = tex
			center_slot.modulate = rarity_color
		else:
			center_slot.texture = null
			push_error("cannot load portrait: " + str(hero_data.image_path))
	
	last_results.append(hero_data)

# 显示十连抽结果（九宫格全部填满）
func show_ten_results(results: Array[Dictionary]):
	clear_grid()
	
	var result_label = get_node_or_null("ResultLabel")
	if result_label:
		var total_new: int = 0
		var total_rare: int = 0
		for r in results:
			if r.is_new:
				total_new += 1
			if r.rarity >= 3:  # 紫色或橙色
				total_rare += 1
		
		if total_new > 0:
			result_label.text = "✨ 十连抽完成！获得 %d 个新武将，其中 %d 个高品质武将" % [total_new, total_rare]
			result_label.add_theme_color_override("font_color", Color(0.8, 1, 0.6))
		else:
			result_label.text = "🔄 十连抽完成！所有武将都是重复，已全部转换为碎片"
			result_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	# 填充九宫格
	for i in range(min(results.size(), grid_slots.size())):
		var slot = grid_slots[i]
		var result = results[i]
		var hero_data = result.hero_data
		var rarity_color = result.rarity_color
		
		if hero_data.has("image_path"):
			var tex = load(hero_data.image_path)
			if tex:
				slot.texture = tex
				slot.modulate = rarity_color
			else:
				slot.texture = null
				push_error("cannot load portrait for slot %d: " % [i] + str(hero_data.image_path))
		else:
			slot.texture = null
			slot.modulate = Color(0.3, 0.3, 0.3)
		
		last_results.append(hero_data)

func _on_recruit_clicked():
	recruit_requested.emit()

func _on_recruit_ten_clicked():
	recruit_ten_requested.emit()

func _on_back_clicked():
	back_requested.emit()
