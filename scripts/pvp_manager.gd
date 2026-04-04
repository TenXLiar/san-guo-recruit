extends Node

# 单例实例
static var instance: pvp_manager = null

# 战斗状态
enum BattleState {
	IDLE,
	PREPARING,
	FIGHTING,
	FINISHED
}

# 战斗单位状态
var current_state: BattleState = BattleState.IDLE

# 战斗配置
const BASE_SKILL_RATE: float = 0.2
const BASE_CRIT_RATE: float = 0.05
const BASE_CRIT_DAMAGE: float = 1.5

# 战斗回调
signal battle_finished(victory: bool, report: Array)
signal round_finished(round: int, events: Array)

func _init():
	if instance == null:
		instance = self
	else:
		queue_free()

# ---------- 辅助函数 ----------
func _normalize_hero_id(hero_id) -> String:
	if typeof(hero_id) == TYPE_STRING:
		return hero_id
	elif typeof(hero_id) == TYPE_DICTIONARY:
		return hero_id.get("id", hero_id.get("hero_id", ""))
	else:
		return ""

# 开始战斗（返回战斗控制器）
func start_battle(attacker_lineup: Array, defender_lineup: Array) -> BattleController:
	var controller = BattleController.new()
	controller.attacker_units = _init_battle_units(attacker_lineup, true)
	controller.defender_units = _init_battle_units(defender_lineup, false)
	controller.round = 0
	controller.finished = false
	controller.victory = false
	controller.report = []
	controller.max_rounds = 50
	controller.manager = self
	
	# 应用羁绊效果
	var attacker_buffs = BondManager.instance.get_total_bond_effects(attacker_lineup)
	var defender_buffs = BondManager.instance.get_total_bond_effects(defender_lineup)
	_apply_buffs(controller.attacker_units, attacker_buffs)
	_apply_buffs(controller.defender_units, defender_buffs)
	
	print("=====================================")
	print("⚔️  [战斗系统] 战斗开始（逐步模式）")
	print("   攻击方人数：", len(controller.attacker_units))
	print("   防守方人数：", len(controller.defender_units))
	print("=====================================")
	
	return controller

# 战斗控制器类
class BattleController:
	var attacker_units: Array = []
	var defender_units: Array = []
	var round: int = 0
	var finished: bool = false
	var victory: bool = false
	var report: Array = []
	var max_rounds: int = 50
	var manager: Node = null
	
	func take_turn() -> Array:
		if finished:
			return []
		
		round += 1
		var round_events = []
		
		# 回合开始效果（燃烧、眩晕等）
		var pre_round_events = manager._process_round_start_effects(attacker_units, defender_units)
		round_events.append_array(pre_round_events)
		
		# 检查是否结束
		if _check_finished():
			finished = true
			manager.round_finished.emit(round, round_events)
			return round_events
		
		# 合并双方单位，按速度排序
		var all_units = []
		all_units.append_array(attacker_units)
		all_units.append_array(defender_units)
		all_units.sort_custom(func(a, b): return a.speed > b.speed)
		
		for unit in all_units:
			if unit.hp <= 0:
				continue
			if _check_finished():
				break
			
			# 眩晕判定
			if unit.debuffs.has("stun") and unit.debuffs["stun"] > 0:
				unit.debuffs["stun"] -= 1
				if unit.debuffs["stun"] <= 0:
					unit.debuffs.erase("stun")
				continue
			
			# 技能判定
			var skill_rate = manager.BASE_SKILL_RATE + unit.buffs.get("skill_rate_buff", 0)
			var use_skill = randf() < skill_rate
			var event
			if use_skill:
				event = manager._use_skill(unit, attacker_units, defender_units)
			else:
				event = manager._normal_attack(unit, attacker_units, defender_units)
			round_events.append(event)
		
		# 回合结束
		manager.round_finished.emit(round, round_events)
		report.append({"round": round, "events": round_events})
		
		# 检查战斗是否结束
		if _check_finished():
			finished = true
			var attacker_alive = manager._count_alive_units(attacker_units) > 0
			var defender_alive = manager._count_alive_units(defender_units) > 0
			victory = attacker_alive and not defender_alive
			
			print("🏁 [战斗结束] 结果：")
			print("   总回合数：%d" % round)
			print("   攻击方存活：%d" % manager._count_alive_units(attacker_units))
			print("   防守方存活：%d" % manager._count_alive_units(defender_units))
			print("   战斗结果：%s" % ("攻击方胜利" if victory else "防守方胜利"))
			
			manager.battle_finished.emit(victory, report)
		
		return round_events
	
	func is_finished() -> bool:
		return finished
	
	func get_result() -> Dictionary:
		return {
			"victory": victory,
			"rounds": round,
			"report": report,
			"attacker_alive": manager._count_alive_units(attacker_units),
			"defender_alive": manager._count_alive_units(defender_units)
		}
	
	func _check_finished() -> bool:
		var attacker_alive = manager._count_alive_units(attacker_units) > 0
		var defender_alive = manager._count_alive_units(defender_units) > 0
		return not attacker_alive or not defender_alive or round >= max_rounds

