extends Node

# 单例实例
static var instance: IdleManager = null

# 配置常量
const BASE_COEFFICIENT: float = 0.01  # 基础产出系数
const MAX_OFFLINE_HOURS: float = 12.0  # 最大离线收益时间
const MAX_OFFLINE_SECONDS: float = MAX_OFFLINE_HOURS * 3600  # 转换为秒

# 产出系数（根据策划案）
const SOLDIER_PER_BRAVERY: float = 0.1    # 每1点勇武 每秒产兵 +0.1
const MONEY_PER_WISDOM: float = 0.05      # 每1点智略 每秒产钱 +0.05
const FOOD_PER_WISDOM: float = 0.05       # 每1点智略 每秒产粮 +0.05

# 玩家资源
var current_gdp: float = 0.0  # 当前国运点（聚贤令）
var total_gdp: float = 0.0  # 累计国运点
var current_money: float = 0.0  # 当前钱
var current_food: float = 0.0  # 当前粮
var current_soldier: float = 0.0  # 当前兵

# 永久增益（来自区域通关）
var permanent_money_bonus: float = 1.0   # 钱产出倍率
var permanent_food_bonus: float = 1.0    # 粮产出倍率
var permanent_soldier_bonus: float = 1.0  # 兵产出倍率

# 倍率相关
var base_multiplier: float = 1.0  # 基础倍率（国运）
var temp_multiplier: float = 1.0  # 临时倍率（由Bongo Cat提供）
var multiplier_end_time: float = 0.0  # 临时倍率结束时间（Unix时间戳）

# 临时增益（策略系统，比如犒赏三军）
var temp_speed_bonus: float = 1.0       # 攻城速度临时增益
var temp_speed_bonus_end_time: float = 0.0  # 增益结束时间

# 离线时间记录
var last_save_time: float = 0.0  # 上次保存时间（Unix时间戳）

# 镇守总属性（来自阵容系统）
var total_guard_bravery: float = 0.0    # 镇守总勇武（产兵）
var total_guard_wisdom: float = 0.0     # 镇守总智略（产钱产粮）

# 信号
signal gdp_updated(amount: float)  # 国运点变化时触发
signal resources_updated()  # 钱粮兵更新时触发
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

# 每秒产出国运点 + 钱粮兵
func _on_second_tick():
	# 计算当前有效倍率（国运）
	var current_multiplier = get_current_multiplier()
	
	# 计算每秒产出：总战力 × 基础系数 × 倍率 + 1
	# 暂时用模拟战力，后续从阵容系统获取
	var total_combat_power = get_total_combat_power()
	var gdp_per_second = total_combat_power * BASE_COEFFICIENT * current_multiplier + 1
	
	# 增加国运点
	add_gdp(gdp_per_second)
	
	# 产出钱粮兵（根据镇守属性和永久增益）
	var money_per_second = total_guard_wisdom * MONEY_PER_WISDOM * permanent_money_bonus * get_temp_speed_bonus()
	var food_per_second = total_guard_wisdom * FOOD_PER_WISDOM * permanent_food_bonus * get_temp_speed_bonus()
	var soldier_per_second = total_guard_bravery * SOLDIER_PER_BRAVERY * permanent_soldier_bonus * get_temp_speed_bonus()
	
	add_money(money_per_second)
	add_food(food_per_second)
	add_soldier(soldier_per_second)

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

# ========== 钱 ==========
# 获取当前钱
func get_current_money() -> float:
	return current_money

# 增加钱
func add_money(amount: float):
	if amount <= 0:
		return
	current_money += amount
	resources_updated.emit()

# 消耗钱，返回是否成功
func spend_money(amount: float) -> bool:
	if current_money >= amount:
		current_money -= amount
		resources_updated.emit()
		return true
	return false

# ========== 粮 ==========
# 获取当前粮
func get_current_food() -> float:
	return current_food

# 增加粮
func add_food(amount: float):
	if amount <= 0:
		return
	current_food += amount
	resources_updated.emit()

# 消耗粮，返回是否成功
func spend_food(amount: float) -> bool:
	if current_food >= amount:
		current_food -= amount
		resources_updated.emit()
		return true
	return false

# ========== 兵 ==========
# 获取当前兵
func get_current_soldier() -> float:
	return current_soldier

# 增加兵
func add_soldier(amount: float):
	if amount <= 0:
		return
	current_soldier += amount
	resources_updated.emit()

# 消耗兵，返回是否成功
func spend_soldier(amount: float) -> bool:
	if current_soldier >= amount:
		current_soldier -= amount
		resources_updated.emit()
		return true
	return false

