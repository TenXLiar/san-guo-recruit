extends Node

# 单例实例
static var instance: BattleManager = null

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
const BASE_SKILL_RATE: float = 0.2  # 基础技能触发概率
const BASE_CRIT_RATE: float = 0.05  # 基础暴击率
const BASE_CRIT_DAMAGE: float = 1.5  # 基础暴击伤害

# 战斗回调
signal battle_finished(victory: bool, report: Array)  # 战斗结束信号
signal round_finished(round: int, events: Array)  # 回合结束信号

func _init():
	if instance == null:
		instance = self
	else:
		queue_free()

# 开始战斗
# attacker: 攻击方阵容（武将ID数组）
# defender: 防守方阵容（武将ID数组）
# 返回战斗结果
func start_battle(attacker_lineup: Array, defender_lineup: Array) -> Dictionary:
	current_state = BattleState.PREPARING
	
	print("=====================================")
	print("⚔️  [战斗系统] 战斗开始")
	print("   攻击方阵容人数：", attacker_lineup.count(func(id): return id != null))
	print("   防守方阵容人数：", defender_lineup.count(func(id): return id != null))
	
	# 初始化战斗单位
	var attacker_units = _init_battle_units(attacker_lineup, true)
	var defender_units = _init_battle_units(defender_lineup, false)
	
	# 获取羁绊效果
	var attacker_buffs = BondManager.instance.get_total_bond_effects(attacker_lineup)
	var defender_buffs = BondManager.instance.get_total_bond_effects(defender_lineup)
	
	print("   🎁 攻击方羁绊加成：", attacker_buffs)
	print("   🎁 防守方羁绊加成：", defender_buffs)
	
	# 应用羁绊效果
	_apply_buffs(attacker_units, attacker_buffs)
	_apply_buffs(defender_units, defender_buffs)
	
	current_state = BattleState.FIGHTING
	var battle_report = []
	var round = 0
	var max_rounds = 50  # 最大回合数，防止无限战斗
	
	while current_state == BattleState.FIGHTING and round < max_rounds:
		round += 1
		var round_events = []
		
		# 回合开始：处理持续伤害和buff/debuff回合递减
		var pre_round_events = _process_round_start_effects(attacker_units, defender_units)
		round_events.append_array(pre_round_events)
		
		# 检查是否战斗已经结束
		if _count_alive_units(attacker_units) == 0 or _count_alive_units(defender_units) == 0:
			break
		
		# 合并双方单位，按速度排序
		var all_units = []
		all_units.append_array(attacker_units)
		all_units.append_array(defender_units)
		all_units.sort_custom(func(a, b): return a.speed > b.speed)
		
		# 每个单位行动
		for unit in all_units:
			if unit.hp <= 0:
				print("      ⚰️ %s 已经阵亡，跳过行动" % unit.name)
				continue
			
			# 检查眩晕
			if unit.debuffs.has("stun") and unit.debuffs["stun"] > 0:
				print("      😵‍💫 %s 被眩晕，跳过行动" % unit.name)
				unit.debuffs["stun"] -= 1
				if unit.debuffs["stun"] <= 0:
					unit.debuffs.erase("stun")
				continue
			
			# 检查是否还有存活的敌方
			if _count_alive_units(attacker_units) == 0 or _count_alive_units(defender_units) == 0:
				break
			
			# 决定行动：普攻或技能
			var skill_rate = BASE_SKILL_RATE + unit.buffs.get("skill_rate_buff", 0)
			var use_skill = randf() < skill_rate
			
			print("      🎯 回合%d：%s 行动，技能概率%.2f%%，是否使用技能：%s" % [
				round, unit.name, skill_rate * 100, str(use_skill)
			])
			
			if use_skill:
				var event = _use_skill(unit, attacker_units, defender_units)
				round_events.append(event)
				if event.message != "":
					print("         📜 %s" % event.message)
			else:
				var event = _normal_attack(unit, attacker_units, defender_units)
				round_events.append(event)
				print("         📜 %s" % event.message)
		
		# 回合结束
		round_finished.emit(round, round_events)
		battle_report.append({
			"round": round,
			"events": round_events
		})
		
		# 检查战斗是否结束
		if _count_alive_units(attacker_units) == 0 or _count_alive_units(defender_units) == 0:
			break
	
	current_state = BattleState.FINISHED
	
	# 计算胜负
	var attacker_alive = _count_alive_units(attacker_units) > 0
	var defender_alive = _count_alive_units(defender_units) > 0
	var victory = attacker_alive and not defender_alive
	
	print("🏁 [战斗结束] 结果：")
	print("   总回合数：%d" % round)
	print("   攻击方存活：%d / %d" % [_count_alive_units(attacker_units), attacker_units.size()])
	print("   防守方存活：%d / %d" % [_count_alive_units(defender_units), defender_units.size()])
	var result_text = "攻击方胜利" if victory else "防守方胜利"
	print("   战斗结果：%s" % result_text)
	print("=====================================")
	
	battle_finished.emit(victory, battle_report)
	
	return {
		"victory": victory,
		"rounds": round,
		"report": battle_report,
		"attacker_remaining": _count_alive_units(attacker_units),
		"defender_remaining": _count_alive_units(defender_units)
	}

