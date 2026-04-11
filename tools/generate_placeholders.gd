#!/usr/bin/env - godot --headless -s

# 批量生成占位头像，按稀有度上色
# 稀有度颜色：
# 1: 白色  #E6E6E6
# 2: 绿色  #4CAF50
# 3: 蓝色  #2196F3
# 4: 紫色  #9C27B0
# 5: 橙色  #FF9800

var RARITY_COLORS = [
	Color(0.9, 0.9, 0.9),  # 1
	Color(0.3, 0.7, 0.3),  # 2
	Color(0.13, 0.59, 0.95),  # 3
	Color(0.61, 0.15, 0.69),  # 4
	Color(1.0, 0.6, 0.0),  # 5
]

# 读取英雄数据
var file_path = "res://data/heroes.json"
var file = FileAccess.open(file_path, FileAccess.READ)
var json_text = file.get_as_text()
file.close()

var json = JSON.new()
var parse_result = json.parse(json_text)
if parse_result != OK:
	print("Failed to parse heroes.json: ", json.get_error_message())
	push_error("parse failed")
end

var data = json.data
var heroes = data.get("heroes", [])

var output_dir = "E:/sanguo/san-guo-recruit/assets/images/"

var generated = 0
for hero in heroes:
	var image_path = output_dir + hero.id + ".png"
	var rarity = max(0, min(hero.get("rarity", 1) - 1, 4))
	var color = RARITY_COLORS[rarity]
	
	# 创建圆形头像
	var size = 128
	var image = Image.new()
	image.create(size, size, false, Image.FORMAT_RGBA8)
	
	# 填充透明
	image.fill(Color(0, 0, 0, 0))
	
	# 画圆形背景
	var center = Vector2(size/2, size/2)
	var radius = size/2 - 4
	for y in range(size):
		for x in range(size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist <= radius:
				var p = color
				# 边缘加深
				if dist > radius - 8:
					p = color * 0.8
				image.set_pixel(x, y, Color(p.r, p.g, p.b, 1))
	
	# 保存PNG
	var f = FileAccess.open(image_path, FileAccess.WRITE)
	image.save_png(f)
	f.close()
	
	generated += 1
	print("Generated placeholder: ", image_path, " rarity ", hero.rarity)

print("\n✅ Done! Generated ", generated, " placeholders")
print("All 77武将占位头像生成完成，按稀有度上色。")
