extends Control

# 九宫格大小
const GRID_SIZE = 3
const MAX_POSITION = GRID_SIZE * GRID_SIZE  # 3x3 = 9 个格子
const MAX_BATTLE_SLOTS = 3  # 最多上阵人数限制

# UI 节点引用
var grid: GridContainer
var bond_info: VBoxContainer
var bond_details: Label
var stats_label: Label

# 数据
var current_lineup: Array = []  # 每个位置保存 {id, data, is_battle: bool} 格式
var selected_hero_id: String = ""
var current_selected_button: Button = null
var current_selected_hero: Dictionary = {}

# 武将库引用
var hero_library: Node = null

# 信号
signal lineup_saved
signal back_requested

func _ready():
	# 初始化九宫格数组（9个空位）
	for i in range(MAX_POSITION):
		current_lineup.append(null)
	
	grid = get_node("LeftContainer/GridContainer") as GridContainer
	bond_info = get_node("LeftContainer/BondInfo") as VBoxContainer
	bond_details = get_node("LeftContainer/BondInfo/BondDetails") as Label
	stats_label = get_node("LeftContainer/BondInfo/StatsLabel") as Label
	
	# 获取武将库单例
	hero_library = HeroLibrary.instance
	
	# 添加背景蒙板，确保不被背景图挡住
	add_background_mask()
	
	if not grid:
		push_error("无法找到 GridContainer 节点")
		return
	if not bond_details or not stats_label:
		push_error("无法找到羁绊或属性标签")
	
	create_grid()
	load_saved_lineup()
	update_bond_info()
	update_stats()
	
	# 绑定按钮信号
	var save_btn = get_node_or_null("ButtonContainer/SaveButton")
	if save_btn:
		save_btn.pressed.connect(_on_save_pressed)
	
	var clear_btn = get_node_or_null("ButtonContainer/ClearButton")
	if clear_btn:
		clear_btn.pressed.connect(_on_clear_pressed)
	
	var back_btn = get_node_or_null("ButtonContainer/BackButton")
	if back_btn:
		back_btn.pressed.connect(_on_back_clicked)
	
	# 监听ESC快捷键返回
	mouse_filter = MOUSE_FILTER_STOP
	
	# 确保GridContainer能接收鼠标事件
	if grid:
		grid.mouse_filter = MOUSE_FILTER_STOP
	
	# 延迟打印尺寸，确保布局完成
	call_deferred("_debug_print_sizes")
	await get_tree().process_frame
	grid.queue_sort()
func _debug_print_sizes():
	print("Grid size: ", grid.size)
	print("Grid child count: ", grid.get_child_count())
	print("LeftContainer size: ", get_node("LeftContainer").size)
	print("LineupUI size: ", size)

# 添加背景蒙板，挡住下方的主背景
func add_background_mask():
	# 创建一个全屏颜色矩形作为背景，放在最底层
	var bg = ColorRect.new()
	bg.name = "BackgroundMask"
	bg.anchors_preset = 15
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_right = -2.0
	bg.offset_bottom = -1.0
	bg.color = Color(0.15, 0.15, 0.15, 0.95)  # 半透明深色蒙板
	bg.mouse_filter = MOUSE_FILTER_IGNORE  # 不阻挡点击
	add_child(bg)
	# 移动到最底层
	move_child(bg, 0)

# 统计当前上阵人数
func count_battle_heroes() -> int:
	var count = 0
	for slot in current_lineup:
		if slot != null and slot.get("is_battle", false):
			count += 1
	return count

# 切换格子武将状态（上阵 ↔ 镇守）
func _toggle_cell_state(index: int):
	var slot = current_lineup[index]
	if slot == null:
		return
	
	var current_is_battle = slot.get("is_battle", false)
	var new_is_battle = !current_is_battle
	
	# 如果要切换到上阵，检查是否已满3人
	if new_is_battle:
		var current_count = count_battle_heroes()
		if current_count >= MAX_BATTLE_SLOTS:
			print("[Lineup] 上阵人数已满（最多%d人），无法切换" % MAX_BATTLE_SLOTS)
			return
	
	# 执行切换
	slot["is_battle"] = new_is_battle
	_update_cell_visual(index)
	update_stats()
	print("格子%d 切换: %s → %s" % [index, ["镇守", "上阵"][int(current_is_battle)], ["镇守", "上阵"][int(new_is_battle)]])

