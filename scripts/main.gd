extends Control
class_name MainUI

# 节点引用
@onready var gdp_label: Label = $TopBar/GDPLabel
@onready var prestige_label: Label = $TopBar/PrestigeLabel
@onready var gm_add_gdp: Button = $TopBar/GMAddGDP
@onready var content_area: Control = $ContentArea
@onready var nav_buttons: HBoxContainer = $BottomNav

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
	# 初始化离线时间
	last_online_time = Time.get_unix_time_from_system()
	
	# 让Background忽略鼠标事件，避免挡住点击
	var bg = get_node_or_null("Background")
	if bg:
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 让ContentArea接收鼠标事件
	content_area.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 显示离线收益
	show_offline_rewards()
	
	update_resource_display()
	
	# 连接导航按钮
	for button in nav_buttons.get_children():
		if button is Button:
			button.connect("pressed", Callable(self, "_on_nav_button_pressed").bind(button.name))
	
	_on_nav_button_pressed("HomeButton")
	
	print("游戏启动成功！当前每秒产出：%.1f 国运点" % gdp_per_second)
	
	# 连接GM按钮
	if gm_add_gdp:
		gm_add_gdp.connect("pressed", Callable(self, "_gm_add_1000_gdp"))
		gm_add_gdp.visible = true  # GM功能默认显示，开发阶段方便测试

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
	# 按F快速抽卡（只在招募页面生效
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F and current_page == "RecruitButton":
			_do_recruit()

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
			popup.anchors_preset = 8
			popup.anchor_top = 0.3
			content_area.add_child(popup)
			
			# 3秒后自动消失
			var timer = Timer.new()
			timer.wait_time = 3.0
			timer.connect("timeout", Callable(popup, "queue_free"))
			add_child(timer)
			timer.start()
	
	# 更新上线时间
	last_online_time = current_time

# 更新资源显示
func update_resource_display():
	gdp_label.text = str(int(current_gdp))
	prestige_label.text = str(current_prestige)

# 导航按钮点击
func _on_nav_button_pressed(button_name: String):
	current_page = button_name
	
	# 卸载当前UI
	if current_ui != null:
		current_ui.queue_free()
	
	# 进入子界面时隐藏底部导航
	nav_buttons.visible = false
	
	# 加载新UI
	match button_name:
		"HomeButton":
			current_ui = home_scene.instantiate()
			# 回到主页显示底部导航
			nav_buttons.visible = true
			# 更新武将数量
			var total = WHITE_HEROES.size() + GREEN_HEROES.size() + BLUE_HEROES.size() + PURPLE_HEROES.size() + ORANGE_HEROES.size()
			current_ui.update_hero_count(owned_heroes.size(), total)
		"RecruitButton":
			current_ui = recruit_scene.instantiate()
			# 连接抽卡信号
			current_ui.connect("recruit_requested", Callable(self, "_do_recruit"))
			# 连接返回信号
			current_ui.connect("back_requested", Callable(self, "_on_back_to_home"))
			print("MainUI: 已连接招募信号")
		"LineupButton":
			current_ui = lineup_scene.instantiate()
			# 连接返回信号
			current_ui.connect("back_requested", Callable(self, "_on_back_to_home"))
			print("MainUI: 已加载阵容编辑界面")
		"BattleButton":
			current_ui = battle_scene.instantiate()
			# 连接返回信号（如果需要）
			if current_ui.has_method("back_requested"):
				current_ui.connect("back_requested", Callable(self, "_on_back_to_home"))
	
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
		# 同步添加到HeroLibrary单例
		HeroLibrary.instance.add_hero(hero_id)
		is_new = true
	else:
		if not hero_fragments.has(hero_id):
			hero_fragments[hero_id] = 0
		hero_fragments[hero_id] += 1
		# 同步添加碎片到HeroLibrary
		HeroLibrary.instance.add_fragments(hero_id, 1)
	
	# 显示结果
	if current_ui != null and current_page == "RecruitButton":
		var fragments = 0
		if not is_new and hero_fragments.has(hero_id):
			fragments = hero_fragments[hero_id]
		current_ui.show_result(hero_data, is_new, RARITY_NAMES[rarity-1], RARITY_COLORS[rarity-1], fragments)
	
	print("抽卡结果：%s (%s)，新武将：%s" % [hero_data.name, RARITY_NAMES[rarity-1], str(is_new)])

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
	popup.anchors_preset = 8
	popup.anchor_top = 0.4
	content_area.add_child(popup)
	
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.connect("timeout", Callable(popup, "queue_free"))
	add_child(timer)
	timer.start()
