extends Node

# 单例实例
static var instance: BondManager = null

# 羁绊类型
enum BondType {
    WEI_3,    # 魏国3人
    SHU_3,    # 蜀国3人
    WU_3,     # 吴国3人
    QUN_3     # 群雄3人
}

# 羁绊配置
var bond_config: Dictionary = {
    BondType.WEI_3: {
        "name": "魏武之强",
        "description": "上阵3名魏国武将：全体攻击+10%",
        "faction": "wei",
        "required_count": 3,
        "effects": {
            "attack_buff": 0.1  # 攻击+10%
        }
    },
    BondType.SHU_3: {
        "name": "桃园结义",
        "description": "上阵3名蜀国武将：全体暴击率+15%",
        "faction": "shu",
        "required_count": 3,
        "effects": {
            "crit_buff": 0.15  # 暴击率+15%
        }
    },
    BondType.WU_3: {
        "name": "江东基业",
        "description": "上阵3名吴国武将：全体技能触发概率+10%",
        "faction": "wu",
        "required_count": 3,
        "effects": {
            "skill_rate_buff": 0.1  # 技能触发+10%
        }
    },
    BondType.QUN_3: {
        "name": "乱世群雄",
        "description": "上阵3名群雄武将：随机获得上述一种效果（每场战斗随机）",
        "faction": "qun",
        "required_count": 3,
        "effects": {
            "random_buff": true  # 随机buff
        }
    }
}

func _init():
    if instance == null:
        instance = self
    else:
        queue_free()

# 获取当前激活的羁绊列表
# 根据输入类型自动处理
func get_active_bonds(input) -> Array:
    var active_bonds = []
    var faction_counts: Dictionary
    
    if input is Array:
        # 输入是阵容数组，先统计势力
        faction_counts = count_factions(input)
    elif input is Dictionary:
        # 输入已经是势力统计
        faction_counts = input
    else:
        return active_bonds
    
    # 检查各势力羁绊
    for bond_type in bond_config:
        var config = bond_config[bond_type]
        if faction_counts[config["faction"]] >= config["required_count"]:
            active_bonds.append({
                "type": bond_type,
                "name": config["name"],
                "description": config["description"],
                "effects": config["effects"]
            })
    
    return active_bonds

# 计算并保存全局羁绊加成
func calculate_all_bonuses(faction_counts: Dictionary):
    var active_bonds = get_active_bonds(faction_counts)
    var total_effects = {}
    
    for bond in active_bonds:
        for effect_name in bond["effects"]:
            var value = bond["effects"][effect_name]
            if total_effects.has(effect_name):
                total_effects[effect_name] += value
            else:
                total_effects[effect_name] = value
    
    # 保存到全局，战斗系统读取
    current_bonuses = total_effects
    print("当前激活羁绊加成：", current_bonuses)

# 当前激活的羁绊加成全局存储
var current_bonuses: Dictionary = {}

# 统计阵容中各势力人数
func count_factions(lineup: Array) -> Dictionary:
    var count = {
        "wei": 0,
        "shu": 0,
        "wu": 0,
        "qun": 0
    }
    
    for hero_id in lineup:
        if hero_id:
            var faction = hero_id.split("_")[0]
            if count.has(faction):
                count[faction] += 1
    
    return count

# 获取总羁绊效果
func get_total_bond_effects(lineup: Array = []) -> Dictionary:
    var active_bonds = get_active_bonds(lineup)
    var total_effects = {}
    
    for bond in active_bonds:
        for effect_name in bond["effects"]:
            var value = bond["effects"][effect_name]
            if total_effects.has(effect_name):
                total_effects[effect_name] += value
            else:
                total_effects[effect_name] = value
    
    return total_effects

# 获取羁绊描述文本列表（用于UI显示）
func get_bond_descriptions(lineup: Array = []) -> Array[String]:
    var active_bonds = get_active_bonds(lineup)
    var descriptions = []
    
    for bond in active_bonds:
        descriptions.append("✅ %s：%s" % [bond["name"], bond["description"]])
    
    return descriptions

# 检查某个羁绊是否激活
func is_bond_active(bond_type: BondType, lineup: Array = []) -> bool:
    var active_bonds = get_active_bonds(lineup)
    for bond in active_bonds:
        if bond["type"] == bond_type:
            return true
    
    return false
