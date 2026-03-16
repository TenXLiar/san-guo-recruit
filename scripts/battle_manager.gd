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
    
    # 初始化战斗单位
    var attacker_units = _init_battle_units(attacker_lineup, true)
    var defender_units = _init_battle_units(defender_lineup, false)
    
    # 获取羁绊效果
    var attacker_buffs = BondManager.instance.get_total_bond_effects(attacker_lineup)
    var defender_buffs = BondManager.instance.get_total_bond_effects(defender_lineup)
    
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
        
        # 合并双方单位，按速度排序
        var all_units = []
        all_units.append_array(attacker_units)
        all_units.append_array(defender_units)
        all_units.sort_custom(func(a, b): return a.speed > b.speed)
        
        # 每个单位行动
        for unit in all_units:
            if unit.hp <= 0:
                continue
            
            # 检查是否还有存活的敌方
            if _count_alive_units(attacker_units) == 0 or _count_alive_units(defender_units) == 0:
                break
            
            # 决定行动：普攻或技能
            var skill_rate = BASE_SKILL_RATE + unit.buffs.get("skill_rate_buff", 0)
            var use_skill = randf() < skill_rate
            
            if use_skill:
                var event = _use_skill(unit, attacker_units, defender_units)
                round_events.append(event)
            else:
                var event = _normal_attack(unit, attacker_units, defender_units)
                round_events.append(event)
        
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
        position += 1
    
    return units

# 应用buff效果
func _apply_buffs(units: Array, buffs: Dictionary):
    for unit in units:
        for buff_name in buffs:
            var value = buffs[buff_name]
            if unit.buffs.has(buff_name):
                unit.buffs[buff_name] += value
            else:
                unit.buffs[buff_name] = value

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
    var message = ""
    
    # 根据技能类型选择目标
    match skill.get("type", "damage"):
        "damage":
            match skill.get("target", "single_enemy"):
                "single_enemy":
                    var target = _select_random_target(defender_units if attacker.is_attacker else attacker_units)
                    if target:
                        targets.append(target)
                "front_enemy":
                    targets = _get_front_units(defender_units if attacker.is_attacker else attacker_units)
                "back_enemy":
                    targets = _get_back_units(defender_units if attacker.is_attacker else attacker_units)
                "all_enemy":
                    targets = _get_all_alive_units(defender_units if attacker.is_attacker else attacker_units)
    
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
    
    if skill.has("attack_buff"):
        for unit in _get_all_alive_units(attacker_units):
            unit.buffs["attack_buff"] = skill.get("attack_buff", 0)
            message += "%s攻击提升%d%%；" % [unit.name, skill.attack_buff * 100]
    
    return {
        "type": "skill",
        "attacker": attacker.name,
        "skill_name": attacker.skill.get("name", "技能"),
        "targets": targets.map(func(t): return t.name),
        "damage": damage_total,
        "message": message
    }

# 计算伤害
func _calculate_damage(attacker: Dictionary, target: Dictionary, multiplier: float = 1.0) -> float:
    # 基础伤害 = 攻击 × 倍率
    var base_damage = attacker.attack * multiplier
    
    # 攻击加成
    var attack_buff = attacker.buffs.get("attack_buff", 0)
    base_damage *= (1 + attack_buff)
    
    # 防御减伤：防御/(防御+100)
    var defense_reduction = target.defense / (target.defense + 100)
    var damage = base_damage * (1 - defense_reduction)
    
    # 暴击判定
    var crit_rate = BASE_CRIT_RATE + attacker.buffs.get("crit_buff", 0)
    var is_crit = randf() < crit_rate
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

# 获取所有存活单位
func _get_all_alive_units(units: Array) -> Array:
    return units.filter(func(u): return u.hp > 0)

# 统计存活单位数量
func _count_alive_units(units: Array) -> int:
    return _get_all_alive_units(units).size()
