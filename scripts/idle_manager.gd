extends Node

# 单例实例
static var instance: IdleManager = null

# 配置常量
const BASE_COEFFICIENT: float = 0.01  # 基础产出系数
const MAX_OFFLINE_HOURS: float = 12.0  # 最大离线收益时间
const MAX_OFFLINE_SECONDS: float = MAX_OFFLINE_HOURS * 3600  # 转换为秒

# 玩家资源
var current_gdp: float = 0.0  # 当前国运点
var total_gdp: float = 0.0  # 累计国运点

# 倍率相关
var base_multiplier: float = 1.0  # 基础倍率
var temp_multiplier: float = 1.0  # 临时倍率（由Bongo Cat提供）
var multiplier_end_time: float = 0.0  # 临时倍率结束时间（Unix时间戳）

# 离线时间记录
var last_save_time: float = 0.0  # 上次保存时间（Unix时间戳）

# 信号
signal gdp_updated(amount: float)  # 国运点变化时触发
signal offline_income_calculated(amount: float)  # 离线收益计算完成时触发
signal multiplier_updated(multiplier: float, remaining_time: float)  # 倍率变化时触发

func _init():
	if instance == null:
		instance = self
	else:
		queue_free()

func _ready():
	# 加载时计算离线收益
	calculate_offline_income()
	# 启动每秒产出定时器
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.connect("timeout", Callable(self, "_on_second_tick"))
	add_child(timer)
	timer.start()

# 每秒产出国运点
func _on_second_tick():
	# 计算当前有效倍率
	var current_multiplier = get_current_multiplier()
	
	# 计算每秒产出：总战力 × 基础系数 × 倍率 + 1
	# 暂时用模拟战力，后续从阵容系统获取
	var total_combat_power = get_total_combat_power()
	var gdp_per_second = total_combat_power * BASE_COEFFICIENT * current_multiplier + 1
	
	# 增加国运点
	add_gdp(gdp_per_second)

# 获取总战力（暂时模拟，后续替换为实际阵容战力计算）
func get_total_combat_power() -> float:
	# TODO: 从阵容系统获取上阵武将总战力
	return 100.0  # 初始模拟值

# 获取当前有效倍率
func get_current_multiplier() -> float:
	var now = Time.get_unix_time_from_system()
	if now < multiplier_end_time:
		return base_multiplier * temp_multiplier
	else:
		temp_multiplier = 1.0
		return base_multiplier

# 设置临时倍率
func set_temp_multiplier(multiplier: float, duration: float):
	var now = Time.get_unix_time_from_system()
	temp_multiplier = multiplier
	multiplier_end_time = now + duration
	multiplier_updated.emit(multiplier, duration)

# 增加国运点
func add_gdp(amount: float):
	if amount <= 0:
		return
	current_gdp += amount
	total_gdp += amount
	gdp_updated.emit(amount)

# 消耗国运点，返回是否成功
func spend_gdp(amount: float) -> bool:
	if current_gdp >= amount:
		current_gdp -= amount
		gdp_updated.emit(-amount)
		return true
	return false

# 获取当前国运点
func get_current_gdp() -> float:
	return current_gdp

# 获取累计国运点
func get_total_gdp() -> float:
	return total_gdp

# 计算离线收益
func calculate_offline_income():
	var now = Time.get_unix_time_from_system()
	
	# 如果是第一次启动，没有离线时间
	if last_save_time == 0:
		last_save_time = now
		return
	
	# 计算离线时间，最多12小时
	var offline_seconds = now - last_save_time
	if offline_seconds > MAX_OFFLINE_SECONDS:
		offline_seconds = MAX_OFFLINE_SECONDS
	
	if offline_seconds <= 0:
		return
	
	# 计算离线收益（离线期间倍率按1倍计算）
	var total_combat_power = get_total_combat_power()
	var offline_income = (total_combat_power * BASE_COEFFICIENT + 1) * offline_seconds
	
	# 添加离线收益
	add_gdp(offline_income)
	offline_income_calculated.emit(offline_income)
	
	# 更新保存时间
	last_save_time = now

# 保存数据（供存档系统调用）
func save_data() -> Dictionary:
	last_save_time = Time.get_unix_time_from_system()
	return {
		"current_gdp": current_gdp,
		"total_gdp": total_gdp,
		"last_save_time": last_save_time,
		"base_multiplier": base_multiplier
	}

# 加载数据（供存档系统调用）
func load_data(data: Dictionary):
	current_gdp = data.get("current_gdp", 0.0)
	total_gdp = data.get("total_gdp", 0.0)
	last_save_time = data.get("last_save_time", 0.0)
	base_multiplier = data.get("base_multiplier", 1.0)
