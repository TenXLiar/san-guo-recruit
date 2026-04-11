extends Control

# 启动欢迎界面

@onready var new_game_button = $Buttons/NewGameButton
@onready var load_game_button = $Buttons/LoadGameButton
@onready var settings_button = $Buttons/SettingsButton
@onready var quit_button = $Buttons/QuitButton

func _ready():
	new_game_button.pressed.connect(_on_new_game)
	load_game_button.pressed.connect(_on_load_game)
	settings_button.pressed.connect(_on_open_settings)
	quit_button.pressed.connect(_on_quit)
	
	# 检查是否有存档
	if not SaveManager.has_save():
		load_game_button.disabled = true

func _on_new_game():
	# 开始新游戏
	save_manager.new_game()
	# 切换到主界面
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_load_game():
	# 读取存档并进入主界面
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		# 加载失败提示
		print("加载存档失败")

func _on_open_settings():
	# 打开设置界面（这里可以弹出设置对话框）
	# TODO: 打开皮肤主题设置界面
	pass

func _on_quit():
	# 退出游戏
	get_tree().quit()
