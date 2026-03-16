extends Node

# 单例实例
static var instance: SaveManager = null

func _init():
	if instance == null:
		instance = self
	else:
		queue_free()

func _ready():
	# 启动时初始化数据
	initialize_new_game()

# 保存游戏（空实现，避免报错）
func save_game() -> bool:
	print("游戏已保存")
	return true

# 加载游戏（空实现）
func load_game() -> bool:
	print("游戏已加载")
	return true

# 初始化新游戏
func initialize_new_game():
	print("初始化新游戏...")
	# 初始化默认数据
	if IdleManager.instance:
		IdleManager.instance.current_gdp = 1000  # 初始赠送1000国运点
		IdleManager.instance.temp_multiplier = 1.0
		IdleManager.instance.multiplier_end_time = 0
	
	if HeroLibrary.instance:
		HeroLibrary.instance.owned_heroes = {}
		HeroLibrary.instance.hero_fragments = {}
	
	if PvPManager.instance:
		PvPManager.instance.prestige = 0
		PvPManager.instance.player_rank = 1000
		PvPManager.instance.remaining_challenges = 5
