extends Node
# 成就管理器 - 记录成就进度，发放奖励

# 成就列表定义
var ACHIEVEMENTS = [
	# 收集类
	{
		"id": "collect_50_heroes",
		"name": "招贤纳士",
		"description": "收集至少50名武将",
		"type": "collection",
		"condition": "collected_heroes >= 50",
		"reward": {"gdp": 10, "prestige": 50},
		"progress": 0,
		"completed": false
	},
	{
		"id": "collect_100_heroes",
		"name": "天下归心",
		"description": "收集至少100名武将",
		"type": "collection",
		"condition": "collected_heroes >= 100",
		"reward": {"gdp": 20, "prestige": 100},
		"progress": 0,
		"completed": false
	},
	{
		"id": "collect_five_tiger",
		"name": "五虎上将",
		"description": "集齐五虎上将",
		"type": "collection",
		"condition": "collected_all_five_tiger",
		"reward": {"fragments_sp_guanyu": 3},
		"progress": 0,
		"completed": false
	},
	{
		"id": "collect_ten_female",
		"name": "佳人如云",
		"description": "收集10名女性武将",
		"type": "collection",
		"condition": "collected_ten_female",
		"reward": {"money": 100, "food": 100},
		"progress": 0,
		"completed": false
	},
	# 战斗类
	{
		"id": "crit_ten_times",
		"name": "一击致命",
		"description": "单场战斗触发暴击10次",
		"type": "battle",
		"condition": "crit_count >= 10",
		"reward": {"prestige": 30},
		"progress": 0,
		"completed": false
	},
	{
		"id": "win_streak_20",
		"name": "百战百胜",
		"description": "排行榜连胜20场",
		"type": "battle",
		"condition": "win_streak >= 20",
		"reward": {"gdp": 5},
		"progress": 0,
		"completed": false
	},
	# 经营类
	{
		"id": "conquer_all_regions",
		"name": "一统天下",
		"description": "征服所有正常区域",
		"type": "conquest",
		"condition": "all_normal_regions_conquered",
		"reward": {"unlock_hidden": "sp_caocao", "money": 500},
		"progress": 0,
		"completed": false
	},
	{
		"id": "resources_break_10000",
		"name": "富可敌国",
		"description": "累计资源总量破万",
		"type": "resource",
		"condition": "total_resources >= 10000",
		"reward": {"permanent_money_bonus": 0.05},
		"progress": 0,
		"completed": false
	},
	# 互动类
	{
		"id": "bongo_tap_1000",
		"name": "鼓手",
		"description": "敲击Bongo Cat累计1000次",
		"type": "interaction",
		"condition": "bongo_taps >= 1000",
		"reward": {"gdp": 10},
		"progress": 0,
		"completed": false
	},
	{
		"id": "bongo_tap_10000",
		"name": "鼓神",
		"description": "敲击Bongo Cat累计10000次",
		"type": "interaction",
		"condition": "bongo_taps >= 10000",
		"reward": {"unlock_hidden": "sp_lubu"},
		"progress": 0,
		"completed": false
	},
	{
		"id": "bongo_crazy_100",
		"name": "暴走达人",
		"description": "触发暴走100次",
		"type": "interaction",
		"condition": "bongo_crazy >= 100",
		"reward": {"gdp_bonus_permanent": 0.02},
		"progress": 0,
		"completed": false
	},
	{
		"id": "trigger_10_events",
		"name": "阅历丰富",
		"description": "触发10个随机事件",
		"type": "event",
		"condition": "events_triggered >= 10",
		"reward": {"event_success_bonus": 0.02},
		"progress": 0,
		"completed": false
	}
]

# 成就状态
var achievements: Array = []

# 信号
signal achievement_unlocked(achievement: Dictionary, reward: Dictionary)
signal all_achievements_completed

func _ready():
	# 初始化成就列表
	achievements = ACHIEVEMENTS.duplicate()
	print("[AchievementManager] 初始化完成，%d 个成就" % achievements.size())

# 更新进度
func update_progress(achievement_id: String, progress: int) -> bool:
	for ach in achievements:
		if ach.id == achievement_id and not ach.completed:
			ach.progress = progress
			# 检查是否完成
			if _check_completed(ach):
				ach.completed = true
				_apply_reward(ach)
				achievement_unlocked.emit(ach, ach.reward)
				print("[AchievementManager] 成就解锁: %s" % ach.name)
				_check_all_completed()
				return true
	return false

# 检查完成
func _check_completed(ach: Dictionary) -> bool:
	if ach.type == "collection":
		if ach.condition == "collected_heroes >= 50":
			return GalleryManager.get_collected_count() >= 50
		elif ach.condition == "collected_heroes >= 100":
			return GalleryManager.get_collected_count() >= 100
	elif ach.type == "interaction":
		# 查找BongoCat节点（不一定在所有场景都有）
		var bongo_cat = get_tree().root.find_node("BongoCat", true, false)
		if bongo_cat == null:
			# 如果找不到，返回false或根据进度判断
			return ach.progress >= ach.get("target", 1)
		var bongo_total = bongo_cat.get_total_taps()
		var bongo_crazy = bongo_cat.get_total_crazy()
		if ach.condition == "bongo_taps >= 1000":
			return bongo_total >= 1000
		elif ach.condition == "bongo_taps >= 10000":
			return bongo_total >= 10000
		elif ach.condition == "bongo_crazy >= 100":
			return bongo_crazy >= 100
	
	return ach.progress >= ach.get("target", 1)

# 应用奖励
func _apply_reward(ach: Dictionary):
	var reward = ach.reward
	if reward.has("gdp"):
		get_node("/root/main").add_gdp(reward.gdp)
	if reward.has("prestige"):
		get_node("/root/main").add_prestige(reward.prestige)
	if reward.has("money"):
		IdleManager.add_money(reward.money)
	if reward.has("food"):
		IdleManager.add_food(reward.food)
	if reward.has("permanent_money_bonus"):
		IdleManager.add_permanent_money_bonus(reward.permanent_money_bonus)
	if reward.has("permanent_food_bonus"):
		IdleManager.add_permanent_food_bonus(reward.permanent_food_bonus)
	if reward.has("gdp_bonus_permanent"):
		IdleManager.add_permanent_gdp_bonus(reward.gdp_bonus_permanent)
	if reward.has("event_success_bonus"):
		EventManager.add_permanent_event_success_bonus(reward.event_success_bonus)
	if reward.has("unlock_hidden"):
		HeroLibrary.unlock_hidden_hero(reward.unlock_hidden)
	if reward.has("fragments_sp_guanyu"):
		HeroLibrary.add_fragments("hidden_sp_guanyu", reward.fragments_sp_guanyu)

# 检查所有是否完成
func _check_all_completed():
	var all_completed = true
	for ach in achievements:
		if not ach.completed:
			all_completed = false
			break
	if all_completed:
		all_achievements_completed.emit()
		print("[AchievementManager] 所有成就完成!")

# 获取成就列表
func get_achievements() -> Array:
	return achievements

# 获取已完成数量
func get_completed_count() -> int:
	var count = 0
	for ach in achievements:
		if ach.completed:
			count += 1
	return count

# 获取存档数据
func get_save_data() -> Dictionary:
	return {
		"achievements": achievements
	}

# 从存档恢复
func load_from_save(save_data: Dictionary):
	if save_data.has("achievements"):
		achievements = save_data.achievements
	print("[AchievementManager] 存档恢复完成，%d/%d 已完成" % [get_completed_count(), achievements.size()])
