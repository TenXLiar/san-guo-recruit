extends Node

# 单例实例
static var instance = null

# 配置常量
const MAX_AI_COUNT: int = 15  # 每日生成15个AI
const MAX_CHALLENGES: int = 10  # 每日挑战次数
const POWER_FACTOR: float = 0.1  # 战力浮动系数（0.85~1.15）
const BOND_PROBABILITY: float = 0.7  # AI阵容羁绊概率

# 玩家数据
var player_rank: int = 100  # 初始排名
var remaining_challenges: int = MAX_CHALLENGES  # 剩余挑战次数
var prestige: int = 0  # 威名
var last_refresh_date: String = ""  # 上次刷新AI的日期（YYYY-MM-DD）

# AI列表
var ai_list: Array = []

# 信号
signal ai_list_updated()  # AI列表更新时触发
signal challenge_finished(victory: bool, rank_changed: bool, reward: int)  # 挑战结束时触发
signal challenges_updated(remaining: int)  # 挑战次数变化时触发

func _init():
	if instance == null:
		instance = self
	else:
		queue_free()

func _ready():
	# 检查是否需要刷新AI
	check_refresh_ai()

# 检查是否需要刷新AI（每天凌晨刷新）
func check_refresh_ai():
	var current_date = Time.get_date_string_from_system()
	if current_date != last_refresh_date or ai_list.is_empty():
		generate_ai_list()
		last_refresh_date = current_date
		remaining_challenges = MAX_CHALLENGES
		challenges_updated.emit(remaining_challenges)

# 生成AI列表
func generate_ai_list():
	ai_list.clear()
	var player_power = _get_player_combat_power()
	
	for i in range(MAX_AI_COUNT):
		# AI排名从比玩家排名高的位置
		var rank = player_rank - (MAX_AI_COUNT - i)
		rank = max(rank, 1)  # 排名不能低于1
		
		# AI战力在玩家战力的0.85~1.15倍
		var ai_power = player_power * (1.0 - POWER_FACTOR + randf() * POWER_FACTOR * 2)
		ai_power = max(ai_power, 100)  # 最低战力
		
		# 生成AI阵容
		var lineup = generate_ai_lineup(ai_power)
		
		var ai = {
			"id": "ai_%d" % i,
			"name": _get_random_ai_name(),
			"rank": rank,
			"power": round(ai_power),
			"lineup": lineup,
			"reward_prestige": round(ai_power * 0.1)  # 奖励威名
		}
		
		ai_list.append(ai)
	
	# 按排名排序
	ai_list.sort_custom(func(a, b): return a.rank < b.rank)
	ai_list_updated.emit()

# 生成随机AI名称
func _get_random_ai_name() -> String:
	var prefixes = ["智勇", "仁义", "奸雄", "白马", "锦帆", "卧龙", "凤雏", "幼麒", "冢虎", "美髯", "常胜", "古之恶来", "虎痴"]
	var suffixes = ["大将", "都督", "丞相", "将军", "谋士", "猛将", "儒将", "勇将", "智将", "豪杰", "名士", "枭雄", "猛将"]
	return prefixes[randi() % prefixes.size()] + suffixes[randi() % suffixes.size()]

# 生成AI阵容
func generate_ai_lineup(target_power: float) -> Array:
	var lineup = []
	lineup.resize(9)
	lineup.fill(null)
	
	var all_heroes = _get_all_heroes()
	var selected_heroes = []
	var total_power = 0.0
	
	# 70%概率生成有羁绊的阵容
	var use_bond = randf() < BOND_PROBABILITY
	var target_faction = null
	
	if use_bond:
		# 随机选择一个势力
		var factions = ["wei", "shu", "wu", "qun"]
		target_faction = factions[randi() % factions.size()]
		# 优先选择该势力武将
		var faction_heroes = all_heroes.filter(func(h): return h.faction == target_faction)
		# 至少选3个同势力武将
		for i in range(3):
			if faction_heroes.is_empty():
				break
			var hero = faction_heroes[randi() % faction_heroes.size()]
			selected_heroes.append(hero)
			total_power += _calculate_hero_power(hero)
			faction_heroes.erase(faction_heroes.find(hero))
			all_heroes.erase(all_heroes.find(hero))
	
	# 填充剩下的位置，直到达到目标战力
	while total_power < target_power and selected_heroes.size() < 9:
		if all_heroes.is_empty():
			break
		var hero = all_heroes[randi() % all_heroes.size()]
		selected_heroes.append(hero)
		total_power += _calculate_hero_power(hero)
		all_heroes.erase(all_heroes.find(hero))
	
	# 将武将分配到阵容位置（优先放前排）
	var positions = [0, 1, 2, 3, 4, 5, 6, 7, 8]
	for i in range(min(selected_heroes.size(), 9)):
		lineup[positions[i]] = selected_heroes[i].id
	
	return lineup

