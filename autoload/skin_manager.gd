extends Node
# 皮肤管理器 - 管理Bongo Cat皮肤和主界面主题

# 皮肤数据结构
var BONGO_SKINS = [
	{
		"id": "default",
		"name": "默认猫咪",
		"description": "最原始的敲鼓小猫",
		"texture_path": "res://assets/bongo/default.png",
		"unlocked": true,
		"unlock_condition": "default",
		"effect_description": "无特殊效果"
	},
	{
		"id": "general",
		"name": "将军猫",
		"description": "身披铠甲，指挥若定",
		"texture_path": "res://assets/bongo/general.png",
		"unlocked": false,
		"unlock_condition": "achievement_conquer_all",
		"effect_description": "敲击获得聚贤令概率+1%"
	},
	{
		"id": "poet",
		"name": "诗人猫",
		"description": "吟诗作对，儒雅风流",
		"texture_path": "res://assets/bongo/poet.png",
		"unlocked": false,
		"unlock_condition": "collect_10_female",
		"effect_description": "事件成功率+2%"
	},
	{
		"id": "mecha",
		"name": "机甲猫",
		"description": "未来科技，钢铁之躯",
		"texture_path": "res://assets/bongo/mecha.png",
		"unlocked": false,
		"unlock_condition": "complete_all_achievements",
		"effect_description": "暴走概率+5%"
	}
]

# 主题数据结构
var MAIN_THEMES = [
	{
		"id": "default",
		"name": "默认水墨",
		"description": "经典水墨古风背景",
		"texture_path": "res://assets/backgrounds/default.jpg",
		"unlocked": true,
		"unlock_condition": "default"
	},
	{
		"id": "snow",
		"name": "雪景",
		"description": "银装素裹，江山如画",
		"texture_path": "res://assets/backgrounds/snow.jpg",
		"unlocked": false,
		"unlock_condition": "conquer_hebei",
	},
	{
		"id": "bamboo",
		"name": "竹林",
		"description": "竹林幽静，贤人雅士",
		"texture_path": "res://assets/backgrounds/bamboo.jpg",
		"unlocked": false,
		"unlock_condition": "conquer_jiangdong",
	}
]

# 当前选择
var current_bongo_skin_id: String = "default"
var current_main_theme_id: String = "default"

# 信号
signal bongo_skin_changed(skin_id: String)
signal main_theme_changed(theme_id: String)
signal skin_unlocked(skin_info: Dictionary)

func _ready():
	print("[SkinManager] 初始化完成，%d 个Bongo皮肤，%d 个主题" % [BONGO_SKINS.size(), MAIN_THEMES.size()])

# 解锁皮肤
func unlock_bongo_skin(skin_id: String) -> bool:
	for skin in BONGO_SKINS:
		if skin.id == skin_id and not skin.unlocked:
			skin.unlocked = true
			skin_unlocked.emit(skin)
			print("[SkinManager] 解锁Bongo皮肤: %s" % skin.name)
			return true
	return false

# 解锁主题
func unlock_main_theme(theme_id: String) -> bool:
	for theme in MAIN_THEMES:
		if theme.id == theme_id and not theme.unlocked:
			theme.unlocked = true
			print("[SkinManager] 解锁主题: %s" % theme.name)
			return true
	return false

# 切换Bongo皮肤
func select_bongo_skin(skin_id: String) -> bool:
	for skin in BONGO_SKINS:
		if skin.id == skin_id and skin.unlocked:
			current_bongo_skin_id = skin_id
			bongo_skin_changed.emit(skin_id)
			print("[SkinManager] 切换Bongo皮肤: %s" % skin_id)
			return true
	return false

# 切换主题
func select_main_theme(theme_id: String) -> bool:
	for theme in MAIN_THEMES:
		if theme.id == theme_id and theme.unlocked:
			current_main_theme_id = theme_id
			main_theme_changed.emit(theme_id)
			print("[SkinManager] 切换主题: %s" % theme_id)
			return true
	return false

# 获取当前Bongo皮肤信息
func get_current_bongo_skin() -> Dictionary:
	for skin in BONGO_SKINS:
		if skin.id == current_bongo_skin_id:
			return skin
	return BONGO_SKINS[0]

# 获取当前Bongo皮肤加成
func get_current_bongo_effects() -> Dictionary:
	var skin = get_current_bongo_skin()
	var effects = {}
	match skin.id:
		"general":
			effects["gdp_bonus"] = 0.01
		"poet":
			effects["event_success_bonus"] = 0.02
		"mecha":
			effects["crazy_chance_bonus"] = 0.05
	return effects

# 获取所有已解锁皮肤
func get_unlocked_bongo_skins() -> Array:
	var result = []
	for skin in BONGO_SKINS:
		if skin.unlocked:
			result.append(skin)
	return result

# 获取所有已解锁主题
func get_unlocked_themes() -> Array:
	var result = []
	for theme in MAIN_THEMES:
		if theme.unlocked:
			result.append(theme)
	return result

# 检查是否解锁
func is_bongo_skin_unlocked(skin_id: String) -> bool:
	for skin in BONGO_SKINS:
		if skin.id == skin_id:
			return skin.unlocked
	return false

# 获取存档数据
func get_save_data() -> Dictionary:
	return {
		"current_bongo_skin_id": current_bongo_skin_id,
		"current_main_theme_id": current_main_theme_id,
		"bongo_skins": BONGO_SKINS,
		"main_themes": MAIN_THEMES
	}

# 从存档恢复
func load_from_save(save_data: Dictionary):
	if save_data.has("current_bongo_skin_id"):
		current_bongo_skin_id = save_data.current_bongo_skin_id
	if save_data.has("current_main_theme_id"):
		current_main_theme_id = save_data.current_main_theme_id
	if save_data.has("bongo_skins"):
		BONGO_SKINS = save_data.bongo_skins
	if save_data.has("main_themes"):
		MAIN_THEMES = save_data.main_themes
	print("[SkinManager] 存档恢复完成，当前皮肤: %s，主题: %s" % [current_bongo_skin_id, current_main_theme_id])
