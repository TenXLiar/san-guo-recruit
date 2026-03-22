extends Control
class_name LineupUI

# 阵容配置
const GRID_SIZE: int = 3  # 3x3九宫格
const MAX_POSITION: int = GRID_SIZE * GRID_SIZE  # 9个格子，只放上阵武将
const MAX_UPFRONT: int = 3  # MVP固定上阵人数上限3
# 镇守槽位：初始1个，每征服一个区域+1 → 从RegionManager获取

# 武将状态：每个已拥有武将记录状态 "upfront" 或 "guard"
var hero_states: Dictionary = {}  # {hero_id: "upfront"/"guard"}

# 信号
signal back_requested # 点击返回按钮发送
signal stats_updated # 状态更新后触发，用于更新产出统计

# 节点引用 - 懒加载获取
var grid: GridContainer = null
var hero_list: VBoxContainer = null
var save_button: Button = null
var bond_details: Label = null
var stats_label: Label = null  # 显示上阵/镇守统计

# 当前阵容：九宫格数组，元素为武将ID，空位为null → 只放上阵武将
var current_lineup: Array = []
# 当前选中的武将ID（用于点击放置）
var selected_hero_id: String = ""
# 所有格子节点引用
var grid_cells: Array = []

func _ready():
	# 打印所有子节点，方便调试
	print("LineupUI 所有子节点:")
	for child in get_children():
		print("  - ", child.name)
	
	# 获取节点引用 - 路径根据实际节点名称调整
	grid = get_node_or_null("GridContainer")
	hero_list = get_node_or_null("ScrollContainer#VBoxContainer")
	save_button = get_node_or_null("SaveButton")
	bond_details = get_node_or_null("BondInfo#BondDetails")
	
	if not grid:
		print("LineupUI: 找不到GridContainer节点")
	if not hero_list:
		print("LineupUI: 找不到ScrollContainer#VBoxContainer节点")
	if not save_button:
		print("LineupUI: 找不到SaveButton节点")
	if not bond_details:
		print("LineupUI: 找不到BondInfo#BondDetails节点")
	
	# 初始化阵容数组
	current_lineup.resize(MAX_POSITION)
	current_lineup.fill(null)
	
	# 创建九宫格
	if grid:
		create_grid()
	# 加载武将列表
	if hero_list:
		load_hero_list()
	# 加载保存的阵容
	load_lineup()
	
	# 更新羁绊显示
	if bond_details:
		update_bond_display()
	
	# 获取统计标签
	stats_label = get_node_or_null("StatsLabel")
	
	# 初始化武将状态（所有武将默认upfront）
	var owned_heroes = HeroLibrary.instance.get_hero_list()
	for hero_id in owned_heroes:
		if not hero_states.has(hero_id):
			hero_states[hero_id] = "upfront"  # 默认上阵
	
	# 连接信号
	if save_button:
		save_button.connect("pressed", Callable(self, "save_lineup"))
	
	# 连接清空按钮
	var clear_btn = get_node_or_null("ClearButton")
	if clear_btn:
		clear_btn.connect("pressed", Callable(self, "clear_lineup"))
	
	# 连接返回按钮
	var back_btn = get_node_or_null("BackButton")
	if back_btn:
		back_btn.connect("pressed", Callable(self, "_on_back_clicked"))
	
	# 更新统计显示
	update_stats_display()

func _on_back_clicked():
	back_requested.emit()

# 监听ESC快捷键返回
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_back_clicked()

# 创建九宫格
func create_grid():
	grid.columns = GRID_SIZE
	grid_cells.resize(MAX_POSITION)
	
	for i in range(MAX_POSITION):
		# 每个格子是一个容器，包含背景纹理和点击按钮
		var container = VBoxContainer.new()
		container.name = "Container_%d" % i
		container.custom_minimum_size = Vector2(90, 90)
		container.spacing = 0
		
		# 头像纹理
		var tex_rect = TextureRect.new()
		tex_rect.name = "Portrait"
		tex_rect.custom_minimum_size = Vector2(80, 80)
		tex_rect.stretch_mode = 2  # STRETCH_MODE_KEEP_ASPECT_COVERED = 2
		container.add_child(tex_rect)
		
		# 透明按钮接收点击
		var cell = Button.new()
		cell.name = "Cell_%d" % i
		cell.custom_minimum_size = Vector2(80, 80)
		cell.text = ""
		cell.modulate = Color(1, 1, 1, 0.01)  # 几乎透明
		cell.connect("pressed", Callable(self, "_on_cell_pressed").bind(i))
		container.add_child(cell)
		
		grid.add_child(container)
		grid_cells[i] = container