func create_grid():
	if not grid:
		return
	
	# 设置 GridContainer 样式（同前）
	grid.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	var grid_style = grid.get_theme_stylebox("panel")
	if grid_style is StyleBoxFlat:
		grid_style.bg_color = Color(0.18, 0.18, 0.18, 0.95)
		grid_style.border_width_left = 3
		grid_style.border_width_right = 3
		grid_style.border_width_top = 3
		grid_style.border_width_bottom = 3
		grid_style.border_color = Color(1, 1, 1, 0.7)
	
	grid.columns = GRID_SIZE
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	
	for i in range(MAX_POSITION):
		var container = VBoxContainer.new()
		container.custom_minimum_size = Vector2(94, 94)
		container.spacing = 2
		
		# 格子背景样式（同前）
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.3, 0.4, 1.0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(1, 1, 1, 0.9)
		container.add_theme_stylebox_override("panel", style)
		
		# 头像区域（图片）
		var tex_rect = TextureRect.new()
		tex_rect.name = "Portrait"
		tex_rect.custom_minimum_size = Vector2(64, 64)
		tex_rect.expand = true
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture = null
		container.add_child(tex_rect)
		
		# 状态标签（显示 上阵/镇守）
		var state_label = Label.new()
		state_label.name = "StateLabel"
		state_label.text = "空位"
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.add_theme_font_size_override("font_size", 10)
		container.add_child(state_label)
		
		# 透明按钮（关键修改：填充整个容器）
		var cell_btn = Button.new()
		cell_btn.name = "Cell_%d" % i
		cell_btn.flat = false
		cell_btn.modulate = Color(1, 1, 1, 0.4)
		cell_btn.text = str(i)
		# 锚点设置：填充整个容器
		cell_btn.anchor_left = 0.0
		cell_btn.anchor_top = 0.0
		cell_btn.anchor_right = 1.0
		cell_btn.anchor_bottom = 1.0
		cell_btn.offset_left = 0
		cell_btn.offset_top = 0
		cell_btn.offset_right = 0
		cell_btn.offset_bottom = 0
		cell_btn.pressed.connect(_on_cell_pressed.bind(i))
		container.add_child(cell_btn)
		
		container.set_meta("index", i)
		container.set_meta("button", cell_btn)
		container.set_meta("state_label", state_label)
		
		grid.add_child(container)
	
	# 提升层级（已存在）
	if grid.get_parent():
		grid.get_parent().move_child(grid, -1)
		grid.z_index = 20
	else:
		push_error("GridContainer 没有父节点，无法调整层级")

# 设置已拥有武将列表（由Main调用设置）
func set_owned_heroes(owned_heroes: Dictionary):
	var container = get_node("RightContainer/ScrollContainer/VBoxContainer") as VBoxContainer
	if not container:
		push_error("找不到RightContainer/ScrollContainer/VBoxContainer")
		return
	
	# 清空现有列表
	for child in container.get_children():
		child.queue_free()
	
	# 按稀有度排序添加
	var rarity_order = [1, 2, 3, 4, 5]
	for rarity in rarity_order:
		for hero_id in owned_heroes:
			var hero_data = owned_heroes[hero_id]
			if hero_data.rarity == rarity:
				_add_hero_button(hero_data, container)

func _add_hero_button(hero_data: Dictionary, container: VBoxContainer):
	# 获取稀有度颜色
	var rarity_colors = [
		Color(1, 1, 1),
		Color(0, 1, 0),
		Color(0, 0.5, 1),
		Color(0.8, 0, 0.8),
		Color(1, 0.5, 0)
	]
	
	var btn = Button.new()
	btn.name = "Hero_" + hero_data.id
	btn.text = "%s (%s) - %s" % [hero_data.name, ["白", "绿", "蓝", "紫", "橙"][hero_data.rarity-1], "💪 " + str(hero_data.attack) + " / " + str(hero_data.defense)]
	btn.custom_minimum_size = Vector2(0, 50)
	btn.modulate = rarity_colors[hero_data.rarity-1]
	btn.pressed.connect(_on_hero_selected.bind(hero_data, btn))
	container.add_child(btn)