# 初始化战斗单位
func _init_battle_units(lineup: Array, is_attacker: bool) -> Array:
	var units = []
	var position = 0
	var side = "攻击方" if is_attacker else "防守方"
	
	print("   📋 [初始化%s] 开始初始化单位：" % side)
	
	for raw_id in lineup:
		var hero_id = _normalize_hero_id(raw_id)
		if hero_id == "":
			position += 1
			continue
		
		var hero_data = HeroLibrary.instance.get_hero_data(hero_id)
		if hero_data.is_empty():
			position += 1
			continue
		
		var force = hero_data.get("force", 50)
		var intelligence = hero_data.get("intelligence", 50)
		var hp = force * 10 + intelligence * 5
		var attack = force * 2
		var defense = force * 0.5 + intelligence * 0.3
		var speed = force * 0.3 + intelligence * 0.7
		
		# 获取技能效果，并确保它是字典
		var skill_effect = hero_data.get("skill_effect", {})
		if typeof(skill_effect) != TYPE_DICTIONARY:
			skill_effect = {}
		
		var unit = {
			"id": hero_id,
			"name": hero_data.get("name", "未知"),
			"faction": hero_data.get("faction", ""),
			"hp": hp,
			"max_hp": hp,
			"attack": attack,
			"defense": defense,
			"speed": speed,
			"intelligence": intelligence,
			"skill": skill_effect,
			"is_attacker": is_attacker,
			"position": position,
			"buffs": {},
			"debuffs": {}
		}
		
		units.append(unit)
		print("      ✅ %s (%s)：HP=%d ATK=%d DEF=%d SPD=%d 技能=%s" % [
			unit.name, unit.faction, unit.hp, unit.attack, unit.defense, unit.speed,
			str(unit.skill.get("name", "无"))
		])
		position += 1
	
	return units

# 应用buff效果
func _apply_buffs(units: Array, buffs: Dictionary):
	if buffs.is_empty():
		return
	
	print("   🎯 [应用羁绊buff]：")
	for unit in units:
		for buff_name in buffs:
			var value = buffs[buff_name]
			if unit.buffs.has(buff_name):
				unit.buffs[buff_name] += value
			else:
				unit.buffs[buff_name] = value
			
			if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
				print("      ➕ %s：%s += %.2f" % [unit.name, buff_name, value])
			else:
				print("      ➕ %s：%s += %s" % [unit.name, buff_name, str(value)])

# 普通攻击
func _normal_attack(attacker: Dictionary, attacker_units: Array, defender_units: Array) -> Dictionary:
	var target = _select_front_target(defender_units if attacker.is_attacker else attacker_units)
	if not target:
		return {
			"type": "attack",
			"attacker": attacker.name,
			"target": "无",
			"damage": 0,
			"message": "%s攻击，但没有目标" % attacker.name
		}
	
	var damage_result = _calculate_damage(attacker, target)
	var damage = damage_result.damage
	var is_crit = damage_result.is_crit
	
	target.hp -= damage
	target.hp = max(target.hp, 0)
	
	return {
		"type": "attack",
		"attacker": attacker.name,
		"target": target.name,
		"damage": damage,
		"is_crit": is_crit,
		"message": "%s对%s造成%d点伤害" % [attacker.name, target.name, damage]
	}

