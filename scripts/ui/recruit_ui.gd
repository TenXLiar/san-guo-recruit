extends Control
# 类名和文件名冲突了，去掉class_name因为autoload不需要它
# class_name RecruitUI

# 信号
signal recruit_requested # 点击招募按钮时发送信号
signal back_requested # 点击返回按钮时发送信号

func _ready():
	# 让根节点也接收鼠标点击
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	var btn = get_node_or_null("RecruitButton")
	if btn:
		print("RecruitUI: 找到RecruitButton，连接信号")
		# 强制开启鼠标接收
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.connect("pressed", Callable(self, "_on_recruit_clicked"))
	else:
		print("RecruitUI: 找不到RecruitButton节点！")
	
	# 连接返回按钮
	var back_btn = get_node_or_null("BackButton")
	if back_btn:
		back_btn.connect("pressed", Callable(self, "_on_back_clicked"))

func _on_input_event(event: InputEvent) -> void:
	# 如果点击鼠标，也触发招募（备用方案）
	if event is InputEventMouseButton and event.pressed:
		print("RecruitUI: 背景被点击，也触发招募")
		recruit_requested.emit()

func _on_recruit_clicked():
	print("RecruitUI: 招募按钮被点击了，发送recruit_requested信号")
	recruit_requested.emit()

func _on_back_clicked():
	back_requested.emit()

# 监听ESC快捷键返回
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_back_clicked()

# 显示国运不足提示
func show_gdp_not_enough():
	var result_label = get_node_or_null("ResultLabel")
	if result_label:
		result_label.text = "❌ 国运点不足，需要100点才能招募"
		result_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))

# 显示抽卡结果
func show_result(hero_data: Dictionary, is_new: bool, rarity_name: String, rarity_color: Color, fragments: int = 0):
	var result_label = get_node_or_null("ResultContainer/ResultLabel")
	var result_tex = get_node_or_null("ResultContainer/LastResult")
	
	if result_label:
		result_label.add_theme_color_override("font_color", rarity_color)
		if is_new:
			result_label.text = "🎉 获得新武将：%s (%s)\n⚔️ 技能：%s | 攻击：%d | 防御：%d" % [
				hero_data.name, rarity_name, 
				hero_data.skill_name, hero_data.attack, hero_data.defense
			]
		else:
			result_label.text = "📦 重复获得：%s\n已转化为%d个碎片" % [hero_data.name, fragments]
			result_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
	
	# 显示武将头像
	if result_tex and hero_data.has("image_path"):
		var tex = load(hero_data.image_path)
		if tex:
			result_tex.texture = tex
			# 根据稀有度给头像加边框颜色
			result_tex.modulate = rarity_color
		else:
			result_tex.texture = null
			print("RecruitUI: 无法加载头像: ", hero_data.image_path)
