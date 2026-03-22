extends Node2D

# 状态枚举
enum CatState {
	IDLE,    # 打瞌睡
	TAP,     # 敲击
	FEVER    # 暴走
}

# 配置常量
const TAP_DURATION: float = 0.2  # 敲击状态持续时间
const FEVER_THRESHOLD: int = 5  # 每秒按键次数阈值触发暴走
const FEVER_DURATION: float = 10.0  # 暴走持续时间
const FEVER_COOLDOWN: float = 5.0  # 暴走冷却时间
const EXP_PER_TAP: int = 1  # 每次按键获得的经验
const EXP_PER_LEVEL: int = 100  # 每级需要的经验
const TAP_GDP_MIN: int = 1  # 每次敲击最少国运
const TAP_GDP_MAX: int = 3  # 每次敲击最多国运
const FEVER_GDP_MIN: int = 5  # 暴走最少国运
const FEVER_GDP_MAX: int = 10  # 暴走最多国运
const TREASURE_PROBABILITY: float = 0.05  # 寻宝概率

# 当前状态
var current_state: CatState = CatState.IDLE
var current_level: int = 1
var current_exp: int = 0
var tap_count_this_second: int = 0
var fever_end_time: float = 0.0
var fever_cooldown_end: float = 0.0

# 节点引用
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var level_label: Label = $LevelLabel
@onready var gdp_label: Label = $GdpLabel

# 信号
signal level_up(new_level: int)  # 升级时触发
signal fever_started()  # 暴走开始时触发
signal fever_ended()  # 暴走结束时触发

func _ready():
	# 启动每秒计数器
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.connect("timeout", Callable(self, "_on_second_timer"))
	add_child(timer)
	timer.start()
	
	# 初始化显示
	update_level_display()
	update_gdp_display()
	# 初始状态为idle
	play_animation("idle")

# 监听输入事件
func _input(event: InputEvent):
	# 只处理按下事件
	if event is InputEventKey and event.pressed and not event.echo:
		_on_key_pressed()
	elif event is InputEventMouseButton and event.pressed:
		_on_key_pressed()

# 按键/鼠标按下处理
func _on_key_pressed():
	tap_count_this_second += 1
	
	# 增加经验
	add_exp(EXP_PER_TAP)
	
	# 给国运
	var gdp_amount = 0
	if current_state != CatState.FEVER:
		gdp_amount = randi_range(TAP_GDP_MIN, TAP_GDP_MAX)
		current_state = CatState.TAP
		play_animation("tap")
		# 0.2秒后回到idle状态
		var tap_timer = Timer.new()
		tap_timer.wait_time = TAP_DURATION
		tap_timer.connect("timeout", Callable(self, "_on_tap_finished"))
		add_child(tap_timer)
		tap_timer.start()
	else:
		gdp_amount = randi_range(FEVER_GDP_MIN, FEVER_GDP_MAX)
	
	# 增加国运
	var main = get_tree().root.get_node("root-main")
	if main:
		main.add_gdp(gdp_amount)
	
	# 检查寻宝
	if randf() < TREASURE_PROBABILITY:
		# 触发寻宝，给少量钱粮兵
		var treasure_min = 5
		var treasure_max = 10
		if current_state == CatState.FEVER:
			treasure_min = 10
			treasure_max = 20
		var money = randi_range(treasure_min, treasure_max)
		var food = randi_range(treasure_min, treasure_max)
		var soldier = randi_range(treasure_min, treasure_max)
		IdleManager.instance.add_money(money)
		IdleManager.instance.add_food(food)
		IdleManager.instance.add_soldier(soldier)
		print("[Bongo Cat] 寻宝! +%d 钱 +%d 粮 +%d 兵" % [money, food, soldier])
	
	# 更新显示
	update_gdp_display()

# 每秒定时器处理
func _on_second_timer():
	var now = Time.get_unix_time_from_system()
	
	# 检查是否触发暴走
	if tap_count_this_second >= FEVER_THRESHOLD and now >= fever_cooldown_end:
		start_fever()
	
	# 重置计数器
	tap_count_this_second = 0
	
	# 检查暴走是否结束
	if current_state == CatState.FEVER and now >= fever_end_time:
		end_fever()

# 开始暴走状态
func start_fever():
	current_state = CatState.FEVER
	play_animation("fever")
	fever_end_time = Time.get_unix_time_from_system() + FEVER_DURATION
	fever_cooldown_end = fever_end_time + FEVER_COOLDOWN
	fever_started.emit()
	print("Bongo Cat进入暴走状态！")

# 结束暴走状态
func end_fever():
	current_state = CatState.IDLE
	play_animation("idle")
	fever_ended.emit()
	print("Bongo Cat暴走结束，进入冷却")

# 敲击动画结束
func _on_tap_finished():
	if current_state == CatState.TAP:
		current_state = CatState.IDLE
		play_animation("idle")

# 播放动画
func play_animation(animation_name: String):
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)

# 增加经验
func add_exp(amount: int):
	current_exp += amount
	# 检查升级
	while current_exp >= get_exp_needed_for_next_level():
		current_exp -= get_exp_needed_for_next_level()
		current_level += 1
		level_up.emit(current_level)
		print("Bongo Cat升级到%d级！" % current_level)
	
	update_level_display()

# 获取下一级需要的经验
func get_exp_needed_for_next_level() -> int:
	return EXP_PER_LEVEL * current_level

# 更新等级显示
func update_level_display():
	level_label.text = "Lv.%d" % current_level

# 更新国运显示
func update_gdp_display():
	if current_state == CatState.FEVER:
		var remaining = fever_end_time - Time.get_unix_time_from_system()
		gdp_label.text = "暴走! +%d-%d/次\n%.0fs" % [FEVER_GDP_MIN, FEVER_GDP_MAX, remaining]
		gdp_label.visible = true
	elif current_state == CatState.TAP:
		gdp_label.text = "+%d-%d/次" % [TAP_GDP_MIN, TAP_GDP_MAX]
		gdp_label.visible = true
	else:
		gdp_label.visible = false

# 保存数据（供存档系统调用）
func save_data() -> Dictionary:
	return {
		"level": current_level,
		"exp": current_exp
	}

# 加载数据（供存档系统调用）
func load_data(data: Dictionary):
	current_level = data.get("level", 1)
	current_exp = data.get("exp", 0)
	update_level_display()