# 使用技能
func _use_skill(attacker: Dictionary, attacker_units: Array, defender_units: Array) -> Dictionary:
	var skill = attacker.skill
	if skill.is_empty():
		return _normal_attack(attacker, attacker_units, defender_units)
	
	var targets = []
	var damage_total = 0
	var heal_total = 0
	var message = ""
	
	# 根据技能类型选择目标并执行
	match skill.get("type", "damage"):
		"damage":
			targets = _select_skill_targets(skill, attacker, attacker_units, defender_units)
			for target in targets:
				var damage_result = _calculate_damage(attacker, target, skill.get("damage_multiplier", 1.0))
				var damage = damage_result.damage
				target.hp -= damage
				target.hp = max(target.hp, 0)
				damage_total += damage
				message += "%s对%s造成%d点伤害；" % [attacker.name, target.name, damage]
			
			# 应用额外效果
			if skill.has("stun_chance"):
				for target in targets:
					if randf() < skill.stun_chance:
						target.debuffs["stun"] = skill.get("stun_duration", 1)
						message += "%s被眩晕%d回合；" % [target.name, skill.stun_duration]
			
			if skill.has("defense_debuff"):
				for target in targets:
					if target.debuffs.has("defense_debuff"):
						target.debuffs["defense_debuff"] += skill.defense_debuff
					else:
						target.debuffs["defense_debuff"] = skill.defense_debuff
					message += "%s防御降低%d%%；" % [target.name, skill.defense_debuff * 100]
			
			if skill.has("self_hp_cost"):
				var cost = attacker.hp * skill.self_hp_cost
				attacker.hp -= cost
				message += "%s消耗%.0f点生命值；" % [attacker.name, cost]
			
			if skill.has("damage_reduction"):
				if attacker.buffs.has("damage_reduction"):
					attacker.buffs["damage_reduction"] += skill.damage_reduction
				else:
					attacker.buffs["damage_reduction"] = skill.damage_reduction
				message += "%s伤害减免提升%d%%；" % [attacker.name, skill.damage_reduction * 100]
			
			if skill.has("attack_buff") and skill.get("duration", 0) > 0:
				var ally_units = _get_all_alive_units(attacker_units)
				if skill.get("target") == "all_ally_wei":
					ally_units = ally_units.filter(func(u): return u.faction == "wei")
				elif skill.get("target") == "all_ally_shu":
					ally_units = ally_units.filter(func(u): return u.faction == "shu")
				elif skill.get("target") == "all_ally_wu":
					ally_units = ally_units.filter(func(u): return u.faction == "wu")
				elif skill.get("target") == "all_ally_qun":
					ally_units = ally_units.filter(func(u): return u.faction == "qun")
				
				for unit in ally_units:
					if unit.buffs.has("attack_buff"):
						unit.buffs["attack_buff"] += skill.attack_buff
					else:
						unit.buffs["attack_buff"] = skill.attack_buff
					message += "%s攻击提升%d%%；" % [unit.name, skill.attack_buff * 100]
			
			if skill.has("skill_rate_buff") and skill.get("duration", 0) > 0:
				var ally_units = _get_all_alive_units(attacker_units)
				if skill.get("target") == "all_ally_wu":
					ally_units = ally_units.filter(func(u): return u.faction == "wu")
				
				for unit in ally_units:
					if unit.buffs.has("skill_rate_buff"):
						unit.buffs["skill_rate_buff"] += skill.skill_rate_buff
					else:
						unit.buffs["skill_rate_buff"] = skill.skill_rate_buff
					message += "%s技能概率提升%d%%；" % [unit.name, skill.skill_rate_buff * 100]
			
			if skill.has("burn_damage") and skill.get("burn_duration", 0) > 0:
				for target in targets:
					if not target.debuffs.has("burn"):
						target.debuffs["burn"] = []
					target.debuffs["burn"].append({
						"damage_percent": skill.burn_damage,
						"remaining": skill.burn_duration
					})
					message += "%s被燃烧，持续%d回合；" % [target.name, skill.burn_duration]
		
		"heal":
			var ally_units = _get_all_alive_units(attacker_units)
			match skill.get("target", "all_ally"):
				"all_ally":
					targets = ally_units
			
			for target in targets:
				var heal_amount = target.max_hp * skill.get("heal_percent", 0.1)
				var healed = heal_amount
				target.hp += heal_amount
				if target.hp > target.max_hp:
					healed = target.max_hp - (target.hp - heal_amount)
					target.hp = target.max_hp
				heal_total += healed
				message += "%s回复%.0f点生命值；" % [target.name, healed]
			
			if skill.has("defense_buff"):
				for unit in targets:
					if unit.buffs.has("defense_buff"):
						unit.buffs["defense_buff"] += skill.defense_buff
					else:
						unit.buffs["defense_buff"] = skill.defense_buff
					message += "%s防御提升%d%%；" % [unit.name, skill.defense_buff * 100]
		
		"buff":
			var ally_units = _get_all_alive_units(attacker_units)
			if skill.get("target") == "all_ally_wei":
				ally_units = ally_units.filter(func(u): return u.faction == "wei")
			elif skill.get("target") == "all_ally_shu":
				ally_units = ally_units.filter(func(u): return u.faction == "shu")
			elif skill.get("target") == "all_ally_wu":
				ally_units = ally_units.filter(func(u): return u.faction == "wu")
			elif skill.get("target") == "all_ally_qun":
				ally_units = ally_units.filter(func(u): return u.faction == "qun")
			elif skill.get("target") == "all_ally":
				pass
			
			targets = ally_units
			
			if skill.has("attack_buff"):
				for unit in targets:
					if unit.buffs.has("attack_buff"):
						unit.buffs["attack_buff"] += skill.attack_buff
					else:
						unit.buffs["attack_buff"] = skill.attack_buff
					message += "%s攻击提升%d%%；" % [unit.name, skill.attack_buff * 100]
			
			if skill.has("skill_rate_buff"):
				for unit in targets:
					if unit.buffs.has("skill_rate_buff"):
						unit.buffs["skill_rate_buff"] += skill.skill_rate_buff
					else:
						unit.buffs["skill_rate_buff"] = skill.skill_rate_buff
					message += "%s技能触发概率提升%d%%；" % [unit.name, skill.skill_rate_buff * 100]
	
	return {
		"type": "skill",
		"attacker": attacker.name,
		"skill_name": skill.get("name", "技能"),
		"targets": targets.map(func(t): return t.name),
		"damage": damage_total,
		"heal": heal_total,
		"message": message
	}

