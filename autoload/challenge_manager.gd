extends Node
# 无尽挑战管理器 - 支持无尽波次和每日试炼

# 无尽挑战数据
var endless_current_wave: int = 0
var endless_total_reward_prestige: int = 0
var endless_current_enemy_strength: float = 1.0

# 每日试炼数据
var daily_trial_enabled: bool = false
var daily_trial_rule: Dictionary = {}
var daily_trial_is_completed: bool = false
var daily_trial_last_reset_day: int = -1

# 强度递增系数
const STRENGTH_INCREMENT_PER_WAVE: float = 0.08  # 每波增加8%难度

# 信号
signal endless_wave_completed(wave: int, reward: Dictionary)
signal daily_trial_completed(reward: Dictionary)

func _ready():
	print("[ChallengeManager] 初始化完成")
	# 检查每日试炼重置
	check_daily_trial_reset()

# 开始无尽挑战
func start_endless_challenge():
	endless_current_wave = 0
	endless_total_reward_prestige = 0
	endless_current_enemy_strength = 1.0
	print("[ChallengeManager] 开始新的无尽挑战")

# 完成当前波，进入下一波
func complete_current_wave() -> Dictionary:
	endless_current_wave += 1
	# 计算奖励
	var reward = calculate_endless_reward(endless_current_wave)
	endless_total_reward_prestige += reward.get("prestige", 0)
	# 增加难度
	endless_current_enemy_strength = 1.0 + endless_current_wave * STRENGTH_INCREMENT_PER_WAVE
	endless_wave_completed.emit(endless_current_wave, reward)
	print("[ChallengeManager] 完成无尽波第%d波，难度现在%.2f" % [endless_current_wave, endless_current_enemy_strength])
	return reward

# 计算无尽奖励
func calculate_endless_reward(wave: int) -> Dictionary:
	# 每5波奖励更多声望和聚贤令
	var prestige: int = wave * 2
	var gdp: int = 0
	var gdp_reward: int = int(wave / 5)
	if gdp_reward > 0:
		gdp = gdp_reward
	return {
		"prestige": prestige,
		"gdp": gdp
	}

# 获取当前无尽难度倍率
func get_current_endless_difficulty() -> float:
	return endless_current_enemy_strength

# 每日试炼 - 生成今日规则
func generate_daily_trial():
	# 检查是否已经完成今日
	if daily_trial_is_completed:
		print("[ChallengeManager] 今日试炼已完成")
		return daily_trial_rule
	
	# 随机生成一个规则
	var rules = [
		{
			"id": "only_female",
			"name": "红颜队",
			"description": "只能上阵女性武将",
			"condition": "all_battle_are_female",
			"reward": {
				"fragments_random_purple": 1
			}
		},
		{
			"id": "only_male",
			"name": "男儿当自强",
			"description": "只能上阵男性武将",
			"condition": "all_battle_are_male",
			"reward": {
				"prestige": 50
			}
		},
		{
			"id": "no_spell",
			"name": "禁用法师",
			"description": "上阵武将平均勇武必须大于智略",
			"condition": "avg_force_greater_than_intelligence",
			"reward": {
				"money": 100,
				"food": 100
			}
		},
		{
			"id": "single_faction",
			"name": "同袍同泽",
			"description": "所有上阵武将必须同一势力",
			"condition": "all_battle_same_faction",
			"reward": {
				"fragments_random_blue": 2
			}
		},
		{
			"id": "high_rarity",
			"name": "精英队伍",
			"description": "上阵武将平均稀有度不低于蓝色",
			"condition": "avg_rarity_min_blue",
			"reward": {
				"gdp": 5
			}
		},
		{
			"id": "all_five_tiger",
			"name": "五虎上将",
			"description": "上阵武将必须全部是五虎上将",
			"condition": "all_battle_are_five_tiger",
			"reward": {
				"unlock_fragment_sp_guanyu": 3
			}
		}
	]
	
	# 随机选一个
	var idx: int = randi() % rules.size()
	daily_trial_rule = rules[idx]
	daily_trial_enabled = true
	daily_trial_is_completed = false
	print("[ChallengeManager] 生成今日试炼: %s - %s" % [daily_trial_rule.id, daily_trial_rule.description])
	return daily_trial_rule

