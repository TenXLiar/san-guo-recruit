extends Control
class_name LineupUI

# 阵容配置
const GRID_SIZE: int = 3  # 3x3九宫格
const MAX_POSITION: int = GRID_SIZE * GRID_SIZE  # 9个位置

# 信号
signal back_requested # 点击返回按钮发送

# 节点引用 - 懒加载获取
var grid: GridContainer = null
var hero_list: VBoxContainer = null
var save_button: Button = null
var bond_details: Label = null

# 当前阵容：数组长度为9，元素为武将ID，空位为null
var current_lineup: Array = []
# 当前选中的武将ID（用于拖拽/点击放置）
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
	
	# 连接信号
	if save_button:
		save_button.connect("pressed", Callable(self, "save_lineup"))
	
	# 连接返回按钮
	var back_btn = get_node_or_null("BackButton")
	if back_btn:
		back_btn.connect("pressed", Callable(self, "_on_back_clicked"))

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
		var cell = Button.new()
		cell.name = "Cell_%d" % i
		cell.custom_minimum_size = Vector2(80, 80)
		cell.text = "空位"
		cell.connect("pressed", Callable(self, "_on_cell_pressed").bind(i))
		grid.add_child(cell)
		grid_cells[i] = cell

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
		var hero_data = HeroLibrary.instance.get_hero_data(hero_id)
		var button = Button.new()
		button.text = hero_data.get("name", "未知")
		button.name = hero_id
		button.custom_minimum_size = Vector2(120, 40)
		button.connect("pressed", Callable(self, "_on_hero_selected").bind(hero_id))
		hero_list.add_child(button)

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
	
	var cell = grid_cells[position]
	var hero_id = current_lineup[position]
	
	if hero_id:
		var hero_data = HeroLibrary.instance.get_hero_data(hero_id)
		cell.text = hero_data.get("name", "未知")
		# 根据势力设置颜色
		var faction = hero_data.get("faction", "")
		match faction:
			"wei": cell.add_theme_color_override("font_color", Color(0, 0.5, 1))  # 蓝色-魏国
			"shu": cell.add_theme_color_override("font_color", Color(0.8, 0, 0))  # 红色-蜀国
			"wu": cell.add_theme_color_override("font_color", Color(0, 0.7, 0))   # 绿色-吴国
			"qun": cell.add_theme_color_override("font_color", Color(0.7, 0, 0.7)) # 紫色-群雄
	else:
		cell.text = "空位"
		cell.add_theme_color_override("font_color", Color(1, 1, 1))

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

# 刷新武将列表（武将库变化时调用）
func refresh_hero_list():
	if hero_list:
		load_hero_list()