# 计算伤害（返回字典）
func _calculate_damage(attacker: Dictionary, target: Dictionary, multiplier: float = 1.0) -> Dictionary:
	var base_damage = attacker.attack * multiplier
	var attack_buff = attacker.buffs.get("attack_buff", 0)
	base_damage *= (1 + attack_buff)
	
	var defense = target.defense
	var defense_debuff = target.debuffs.get("defense_debuff", 0)
	defense *= (1 - defense_debuff)
	var defense_reduction = defense / (defense + 100)
	var damage = base_damage * (1 - defense_reduction)
	
	var damage_reduction = target.buffs.get("damage_reduction", 0)
	damage *= (1 - damage_reduction)
	
	var crit_rate = BASE_CRIT_RATE + attacker.buffs.get("crit_buff", 0)
	var is_crit = randf() < crit_rate
	if attacker.skill.has("critical") and attacker.skill.critical:
		is_crit = true
	if is_crit:
		damage *= BASE_CRIT_DAMAGE
	
	var random_factor = 0.95 + randf() * 0.1
	damage *= random_factor
	damage = round(max(damage, 1))
	
	return {
		"damage": damage,
		"is_crit": is_crit
	}

# 选择前排目标
func _select_front_target(units: Array) -> Dictionary:
	var front_units = _get_front_units(units)
	if front_units.is_empty():
		return _select_random_target(units)
	return front_units[randi() % front_units.size()]

func _get_front_units(units: Array) -> Array:
	return units.filter(func(u): return u.hp > 0 and u.position < 3)

func _get_back_units(units: Array) -> Array:
	return units.filter(func(u): return u.hp > 0 and u.position >= 6)

func _select_random_target(units: Array) -> Dictionary:
	var alive = _get_all_alive_units(units)
	if alive.is_empty():
		return {}
	return alive[randi() % alive.size()]

func _select_skill_targets(skill: Dictionary, attacker: Dictionary, attacker_units: Array, defender_units: Array) -> Array:
	var enemies = defender_units if attacker.is_attacker else attacker_units
	var allies = attacker_units if attacker.is_attacker else defender_units
	var targets = []
	
	match skill.get("target", "single_enemy"):
		"single_enemy":
			var target = _select_random_target(enemies)
			if target:
				targets.append(target)
		"front_enemy":
			targets = _get_front_units(enemies)
		"back_enemy":
			targets = _get_back_units(enemies)
		"all_enemy":
			targets = _get_all_alive_units(enemies)
		"random_enemy":
			var alive_enemies = _get_all_alive_units(enemies)
			var count = skill.get("target_count", 2)
			for i in range(count):
				if alive_enemies.size() > 0:
					var idx = randi() % alive_enemies.size()
					targets.append(alive_enemies[idx])
					alive_enemies.remove_at(idx)
	
	return targets

