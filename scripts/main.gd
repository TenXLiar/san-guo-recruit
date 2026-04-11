extends Control
class_name MainUI

# 节点引用
@onready var gdp_label: Label = $TopBar/GDPLabel
@onready var prestige_label: Label = $TopBar/PrestigeLabel
@onready var money_label: Label = $TopBar/MoneyLabel
@onready var food_label: Label = $TopBar/FoodLabel
@onready var soldier_label: Label = $TopBar/SoldierLabel
@onready var region_name_btn: Button = $TopBar/RegionNameBtn
@onready var region_progress_bar: ProgressBar = $TopBar/RegionProgress
@onready var gm_add_gdp: Button = $TopBar/GMAddGDP
@onready var content_area: Control = $ContentArea
@onready var nav_buttons: HBoxContainer = $BottomNav
@onready var background_tex: TextureRect = $Background

# 区域详情弹窗
var region_detail_dialog: AcceptDialog = null

# 策略面板
var strategy_dialog: AcceptDialog = null
var strategy_vbox: VBoxContainer = null

# 策略定义
var STRATEGIES = [
	{
		"id": "speed_boost",
		"name": "犒赏三军",
		"description": "攻城速度+50%，持续30秒\n消耗：钱 50 + 粮 50",
		"cost_money": 50,
		"cost_food": 50,
		"cost_soldier": 0,
		"speed_bonus": 1.5,
		"duration": 30
	},
	{
		"id": "spying",
		"name": "间谍活动",
		"description": "下一次随机事件成功率+20%\n消耗：钱 30",
		"cost_money": 30,
		"cost_food": 0,
		"cost_soldier": 0,
		"event_bonus": 0.2,
		"duration": 1
	},
	{
		"id": "recruit_soldier",
		"name": "紧急征兵",
		"description": "立即获得大量兵力\n消耗：钱 50 + 粮 50\n获得：(钱+粮) * 0.8",
		"cost_money": 50,
		"cost_food": 50,
		"cost_soldier": 0,
		"soldier_multiplier": 0.8
	}
]

# 游戏数据
var current_gdp: float = 1000.0
var current_prestige: int = 0
var current_rank: int = 1000
var owned_heroes: Dictionary = {}
var hero_fragments: Dictionary = {}

# 🎮 挂机系统配置
var gdp_per_second: float = 1.0  # 每秒产出1点国运点
var offline_time_limit: int = 8 * 3600  # 最多累计8小时离线收益
var last_online_time: int = 0  # 上次在线时间
var offline_earned: float = 0  # 离线收益

# 武将配置（按稀有度分类）
var WHITE_HEROES: Array = [
	{"id": "wei_yujin", "name": "于禁", "rarity": 1, "faction": "魏", "skill": "毅重", "attack": 75, "defense": 85},
	{"id": "shu_weiyan", "name": "魏延", "rarity": 1, "faction": "蜀", "skill": "狂骨", "attack": 82, "defense": 76},
	{"id": "wu_huanggai", "name": "黄盖", "rarity": 1, "faction": "吴", "skill": "苦肉", "attack": 78, "defense": 80},
	{"id": "qun_dongzhuo", "name": "董卓", "rarity": 1, "faction": "群", "skill": "酒池肉林", "attack": 80, "defense": 75}
]

var GREEN_HEROES: Array = [
	{"id": "wei_caoren", "name": "曹仁", "rarity": 2, "faction": "魏", "skill": "据守", "attack": 78, "defense": 92},
	{"id": "shu_huangzhong", "name": "黄忠", "rarity": 2, "faction": "蜀", "skill": "百步穿杨", "attack": 86, "defense": 75},
	{"id": "wu_sunquan", "name": "孙权", "rarity": 2, "faction": "吴", "skill": "制衡", "attack": 82, "defense": 88},
	{"id": "qun_zhangjiao", "name": "张角", "rarity": 2, "faction": "群", "skill": "黄天太平", "attack": 80, "defense": 78}
]

var BLUE_HEROES: Array = [
	{"id": "wei_xiahoudun", "name": "夏侯惇", "rarity": 3, "faction": "魏", "skill": "刚烈", "attack": 88, "defense": 90},
	{"id": "wei_zhangliao", "name": "张辽", "rarity": 3, "faction": "魏", "skill": "突袭", "attack": 92, "defense": 86},
	{"id": "shu_zhaoyun", "name": "赵云", "rarity": 3, "faction": "蜀", "skill": "龙胆", "attack": 93, "defense": 89},
	{"id": "wu_lvmeng", "name": "吕蒙", "rarity": 3, "faction": "吴", "skill": "白衣渡江", "attack": 87, "defense": 85},
	{"id": "qun_yuanshao", "name": "袁绍", "rarity": 3, "faction": "群", "skill": "乱击", "attack": 85, "defense": 83}
]

