extends Node
# 随机事件管理器 - 每小时概率触发随机事件

# 配置常量
const BASE_PROBABILITY: float = 0.1  # 基础概率每小时
const CHECK_INTERVAL: float = 300.0  # 每5分钟检查一次（开发测试方便）

# 所有事件从外部JSON加载
var all_events: Array = []
var event_chains: Array = []  # 所有事件链

# 当前待处理事件
var pending_event: Dictionary = {}

# 事件链状态记录
var current_chain_progress: Dictionary = {}  # {chain_id: current_step}

# 信号
signal event_triggered(event: Dictionary)
signal event_handled
signal event_chain_completed(chain_id: String, reward: Dictionary)

func _ready():
	# 从JSON加载所有事件
	load_events_from_json()
	# 启动检查定时器
	var timer = Timer.new()
	timer.wait_time = CHECK_INTERVAL
	timer.connect("timeout", Callable(self, "_check_trigger_event"))
	add_child(timer)
	timer.start()
	print("[EventManager] 初始化完成，加载了 %d 个事件，每%d分钟检查一次" % [all_events.size(), int(CHECK_INTERVAL / 60)])

# 从外部JSON加载事件
func load_events_from_json():
	var file = FileAccess.open("res://data/events.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result == OK:
			var data = json.data
			all_events = data.get("all_events", [])
			event_chains = data.get("event_chains", [])
			print("[EventManager] 成功加载 %d 个事件，%d 个事件链" % [all_events.size(), event_chains.size()])
		else:
			push_error("Failed to parse events.json: " + json.get_error_message())
	else:
		push_error("Cannot open events.json")

# 获取事件链
func get_event_chain(chain_id: String) -> Dictionary:
	for chain in event_chains:
		if chain.id == chain_id:
			return chain
	return {}

# 开始事件链
func start_event_chain(chain_id: String):
	var chain = get_event_chain(chain_id)
	if chain.empty():
		return
	
	current_chain_progress[chain_id] = 0
	# 触发第一步
	var first_step = chain.steps[0]
	var event = find_event_by_id(first_step.event_id)
	if not event.empty():
		_show_event_dialog(event)
		print("[EventManager] 开始事件链: %s" % chain_id)

# 处理事件链下一步
func progress_event_chain(chain_id: String, success: bool):
	if not current_chain_progress.has(chain_id):
		return
	
	var chain = get_event_chain(chain_id)
	if chain.empty():
		return
	
	var current_step_index = current_chain_progress[chain_id]
	var current_step = chain.steps[current_step_index]
	
	if success and current_step.has("next_if_success") and current_step.next_if_success != null:
		# 找下一步
		var next_step_index = current_step_index + 1
		if next_step_index < chain.steps.size():
			current_chain_progress[chain_id] = next_step_index
			var next_step = chain.steps[next_step_index]
			var next_event = find_event_by_id(next_step.event_id)
			if not next_event.empty():
				_show_event_dialog(next_event)
				print("[EventManager] 事件链 %s 进度到第%d步" % [chain_id, next_step_index + 1])
		else:
			# 完成了
			if current_step.has("reward"):
				_apply_chain_reward(chain_id, current_step.reward)
			event_chain_completed.emit(chain_id, current_step.reward)
			current_chain_progress.erase(chain_id)
			print("[EventManager] 事件链 %s 完成" % chain_id)
	elif not success:
		# 失败，终止链
		current_chain_progress.erase(chain_id)
		print("[EventManager] 事件链 %s 失败终止" % chain_id)

# 应用事件链奖励
func _apply_chain_reward(chain_id: String, reward: Dictionary):
	if reward.has("unlock_hidden_hero"):
		for hero_id in reward.unlock_hidden_hero:
			# 通知 HeroLibrary 解锁隐藏武将
			print("[EventManager] 事件链完成解锁隐藏武将: %s" % hero_id)
			HeroLibrary.unlock_hidden_hero(hero_id)
	if reward.has("reward_progress"):
		ProgressManager.add_progress(reward.reward_progress)
	if reward.has("reward_fragments"):
		# 奖励武将碎片，留给HeroLibrary处理
		for frag_id in reward.reward_fragments:
			var count = reward.get("reward_fragments_count", 3)
			HeroLibrary.add_fragments(frag_id, count)
	if reward.has("permanent_progress_bonus"):
		ProgressManager.add_permanent_speed_bonus(reward.permanent_progress_bonus)
	if reward.has("permanent_money_bonus"):
		IdleManager.add_permanent_money_bonus(reward.permanent_money_bonus)
	if reward.has("permanent_food_bonus"):
		IdleManager.add_permanent_food_bonus(reward.permanent_food_bonus)
	if reward.has("permanent_soldier_bonus"):
		IdleManager.add_permanent_soldier_bonus(reward.permanent_soldier_bonus)

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
	var candidate_events = []
	
	# 将区域事件池中的每个事件加入候选列表
	for eid in event_ids:
		var found = find_event_by_id(eid)
		if not found.empty():
			candidate_events.append(found)
	
	# 如果候选列表空，使用所有事件随机
	if candidate_events.empty():
		candidate_events = all_events
	
	if candidate_events.empty():
		return
	
	# 随机选一个
	var idx = randi() % candidate_events.size()
	var selected_event = candidate_events[idx]
	pending_event = selected_event
	_show_event_dialog(selected_event)
	print("[EventManager] 触发事件: %s" % selected_event.title)

# 找到事件根据ID
func find_event_by_id(event_id: String) -> Dictionary:
	for e in all_events:
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
