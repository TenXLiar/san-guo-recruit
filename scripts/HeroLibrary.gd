extends Node

# 单例实例
static var instance: HeroLibrary = null

# 玩家拥有的武将：key=武将ID，value=拥有数量（1表示拥有，碎片单独存储）
var owned_heroes: Dictionary = {}

# 武将碎片：key=武将ID，value=碎片数量
var hero_fragments: Dictionary = {}

# 玩家当前PVP排名
var player_pvp_rank: int = 1000  # 初始排名 1000，数字越小排名越高

# 信号
signal hero_added(hero_id: String, is_new: bool)  # 武将添加时触发，is_new表示是否是首次获得
signal fragments_updated(hero_id: String, amount: int)  # 碎片变化时触发

func _init():
	if instance == null:
		instance = self
	else:
		queue_free()

# 添加武将（首次添加到武将库，重复则加碎片）
# 返回是否是新武将
func add_hero(hero_id: String) -> bool:
	var is_new = false
	
	if not owned_heroes.has(hero_id):
		# 新武将，加入武将库
		owned_heroes[hero_id] = true
		is_new = true
	else:
		# 重复武将，加1个碎片
		add_fragments(hero_id, 1)
	
	hero_added.emit(hero_id, is_new)
	return is_new

# 添加碎片
func add_fragments(hero_id: String, amount: int):
	if amount <= 0:
		return
	
	if not hero_fragments.has(hero_id):
		hero_fragments[hero_id] = 0
	
	hero_fragments[hero_id] += amount
	fragments_updated.emit(hero_id, amount)

# 消耗碎片，返回是否成功
func spend_fragments(hero_id: String, amount: int) -> bool:
	if amount <= 0:
		return false
	
	if get_hero_fragments(hero_id) >= amount:
		hero_fragments[hero_id] -= amount
		fragments_updated.emit(hero_id, -amount)
		return true
	return false

# 检查是否拥有该武将
func has_hero(hero_id: String) -> bool:
	return owned_heroes.has(hero_id) and owned_heroes[hero_id]

# 获取所有已拥有武将的ID列表
func get_hero_list() -> Array:
	return owned_heroes.keys().filter(func(id): return owned_heroes[id])

# 获取武将碎片数量
func get_hero_fragments(hero_id: String) -> int:
	return hero_fragments.get(hero_id, 0)

# 获取武将详细信息（从JSON加载）
static var all_heroes: Dictionary = {}

func get_hero_data(hero_id: String) -> Dictionary:
	# 首次加载时读取所有武将数据
	if all_heroes.is_empty():
		var file = FileAccess.open("res://data/heroes.json", FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_text) == OK:
				var data = json.data
				for hero in data.get("heroes", []):
					all_heroes[hero.id] = hero
				print("✅ 已加载 %d 个武将数据" % all_heroes.size())
			else:
				print("❌ 解析 heroes.json 失败")
		else:
			print("❌ 找不到 heroes.json 文件")
	
	var hero_data = all_heroes.get(hero_id, {})
	if hero_data is Dictionary:
		if not hero_data.has("attack"):
			hero_data["attack"] = hero_data.get("force", 0)
		if not hero_data.has("defense"):
			hero_data["defense"] = hero_data.get("intelligence", 0)
		return hero_data
	else:
		return {}
	
	# 确保包含 attack 和 defense 字段（战斗系统需要）
	# 假设 JSON 中原本有 force（勇武）和 intelligence（智略）
	if not hero_data.has("attack"):
		hero_data["attack"] = hero_data.get("force", 0)
	if not hero_data.has("defense"):
		hero_data["defense"] = hero_data.get("intelligence", 0)
	
	# 确保其他字段存在
	if not hero_data.has("name"):
		hero_data["name"] = hero_id
	if not hero_data.has("faction"):
		hero_data["faction"] = "qun"
	if not hero_data.has("rarity"):
		hero_data["rarity"] = 1
	
	return hero_data

# 升星（消耗碎片，提升星级，MVP暂不实现）
func upgrade_star(hero_id: String) -> bool:
	# TODO: 实现升星逻辑
	return false

# 保存数据（供存档系统调用）
func save_data() -> Dictionary:
	return {
		"owned_heroes": owned_heroes.duplicate(),
		"hero_fragments": hero_fragments.duplicate()
	}

# 加载数据（供存档系统调用）
func load_data(data: Dictionary):
	owned_heroes = data.get("owned_heroes", {})
	hero_fragments = data.get("hero_fragments", {})

# 保存当前阵容（9宫格，数组长度9，空位为null）
var saved_lineup: Array = []

func save_lineup(lineup: Array):
	saved_lineup = lineup.duplicate()
	# 同时保存到 SaveManager
	SaveManager.save_lineup(lineup)
	print("阵容已保存：", saved_lineup)

# 获取保存的阵容
func get_saved_lineup() -> Array:
	# 优先从 SaveManager 加载（持久化存储）
	var lineup = SaveManager.load_lineup()
	if lineup == null or lineup.size() != 9:
		# 如果 SaveManager 没有数据，使用本地缓存
		if saved_lineup.size() == 9:
			lineup = saved_lineup.duplicate()
		else:
			# 初始化一个空阵容
			lineup = []
			lineup.resize(9)
			lineup.fill(null)
	return lineup

# 获取所有已解锁武将ID
func get_all_unlocked_hero_ids() -> Array:
	var ids: Array = []
	for hero_id in owned_heroes:
		ids.append(hero_id)  # owned_heroes 保存的就是所有已拥有武将，key就是id，value就是数据，所以全部加入
	return ids

# 获取玩家当前PVP排名
func get_player_pvp_rank() -> int:
	return player_pvp_rank

# 设置玩家当前PVP排名
func set_player_pvp_rank(new_rank: int):
	player_pvp_rank = new_rank

# 重置数据（测试用）
func reset():
	owned_heroes.clear()
	hero_fragments.clear()
	saved_lineup.clear()
	saved_lineup.resize(9)
	saved_lineup.fill(null)
	# 也可以清除 SaveManager 的存档（可选）
	SaveManager.save_lineup(saved_lineup)