var PURPLE_HEROES: Array = [
	{"id": "wei_caocao", "name": "曹操", "rarity": 4, "faction": "魏", "skill": "乱世奸雄", "attack": 95, "defense": 85},
	{"id": "shu_liubei", "name": "刘备", "rarity": 4, "faction": "蜀", "skill": "仁德", "attack": 80, "defense": 95},
	{"id": "shu_zhangfei", "name": "张飞", "rarity": 4, "faction": "蜀", "skill": "咆哮", "attack": 97, "defense": 80},
	{"id": "wu_zhouyu", "name": "周瑜", "rarity": 4, "faction": "吴", "skill": "火烧赤壁", "attack": 93, "defense": 82},
	{"id": "qun_diaochan", "name": "貂蝉", "rarity": 4, "faction": "群", "skill": "离间", "attack": 85, "defense": 70}
]

var ORANGE_HEROES: Array = [
	{"id": "shu_guanyu", "name": "关羽", "rarity": 5, "faction": "蜀", "skill": "武圣", "attack": 98, "defense": 88},
	{"id": "qun_lvbu", "name": "吕布", "rarity": 5, "faction": "群", "skill": "无双", "attack": 100, "defense": 75},
	{"id": "wei_xiahouyuan", "name": "夏侯渊", "rarity": 5, "faction": "魏", "skill": "神速", "attack": 96, "defense": 82},
	{"id": "wu_ganing", "name": "甘宁", "rarity": 5, "faction": "吴", "skill": "锦帆贼", "attack": 94, "defense": 85}
]

var RARITY_NAMES: Array = ["白", "绿", "蓝", "紫", "橙"]
var RARITY_COLORS: Array = [Color(1,1,1), Color(0,1,0), Color(0,0.5,1), Color(0.8,0,0.8), Color(1,0.5,0)]

# 当前页面
var current_page: String = ""
var current_ui: Node = null  # 当前加载的UI

# 场景缓存
var home_scene: PackedScene = preload("res://scenes/home.tscn")
var recruit_scene: PackedScene = preload("res://scenes/recruit.tscn")
var lineup_scene: PackedScene = preload("res://scenes/lineup.tscn")
var library_scene: PackedScene = preload("res://scenes/library.tscn")
var battle_scene: PackedScene = preload("res://scenes/battle.tscn")