# 获取所有武将数据
static var all_heroes: Array = []

func _get_all_heroes() -> Array:
	if all_heroes.is_empty():
		var file = FileAccess.open("res://data/heroes.json", FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_text) == OK:
				var data = json.data
				all_heroes = data.get("heroes", [])
	return all_heroes.duplicate()

# 计算武将战力
func _calculate_hero_power(hero: Dictionary) -> float:
	var power = hero.get("force", 0) * 0.4 + \
				hero.get("intelligence", 0) * 0.3 + \
				hero.get("politics", 0) * 0.2 + \
				hero.get("charm", 0) * 0.1
	return power * (1 + hero.get("rarity", 1) * 0.2)

# 获取玩家总战力
func _get_player_combat_power() -> float:
	# TODO: 从LineupUI获取玩家总战力
	# 暂时返回模拟值
	return 500.0

# 挑战AI
func challenge_ai(ai_index: int) -> Dictionary:
	# 检查挑战次数
	if remaining_challenges <= 0:
		return {
			"success": false,
			"message": "今日挑战次数已用完"
		}
	
	# 检查索引是否有效
	if ai_index < 0 or ai_index >= ai_list.size():
		return {
			"success": false,
			"message": "无效的AI索引"
		}
	
	var ai = ai_list[ai_index]
	
	# 检查排名是否高于玩家
	if ai.rank >= player_rank:
		return {
			"success": false,
			"message": "只能挑战排名高于自己的AI"
		}
	
	# 扣除挑战次数
	remaining_challenges -= 1
	challenges_updated.emit(remaining_challenges)
	
	# 获取玩家阵容
	# TODO: 从LineupUI获取玩家阵容
	var player_lineup = []
	player_lineup.resize(9)
	player_lineup.fill(null)
	
	# 开始战斗
	var battle_result = BattleManager.instance.start_battle(player_lineup, ai.lineup)
	var victory = battle_result.get("victory", false)
	var rank_changed = false
	
	# 处理胜负
	if victory:
		# 胜利，交换排名
		var old_rank = player_rank
		player_rank = ai.rank
		ai.rank = old_rank
		rank_changed = true
		
		# 增加威名
		prestige += ai.reward_prestige
		
		# 重新排序AI列表
		ai_list.sort_custom(func(a, b): return a.rank < b.rank)
		ai_list_updated.emit()
	
	challenge_finished.emit(victory, rank_changed, ai.reward_prestige if victory else 0)
	
	return {
		"success": true,
		"victory": victory,
		"rank_changed": rank_changed,
		"old_rank": battle_result.get("old_rank", player_rank),
		"new_rank": player_rank,
		"reward_prestige": ai.reward_prestige if victory else 0,
		"battle_report": battle_result.get("report", [])
	}

# 获取AI列表
func get_ai_list() -> Array:
	check_refresh_ai()
	return ai_list.duplicate()

# 获取玩家信息
func get_player_info() -> Dictionary:
	return {
		"rank": player_rank,
		"remaining_challenges": remaining_challenges,
		"prestige": prestige,
		"max_challenges": MAX_CHALLENGES
	}

# 购买额外挑战次数（MVP暂不实现）
func buy_extra_challenges() -> bool:
	# TODO: 实现购买逻辑
	return false

# 保存数据（供存档系统调用）
func save_data() -> Dictionary:
	return {
		"player_rank": player_rank,
		"remaining_challenges": remaining_challenges,
		"prestige": prestige,
		"last_refresh_date": last_refresh_date,
		"ai_list": ai_list.duplicate()
	}

# 加载数据（供存档系统调用）
func load_data(data: Dictionary):
	player_rank = data.get("player_rank", 100)
	remaining_challenges = data.get("remaining_challenges", MAX_CHALLENGES)
	prestige = data.get("prestige", 0)
	last_refresh_date = data.get("last_refresh_date", "")
	ai_list = data.get("ai_list", [])
	# 检查是否需要刷新AI
	check_refresh_ai()
