extends Control
class_name HomeUI

# 点击加速配置
var click_amount: float = 10.0  # 每次点击给10国运点
var click_multiplier: float = 1.0  # 倍率，后续可以升级
var last_click_time: float = 0.0
var click_cooldown: float = 0.1  # 防止连点

# 信号：点击获得国运
signal clicked_gdp(amount: float)

func _ready():
	# 让根节点接收鼠标点击
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 添加点击提示文字
	var click_hint = Label.new()
	click_hint.name = "ClickHint"
	click_hint.text = "🖱️ 点击屏幕任意位置加速获得国运！"
	click_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	click_hint.anchor_left = 0.5
	click_hint.anchor_right = 0.5
	click_hint.offset_left = 150.0
	click_hint.offset_top = 110.0
	click_hint.offset_right = -150.0
	click_hint.offset_bottom = 133.0
	click_hint.set_size(Vector2(0, 23))
	add_child(click_hint)
	
	# 调整原有IdleInfo位置向上
	var idle_info = get_node_or_null("IdleInfo")
	if idle_info:
		idle_info.offset_top = 66.0

# 更新武将数量显示
func update_hero_count(count: int, total: int):
	# 直接遍历子节点找武将数量标签
	for child in get_children():
		if child.name == "HeroCount":
			child.text = "已收集武将：%d / %d" % [count, total]
			child.offset_top = 160.0
			break

# 处理鼠标点击
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_click_time >= click_cooldown:
			last_click_time = current_time
			var amount = click_amount * click_multiplier
			clicked_gdp.emit(amount)
			_show_click_popup(event.position, int(amount))

# 显示点击获得的弹出数字
func _show_click_popup(position: Vector2, amount: int):
	var popup = Label.new()
	popup.text = "+%d" % amount
	popup.add_theme_font_size_override("font_size", 24)
	popup.add_theme_color_override("font_color", Color(1, 0.84, 0))
	popup.position = position
	popup.z_index = 100
	add_child(popup)
	
	# 动画：上浮然后消失
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "position", position + Vector2(0, -50), 1.0)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 1.0)
	tween.finished.connect(popup.queue_free)
	tween.play()
