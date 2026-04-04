extends Control

# UI 节点引用
@onready var battle_log: RichTextLabel = $BattleLog
@onready var auto_battle_button: Button = $ControlContainer/HBox/AutoBattleButton
@onready var step_button: Button = $ControlContainer/HBox/NextStepButton
@onready var speed_slider: Slider = $ControlContainer/HBox/SpeedSlider
@onready var back_button: Button = $ControlContainer/HBox/BackButton

# 当前战斗状态
var is_battle_running = false
var is_auto_battle = false
var battle_speed = 1.0
var current_battle = null   # 注意：没有类型声明

func _ready():
	start_battle()
	
	if auto_battle_button and not auto_battle_button.is_connected("pressed", _on_auto_battle_toggled):
		auto_battle_button.connect("pressed", _on_auto_battle_toggled)
	if step_button and not step_button.is_connected("pressed", _on_next_step):
		step_button.connect("pressed", _on_next_step)
	if speed_slider and not speed_slider.is_connected("value_changed", _on_speed_changed):
		speed_slider.connect("value_changed", _on_speed_changed)
	if back_button and not back_button.is_connected("pressed", _on_back):
		back_button.connect("pressed", _on_back)

func _normalize_hero_id(hero_id):
	if typeof(hero_id) == TYPE_STRING:
		return hero_id
	elif typeof(hero_id) == TYPE_DICTIONARY:
		return hero_id.get("id", hero_id.get("hero_id", ""))
	else:
		return ""

func get_faction_name(faction: String) -> String:
	match faction:
		"wei": return "魏"
		"shu": return "蜀"
		"wu": return "吴"
		"qun": return "群"
	return "?"

func get_faction_color(faction: String) -> Color:
	match faction:
		"wei": return Color(0, 0.5, 1)
		"shu": return Color(0.8, 0, 0)
		"wu": return Color(0, 0.7, 0)
		"qun": return Color(0.7, 0, 0.7)
	return Color(1, 1, 1)

func print_lineup_details(lineup: Array, side: String):
	print("========== " + side + " 阵容详情 ==========")
	for i in range(9):
		var raw_id = lineup[i]
		var hero_id = _normalize_hero_id(raw_id)
		if hero_id != null and hero_id != "":
			var hero_data = HeroLibrary.get_hero_data(hero_id)
			if hero_data is Dictionary and not hero_data.is_empty():
				var name = hero_data.get("name", "未知")
				var faction = get_faction_name(hero_data.get("faction", ""))
				var attack = hero_data.get("attack", 0)
				var defense = hero_data.get("defense", 0)
				var rarity = hero_data.get("rarity", 0)
				print("  格子 %d: %s (%s) 勇武:%d 智略:%d 稀有度:%d" % [i, name, faction, attack, defense, rarity])
			else:
				print("  格子 %d: 武将ID %s 未在武将库中找到（数据类型: %s）" % [i, hero_id, typeof(hero_data)])
		else:
			print("  格子 %d: 空" % i)
	print("==================================\n")

func start_battle():
	print("=== start_battle 开始 ===")
	if not BattleManager:
		print("❌ BattleManager 不存在")
		battle_log.append_text("[color=red]战斗管理器未初始化！[/color]\n")
		return
	print("✅ BattleManager 存在")
	
	is_battle_running = true
	
	if not pvp_manager:
		print("❌ PvPManager 单例不存在")
		battle_log.append_text("[color=red]找不到PvPManager！[/color]\n")
		return
	
	print("✅ PvPManager 存在")
	
	var player_lineup = pvp_manager.get_player_lineup()
	var enemy_lineup = pvp_manager.generate_random_enemy_lineup()
	
	print("player_lineup: ", player_lineup)
	print("enemy_lineup: ", enemy_lineup)
	
	print_lineup_details(player_lineup, "我方")
	print_lineup_details(enemy_lineup, "敌方")
	
	draw_battle_lineup(player_lineup, "AttackerContainer/AttackerGrid")
	draw_battle_lineup(enemy_lineup, "DefenderContainer/DefenderGrid")
	
	current_battle = BattleManager.start_battle(player_lineup, enemy_lineup)
	battle_log.clear()
	update_battle_log()
	
	if is_auto_battle:
		_do_next_step()
	
	print("=== start_battle 结束 ===")