func _process_round_start_effects(attacker_units: Array, defender_units: Array) -> Array:
	var events = []
	var all_units = []
	all_units.append_array(attacker_units)
	all_units.append_array(defender_units)
	
	for unit in all_units:
		if unit.hp <= 0:
			continue
		
		if unit.debuffs.has("burn"):
			var burn_damage = 0
			for i in range(unit.debuffs["burn"].size() - 1, -1, -1):
				var burn = unit.debuffs["burn"][i]
				var damage = unit.max_hp * burn.damage_percent
				burn_damage += damage
				unit.hp -= damage
				burn.remaining -= 1
				if burn.remaining <= 0:
					unit.debuffs["burn"].remove_at(i)
			
			if unit.debuffs["burn"].is_empty():
				unit.debuffs.erase("burn")
			
			if burn_damage > 0:
				unit.hp = max(unit.hp, 0)
				events.append({
					"type": "dot",
					"target": unit.name,
					"damage": burn_damage,
					"message": "%s受到燃烧伤害%.0f点" % [unit.name, burn_damage]
				})
		
		if unit.debuffs.has("stun"):
			unit.debuffs["stun"] -= 1
			if unit.debuffs["stun"] <= 0:
				unit.debuffs.erase("stun")
			events.append({
				"type": "stun",
				"target": unit.name,
				"message": "%s被眩晕，无法行动" % unit.name
			})
	
	return events

func _get_all_alive_units(units: Array) -> Array:
	return units.filter(func(u): return u.hp > 0)

func _count_alive_units(units: Array) -> int:
	return _get_all_alive_units(units).size()

# 获取玩家保存的阵容（从HeroLibrary读取）
func get_player_lineup() -> Array:
	return HeroLibrary.get_saved_lineup()

# 生成敌方随机阵容
func generate_random_enemy_lineup() -> Array:
	# 根据玩家当前排名生成随机阵容
	var enemy_count = 9  # 敌方也是满九宫格
	var enemy_lineup: Array = []
	
	# 获取所有已解锁武将
	var all_heroes = HeroLibrary.get_all_unlocked_hero_ids()
	print("[PvP] 已解锁武将总数: ", all_heroes.size())
	print("[PvP] 已解锁武将列表: ", all_heroes)
	
	if all_heroes.size() == 0:
		# 如果没有解锁任何武将，全部填空
		for i in range(enemy_count):
			enemy_lineup.append(null)
		return enemy_lineup
	
	# 如果解锁武将不够9个，我们重复采样，保证填满9个格子（可以重复）
	if all_heroes.size() < enemy_count:
		print("[PvP] 解锁不够9个，重复采样填满")
		for i in range(enemy_count):
			var idx = randi() % all_heroes.size()
			enemy_lineup.append(all_heroes[idx])
		print("[PvP] 生成敌方阵容: ", enemy_lineup)
		return enemy_lineup
	
	# 解锁够9个，随机不放回选9个
	print("[PvP] 解锁 >=9 个，随机不放回采样")
	for i in range(enemy_count):
		var idx = randi() % all_heroes.size()
		enemy_lineup.append(all_heroes[idx])
		all_heroes.erase(idx)
	
	print("[PvP] 生成敌方阵容: ", enemy_lineup)
	return enemy_lineup

# 获取玩家当前排名
func get_player_rank() -> int:
	return HeroLibrary.get_player_pvp_rank()

# 计算战斗奖励
func calculate_reward(result) -> Dictionary:
	var victory = result.victory
	var rounds = result.rounds
	var attacker_alive = result.attacker_alive
	
	# 基础奖励声望
	var base_prestige = 50
	# 胜利额外奖励
	if victory:
		base_prestige += 50 * attacker_alive
	
	# 排名变化：胜利升排名（数字变小排名更高）
	var old_rank = get_player_rank()
	var new_rank = max(1, old_rank - 1)
	
	return {
		"prestige": base_prestige,
		"old_rank": old_rank,
		"new_rank": new_rank
	}

# 应用战斗奖励
func apply_reward(reward: Dictionary):
	var prestige = reward.prestige
	var new_rank = reward.new_rank
	
	# 增加声望
	var main = get_tree().root.get_node("Main").get_node("ContentArea").get_children()[-1]
	if main and main.has_method("add_prestige"):
		main.add_prestige(prestige)
	
	# 更新排名
	HeroLibrary.set_player_pvp_rank(new_rank)
	
	print("[PvP] 奖励应用：声望 +%d，排名变为 %d" % [prestige, new_rank])
