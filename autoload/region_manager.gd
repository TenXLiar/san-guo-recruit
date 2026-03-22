extends Node
# 区域管理器 - 管理区域解锁和进度

# 区域数据结构
var regions: Array = []          # 所有区域数据（从JSON加载）
var unlocked_regions: Array = []  # 已解锁的区域ID列表
var region_progress: Dictionary = {}  # 每个区域的进度 [0.0 - 100.0]
var current_region_id: String = ""  # 当前攻略区域
var permanent_bonuses: Dictionary = {}  # 永久增益 {"food_bonus": 0.05, ...}

# 信号
signal region_unlocked(region_id: String)
signal region_completed(region_id: String)
signal progress_updated(region_id: String, progress: float)

func _ready():
	# 从JSON加载区域数据
	load_regions_from_json()
	# 初始化：解锁第一个区域
	if regions.size() > 0:
		unlocked_regions = [regions[0].id]
		region_progress[regions[0].id] = 0.0
		current_region_id = regions[0].id
	print("[RegionManager] 初始化完成，加载了 %d 个区域" % regions.size())
	print("[RegionManager] 当前攻略区域: %s" % current_region_id)

# 从data/regions.json加载区域数据
func load_regions_from_json():
	var file = FileAccess.open("res://data/regions.json", FileAccess.READ)
	if not file:
		push_error("[RegionManager] 无法加载regions.json")
		return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("[RegionManager] JSON解析错误: " + json.get_error_message())
		return
	regions = json.data
	print("[RegionManager] 成功加载 %d 个区域配置" % regions.size())

# 获取当前区域数据
func get_current_region() -> Dictionary:
	for r in regions:
		if r.id == current_region_id:
			return r
	return {}

# 获取指定区域数据
func get_region(region_id: String) -> Dictionary:
	for r in regions:
		if r.id == region_id:
			return r
	return {}

# 检查区域是否已解锁
func is_region_unlocked(region_id: String) -> bool:
	return region_id in unlocked_regions

# 检查区域是否已完成
func is_region_completed(region_id: String) -> bool:
	if not region_progress.has(region_id):
		return false
	return region_progress[region_id] >= 100.0

# 增加当前区域进度
func add_region_progress(amount: float) -> bool:
	# 检查当前区域是否已经完成
	if region_progress[current_region_id] >= 100:
		return false
	# 增加进度
	region_progress[current_region_id] += amount
	# 限制最大100
	if region_progress[current_region_id] > 100:
		region_progress[current_region_id] = 100
	# 发出进度更新信号
	progress_updated.emit(current_region_id, region_progress[current_region_id])
	print("[RegionManager] %s 进度 +%.1f = %.1f%%" % [current_region_id, amount, region_progress[current_region_id]])
	# 检查是否完成
	if region_progress[current_region_id] >= 100:
		return _handle_current_region_completed()
	return true

# 处理当前区域完成
func _handle_current_region_completed() -> bool:
	# 发出完成信号
	region_completed.emit(current_region_id)
	# 查找下一个区域
	var next_region = get_next_unlocked_region()
	if next_region != null:
		unlock_next_region(next_region.id)
		print("[RegionManager] 区域 %s 已完成，自动解锁下一个: %s" % [current_region_id, next_region.id])
	return true

# 获取下一个可解锁区域
func get_next_unlocked_region() -> Dictionary:
	for r in regions:
		# 如果已经解锁跳过
		if r.id in unlocked_regions:
			continue
		# 检查解锁条件（前置区域是否完成）
		if r.unlock_condition == null:
			continue  # 第一个区域已经解锁
		if is_region_completed(r.unlock_condition):
			return r
	return {}

# 解锁下一个区域
func unlock_next_region(region_id: String) -> bool:
	if region_id in unlocked_regions:
		return false  # 已经解锁
	unlocked_regions.append(region_id)
	region_progress[region_id] = 0.0
	current_region_id = region_id
	region_unlocked.emit(region_id)
	print("[RegionManager] 解锁新区域: %s" % region_id)
	return true

# 获取当前进度
func get_progress(region_id: String = "") -> float:
	if region_id == "":
		region_id = current_region_id
	if not region_progress.has(region_id):
		return 0.0
	return region_progress[region_id]

# 获取镇守槽位数量（初始1个，每征服一个区域+1）
func get_available_guard_slots() -> int:
	var count = 1
	for r in unlocked_regions:
		if is_region_completed(r):
			count += 1
	return count

# 获取用于存档的数据
func get_save_data() -> Dictionary:
	return {
		"unlocked_regions": unlocked_regions,
		"region_progress": region_progress,
		"current_region_id": current_region_id,
		"permanent_bonuses": permanent_bonuses
	}

# 从存档恢复
func load_from_save(save_data: Dictionary):
	if save_data.has("unlocked_regions"):
		unlocked_regions = save_data.unlocked_regions
	if save_data.has("region_progress"):
		region_progress = save_data.region_progress
	if save_data.has("current_region_id"):
		current_region_id = save_data.current_region_id
	if save_data.has("permanent_bonuses"):
		permanent_bonuses = save_data.permanent_bonuses
	print("[RegionManager] 存档恢复完成: %d 个已解锁区域" % unlocked_regions.size())