func draw_battle_lineup(lineup: Array, grid_node_path: String):
	var grid = get_node(grid_node_path) as GridContainer
	if not grid:
		push_error("找不到九宫格节点: " + grid_node_path)
		return
	
	for child in grid.get_children():
		child.queue_free()
	
	for i in range(9):
		if i >= lineup.size():
			continue
		
		var raw_id = lineup[i]
		var hero_id = _normalize_hero_id(raw_id)
		
		var container = VBoxContainer.new()
		container.custom_minimum_size = Vector2(94, 94)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.3, 0.4, 1.0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(1, 1, 1, 0.9)
		container.add_theme_stylebox_override("panel", style)
		
		var tex_rect = TextureRect.new()
		tex_rect.name = "Portrait"
		tex_rect.custom_minimum_size = Vector2(80, 80)
		tex_rect.expand = true
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture = null
		
		if hero_id != "":
			var hero_data = HeroLibrary.get_hero_data(hero_id)
			if hero_data is Dictionary and not hero_data.is_empty():
				var image_path = "res://assets/images/%s.png" % hero_id
				var tex = load(image_path)
				if tex:
					tex_rect.texture = tex
					var faction_color = get_faction_color(hero_data.get("faction", ""))
					tex_rect.modulate = faction_color
		
		container.add_child(tex_rect)
		grid.add_child(container)

func _do_auto_next_step():
	if not is_battle_running:
		start_battle()
		if is_auto_battle:
			_timer_start_next_battle()

func _timer_start_next_battle():
	var timer = Timer.new()
	timer.wait_time = 1.0 / battle_speed
	timer.one_shot = true
	timer.timeout.connect(_do_auto_next_step)
	add_child(timer)
	timer.start()

func _do_next_step():
	if not current_battle:
		return
	
	var events = current_battle.take_turn()
	for event in events:
		if event.has("message") and event.message != "":
			append_battle_log(event.message)
		else:
			if event.get("type") == "attack":
				append_battle_log("%s 对 %s 造成 %d 点伤害" % [event.get("attacker", "?"), event.get("target", "?"), event.get("damage", 0)])
			elif event.get("type") == "skill":
				append_battle_log("%s 使用 %s，造成 %d 点伤害，治疗 %d 点" % [event.get("attacker", "?"), event.get("skill_name", "技能"), event.get("damage", 0), event.get("heal", 0)])
			elif event.get("type") == "dot":
				append_battle_log(event.get("message", "持续伤害"))
			elif event.get("type") == "stun":
				append_battle_log(event.get("message", "眩晕"))
			else:
				append_battle_log("发生了未知事件")
	update_battle_log()
	
	if current_battle.is_finished():
		process_battle_result(current_battle.get_result())

func append_battle_log(text: String):
	battle_log.append_text(text + "\n")

func update_battle_log():
	await get_tree().process_frame
	var scrollbar = battle_log.get_v_scroll_bar()
	scrollbar.value = scrollbar.max_value

func process_battle_result(result):
	is_battle_running = false
	current_battle = null
	
	if result.victory:
		battle_log.append_text("\n[color=green][b]🎉 战斗胜利！[/b][/color]\n")
		battle_log.append_text("\n总共进行 %d 回合\n剩余 %d 个单位存活\n" % [result.rounds, result.attacker_alive])
		if pvp_manager:
			var reward = pvp_manager.calculate_reward(result)
			pvp_manager.apply_reward(reward)
			battle_log.append_text("\n[color=gold]获得奖励：声望 +%d\n排名提升: %d → %d[/color]\n" % [reward.prestige, reward.old_rank, reward.new_rank])
	else:
		battle_log.append_text("\n[color=red][b]💀 战斗失败[/b][/color]\n")
		battle_log.append_text("\n你 %d 个单位存活，敌人 %d 个单位存活\n" % [result.attacker_alive, result.defender_alive])
	
	if is_auto_battle and not is_battle_running:
		_timer_start_next_battle()

func _on_auto_battle_toggled():
	is_auto_battle = !is_auto_battle
	auto_battle_button.text = "自动战斗：%s" % ("关闭" if is_auto_battle else "开启")
	if is_auto_battle and not is_battle_running:
		_timer_start_next_battle()

func _on_speed_changed(value: float):
	battle_speed = value

func _on_next_step():
	if is_battle_running:
		_do_next_step()

func _on_back():
	get_tree().change_scene_to_file("res://scenes/main.tscn")