func _ready():
	# 从存档加载数据
	if SaveManager.has_save():
		var loaded = SaveManager.load_game()
		current_gdp = loaded.get("current_gdp", 1000.0)
		current_prestige = loaded.get("current_prestige", 0)
		current_rank = loaded.get("current_rank", 1000)
		owned_heroes = loaded.get("owned_heroes", {})
		hero_fragments = loaded.get("hero_fragments", {})
		last_online_time = loaded.get("last_online_time", Time.get_unix_time_from_system())
		print("[MainUI] 存档加载完成")
	else:
		# 初始化离线时间
		last_online_time = Time.get_unix_time_from_system()
		print("[MainUI] 无存档，使用初始数据")
	
	# 动态加载背景纹理（安全加载，避免资源缺失报错）
	if background_tex:
		var tex = load("res://assets/images/main_background.png")
		if tex:
			background_tex.texture = tex
			background_tex.modulate = Color(1, 1, 1)
		else:
			print("[MainUI] 背景图片未找到: res://assets/images/main_background.png")
			# 如果找不到背景，就把背景设为透明，不要显示红色底板
			background_tex.texture = null
			background_tex.modulate = Color(1, 1, 1, 0)
	
	# 确保MainUI背景不是红色，使用深色主题背景
	self.modulate = Color(1, 1, 1)
	self.bg_color = Color(0.15, 0.15, 0.15, 1)
	
	# 动态加载按钮背景纹理（安全加载）
	var button_bg = load("res://assets/images/button_bg.png")
	if button_bg:
		var home_btn = get_node("BottomNav/HomeButton")
		var recruit_btn = get_node("BottomNav/RecruitButton")
		var lineup_btn = get_node("BottomNav/LineupButton")
		var battle_btn = get_node("BottomNav/BattleButton")
		var strategy_btn = get_node("BottomNav/StrategyButton")
		
		if home_btn and home_btn is Button: home_btn.icon = button_bg
		if recruit_btn and recruit_btn is Button: recruit_btn.icon = button_bg
		if lineup_btn and lineup_btn is Button: lineup_btn.icon = button_bg
		if battle_btn and battle_btn is Button: battle_btn.icon = button_bg
		if strategy_btn and strategy_btn is Button: strategy_btn.icon = button_bg
	else:
		print("[MainUI] 按钮背景图片未找到: res://assets/images/button_bg.png")
	
	# 让Background忽略鼠标事件，避免挡住点击
	background_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 让ContentArea接收鼠标事件
	content_area.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 显示离线收益
	show_offline_rewards()
	
	update_resource_display()
	
	# 连接导航按钮（Godot 4 风格）
	for button in nav_buttons.get_children():
		if button is Button:
			button.pressed.connect(_on_nav_button_pressed.bind(button.name))
	
	_on_nav_button_pressed("HomeButton")
	
	print("游戏启动成功！当前每秒产出：%.1f 国运点" % gdp_per_second)
	
	# 连接GM按钮
	if gm_add_gdp:
		gm_add_gdp.pressed.connect(_gm_add_1000_gdp)
		gm_add_gdp.visible = true  # GM功能默认显示，开发阶段方便测试
	
	# 连接区域按钮点击
	if region_name_btn:
		region_name_btn.pressed.connect(_show_region_detail)
	
	# 创建区域详情弹窗
	region_detail_dialog = AcceptDialog.new()
	region_detail_dialog.title = "区域详情"
	region_detail_dialog.min_size = Vector2(400, 300)
	add_child(region_detail_dialog)
	
	# 创建策略对话框
	strategy_dialog = AcceptDialog.new()
	strategy_dialog.title = "📋 策略使用"
	strategy_dialog.min_size = Vector2(450, 400)
	strategy_vbox = VBoxContainer.new()
	strategy_vbox.custom_minimum_size = Vector2(0, 300)
	strategy_dialog.add_child(strategy_vbox)
	strategy_dialog.confirmed.connect(_on_strategy_confirmed)
	add_child(strategy_dialog)
	
	# 创建每个策略按钮
	for s in STRATEGIES:
		var btn = Button.new()
		btn.text = "%s\n%s" % [s.name, s.description]
		btn.custom_minimum_size = Vector2(0, 80)
		btn.pressed.connect(_select_strategy.bind(s))
		strategy_vbox.add_child(btn)
	
	# 监听进度更新，刷新UI
	if ProgressManager.has_signal("progress_updated"):
		ProgressManager.progress_updated.connect(_on_progress_updated)
	
	# 连接策略按钮
	var strategy_btn = get_node_or_null("BottomNav/StrategyButton")
	if strategy_btn:
		strategy_btn.pressed.connect(_show_strategy_dialog)
	
	# 监听资源更新信号，实时刷新顶部栏显示
	if IdleManager and IdleManager.has_signal("resources_updated"):
		IdleManager.resources_updated.connect(update_resource_display)
	
	# 自动保存 when closing
	tree_exiting.connect(_auto_save)

# 🕒 每帧更新挂机收益
var _accum: float = 0
func _process(delta: float):
	# 实时增加国运点
	current_gdp += gdp_per_second * delta
	_accum += delta
	if _accum >= 5:
		print("挂机运行中，current_gdp = ", int(current_gdp))
		_accum = 0
	update_resource_display()

# 监听键盘事件
func _input(event: InputEvent) -> void:
	# 按F快速抽卡（只在招募页面生效）
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F and current_page == "RecruitButton":
			_do_recruit()
		elif event.keycode == KEY_R and current_page == "RecruitButton":
			_do_recruit_ten()

# 🏆 显示离线收益
func show_offline_rewards():
	var current_time = Time.get_unix_time_from_system()
	var offline_time = current_time - last_online_time
	
	if offline_time > 0:
		# 最多累计8小时
		offline_time = min(offline_time, offline_time_limit)
		offline_earned = offline_time * gdp_per_second
		current_gdp += offline_earned
		
		if offline_earned > 1:
			# 弹出提示
			var popup = Label.new()
			popup.text = "🎉 离线收益：%d 国运点\n⏰ 离线了%d分钟" % [int(offline_earned), int(offline_time / 60)]
			popup.add_theme_font_size_override("font_size", 20)
			popup.modulate = Color(1, 0.84, 0)
			popup.anchors_preset = Control.PRESET_CENTER
			popup.anchor_top = 0.3
			content_area.add_child(popup)
			
			# 3秒后自动消失
			var timer = Timer.new()
			timer.wait_time = 3.0
			timer.timeout.connect(popup.queue_free)
			add_child(timer)
			timer.start()
	
	# 更新上线时间
	last_online_time = current_time

