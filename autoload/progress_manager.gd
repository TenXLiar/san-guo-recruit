extends Node
# 攻城进度管理器 - 管理区域进度推进和资源消耗

# 配置常量
const PROGRESS_STEP: float = 5.0  # 每推进多少百分比消耗一次资源
const BASE_FOOD_COST: float = 10.0  # 每5%进度基础粮草消耗
const BASE_SOLDIER_COST: float = 5.0  # 每5%进度基础兵力消耗

# 进度积累（在下一次达到5%之前积累）
var accumulated_progress: float = 0.0

# 信号
signal progress_updated(current_progress: float)  # 进度更新
signal region_completed()  # 当前区域完成
signal resource_consumed()  # 资源已消耗

func _ready():
	# 每秒推进一次进度
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.connect("timeout", Callable(self, "_on_second_tick"))
	add_child(timer)
	timer.start()
	print("[ProgressManager] 初始化完成")

# 每秒推进进度
func _on_second_tick():
	# 获取当前区域
	var current_region = RegionManager.get_current_region()
	if current_region.is_empty():
		return
	
	# 如果当前区域已经完成，不推进
	if RegionManager.is_region_completed(RegionManager.get_current_region().id):
		return
	
	# 计算推进速度：上阵总勇武 + 上阵总智略 × 区域倍率 × 速度加成
	var speed = get_current_progress_speed()
	speed *= current_region.speed_multiplier
	speed *= IdleManager.get_total_speed_bonus()
	
	# 积累进度
	accumulated_progress += speed
	
	# 检查是否达到一步
	var steps = int(accumulated_progress / PROGRESS_STEP)
	if steps <= 0:
		# 没有达到一步，只更新积累
		RegionManager.add_region_progress(speed)
		progress_updated.emit(RegionManager.get_progress())
		return
	
	# 每一步消耗资源
	for i in range(steps):
		if not _consume_resources(current_region):
			# 资源不足，停止推进
			break
		# 扣除已消耗的进度
		accumulated_progress -= PROGRESS_STEP
		# 推进进度
		RegionManager.add_region_progress(PROGRESS_STEP)
	
	# 发出进度更新信号
	progress_updated.emit(RegionManager.get_progress())

# 计算当前进度速度：总勇武 + 总智略
# （上阵武将勇武 + 上阵文臣智略）
func get_current_progress_speed() -> float:
	# 从阵容系统获取上阵武将的总勇武和总智略
	# LineupUI 是场景节点，需要找实例
	var root = get_tree().root
	var main_ui = root.get_node_or_null("root-main/Content/LineupUI")
	if main_ui:
		var stats = main_ui.get_total_progress_stats()
		var total = stats.total_bravery + stats.total_wisdom
		if total <= 0:
			total = 1.0  # 保证至少有一点速度
		return total
	# 默认返回1保证能推进
	return 1.0

# 根据区域倍率计算消耗，然后消耗资源
func _consume_resources(region: Dictionary) -> bool:
	# 计算实际消耗
	var food_cost = BASE_FOOD_COST * region.food_consumption_multiplier
	var soldier_cost = BASE_SOLDIER_COST * region.soldier_consumption_multiplier
	
	# 检查资源是否足够
	if IdleManager.get_current_food() < food_cost:
		print("[ProgressManager] 粮草不足，停止推进")
		return false
	if IdleManager.get_current_soldier() < soldier_cost:
		print("[ProgressManager] 兵力不足，停止推进")
		return false
	
	# 消耗资源
	IdleManager.spend_food(food_cost)
	IdleManager.spend_soldier(soldier_cost)
	resource_consumed.emit()
	print("[ProgressManager] 消耗 粮:%.1f 兵:%.1f 推进%d%%" % [food_cost, soldier_cost, PROGRESS_STEP])
	return true

# 获取当前进度百分比
func get_current_progress() -> float:
	return RegionManager.get_progress()

# 手动增加进度（用于事件奖励）
func add_progress(amount: float) -> bool:
	var before_completed = RegionManager.is_region_completed(RegionManager.get_current_region().id)
	var result = RegionManager.add_region_progress(amount)
	accumulated_progress += amount
	progress_updated.emit(RegionManager.get_progress())
	
	# 如果刚刚完成，发出信号
	var after_completed = RegionManager.is_region_completed(RegionManager.get_current_region().id)
	if not before_completed && after_completed:
		region_completed.emit()
	
	return result
