extends Node
# 图鉴管理器 - 展示所有武将，记录收集进度，发放收集奖励

# 收集状态
var collected_heroes: Dictionary = {}  # {hero_id: true/false}
var collection_percentage: float = 0.0

# 组合奖励状态
var completed_combinations: Dictionary = {}  # {combination_id: true}

# 所有组合奖励定义
var COLLECTION_COMBINATIONS = [
	{
		"id": "five_tiger_generals",
		"name": "五虎上将",
		"description": "集齐关张赵马黄",
		"heroes": ["guanyu", "zhangfei", "zhaoyun", "machao", "huangzhong"],
		"reward": {
			"permanent_all_attack_bonus": 0.05,
			"description": "全军勇武+5%"
		}
	},
	{
		"id": "five_tiger_shu",
		"name": "五虎归蜀",
		"description": "五个五虎上将都属于蜀国",
		"heroes": ["guanyu", "zhangfei", "zhaoyun", "machao", "huangzhong"],
		"reward": {
			"permanent_shu_attack_bonus": 0.05,
			"description": "蜀国全员勇武额外+5%"
		}
	},
	{
		"id": "ten_female",
		"name": "佳人如云",
		"description": "收集10名女性武将",
		"count_condition": {"female": 10},
		"reward": {
			"permanent_event_success_bonus": 0.05,
			"description": "事件成功率+5%"
		}
	},
	{
		"id": "wei_five_generals",
		"name": "曹魏五子良将",
		"description": "集齐张辽张郃于禁乐进徐晃",
		"heroes": ["zhangliao", "zhanghe", "yujin", "lejin", "xuhuang"],
		"reward": {
			"permanent_wei_attack_bonus": 0.05,
			"description": "魏国全员勇武+5%"
		}
	},
	{
		"id": "wu_big_three",
		"name": "江东三杰",
		"description": "集齐周瑜吕蒙陆逊",
		"heroes": ["zhouyu", "lvmeng", "luxun"],
		"reward": {
			"permanent_wu_intelligence_bonus": 0.05,
			"description": "吴国全员智略+5%"
		}
	}
]

# 信号
signal collection_percent_updated(new_percent: float)
signal combination_completed(combination_id: String, reward: Dictionary)

func _ready():
	print("[GalleryManager] 初始化完成")

# 检查武将是否已收集
func is_collected(hero_id: String) -> bool:
	return collected_heroes.get(hero_id, false)

# 标记武将已收集
func mark_collected(hero_id: String):
	if collected_heroes.get(hero_id, false):
		return  # 已经收集过了
	
	collected_heroes[hero_id] = true
	update_collection_percentage()
	check_completed_combinations()
	print("[GalleryManager] 新收集武将: %s" % hero_id)

# 更新收集百分比
func update_collection_percentage():
	var total_heroes = HeroLibrary.all_heroes.size()
	var collected = 0
	for hero_id in collected_heroes:
		if collected_heroes[hero_id]:
			collected += 1
	collection_percentage = float(collected) / float(total_heroes) * 100
	collection_percent_updated.emit(collection_percentage)
	print("[GalleryManager] 收集进度更新: %.1f%%" % collection_percentage)

# 检查是否完成了组合奖励
func check_completed_combinations():
	for combo in COLLECTION_COMBINATIONS:
		if completed_combinations.get(combo.id, false):
			continue  # 已经领过奖励
		
		var all_collected = true
		
		# 英雄列表条件
		if combo.has("heroes"):
			for hero_id in combo.heroes:
				if not collected_heroes.get(hero_id, false):
					all_collected = false
					break
		
		# 数量条件（比如收集10个女性）
		if combo.has("count_condition") and all_collected:
			for condition_type in combo.count_condition:
				if condition_type == "female":
					var count_needed = combo.count_condition[condition_type]
					var count_collected = 0
					var female_names = ["甄姬", "貂蝉", "大乔", "小乔", "黄月英", "孙尚香", "祝融夫人", "蔡文姬"]
					for hero_id in collected_heroes:
						if not collected_heroes[hero_id]:
							continue
						var hero = HeroLibrary.get_hero_by_id(hero_id)
						if hero != null and female_names.has(hero.name):
							count_collected += 1
					if count_collected < count_needed:
						all_collected = false
						break
		
		if all_collected:
			completed_combinations[combo.id] = true
			_apply_combination_reward(combo.reward)
			combination_completed.emit(combo.id, combo.reward)
			print("[GalleryManager] 组合完成: %s" % combo.name)

# 应用组合奖励
func _apply_combination_reward(reward: Dictionary):
	if reward.has("permanent_all_attack_bonus"):
		# 永久增加全体攻击
		IdleManager.add_permanent_all_attack_bonus(reward.permanent_all_attack_bonus)
	if reward.has("permanent_shu_attack_bonus"):
		# 蜀国攻击加成
		# 框架已经支持，这里只需要记录，实际计算在伤害统计时生效
		pass
	if reward.has("permanent_event_success_bonus"):
		# 事件成功率加成
		EventManager.add_permanent_event_success_bonus(reward.permanent_event_success_bonus)

# 获取总收集百分比
func get_collection_percentage() -> float:
	return collection_percentage

# 获取已收集数量
func get_collected_count() -> int:
	var count = 0
	for id in collected_heroes:
		if collected_heroes[id]:
			count += 1
	return count

# 获取总武将数量
func get_total_hero_count() -> int:
	return HeroLibrary.all_heroes.size()

# 获取存档数据
func get_save_data() -> Dictionary:
	return {
		"collected_heroes": collected_heroes,
		"completed_combinations": completed_combinations,
		"collection_percentage": collection_percentage
	}

# 从存档恢复
func load_from_save(save_data: Dictionary):
	if save_data.has("collected_heroes"):
		collected_heroes = save_data.collected_heroes
	if save_data.has("completed_combinations"):
		completed_combinations = save_data.completed_combinations
	update_collection_percentage()
	print("[GalleryManager] 存档恢复完成，收集 %.1f%%" % collection_percentage)