# 更新资源显示
func update_resource_display():
	gdp_label.text = "%.1f" % current_gdp
	prestige_label.text = "%d" % current_prestige
	if money_label:
		money_label.text = "%.0f 💰" % IdleManager.get_current_money()
	if food_label:
		food_label.text = "%.0f 🌾" % IdleManager.get_current_food()
	if soldier_label:
		soldier_label.text = "%.0f ⚔️" % IdleManager.get_current_soldier()
	if region_name_btn:
		var current_region = RegionManager.get_current_region()
		if current_region != {}:
			region_name_btn.text = "📋 " + current_region.name
	if region_progress_bar:
		region_progress_bar.value = RegionManager.get_progress() / 100.0

# 导航按钮点击
func _on_nav_button_pressed(button_name: String):
	current_page = button_name
	
	# 卸载当前UI（必须先移除再删除，避免「已经有父节点」错误）
	if current_ui != null:
		content_area.remove_child(current_ui)
		current_ui.queue_free()
	
	# 进入子界面时隐藏底部导航
	nav_buttons.visible = false
	
	# 加载新UI
	match button_name:
		"HomeButton":
			current_ui = home_scene.instantiate()
			# 连接点击加速信号
			current_ui.clicked_gdp.connect(_on_click_gdp)
			# 回到主页显示底部导航
			nav_buttons.visible = true
			# 更新武将数量
			var total = WHITE_HEROES.size() + GREEN_HEROES.size() + BLUE_HEROES.size() + PURPLE_HEROES.size() + ORANGE_HEROES.size()
			current_ui.update_hero_count(owned_heroes.size(), total)
		"RecruitButton":
			current_ui = recruit_scene.instantiate()
			# 连接抽卡信号
			current_ui.recruit_requested.connect(_do_recruit)
			current_ui.recruit_ten_requested.connect(_do_recruit_ten)
			# 连接返回信号
			current_ui.back_requested.connect(_on_back_to_home)
			print("MainUI: 已连接招募信号（单抽+十连）")
		"LineupButton":
			current_ui = lineup_scene.instantiate()
			# 设置已拥有武将列表
			current_ui.set_owned_heroes(owned_heroes)
			# 连接返回信号
			current_ui.back_requested.connect(_on_back_to_home)
			print("MainUI: 已加载阵容编辑界面")
		"BattleButton":
			current_ui = battle_scene.instantiate()
			# 连接返回信号（如果需要）
			if current_ui.has_signal("back_requested"):
				current_ui.back_requested.connect(_on_back_to_home)
	
	# 添加到内容区
	if current_ui != null:
		content_area.add_child(current_ui)

# 返回主页处理
func _on_back_to_home():
	_on_nav_button_pressed("HomeButton")

# 抽卡逻辑
func _do_recruit():
	print("抽卡触发！")
	
	if current_gdp < 100:
		if current_ui != null and current_page == "RecruitButton":
			current_ui.show_gdp_not_enough()
		return
	
	# 扣除国运点
	current_gdp -= 100
	update_resource_display()
	
	# 随机稀有度
	var roll = randi() % 100
	var hero_list = []
	var rarity = 1
	
	if roll < 1:
		hero_list = ORANGE_HEROES
		rarity = 5
		print("抽到橙将！")
	elif roll < 3:
		hero_list = PURPLE_HEROES
		rarity = 4
		print("抽到紫将！")
	elif roll < 10:
		hero_list = BLUE_HEROES
		rarity = 3
		print("抽到蓝将！")
	elif roll < 30:
		hero_list = GREEN_HEROES
		rarity = 2
		print("抽到绿将！")
	else:
		hero_list = WHITE_HEROES
		rarity = 1
		print("抽到白将！")
	
	# 从对应稀有度里随机一个武将
	var hero_data = hero_list[randi() % hero_list.size()]
	
	# 处理结果
	var hero_id = hero_data.id
	var is_new = false
	
	if not owned_heroes.has(hero_id):
		owned_heroes[hero_id] = hero_data
		# 同步添加到HeroLibrary（假设HeroLibrary是autoload）
		HeroLibrary.add_hero(hero_id)
		is_new = true
	else:
		if not hero_fragments.has(hero_id):
			hero_fragments[hero_id] = 0
		hero_fragments[hero_id] += 1
		# 同步添加碎片到HeroLibrary
		HeroLibrary.add_fragments(hero_id, 1)
	
	# 显示结果
	if current_ui != null and current_page == "RecruitButton":
		var fragments = 0
		if not is_new and hero_fragments.has(hero_id):
			fragments = hero_fragments[hero_id]
		current_ui.show_result(hero_data, is_new, RARITY_NAMES[rarity-1], RARITY_COLORS[rarity-1], fragments)
	
	print("抽卡结果：%s (%s)，新武将：%s" % [hero_data.name, RARITY_NAMES[rarity-1], str(is_new)])

