extends Control
class_name BattleUI

# 单例引用
var PVPManager = preload("res://scripts/pvp_manager.gd").instance
var HeroLibrary = preload("res://scripts/hero_library.gd").instance
var BattleManager = preload("res://scripts/battle_manager.gd").instance

# 节点引用
var title_label: Label
var desc_label: Label
var attacker_container: VBoxContainer
var defender_container: VBoxContainer
var battle_log: RichTextLabel
var auto_battle_button: Button
var next_step_button: Button
var back_button: Button
var speed_slider: HSlider

signal back_requested

# 战斗状态
var is_auto_battle: bool = false
var battle_speed: float = 1.0
var current_battle_result: Dictionary = {}
var is_battle_running: bool = false

func _ready():
	# 获取节点引用
	title_label = get_node("Title")
	desc_label = get_node("Desc")
	attacker_container = get_node("AttackerContainer")
	defender_container = get_node("DefenderContainer")
	battle_log = get_node("BattleLog")
	auto_battle_button = get_node("ControlContainer/HBox/AutoBattleButton")
	next_step_button = get_node("ControlContainer/HBox/NextStepButton")
	back_button = get_node("ControlContainer/HBox/BackButton")
	speed_slider = get_node("ControlContainer/HBox/SpeedSlider")
	
	# 连接信号
	auto_battle_button.connect("pressed", Callable(self, "_on_auto_battle_toggled"))
	next_step_button.connect("pressed", Callable(self, "_on_next_step"))
	back_button.connect("pressed", Callable(self, "_on_back"))
	speed_slider.connect("value_changed", Callable(self, "_on_speed_changed"))
	
	speed_slider.value = 1.0
	if desc_label:
		desc_label.visible = false
	
	# 开始战斗
	start_battle()

func start_battle():
	# 获取玩家阵容
	var player_lineup = HeroLibrary.instance.get_saved_lineup()
	# 获取当前排行榜上的敌人（这里先用随机AI阵容）
	var enemy_lineup = PVPManager.instance.generate_random_enemy_lineup()
	
	# 清空容器
	for child in attacker_container.get_children():
		child.queue_free()
	for child in defender_container.get_children():
		child.queue_free()
	
	# 创建双方单位展示
	create_unit_icons(player_lineup, attacker_container, true)
	create_unit_icons(enemy_lineup, defender_container, false)
	
	battle_log.clear()
	battle_log.append_text("[b]战斗开始！[/b]\n")
	
	# 启动自动战斗
	is_battle_running = true
	_call_battle(player_lineup, enemy_lineup)

func create_unit_icons(lineup: Array, container: VBoxContainer, is_player: bool):
	for hero_id in lineup:
		if not hero_id:
			# 空位
			var box = HBoxContainer.new()
			box.spacing = 8
			var empty_tex = TextureRect.new()
			empty_tex.custom_minimum_size = Vector2(40, 40)
			box.add_child(empty_tex)
			var empty = Label.new()
			empty.text = "(空位)"
			empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			empty.custom_minimum_size = Vector2(120, 0)
			box.add_child(empty)
			container.add_child(box)
			continue
		
		var hero_data = HeroLibrary.instance.get_hero_data(hero_id)
		if hero_data.is_empty():
			continue
		
		var hp = hero_data.force * 10 + hero_data.intelligence * 5
		var attack = hero_data.force * 2
		
		var box = HBoxContainer.new()
		box.spacing = 8
		box.alignment = 1
		
		# 武将头像
		if hero_data.has("image_path"):
			var portrait = TextureRect.new()
			portrait.custom_minimum_size = Vector2(40, 40)
			portrait.stretch_mode = 2  # STRETCH_MODE_KEEP_ASPECT_COVERED = 2
			var tex = load(hero_data.image_path)
			if tex:
				portrait.texture = tex
				portrait.modulate = get_faction_color(hero_data.faction)
			box.add_child(portrait)
		
		var vbox = VBoxContainer.new()
		vbox.spacing = 2
		
		var name_label = Label.new()
		name_label.text = "%s [%s]" % [hero_data.name, get_faction_name(hero_data.faction)]
		name_label.add_theme_color_override("font_color", get_faction_color(hero_data.faction))
		name_label.custom_minimum_size = Vector2(100, 0)
		name_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(name_label)
		
		var hp_label = Label.new()
		hp_label.name = "hp_label"
		hp_label.text = "HP: %d" % hp
		hp_label.custom_minimum_size = Vector2(80, 0)
		hp_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(hp_label)
		
		box.add_child(vbox)
		container.add_child(box)

func get_faction_name(faction: String) -> String:
	match faction:
		"wei": return "魏"
		"shu": return "蜀"
		"wu": return "吴"
		"qun": return "群"
	return faction

func get_faction_color(faction: String) -> Color:
	match faction:
		"wei": return Color(0.2, 0.4, 0.8)
		"shu": return Color(0.8, 0.2, 0.2)
		"wu": return Color(0.2, 0.6, 0.2)
		"qun": return Color(0.6, 0.3, 0.1)
	return Color(1, 1, 1)

func _call_battle(player_lineup: Array, enemy_lineup: Array):
	# 开始战斗
	var result = BattleManager.instance.start_battle(player_lineup, enemy_lineup)
	_process_battle_result(result)

func _process_battle_result(result: Dictionary):
	current_battle_result = result
	is_battle_running = false
	
	if result.victory:
		battle_log.append_text("\n[color=green][b]🎉 战斗胜利！[/b][/color]")
		battle_log.append_text("\n共进行%d回合，剩余%d个单位存活\n" % [result.rounds, result.attacker_remaining])
		
		# 发放奖励
		var reward = PVPManager.instance.calculate_reward(result)
		PVPManager.instance.apply_reward(reward)
		battle_log.append_text("\n[color=gold]获得奖励：[/color]声望+%d\n" % reward.prestige)
		
		# 更新排名
		PVPManager.instance.update_rank_after_win(reward.new_rank)
		battle_log.append_text("[color=gold]排名提升：%d → %d[/color]\n" % [reward.old_rank, reward.new_rank])
	else:
		battle_log.append_text("\n[color=red][b]💀 战斗失败[/b][/color]")
		battle_log.append_text("\n共进行%d回合\n" % result.rounds)
	
	# 如果开启了自动战斗，自动开始下一场
	if is_auto_battle:
		_timer_start_next_battle()
	battle_log.scroll_to_line(battle_log.get_line_count())

func _on_auto_battle_toggled():
	is_auto_battle = !is_auto_battle
	if is_auto_battle:
		auto_battle_button.text = "自动战斗：开启 ✅"
		# 如果战斗已经结束，自动开始下一场
		if not is_battle_running:
			_timer_start_next_battle()
	else:
		auto_battle_button.text = "自动战斗：关闭 ⚪"
	battle_log.scroll_to_line(battle_log.get_line_count())

func _timer_start_next_battle():
	# 延迟一小会儿自动开始下一场
	var timer = Timer.new()
	timer.wait_time = 1.5 / battle_speed
	timer.one_shot = true
	timer.connect("timeout", Callable(self, "_do_auto_next"))
	add_child(timer)
	timer.start()

func _do_auto_next():
	if is_auto_battle and not is_battle_running:
		start_battle()

func _on_next_step():
	# 如果已经战斗结束，重新开始新战斗
	if not is_battle_running:
		start_battle()
		return

func _on_speed_changed(value: float):
	battle_speed = value

func _on_back():
	back_requested.emit()

func _on_battle_round(round: int, events: Array):
	for event in events:
		battle_log.append_text(event.message + "\n")
	battle_log.scroll_to_line(battle_log.get_line_count())
