extends Node
# class_name SaveManager - 不需要，因为autoload名称已经是SaveManager了
signal save_loaded

# 存档文件路径
var save_path: String = "user://sanguo_recruit.save"

# 存档数据结构
var save_data: Dictionary = {
	"version": 2,  # 版本2 - 新增区域系统数据
	"current_gdp": 1000.0,
	"current_prestige": 0,
	"current_rank": 1000,
	"owned_heroes": {},
	"hero_fragments": {},
	"last_online_time": 0,
	# 新增 - 区域系统数据
	"region_unlocked_regions": [],
	"region_progress": {},
	"region_current_id": "",
	"region_permanent_bonuses": {},
	# 新增 - 钱/粮/兵
	"current_money": 0.0,
	"current_food": 0.0,
	"current_soldier": 0.0,
	# 新增 - 永久增益
	"permanent_money_bonus": 1.0,
	"permanent_food_bonus": 1.0,
	"permanent_soldier_bonus": 1.0,
	# 新增 - 镇守属性
	"total_guard_bravery": 0.0,
	"total_guard_wisdom": 0.0,
	# 新增 - Bongo Cat
	"bongo_level": 1,
	"bongo_exp": 0,
	# 新增 - 临时速度增益
	"temp_speed_bonus": 1.0,
	"temp_speed_bonus_end": 0.0
}

func _ready():
	print("[SaveManager] 初始化完成")

# 保存游戏
func save_game(main_data: Dictionary) -> bool:
	save_data.version = 2
	save_data.current_gdp = main_data.get("current_gdp", 1000.0)
	save_data.current_prestige = main_data.get("current_prestige", 0)
	save_data.current_rank = main_data.get("current_rank", 1000)
	save_data.owned_heroes = main_data.get("owned_heroes", {})
	save_data.hero_fragments = main_data.get("hero_fragments", {})
	save_data.last_online_time = main_data.get("last_online_time", Time.get_unix_time_from_system())
	# 新增 - 区域系统
	var region_manager = get_node_or_null("/root/RegionManager")
	if region_manager:
		var region_data = region_manager.get_save_data()
		save_data.region_unlocked_regions = region_data.unlocked_regions
		save_data.region_progress = region_data.region_progress
		save_data.region_current_id = region_data.current_region_id
		save_data.region_permanent_bonuses = region_data.permanent_bonuses
	# 新增 - 资源系统
	var idle_manager = get_node_or_null("/root/IdleManager")
	if idle_manager:
		save_data.current_money = idle_manager.get_current_money()
		save_data.current_food = idle_manager.get_current_food()
		save_data.current_soldier = idle_manager.get_current_soldier()
		save_data.permanent_money_bonus = idle_manager.permanent_money_bonus
		save_data.permanent_food_bonus = idle_manager.permanent_food_bonus
		save_data.permanent_soldier_bonus = idle_manager.permanent_soldier_bonus
		save_data.total_guard_bravery = idle_manager.total_guard_bravery
		save_data.total_guard_wisdom = idle_manager.total_guard_wisdom
		save_data.temp_speed_bonus = idle_manager.temp_speed_bonus
		save_data.temp_speed_bonus_end = idle_manager.temp_speed_bonus_end_time
	# 新增 - Bongo Cat
	var bongo_cat = get_node_or_null("/root/BongoCat")
	if bongo_cat:
		save_data.bongo_level = bongo_cat.current_level
		save_data.bongo_exp = bongo_cat.current_exp
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		print("[SaveManager] 保存失败：无法打开文件")
		return false
	
	var len = file.get_length()
	file.store_var(save_data)
	len = file.get_length() # get length after writing
	file.close()
	print("[SaveManager] 保存成功，存档大小：%d bytes" % len)
	return true

# 读取游戏
func load_game() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		print("[SaveManager] 存档不存在，使用初始数据")
		return save_data.duplicate()
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		print("[SaveManager] 读取失败：无法打开文件")
		return save_data.duplicate()
	
	var loaded = file.get_var()
	file.close()
	
	save_data = loaded
	print("[SaveManager] 读取成功：%d 个武将，%.1f 国运" % [save_data.owned_heroes.size(), save_data.current_gdp])
	
	# 加载数据到各个管理器
	var region_manager = get_node_or_null("/root/RegionManager")
	if region_manager and save_data.has("region_unlocked_regions"):
		region_manager.load_from_save({
			"unlocked_regions": save_data.region_unlocked_regions,
			"region_progress": save_data.region_progress,
			"current_region_id": save_data.region_current_id,
			"permanent_bonuses": save_data.region_permanent_bonuses
		})
	var idle_manager = get_node_or_null("/root/IdleManager")
	if idle_manager and save_data.has("current_money"):
		idle_manager.current_money = save_data.get("current_money", 0.0)
		idle_manager.current_food = save_data.get("current_food", 0.0)
		idle_manager.current_soldier = save_data.get("current_soldier", 0.0)
		idle_manager.permanent_money_bonus = save_data.get("permanent_money_bonus", 1.0)
		idle_manager.permanent_food_bonus = save_data.get("permanent_food_bonus", 1.0)
		idle_manager.permanent_soldier_bonus = save_data.get("permanent_soldier_bonus", 1.0)
		idle_manager.total_guard_bravery = save_data.get("total_guard_bravery", 0.0)
		idle_manager.total_guard_wisdom = save_data.get("total_guard_wisdom", 0.0)
		idle_manager.temp_speed_bonus = save_data.get("temp_speed_bonus", 1.0)
		idle_manager.temp_speed_bonus_end_time = save_data.get("temp_speed_bonus_end", 0.0)
	var bongo_cat = get_node_or_null("/root/BongoCat")
	if bongo_cat and save_data.has("bongo_level"):
		bongo_cat.current_level = save_data.get("bongo_level", 1)
		bongo_cat.current_exp = save_data.get("bongo_exp", 0)
		bongo_cat.update_level_display()
	
	save_loaded.emit()
	return save_data

# 保存阵容
func save_lineup(lineup_data: Array) -> bool:
	# 阵容数据保存在单独的文件
	var lineup_path = "user://sanguo_lineup.save"
	var file = FileAccess.open(lineup_path, FileAccess.WRITE)
	if not file:
		print("[SaveManager] 阵容保存失败：无法打开文件")
		return false
	
	file.store_var(lineup_data)
	file.close()
	print("[SaveManager] 阵容保存成功")
	return true

# 加载阵容
func load_lineup() -> Array:
	var lineup_path = "user://sanguo_lineup.save"
	if not FileAccess.file_exists(lineup_path):
		print("[SaveManager] 没有保存的阵容，返回空数组")
		return []
	
	var file = FileAccess.open(lineup_path, FileAccess.READ)
	if not file:
		print("[SaveManager] 阵容加载失败：无法打开文件")
		return []
	
	var loaded = file.get_var()
	file.close()
	print("[SaveManager] 阵容加载成功：%d 个武将" % loaded.count(func(h): return h != null))
	return loaded

# 删除存档
func delete_save() -> bool:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		print("[SaveManager] 存档已删除")
		# 同时删除阵容文件
		var lineup_path = "user://sanguo_lineup.save"
		if FileAccess.file_exists(lineup_path):
			DirAccess.remove_absolute(lineup_path)
		return true
	return false

# 检查是否有存档
func has_save() -> bool:
	return FileAccess.file_exists(save_path)