# 检查每日试炼重置
func check_daily_trial_reset():
	# 获取今天日期（天数从某个起点算） - 用时间戳计算天数差
	var unix_time = Time.get_unix_time_from_system()
	var day_of_year: int = int(unix_time / 86400)  # 每天86400秒
	if day_of_year != daily_trial_last_reset_day:
		# 新的一天，重置
		daily_trial_last_reset_day = day_of_year
		daily_trial_is_completed = false
		generate_daily_trial()
		print("[ChallengeManager] 每日试炼已重置")

# 完成每日试炼
func complete_daily_trial(passed: bool):
	if not passed:
		return
	
	daily_trial_is_completed = true
	var reward = daily_trial_rule.get("reward", {})
	daily_trial_completed.emit(reward)
	print("[ChallengeManager] 每日试炼完成，获得奖励: %s" % str(reward))

# 检查当前上阵是否符合每日试炼规则
func check_rule_compliance(battle_heroes: Array) -> bool:
	if not daily_trial_enabled or daily_trial_rule.is_empty():
		return true  # 没开试炼就算符合
	
	var rule_id: String = daily_trial_rule.id
	match rule_id:
		"only_female":
			for h in battle_heroes:
				# 判断性别（名字在列表）
				var female_names = ["甄姬", "貂蝉", "大乔", "小乔", "黄月英", "孙尚香", "祝融夫人", "蔡文姬"]
				if not female_names.has(h.data.name):
					return false
			return true
		"only_male":
			var female_names = ["甄姬", "貂蝉", "大乔", "小乔", "黄月", "孙尚香", "祝融夫人", "蔡文姬"]
			for h in battle_heroes:
				if female_names.has(h.data.name):
					return false
			return true
		"no_spell":
			var total_force: float = 0.0
			var total_intelligence: float = 0.0
			var count: int = max(1, battle_heroes.size())
			for h in battle_heroes:
				total_force += float(h.data.get("force", 0))
				total_intelligence += float(h.data.get("intelligence", 0))
			return total_force > total_intelligence
		"single_faction":
			if battle_heroes.is_empty():
				return true
			var faction: String = battle_heroes[0].data.get("faction", "")
			for h in battle_heroes.slice(1):
				if h.data.get("faction", "") != faction:
					return false
			return true
		"high_rarity":
			var total_rarity: int = 0
			var count: int = max(1, battle_heroes.size())
			for h in battle_heroes:
				total_rarity += int(h.data.get("rarity", 1))
			var avg_rarity: float = float(total_rarity) / float(count)
			return avg_rarity >= 3  # 蓝色稀有就是>=3
		"all_five_tiger":
			var five_tiger_names = ["关于", "张飞", "赵云", "马超", "黄忠"]
			for h in battle_heroes:
				if not five_tiger_names.has(h.data.name):
					return false
			return battle_heroes.size() >= 5
		_:
			return true  # 默认符合
	return true

# 获取存档数据
func get_save_data() -> Dictionary:
	return {
		"endless_current_wave": endless_current_wave,
		"endless_total_reward_prestige": endless_total_reward_prestige,
		"daily_trial_completed": daily_trial_is_completed,
		"daily_trial_last_reset_day": daily_trial_last_reset_day,
		"daily_trial_rule": daily_trial_rule
	}

# 从存档恢复
func load_from_save(save_data: Dictionary):
	if save_data.has("endless_current_wave"):
		endless_current_wave = save_data.endless_current_wave
	if save_data.has("endless_total_reward_prestige"):
		endless_total_reward_prestige = save_data.endless_total_reward_prestige
	if save_data.has("daily_trial_completed"):
		daily_trial_is_completed = save_data.daily_trial_completed
	if save_data.has("daily_trial_last_reset_day"):
		daily_trial_last_reset_day = save_data.daily_trial_last_reset_day
	if save_data.has("daily_trial_rule"):
		daily_trial_rule = save_data.daily_trial_rule
	print("[ChallengeManager] 存档恢复完成")