# 加载武将列表
func load_hero_list():
	# 清空现有列表
	if not hero_list:
		return
	
	for child in hero_list.get_children():
		child.queue_free()
	
	# 获取所有已拥有的武将
	var owned_heroes = HeroLibrary.instance.get_hero_list()
	print("LineupUI: 加载", owned_heroes.size(), "个已拥有武将")
	
	for hero_id in owned_heroes:
		# 创建水平容器放按钮和状态切换
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(200, 40)
		
		# 武将选择按钮
		var button = Button.new()
		button.text = HeroLibrary.instance.get_hero_data(hero_id).get("name", "未知")
		button.name = hero_id
		button.custom_minimum_size = Vector2(120, 40)
		button.connect("pressed", Callable(self, "_on_hero_selected").bind(hero_id))
		hbox.add_child(button)
		
		# 状态切换按钮
		var state_btn = Button.new()
		state_btn.name = "StateBtn_" + hero_id
		state_btn.custom_minimum_size = Vector2(70, 40)
		_update_state_button_text(state_btn, hero_states[hero_id])
		state_btn.connect("pressed", Callable(self, "_toggle_hero_state").bind(hero_id, state_btn))
		hbox.add_child(state_btn)
		
		hero_list.add_child(hbox)

# 武将选择事件
func _on_hero_selected(hero_id: String):
	selected_hero_id = hero_id
	print("LineupUI: 选择了武将：", hero_id)

# 格子点击事件
func _on_cell_pressed(position: int):
	if selected_hero_id == "":
		return
	
	if not grid_cells[position]:
		return
	
	# 检查是否已经在阵容中
	if current_lineup.find(selected_hero_id) != -1:
		print("LineupUI: 该武将已经在阵容中")
		return
	
	# 放置武将
	current_lineup[position] = selected_hero_id
	update_grid_cell(position)
	if bond_details:
		update_bond_display()

# 更新格子显示
func update_grid_cell(position: int):
	if position < 0 or position >= MAX_POSITION:
		return
	
	if not grid_cells[position]:
		return
	
	var container = grid_cells[position]
	var portrait = container.get_node_or_null("Portrait")
	var cell_btn = container.get_node_or_null("Cell_%d" % position) % position
	var hero_id = current_lineup[position]
	
	if hero_id and portrait:
		var hero_data = HeroLibrary.instance.get_hero_data(hero_id)
		# 加载头像纹理
		if hero_data.has("image_path") and portrait:
			var tex = load(hero_data.image_path)
			if tex:
				portrait.texture = tex
				# 根据势力染色边框
				var faction = hero_data.get("faction", "")
				match faction:
					"wei": portrait.modulate = Color(0, 0.5, 1)  # 蓝色-魏国
					"shu": portrait.modulate = Color(0.8, 0, 0)  # 红色-蜀国
					"wu": portrait.modulate = Color(0, 0.7, 0)   # 绿色-吴国
					"qun": portrait.modulate = Color(0.7, 0, 0.7) # 紫色-群雄
		else:
			portrait.texture = null
			portrait.modulate = Color(1, 1, 1)
	else:
		if portrait:
			portrait.texture = null
			portrait.modulate = Color(1, 1, 1)

# 更新所有格子
func update_all_cells():
	for i in range(MAX_POSITION):
		update_grid_cell(i)

# 保存阵容
func save_lineup():
	# 保存到存档系统（临时打印）
	print("LineupUI: 保存阵容：", current_lineup)
	# TODO: 调用存档系统保存
	# SaveManager.instance.save_data()

# 加载阵容
func load_lineup():
	# 从存档系统加载（临时初始化）
	# TODO: 调用存档系统加载
	current_lineup.fill(null)
	update_all_cells()

# 获取当前阵容
func get_current_lineup() -> Array:
	return current_lineup.duplicate()

# 获取上阵武将总战力
func get_total_combat_power() -> float:
	var total: float = 0.0
	for hero_id in current_lineup:
		if hero_id:
			var hero_data = HeroLibrary.instance.get_hero_data(hero_id)
			# 战力计算：攻击*0.4 + 防御*0.3
			var power = hero_data.get("attack", 0) * 0.4 + \
						hero_data.get("defense", 0) * 0.3
			total += power * (1 + hero_data.get("rarity", 1) * 0.2)  # 稀有度加成
	return total

# 获取上阵武将按势力分组
func get_heroes_by_faction() -> Dictionary:
	var factions = {
		"wei": 0,
		"shu": 0,
		"wu": 0,
		"qun": 0
	}
	
	for hero_id in current_lineup:
		if hero_id:
			var hero_data = HeroLibrary.instance.get_hero_data(hero_id)
			var faction = hero_data.get("faction", "")
			if factions.has(faction):
				factions[faction] += 1
	
	return factions

