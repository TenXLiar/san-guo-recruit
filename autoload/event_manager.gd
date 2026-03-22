extends Node
# 随机事件管理器 - 每小时概率触发随机事件

# 配置常量
const BASE_PROBABILITY: float = 0.1  # 基础概率每小时
const CHECK_INTERVAL: float = 300.0  # 每5分钟检查一次（开发测试方便）

# 基础事件库（策划案预设5个基础事件）
var BASE_EVENTS = [
	{
		"id": "bandit_attack",
		"title": "山贼来袭",
		"description": "一群山贼洗劫了粮道，损失了部分粮草。你决定：",
		"options": [
			{
				"text": "迎击山贼",
				"cost_soldier": 10,
				"reward_progress": 5,
				"description": "击退山贼获得进度奖励"
			},
			{
				"text": "放弃绕道",
				"cost_progress": 3,
				"description": "损失进度，但不消耗兵力"
			}
		]
	},
	{
		"id": "merchant_visit",
		"title": "商人来访",
		"description": "行商路过你的领地，想要和你交易：",
		"options": [
			{
				"text": "买粮（20钱 → 30粮）",
				"cost_money": 20,
				"reward_food": 30,
				"description": "用钱买粮"
			},
			{
				"text": "买兵（20粮 → 15兵）",
				"cost_food": 20,
				"reward_soldier": 15,
				"description": "用粮换兵"
			}
		]
	},
	{
		"id": "flood_disaster",
		"title": "洪水灾害",
		"description": "连日大雨引发洪水，冲毁了部分农田：",
		"options": [
			{
				"text": "开仓赈灾",
				"cost_food": 20,
				"reward_event_probability": -0.1,
				"description": "消耗粮草减少后续事件概率"
			},
			{
				"text": "任由洪水泛滥",
				"cost_food": 0,
				"reward_food": -10,
				"description": "损失部分现有粮草"
			}
		]
	},
	{
		"id": "farmer_request",
		"title": "百姓请命",
		"description": "当地百姓请求减税，答应可以提高后续产出：",
		"options": [
			{
				"text": "答应请求",
				"cost_money": 10,
				"permanent_money_bonus": 0.05,
				"description": "永久增加钱产出+5%"
			},
			{
				"text": "拒绝请求",
				"description": "无变化"
			}
		]
	},
	{
		"id": "recruit_volunteers",
		"title": "募兵",
		"description": "乡里征召志愿兵，你可以：",
		"options": [
			{
				"text": "花钱招募",
				"cost_money": 25,
				"reward_soldier": 25,
				"description": "直接获得25兵力"
			},
			{
				"text": "征粮换兵",
				"cost_food": 20,
				"reward_soldier": 20,
				"description": "消耗粮草获得兵力"
			}
		]
	}
]

# 当前待处理事件
var pending_event: Dictionary = {}

# 信号
signal event_triggered(event: Dictionary)
signal event_handled

func _ready():
	# 启动检查定时器
	var timer = Timer.new()
	timer.wait_time = CHECK_INTERVAL
	timer.connect("timeout", Callable(self, "_check_trigger_event"))
	add_child(timer)
	timer.start()
	print("[EventManager] 初始化完成，每%d分钟检查一次事件" % int(CHECK_INTERVAL / 60))

# 每次检查是否触发事件
func _check_trigger_event():
	# 计算当前概率：基础概率 + 智略加成（每10智略+1%）
	var current_prob = BASE_PROBABILITY
	var total_wisdom = 0.0
	# 从Lineup获取镇守总智略
	var root = get_tree().root
	var lineup_ui = root.get_node_or_null("root-main/Content/LineupUI")
	if lineup_ui:
		var stats = lineup_ui.calculate_total_stats()
		current_prob += stats.total_guard_wisdom / 10 * 0.01
	
	# Roll点判断
	if randf() < current_prob:
		_trigger_random_event()

# 触发随机事件
func _trigger_random_event():
	# 从当前区域事件池随机选一个事件
	var current_region = RegionManager.get_current_region()
	var event_ids = current_region.event_ids
	var all_events = []
	
	# 先加基础事件
	for e in BASE_EVENTS:
		all_events.append(e)
	# 再加区域事件（后续扩展）
	for eid in event_ids:
		# TODO: 从区域事件库查找，现在先用基础事件
		var found = _find_base_event(eid)
		if found != null:
			all_events.append(found)
	
	if all_events.empty():
		return
	
	# 随机选一个
	var idx = randi() % all_events.size()
	var selected_event = all_events[idx]
	pending_event = selected_event
	_show_event_dialog(selected_event)
	print("[EventManager] 触发事件: %s" % selected_event.title)

# 找到基础事件
func _find_base_event(event_id: String) -> Dictionary:
	for e in BASE_EVENTS:
		if e.id == event_id:
			return e
	return {}

# 显示事件弹窗
func _show_event_dialog(event: Dictionary):
	# 创建弹窗
	var dialog = AcceptDialog.new()
	dialog.title = event.title
	dialog.set_min_size(Vector2(400, 300))
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(0, 200)
	
	# 事件描述
	var desc = Label.new()
	desc.text = event.description
	desc.custom_minimum_size = Vector2(0, 80)
	desc.autowrap = true
	vbox.add_child(desc)
	
	# 添加选项按钮
	for option in event.options:
		var btn = Button.new()
		btn.text = option.text + "\n" + option.description
		btn.custom_minimum_size = Vector2(0, 60)
		btn.connect("pressed", Callable(self, "_on_option_selected").bind(option, dialog))
		vbox.add_child(btn)
	
	dialog.add_child(vbox)
	dialog.connect("canceled", Callable(self, "_on_event_canceled"))
	get_tree().root.add_child(dialog)
	dialog.show()

# 选择了事件选项
func _on_option_selected(option: Dictionary, dialog: AcceptDialog):
	# 消耗资源
	if option.has("cost_money"):
		IdleManager.spend_money(option.cost_money)
	if option.has("cost_food"):
		IdleManager.spend_food(option.cost_food)
	if option.has("cost_soldier"):
		IdleManager.spend_soldier(option.cost_soldier)
	
	# 发放奖励
	if option.has("reward_progress"):
		ProgressManager.add_progress(option.reward_progress)
	if option.has("reward_food"):
		IdleManager.add_food(option.reward_food)
	if option.has("reward_money"):
		IdleManager.add_money(option.reward_money)
	if option.has("reward_soldier"):
		IdleManager.add_soldier(option.reward_soldier)
	if option.has("permanent_money_bonus"):
		IdleManager.add_permanent_money_bonus(option.permanent_money_bonus)
	if option.has("permanent_food_bonus"):
		IdleManager.add_permanent_food_bonus(option.permanent_food_bonus)
	if option.has("permanent_soldier_bonus"):
		IdleManager.add_permanent_soldier_bonus(option.permanent_soldier_bonus)
	if option.has("reward_event_probability"):
		# 记录临时加成，后续检查使用
		pass
	
	# 关闭对话框
	dialog.queue_free()
	pending_event = {}
	event_handled.emit()
	print("[EventManager] 事件处理完成: %s" % option.text)

# 取消事件
func _on_event_canceled():
	pending_event = {}