# 初始化战斗单位
func _init_battle_units(lineup: Array, is_attacker: bool) -> Array:
	var units = []
	var position = 0
	var side = "攻击方" if is_attacker else "防守方"
	
	print("   📋 [初始化%s] 开始初始化单位：" % side)
	
	for hero_id in lineup:
		if not hero_id:
			position += 1
			continue
		
		var hero_data = HeroLibrary.instance.get_hero_data(hero_id)
		if hero_data.is_empty():
			position += 1
			continue
		
		# 计算属性
		var force = hero_data.get("force", 50)
		var intelligence = hero_data.get("intelligence", 50)
		var hp = force * 10 + intelligence * 5  # 生命值
		var attack = force * 2  # 攻击力
		var defense = force * 0.5 + intelligence * 0.3  # 防御
		var speed = force * 0.3 + intelligence * 0.7  # 速度
		
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
			"skill": hero_data.get("skill_effect", {}),
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
			print("      ➕ %s：%s += %.2f" % [unit.name, buff_name, value])

# 普通攻击
func _normal_attack(attacker: Dictionary, attacker_units: Array, defender_units: Array) -> Dictionary:
	# 选择目标：敌方前排随机一个
	var target = _select_front_target(defender_units if attacker.is_attacker else attacker_units)
	if not target:
		return {
			"type": "attack",
			"attacker": attacker.name,
			"target": "无",
			"damage": 0,
			"message": "%s攻击，但没有目标" % attacker.name
		}
	
	# 计算伤害
	var damage = _calculate_damage(attacker, target)
	
	# 应用伤害
	target.hp -= damage
	target.hp = max(target.hp, 0)
	
	return {
		"type": "attack",
		"attacker": attacker.name,
		"target": target.name,
		"damage": damage,
		"is_crit": damage.is_crit,
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
			# 伤害类技能
			targets = _select_skill_targets(skill, attacker, attacker_units, defender_units)
			
			# 对目标造成伤害
			for target in targets:
				var damage = _calculate_damage(attacker, target, skill.get("damage_multiplier", 1.0))
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
				# 自伤类技能
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
				# 己方群体攻击buff
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
				# 技能触发概率buff
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
				# 燃烧效果
				for target in targets:
					if not target.debuffs.has("burn"):
						target.debuffs["burn"] = []
					target.debuffs["burn"].append({
						"damage_percent": skill.burn_damage,
						"remaining": skill.burn_duration
					})
					message += "%s被燃烧，持续%d回合；" % [target.name, skill.burn_duration]
		
		"heal":
			# 治疗类技能
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
			# 增益类技能
			var ally_units = _get_all_alive_units(attacker_units)
			# 根据目标筛选
			if skill.get("target") == "all_ally_wei":
				ally_units = ally_units.filter(func(u): return u.faction == "wei")
			elif skill.get("target") == "all_ally_shu":
				ally_units = ally_units.filter(func(u): return u.faction == "shu")
			elif skill.get("target") == "all_ally_wu":
				ally_units = ally_units.filter(func(u): return u.faction == "wu")
			elif skill.get("target") == "all_ally_qun":
				ally_units = ally_units.filter(func(u): return u.faction == "qun")
			elif skill.get("target") == "all_ally":
				pass # 已经是所有
			
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

# 计算伤害
func _calculate_damage(attacker: Dictionary, target: Dictionary, multiplier: float = 1.0) -> float:
	# 基础伤害 = 攻击 × 倍率
	var base_damage = attacker.attack * multiplier
	
	# 攻击加成
	var attack_buff = attacker.buffs.get("attack_buff", 0)
	base_damage *= (1 + attack_buff)
	
	# 防御减伤 + 防御debuff
	var defense = target.defense
	var defense_debuff = target.debuffs.get("defense_debuff", 0)
	defense *= (1 - defense_debuff)
	var defense_reduction = defense / (defense + 100)
	var damage = base_damage * (1 - defense_reduction)
	
	# 伤害减免
	var damage_reduction = target.buffs.get("damage_reduction", 0)
	damage *= (1 - damage_reduction)
	
	# 暴击判定
	var crit_rate = BASE_CRIT_RATE + attacker.buffs.get("crit_buff", 0)
	var is_crit = randf() < crit_rate
	# 技能必定暴击
	if attacker.skill.has("critical") and attacker.skill.critical:
		is_crit = true
	if is_crit:
		damage *= BASE_CRIT_DAMAGE
	
	# 随机浮动±5%
	var random_factor = 0.95 + randf() * 0.1
	damage *= random_factor
	
	return round(max(damage, 1))

# 选择前排目标
func _select_front_target(units: Array) -> Dictionary:
	var front_units = _get_front_units(units)
	if front_units.is_empty():
		return _select_random_target(units)
	return front_units[randi() % front_units.size()]

# 获取前排单位（位置0-2）
func _get_front_units(units: Array) -> Array:
	return units.filter(func(u): return u.hp > 0 and u.position < 3)

# 获取后排单位（位置6-8）
func _get_back_units(units: Array) -> Array:
	return units.filter(func(u): return u.hp > 0 and u.position >= 6)

# 选择随机目标
func _select_random_target(units: Array) -> Dictionary:
	var alive = _get_all_alive_units(units)
	if alive.is_empty():
		return {}
	return alive[randi() % alive.size()]

# 根据技能配置选择目标
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
			# 随机选择N个目标
			var alive_enemies = _get_all_alive_units(enemies)
			var count = skill.get("target_count", 2)
			for i in range(count):
				if alive_enemies.size() > 0:
					var idx = randi() % alive_enemies.size()
					targets.append(alive_enemies[idx])
					alive_enemies.remove_at(idx)
	
	return targets

# 处理回合开始前的持续效果（燃烧、debuff递减等）
func _process_round_start_effects(attacker_units: Array, defender_units: Array) -> Array:
	var events = []
	var all_units = []
	all_units.append_array(attacker_units)
	all_units.append_array(defender_units)
	
	for unit in all_units:
		if unit.hp <= 0:
			continue
		
		# 处理燃烧伤害
		if unit.debuffs.has("burn"):
			var burn_damage = 0
			# 反向遍历，移除已结束的燃烧
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
		
		# 处理眩晕：如果有眩晕，本回合不能行动（这里直接减少一回合）
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

# 获取所有存活单位
func _get_all_alive_units(units: Array) -> Array:
	return units.filter(func(u): return u.hp > 0)

# 统计存活单位数量
func _count_alive_units(units: Array) -> int:
	return _get_all_alive_units(units).size()
