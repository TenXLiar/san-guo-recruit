extends Node2D

# 状态枚举
enum CatState {
	IDLE,    # 打瞌睡
	TAP,     # 敲击
	FEVER    # 暴走
}

# 配置常量
const TAP_DURATION: float = 0.2  # 敲击状态持续时间
const TAP_MULTIPLIER: float = 1.5  # 普通加速倍率
const TAP_DURATION_EFFECT: float = 5.0  # 普通加速持续时间
const FEVER_THRESHOLD: int = 5  # 每秒按键次数阈值触发暴走
const FEVER_MULTIPLIER: float = 3.0  # 暴走倍率
const FEVER_DURATION: float = 10.0  # 暴走持续时间
const FEVER_COOLDOWN: float = 5.0  # 暴走冷却时间
const EXP_PER_TAP: int = 1  # 每次按键获得的经验
const EXP_PER_LEVEL: int = 100  # 每级需要的经验

# 当前状态
var current_state: CatState = CatState.IDLE
var current_level: int = 1
var current_exp: int = 0
var tap_count_this_second: int = 0
var multiplier_end_time: float = 0.0
var fever_end_time: float = 0.0
var fever_cooldown_end: float = 0.0

# 节点引用
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var level_label: Label = $LevelLabel
@onready var multiplier_label: Label = $MultiplierLabel

# 信号
signal multiplier_changed(multiplier: float, remaining: float)  # 倍率变化时触发
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
	update_multiplier_display()
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
	
	# 普通敲击状态
	if current_state != CatState.FEVER:
		current_state = CatState.TAP
		play_animation("tap")
		# 设置加速效果，可叠加刷新
		multiplier_end_time = Time.get_unix_time_from_system() + TAP_DURATION_EFFECT
		update_multiplier()
		
		# 0.2秒后回到idle状态
		var tap_timer = Timer.new()
		tap_timer.wait_time = TAP_DURATION
		tap_timer.connect("timeout", Callable(self, "_on_tap_finished"))
		add_child(tap_timer)
		tap_timer.start()

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
	
	# 更新倍率显示
	update_multiplier()

# 开始暴走状态
func start_fever():
	current_state = CatState.FEVER
	play_animation("fever")
	fever_end_time = Time.get_unix_time_from_system() + FEVER_DURATION
	fever_cooldown_end = fever_end_time + FEVER_COOLDOWN
	update_multiplier()
	fever_started.emit()
	print("Bongo Cat进入暴走状态！")

# 结束暴走状态
func end_fever():
	current_state = CatState.IDLE
	play_animation("idle")
	fever_ended.emit()
	update_multiplier()
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

# 更新倍率
func update_multiplier():
	var now = Time.get_unix_time_from_system()
	var multiplier = 1.0
	var remaining = 0.0
	
	if current_state == CatState.FEVER and now < fever_end_time:
		multiplier = FEVER_MULTIPLIER
		remaining = fever_end_time - now
	elif now < multiplier_end_time:
		multiplier = TAP_MULTIPLIER
		remaining = multiplier_end_time - now
	
	# 更新挂机管理器的倍率
	IdleManager.instance.set_temp_multiplier(multiplier, remaining)
	
	# 更新显示
	update_multiplier_display(multiplier, remaining)
	multiplier_changed.emit(multiplier, remaining)

# 更新倍率显示
func update_multiplier_display(multiplier: float = 1.0, remaining: float = 0.0):
	if multiplier > 1.0:
		multiplier_label.text = "%.1fx 加速\n%.0fs" % [multiplier, remaining]
		multiplier_label.visible = true
	else:
		multiplier_label.visible = false

# 获取当前倍率
func get_current_multiplier() -> float:
	var now = Time.get_unix_time_from_system()
	if current_state == CatState.FEVER and now < fever_end_time:
		return FEVER_MULTIPLIER
	elif now < multiplier_end_time:
		return TAP_MULTIPLIER
	return 1.0

# 保存数据（供存档系统调用）
func save_data() -> Dictionary:
	return {
		"level": current_level,
		"exp": current_exp,
		"total_taps": tap_count_this_second  # 临时保存，重启后不保留
	}

# 加载数据（供存档系统调用）
func load_data(data: Dictionary):
	current_level = data.get("level", 1)
	current_exp = data.get("exp", 0)
	update_level_display()