func load_saved_lineup():
	# 从SaveManager加载保存的阵容
	var saved = SaveManager.load_lineup()
	if saved and saved.size() == MAX_POSITION:
		current_lineup = saved
		# 兼容旧存档（直接存data不是slot）
		for i in range(MAX_POSITION):
			if current_lineup[i] != null and not current_lineup[i].has("data"):
				# 转换旧格式到新格式，默认镇守
				current_lineup[i] = {
					"id": current_lineup[i].id,
					"data": current_lineup[i],
					"is_battle": false
				}
			_update_cell_visual(i)
		# 加载后更新IdleManager镇守属性
		var total_guard_attack: float = 0.0
		var total_guard_defense: float = 0.0
		for slot in current_lineup:
			if slot != null:
				var hero_data = slot.get("data", {})
				var is_battle = slot.get("is_battle", false)
				if not is_battle:
					total_guard_attack += float(hero_data.get("attack", 0))
					total_guard_defense += float(hero_data.get("defense", 0))
		IdleManager.update_guard_stats(total_guard_attack, total_guard_defense)
		print("已加载保存的阵容，更新镇守属性: 勇武 %.1f 智略 %.1f" % [total_guard_attack, total_guard_defense])
	else:
		# 空阵容，属性清零
		IdleManager.update_guard_stats(0, 0)
	print("已加载保存的阵容")

# 获取上阵总属性（供ProgressManager使用）
func get_total_progress_stats() -> Dictionary:
	var total_bravery: float = 0.0
	var total_wisdom: float = 0.0
	for slot in current_lineup:
		if slot != null:
			var hero_data = slot.get("data", {})
			var is_battle = slot.get("is_battle", false)
			if is_battle:
				total_bravery += float(hero_data.get("attack", 0))
				total_wisdom += float(hero_data.get("defense", 0))
	return {
		"total_bravery": total_bravery,
		"total_wisdom": total_wisdom
	}

# 计算所有镇守总属性（已在update_stats中调用，这里提供给外部）
func calculate_total_stats() -> Dictionary:
	var total_guard_bravery: float = 0.0
	var total_guard_wisdom: float = 0.0
	for slot in current_lineup:
		if slot != null:
			var hero_data = slot.get("data", {})
			var is_battle = slot.get("is_battle", false)
			if not is_battle:
				total_guard_bravery += float(hero_data.get("attack", 0))
				total_guard_wisdom += float(hero_data.get("defense", 0))
	return {
		"total_guard_bravery": total_guard_bravery,
		"total_guard_wisdom": total_guard_wisdom
	}

func save_lineup():
	# 保存到SaveManager
	SaveManager.save_lineup(current_lineup)
	print("阵容已保存")

func update_bond_info():
	if bond_details:
		# 这里后续可以添加羁绊系统，现在先显示占位
		var placed_count = 0
		for h in current_lineup:
			if h != null:
				placed_count += 1
		
		if placed_count == 0:
			bond_details.text = "尚未放置武将\n请点击左侧武将，然后点击九宫格空位放置"
		elif placed_count < MAX_POSITION:
			bond_details.text = "羁绊系统开发中...\n已放置 %d/%d 个武将" % [placed_count, MAX_POSITION]
		else:
			bond_details.text = "九宫格已满\n羁绊系统开发中..."

func update_stats():
	if stats_label:
		var battle_count: int = 0
		var guard_count: int = 0
		var total_battle_attack: float = 0.0  # 上阵总勇武（攻城进度）
		var total_battle_defense: float = 0.0  # 上阵总智略（攻城进度）
		var total_guard_attack: float = 0.0  # 镇守总勇武（产兵）
		var total_guard_defense: float = 0.0  # 镇守总智略（产钱粮）
		
		for slot in current_lineup:
			if slot != null:
				var hero_data = slot.get("data", {})
				var is_battle = slot.get("is_battle", false)
				if is_battle:
					battle_count += 1
					total_battle_attack += float(hero_data.get("attack", 0))
					total_battle_defense += float(hero_data.get("defense", 0))
				else:
					guard_count += 1
					total_guard_attack += float(hero_data.get("attack", 0))
					total_guard_defense += float(hero_data.get("defense", 0))
		
		stats_label.text = "上阵: %d/%d\n总勇武: %.1f  |  总智略: %.1f\n镇守: %d人\n产出加成: 兵 %.1f/秒  钱 %.1f/秒 粮 %.1f/秒" % [
			battle_count, MAX_BATTLE_SLOTS, 
			total_battle_attack, total_battle_defense,
			guard_count,
			total_guard_attack * 0.1,
			total_guard_defense * 0.05,
			total_guard_defense * 0.05
		]