# 更新羁绊显示
func update_bond_display():
	if not bond_details:
		return
	
	# 获取势力统计
	var factions = get_heroes_by_faction()
	var active_bonds = BondManager.instance.get_active_bonds(factions)
	
	if active_bonds.is_empty():
		bond_details.text = "暂无羁绊激活"
		return
	
	var text: String = ""
	for bond in active_bonds:
		text += "✅ " + bond.name + ": " + bond.description + "\n"
	
	bond_details.text = text
	# 更新全局羁绊加成
	BondManager.instance.calculate_all_bonuses(factions)

# 切换武将状态
func _toggle_hero_state(hero_id: String, button: Button):
	var current_state = hero_states[hero_id]
	if current_state == "upfront":
		hero_states[hero_id] = "guard"
	else:
		hero_states[hero_id] = "upfront"
	# 更新按钮文字
	_update_state_button_text(button, hero_states[hero_id])
	# 重新计算统计
	update_stats_display()
	stats_updated.emit()
	print("[LineupUI] 切换 %s 状态 -> %s" % [hero_id, hero_states[hero_id]])

# 更新状态按钮文字
func _update_state_button_text(button: Button, state: String):
	if state == "upfront":
		button.text = "⚔️上阵"
		button.add_theme_color_override("font_color", Color(0, 1, 0))
	else:
		button.text = "🏯镇守"
		button.add_theme_color_override("font_color", Color(1, 0.8, 0))

# 更新统计显示
func update_stats_display():
	if not stats_label:
		return
	
	var stats = calculate_total_stats()
	var text = "上阵: %d/%d  |  镇守槽: %d/%d\n" % [stats.upfront_count, get_max_upfront(), stats.guard_count, get_max_guard_slots()]
	text += "总勇武（镇守）: %.1f  |  总智略（镇守）: %.1f" % [stats.total_guard_bravery, stats.total_guard_wisdom]
	stats_label.text = text
	
	# 更新IdleManager的镇守属性
	IdleManager.instance.update_guard_stats(stats.total_guard_bravery, stats.total_guard_wisdom)

# 计算总统计：上阵数量、镇守数量、总勇武、总智略
func calculate_total_stats() -> Dictionary:
	var result = {
		"upfront_count": 0,
		"guard_count": 0,
		"total_guard_bravery": 0.0,
		"total_guard_wisdom": 0.0
	}
	
	# 遍历所有已拥有武将，按状态统计
	var owned_heroes = HeroLibrary.instance.get_hero_list()
	for hero_id in owned_heroes:
		var state = hero_states.get(hero_id, "upfront")
		var hero_data = HeroLibrary.instance.get_hero_data(hero_id)
		
		if state == "upfront":
			result.upfront_count += 1
		else:
			result.guard_count += 1
			# 镇守武将贡献属性
			# force = 勇武（武力），intelligence = 智略（智力）
			if hero_data.has("force"):
				result.total_guard_bravery += hero_data.force
			if hero_data.has("intelligence"):
				result.total_guard_wisdom += hero_data.intelligence
	
	return result

# 获取最大上阵人数
func get_max_upfront() -> int:
	return MAX_UPFRONT

# 获取最大镇守槽位
func get_max_guard_slots() -> int:
	return RegionManager.instance.get_available_guard_slots()

# 检查是否可以切换到upfront（是否超过上限）
func can_switch_to_upfront() -> bool:
	var stats = calculate_total_stats()
	return stats.upfront_count < get_max_upfront()

# 检查是否可以切换到guard（是否超过上限）
func can_switch_to_guard() -> bool:
	var stats = calculate_total_stats()
	return stats.guard_count < get_max_guard_slots()

# 获取上阵总勇武+智略（用于攻城进度）
func get_total_progress_stats() -> Dictionary:
	var result = {
		"total_bravery": 0.0,
		"total_wisdom": 0.0
	}
	
	# 遍历所有已拥有武将，只统计上阵
	var owned_heroes = HeroLibrary.instance.get_hero_list()
	for hero_id in owned_heroes:
		var state = hero_states.get(hero_id, "upfront")
		var hero_data = HeroLibrary.instance.get_hero_data(hero_id)
		
		if state == "upfront":
			# force = 勇武（武力），intelligence = 智略（智力）
			if hero_data.has("force"):
				result.total_bravery += hero_data.force
			if hero_data.has("intelligence"):
				result.total_wisdom += hero_data.intelligence
	
	return result

# 刷新武将列表（武将库变化时调用）
func refresh_hero_list():
	if hero_list:
		load_hero_list()
	update_stats_display()