# ========== 镇守属性更新 ==========
# 更新镇守总属性（由阵容系统调用）
func update_guard_stats(total_bravery: float, total_wisdom: float):
	total_guard_bravery = total_bravery
	total_guard_wisdom = total_wisdom
	print("[IdleManager] 更新镇守属性: 勇武=%.1f 智略=%.1f" % [total_bravery, total_wisdom])

# 获取当前攻城速度加成（临时+永久）
func get_total_speed_bonus() -> float:
	return get_temp_speed_bonus()

# 获取当前临时攻城速度加成
func get_temp_speed_bonus() -> float:
	var now = Time.get_unix_time_from_system()
	if now < temp_speed_bonus_end_time:
		return temp_speed_bonus
	else:
		temp_speed_bonus = 1.0
		return 1.0

# 设置临时速度加成（策略系统调用）
func set_temp_speed_bonus(bonus: float, duration: float):
	var now = Time.get_unix_time_from_system()
	temp_speed_bonus = bonus
	temp_speed_bonus_end_time = now + duration
	print("[IdleManager] 设置临时速度加成: %.1f x 持续 %.1f 秒" % [bonus, duration])

# ========== 永久增益（区域通关奖励） ==========
func add_permanent_money_bonus(bonus_percent: float):
	permanent_money_bonus *= (1 + bonus_percent)
	print("[IdleManager] 永久钱产出+%.1f%%" % [bonus_percent * 100])

func add_permanent_food_bonus(bonus_percent: float):
	permanent_food_bonus *= (1 + bonus_percent)
	print("[IdleManager] 永久粮产出+%.1f%%" % [bonus_percent * 100])

func add_permanent_soldier_bonus(bonus_percent: float):
	permanent_soldier_bonus *= (1 + bonus_percent)
	print("[IdleManager] 永久兵产出+%.1f%%" % [bonus_percent * 100])

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
	
	# 计算国运离线收益（离线期间倍率按1倍计算）
	var total_combat_power = get_total_combat_power()
	var offline_income = (total_combat_power * BASE_COEFFICIENT + 1) * offline_seconds
	
	# 添加国运离线收益
	add_gdp(offline_income)
	
	# 计算钱粮兵离线收益（永久增益，临时增益不计算离线）
	var offline_money = total_guard_wisdom * MONEY_PER_WISDOM * permanent_money_bonus * offline_seconds
	var offline_food = total_guard_wisdom * FOOD_PER_WISDOM * permanent_food_bonus * offline_seconds
	var offline_soldier = total_guard_bravery * SOLDIER_PER_BRAVERY * permanent_soldier_bonus * offline_seconds
	
	add_money(offline_money)
	add_food(offline_food)
	add_soldier(offline_soldier)
	
	offline_income_calculated.emit(offline_income)
	
	# 更新保存时间
	last_save_time = now

# 保存数据（供存档系统调用）
func save_data() -> Dictionary:
	last_save_time = Time.get_unix_time_from_system()
	return {
		"current_gdp": current_gdp,
		"total_gdp": total_gdp,
		"current_money": current_money,
		"current_food": current_food,
		"current_soldier": current_soldier,
		"permanent_money_bonus": permanent_money_bonus,
		"permanent_food_bonus": permanent_food_bonus,
		"permanent_soldier_bonus": permanent_soldier_bonus,
		"total_guard_bravery": total_guard_bravery,
		"total_guard_wisdom": total_guard_wisdom,
		"last_save_time": last_save_time,
		"base_multiplier": base_multiplier,
		"temp_multiplier": temp_multiplier,
		"multiplier_end_time": multiplier_end_time,
		"temp_speed_bonus": temp_speed_bonus,
		"temp_speed_bonus_end_time": temp_speed_bonus_end_time
	}

# 加载数据（供存档系统调用）
func load_data(data: Dictionary):
	current_gdp = data.get("current_gdp", 0.0)
	total_gdp = data.get("total_gdp", 0.0)
	current_money = data.get("current_money", 0.0)
	current_food = data.get("current_food", 0.0)
	current_soldier = data.get("current_soldier", 0.0)
	permanent_money_bonus = data.get("permanent_money_bonus", 1.0)
	permanent_food_bonus = data.get("permanent_food_bonus", 1.0)
	permanent_soldier_bonus = data.get("permanent_soldier_bonus", 1.0)
	total_guard_bravery = data.get("total_guard_bravery", 0.0)
	total_guard_wisdom = data.get("total_guard_wisdom", 0.0)
	last_save_time = data.get("last_save_time", 0.0)
	base_multiplier = data.get("base_multiplier", 1.0)
	temp_multiplier = data.get("temp_multiplier", 1.0)
	multiplier_end_time = data.get("multiplier_end_time", 0.0)
	temp_speed_bonus = data.get("temp_speed_bonus", 1.0)
	temp_speed_bonus_end_time = data.get("temp_speed_bonus_end_time", 0.0)
