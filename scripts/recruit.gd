extends Control
class_name RecruitUI

# 招募配置
const RECRUIT_COST: int = 100  # 单次招募消耗
const RARITY_WEIGHTS: Dictionary = {
    1: 70,  # 白色
    2: 25,  # 绿色
    3: 5,   # 蓝色
    4: 0,   # 紫色（暂不加入卡池）
    5: 0    # 橙色（暂不加入卡池）
}

# 节点引用
@onready var gdp_label: Label = $GDPDisplay/GDPLabel
@onready var recruit_button: Button = $RecruitButton
@onready var result_popup: Control = $ResultPopup
@onready var result_name_label: Label = $ResultPopup/NameLabel
@onready var result_rarity_label: Label = $ResultPopup/RarityLabel
@onready var result_type_label: Label = $ResultPopup/TypeLabel
@onready var close_button: Button = $ResultPopup/CloseButton

# 武将数据
var all_heroes: Array = []
var hero_library: Node = null

func _ready():
    # 加载武将数据
    load_hero_data()
    # 获取武将库单例
    hero_library = HeroLibrary.instance
    # 更新GDP显示
    update_gdp_display()
    # 连接信号
    recruit_button.connect("pressed", Callable(self, "_on_recruit_pressed"))
    close_button.connect("pressed", Callable(self, "_on_close_result_pressed"))
    IdleManager.instance.connect("gdp_updated", Callable(self, "_on_gdp_updated"))

# 加载武将数据
func load_hero_data():
    var file = FileAccess.open("res://data/heroes.json", FileAccess.READ)
    if file:
        var json_text = file.get_as_text()
        file.close()
        var json = JSON.new()
        var parse_result = json.parse(json_text)
        if parse_result == OK:
            var data = json.data
            all_heroes = data.get("heroes", [])
        else:
            print("JSON解析错误: ", json.get_error_message())
    else:
        print("无法打开武将数据文件")

# 更新GDP显示
func update_gdp_display():
    gdp_label.text = str(IdleManager.instance.get_current_gdp())
    # 按钮是否可点击
    recruit_button.disabled = IdleManager.instance.get_current_gdp() < RECRUIT_COST

# 招募按钮点击事件
func _on_recruit_pressed():
    # 检查是否足够国运点
    if not IdleManager.instance.spend_gdp(RECRUIT_COST):
        print("国运点不足")
        return
    
    # 执行招募
    var result = do_recruit()
    # 显示结果
    show_recruit_result(result)

# 执行招募逻辑
func do_recruit() -> Dictionary:
    # 随机稀有度
    var rarity = roll_rarity()
    # 从对应稀有度的武将中随机选择
    var possible_heroes = all_heroes.filter(func(h): return h.rarity == rarity)
    if possible_heroes.is_empty():
        # 如果该稀有度没有武将，降级选择
        possible_heroes = all_heroes.filter(func(h): return h.rarity <= rarity)
    
    var hero = possible_heroes[randi() % possible_heroes.size()]
    
    # 添加到武将库
    var is_new = hero_library.add_hero(hero.id)
    
    return {
        "hero": hero,
        "is_new": is_new,
        "rarity": rarity
    }

# 随机稀有度
func roll_rarity() -> int:
    var total_weight = 0
    for weight in RARITY_WEIGHTS.values():
        total_weight += weight
    
    var roll = randi() % total_weight
    var current_weight = 0
    
    var keys = RARITY_WEIGHTS.keys()
    keys.sort()
    for rarity in keys:
        current_weight += RARITY_WEIGHTS[rarity]
        if roll < current_weight:
            return rarity
    
    return 1  # 默认白色

# 显示招募结果
func show_recruit_result(result: Dictionary):
    var hero = result.hero
    var is_new = result.is_new
    
    result_name_label.text = hero.name
    result_rarity_label.text = get_rarity_text(result.rarity)
    result_rarity_label.add_theme_color_override("font_color", get_rarity_color(result.rarity))
    
    if is_new:
        result_type_label.text = "新武将！"
        result_type_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
    else:
        var fragments = hero_library.get_hero_fragments(hero.id)
        result_type_label.text = "重复获得，碎片+1（当前：%d）" % fragments
        result_type_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1))
    
    result_popup.visible = true

# 获取稀有度文本
func get_rarity_text(rarity: int) -> String:
    match rarity:
        1: return "白色"
        2: return "绿色"
        3: return "蓝色"
        4: return "紫色"
        5: return "橙色"
    return "未知"

# 获取稀有度颜色
func get_rarity_color(rarity: int) -> Color:
    match rarity:
        1: return Color(1, 1, 1)
        2: return Color(0, 1, 0)
        3: return Color(0, 0.5, 1)
        4: return Color(0.7, 0, 1)
        5: return Color(1, 0.5, 0)
    return Color(1, 1, 1)

# 关闭结果弹窗
func _on_close_result_pressed():
    result_popup.visible = false

# GDP更新事件
func _on_gdp_updated(amount: float):
    update_gdp_display()

# 概率测试函数（供测试用）
func test_recruit_probability(times: int = 1000):
    var results = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
    for i in range(times):
        var rarity = roll_rarity()
        results[rarity] += 1
    
    print("招募%d次结果：" % times)
    for rarity in results:
        var percent = results[rarity] / times * 100
        print("%s: %d次 (%.1f%%)" % [get_rarity_text(rarity), results[rarity], percent])