# 十连抽逻辑
func _do_recruit_ten():
	print("十连抽触发！")
	
	if current_gdp < 900:
		if current_ui != null and current_page == "RecruitButton":
			current_ui.show_gdp_not_enough(900)
		return
	
	# 扣除国运点（十连九折优惠）
	current_gdp -= 900
	update_resource_display()
	
	# 抽取9个武将，填满九宫格
	var results: Array[Dictionary] = []
	
	for i in range(9):
		# 随机稀有度
		var roll = randi() % 100
		var hero_list = []
		var rarity = 1
		
		if roll < 1:
			hero_list = ORANGE_HEROES
			rarity = 5
			print("抽到橙将！")
		elif roll < 3:
			hero_list = PURPLE_HEROES
			rarity = 4
			print("抽到紫将！")
		elif roll < 10:
			hero_list = BLUE_HEROES
			rarity = 3
			print("抽到蓝将！")
		elif roll < 30:
			hero_list = GREEN_HEROES
			rarity = 2
			print("抽到绿将！")
		else:
			hero_list = WHITE_HEROES
			rarity = 1
			print("抽到白将！")
		
		# 从对应稀有度里随机一个武将
		var hero_data = hero_list[randi() % hero_list.size()]
		
		# 处理结果
		var hero_id = hero_data.id
		var is_new = false
		
		if not owned_heroes.has(hero_id):
			owned_heroes[hero_id] = hero_data
			# 同步添加到HeroLibrary（假设HeroLibrary是autoload）
			HeroLibrary.add_hero(hero_id)
			is_new = true
		else:
			if not hero_fragments.has(hero_id):
				hero_fragments[hero_id] = 0
			hero_fragments[hero_id] += 1
			# 同步添加碎片到HeroLibrary
			HeroLibrary.add_fragments(hero_id, 1)
		
		# 添加到结果列表
		results.append({
			"hero_data": hero_data,
			"is_new": is_new,
			"rarity": rarity,
			"rarity_color": RARITY_COLORS[rarity-1]
		})
	
	# 显示结果在九宫格
	if current_ui != null and current_page == "RecruitButton":
		current_ui.show_ten_results(results)
	
	var new_count: int = 0
	for r in results:
		if r.is_new:
			new_count += 1
	print("十连抽完成，共 %d 个新武将" % [new_count])

# GM功能：增加1000国运点
func _gm_add_1000_gdp():
	current_gdp += 1000
	update_resource_display()
	print("[GM] 增加了1000国运点，当前：%d" % int(current_gdp))
	
	# 弹出提示
	var popup = Label.new()
	popup.text = "🎉 [GM] +1000 国运点"
	popup.add_theme_font_size_override("font_size", 20)
	popup.modulate = Color(1, 0.2, 0.2)
	popup.anchors_preset = Control.PRESET_CENTER
	popup.anchor_top = 0.4
	content_area.add_child(popup)
	
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(popup.queue_free)
	add_child(timer)
	timer.start()

# 处理点击获得国运
func _on_click_gdp(amount: float):
	current_gdp += amount
	update_resource_display()
	print("[点击加速] +%.1f 国运点，当前：%.1f" % [amount, current_gdp])

# 显示提示toast
func _show_toast(text: String):
	var popup = Label.new()
	popup.text = text
	popup.add_theme_font_size_override("font_size", 18)
	if text.begins_with("❌"):
		popup.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	else:
		popup.add_theme_color_override("font_color", Color(0.2, 1, 0.2))
	popup.anchors_preset = Control.PRESET_CENTER
	popup.anchor_top = 0.2
	content_area.add_child(popup)
	
	# 3秒后消失
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.timeout.connect(popup.queue_free)
	add_child(timer)
	timer.start()

