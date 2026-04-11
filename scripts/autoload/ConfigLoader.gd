#!/usr/bin/env -S godot -s
"""
ConfigLoader - 全局配置加载器
自动加载 data/ 目录下所有 CSV 配置数据，供全局访问

使用方法:
- 放在 autoload/ 目录下，Godot 启动自动加载
- ConfigLoader.heroes 获取所有武将配置
- ConfigLoader.get_hero_by_id("shu_guanyu") 获取单个武将
"""

extends Node

# 存储所有加载好的配置
var configs: Dictionary = {}
var heroes: Array = []
var heroes_by_id: Dictionary = {}
var skills: Array = []
var regions: Array = []
var events: Array = []
var game_config: Dictionary = {}

func _ready():
	# 自动加载所有 CSV
	load_all_configs()
	print("✅ ConfigLoader 初始化完成，已加载:")
	if heroes.size() > 0:
		print(f"   - 武将: {heroes.size()} 个")
	if skills.size() > 0:
		print(f"   - 技能: {skills.size()} 个")
	if regions.size() > 0:
		print(f"   - 区域: {regions.size()} 个")
	if not game_config.is_empty():
		print(f"   - 游戏配置: {game_config.size()} 项")

func load_csv(file_path: String) -> Array:
	"""加载 CSV 文件返回字典数组"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error(f"❌ 无法加载 CSV: {file_path}")
		return []
	
	# 读取第一行作为表头
	var line = file.get_csv_line()
	var headers = line
	if headers.empty():
		push_error(f"❌ CSV 文件为空: {file_path}")
		return []
	
	var result = []
	
	# 逐行读取
	while not file.eof_reached():
		line = file.get_csv_line()
		if line.empty():
			continue
		if line.size() != headers.size():
			push_warning(f"⚠️  行数据列数不匹配，跳过: {line}")
			continue
		
		var row = {}
		for i in range(headers.size()):
			var key = headers[i].strip()
			var value = line[i].strip()
			# 尝试转换为数字
			if value.is_valid_float():
				row[key] = value.to_float()
			elif value.is_valid_int():
				row[key] = value.to_int()
			else:
				row[key] = value
		result.append(row)
	
	file.close()
	return result

func load_all_configs():
	"""加载 data 目录下所有已知配置"""
	# 武将配置
	var heroes_csv = load_csv("res://data/heroes.csv")
	if heroes_csv.size() > 0:
		heroes = heroes_csv
		# 构建 ID 索引
		for hero in heroes:
			if hero.has("id"):
				heroes_by_id[hero.id] = hero
		configs.heroes = heroes
	
	# 技能配置
	var skills_csv = load_csv("res://data/skills.csv")
	if skills_csv.size() > 0:
		skills = skills_csv
		configs.skills = skills
	
	# 区域配置
	var regions_csv = load_csv("res://data/regions.csv")
	if regions_csv.size() > 0:
		regions = regions_csv
		configs.regions = regions
	
	# 事件配置
	var events_csv = load_csv("res://data/events.csv")
	if events_csv.size() > 0:
		events = events_csv
		configs.events = events
	
	# 游戏全局配置
	var config_csv = load_csv("res://data/game_config.csv")
	if config_csv.size() > 0:
		# 转成字典方便查询: category.key -> value
		for row in config_csv:
			var category = row.get("category", "")
			var key = row.get("key", "")
			var value = row.get("value", "")
			var type_str = row.get("type", "string")
			
			# 确保类型正确
			if type_str == "int":
				value = int(value)
			elif type_str == "float":
				value = float(value)
			elif type_str == "bool":
				value = value in ["true", "True", "1", "yes"]
			
			if category != "":
				if not game_config.has(category):
					game_config[category] = {}
				game_config[category][key] = value
		configs.game_config = game_config

func get_hero_by_id(hero_id: String) -> Dictionary:
	"""根据 ID 获取武将数据"""
	if heroes_by_id.has(hero_id):
		return heroes_by_id[hero_id]
	return {}

func get_heroes_by_faction(faction: String) -> Array:
	"""按阵营筛选武将"""
	var result = []
	for hero in heroes:
		if hero.get("faction", "") == faction:
			result.append(hero)
	return result

func get_heroes_by_rarity(rarity: int) -> Array:
	"""按稀有度筛选武将"""
	var result = []
	for hero in heroes:
		if hero.get("rarity", 0) == rarity:
			result.append(hero)
	return result

func get_all_heroes() -> Array:
	"""获取所有武将"""
	return heroes

func get_config(config_name: String) -> Array:
	"""获取任意配置表"""
	if configs.has(config_name):
		return configs[config_name]
	return []

func get_game_config(category: String, key: String, default):
	"""获取游戏配置
	示例:
	    get_game_config("recruit", "cost_single", 100)
	"""
	if game_config.has(category) and game_config[category].has(key):
		return game_config[category][key]
	return default

func get_recruit_config(key: String, default):
	"""快捷获取抽卡配置"""
	return get_game_config("recruit", key, default)

func get_base_config(key: String, default):
	"""快捷获取基础配置"""
	return get_game_config("base", key, default)