# 选中左侧武将
func _on_hero_selected(hero_data: Dictionary, button: Button):
	# 取消之前选中
	if current_selected_button:
		current_selected_button.disabled = false
	
	# 选中新的
	selected_hero_id = hero_data.id
	current_selected_button = button
	current_selected_hero = hero_data
	current_selected_button.disabled = true
	
	print("选中武将: " + hero_data.name)

# 点击九宫格格子
func _on_cell_pressed(index: int):
	print("格子 ", index, " 被点击")
	if selected_hero_id == "":
		# 没有选中武将，如果格子有武将，切换状态（上阵/镇守）
		if current_lineup[index] != null:
			_toggle_cell_state(index)
		return
	
	# 实际上，_on_hero_selected 已经拿到了完整的 hero_data，我们已经保存了
	if current_selected_hero != {}:
		# 如果要放置为上阵，检查是否已经满了3个上阵
		# 默认新放置都是镇守，用户可以点击切换
		var battle_count = count_battle_heroes()
		# 放置数据结构包含状态
		var new_slot = {
			"id": current_selected_hero.id,
			"data": current_selected_hero,
			"is_battle": false  # 默认镇守
		}
		current_lineup[index] = new_slot
		_update_cell_visual(index)
		update_bond_info()
		update_stats()
		print("放置武将 " + current_selected_hero.name + " 到格子 " + str(index) + " 状态：镇守")

# 监听ESC快捷键返回
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_back_clicked()

func _on_save_pressed():
	save_lineup()
	# 更新IdleManager镇守属性，影响钱粮兵产出（只有镇守武将贡献）
	var total_guard_attack: float = 0.0
	var total_guard_defense: float = 0.0
	for slot in current_lineup:
		if slot != null:
			var hero_data = slot.get("data", {})
			var is_battle = slot.get("is_battle", false)
			if not is_battle:
				total_guard_attack += float(hero_data.get("attack", 0))
				total_guard_defense += float(hero_data.get("defense", 0))
	# 更新到IdleManager，勇武对应attack，智略对应defense
	IdleManager.update_guard_stats(total_guard_attack, total_guard_defense)
	lineup_saved.emit()
	# 显示保存提示
	print("阵容已保存，更新镇守属性: 勇武 %.1f 智略 %.1f" % [total_guard_attack, total_guard_defense])

func _on_clear_pressed():
	for i in range(MAX_POSITION):
		current_lineup[i] = null
		_update_cell_visual(i)
	if current_selected_button:
		current_selected_button.disabled = false
	selected_hero_id = ""
	current_selected_button = null
	update_bond_info()
	update_stats()
	# 清空后更新镇守属性为0
	IdleManager.update_guard_stats(0, 0)
	print("阵容已清空")

func _on_back_clicked():
	back_requested.emit()

func _update_cell_visual(index: int):
	if not grid:
		return
	
	var container = grid.get_child(index)
	if container:
		var tex_rect = container.get_node("Portrait") as TextureRect
		var state_label = container.get_meta("state_label", null) as Label
		var slot = current_lineup[index]
		
		if slot != null:
			var hero = slot.get("data", {})
			var is_battle = slot.get("is_battle", false)
			# 根据id加载头像纹理
			var image_path = "res://assets/images/%s.png" % hero.id
			var tex = load(image_path)
			if tex:
				tex_rect.texture = tex
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				# 根据稀有度上色
				var rarity_colors = [
					Color(1, 1, 1),
					Color(0, 1, 0),
					Color(0, 0.5, 1),
					Color(0.8, 0, 0.8),
					Color(1, 0.5, 0)
				]
				tex_rect.modulate = rarity_colors[hero.rarity-1]
				# 更新状态标签颜色和文字
				if state_label:
					state_label.text = ["镇守", "上阵"][int(is_battle)]
					if is_battle:
						state_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # 上阵红色
					else:
						state_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))  # 镇守绿色
			else:
				# 加载失败，显示一个占位色块
				tex_rect.texture = null
				# 设置一个背景色（临时）
				tex_rect.add_theme_stylebox_override("panel", StyleBoxFlat.new())
				var placeholder_style = tex_rect.get_theme_stylebox("panel")
				if placeholder_style is StyleBoxFlat:
					placeholder_style.bg_color = Color(0.5, 0.5, 0.5)
				push_error("无法加载头像: " + image_path)
				if state_label:
					state_label.text = "缺失"
		else:
			tex_rect.texture = null
			if state_label:
				state_label.text = "空位"
				state_label.add_theme_color_override("font_color", Color(1, 1, 1))