# 进度更新回调
func _on_progress_updated(progress: float):
	update_resource_display()

# 显示区域详情
func _show_region_detail():
	var current_region = RegionManager.get_current_region()
	if current_region.is_empty():
		return
	
	# 构建详情文本
	var text = "**%s**\n\n%s\n\n" % [current_region.name, current_region.description]
	text += "**消耗倍率**: \n"
	text += "- 粮草: x%.1f\n" % current_region.food_consumption_multiplier
	text += "- 兵力: x%.1f\n" % current_region.soldier_consumption_multiplier
	text += "- 速度: x%.1f\n\n" % current_region.speed_multiplier
	text += "**当前进度: %.1f%%\n" % RegionManager.get_progress()
	text += "\n**通关奖励: %s" % current_region.first_clear_reward.description
	
	region_detail_dialog.set_text(text)
	region_detail_dialog.show()

# 显示策略对话框
func _show_strategy_dialog():
	strategy_dialog.show()

# 选择策略
func _select_strategy(strategy: Dictionary):
	# 检查资源是否足够
	if IdleManager.get_current_money() < strategy.get("cost_money", 0):
		_show_toast("❌ 钱不足，无法使用此策略")
		return
	if IdleManager.get_current_food() < strategy.get("cost_food", 0):
		_show_toast("❌ 粮草不足，无法使用此策略")
		return
	if IdleManager.get_current_soldier() < strategy.get("cost_soldier", 0):
		_show_toast("❌ 兵力不足，无法使用此策略")
		return
	
	# 消耗资源
	IdleManager.spend_money(strategy.get("cost_money", 0))
	IdleManager.spend_food(strategy.get("cost_food", 0))
	IdleManager.spend_soldier(strategy.get("cost_soldier", 0))
	
	# 应用策略效果
	match strategy.id:
		"speed_boost":
			# 犒赏三军：攻城速度+50% 持续30秒
			IdleManager.set_temp_speed_bonus(strategy.speed_bonus, strategy.duration)
			_show_toast("✅ 犒赏三军生效！速度+50%%，持续30秒")
		"spying":
			# 间谍活动：下一次事件成功率+20% （后续事件系统实现，现在只消耗给钱记录）
			_show_toast("✅ 间谍活动生效！下一事件成功率+20%%")
		"recruit_soldier":
			# 紧急征兵：获得(钱+粮) * 系数
			var soldier_gain = (strategy.cost_money + strategy.cost_food) * strategy.soldier_multiplier
			IdleManager.add_soldier(soldier_gain)
			_show_toast("✅ 紧急征兵完成！获得 +%.0f 兵力" % soldier_gain)
	
	# 关闭对话框
	strategy_dialog.hide()
	update_resource_display()

# 确认按钮不用了，我们直接点击按钮执行
func _on_strategy_confirmed():
	strategy_dialog.hide()

# 获取已拥有武将字典（供阵容界面读取）
func get_owned_heroes() -> Dictionary:
	return owned_heroes

# 根据ID获取武将数据（供阵容界面读取）
func get_owned_hero_data(hero_id: String) -> Dictionary:
	if owned_heroes.has(hero_id):
		return owned_heroes[hero_id]
	return {}

# 自动保存
func _auto_save():
	var save_data = {
		"current_gdp": current_gdp,
		"current_prestige": current_prestige,
		"current_rank": current_rank,
		"owned_heroes": owned_heroes,
		"hero_fragments": hero_fragments,
		"last_online_time": Time.get_unix_time_from_system()
	}
	var success = SaveManager.save_game(save_data)
	if success:
		print("[MainUI] 自动保存成功")
	else:
		print("[MainUI] 自动保存失败")

# 手动保存按钮（可以在UI添加）
func _manual_save():
	_auto_save()
	# 弹出提示
	var popup = Label.new()
	popup.text = "💾 存档成功！"
	popup.add_theme_font_size_override("font_size", 20)
	popup.modulate = Color(0, 1, 0)
	popup.anchors_preset = Control.PRESET_CENTER
	popup.anchor_top = 0.5
	content_area.add_child(popup)
	
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(popup.queue_free)
	add_child(timer)
	timer.start()
