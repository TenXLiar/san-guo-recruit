# 游戏配置数据

这个文件夹存放所有游戏配置数据：

- `xlsx/` 目录：源文件，用 Excel 直接编辑
- `*.csv`：导出后的 CSV 文件
- `*.json`：导出后的 JSON 文件（按需使用）

## 数据说明

### heroes.csv - 武将配置
| 字段 | 说明 | 示例 |
|------|------|------|
| id | 唯一ID | shu_guanyu |
| name | 名称 | 关羽 |
| rarity | 稀有度(1-5) | 5 |
| faction | 阵营 | 蜀 |
| skill_id | 技能ID | wusheng |
| attack | 攻击力 | 98 |
| defense | 防御力 | 88 |
| description | 描述 | 威震华夏的武圣 |

### skills.csv - 技能配置
| 字段 | 说明 |
|------|------|
| id | 技能ID |
| name | 技能名称 |
| description | 技能描述 |
| effect_type | 效果类型 |
| effect_value | 效果数值 |

### regions.csv - 区域配置
| 字段 | 说明 |
|------|------|
| id | 区域ID |
| name | 区域名称 |
| description | 区域描述 |
| food_mult | 粮草消耗倍率 |
| soldier_mult | 兵力消耗倍率 |
| speed_mult | 进度速度倍率 |
| reward_type | 奖励类型 |
| reward_value | 奖励数值 |

### events.csv - 随机事件配置
| 字段 | 说明 |
|------|------|
| id | 事件ID |
| title | 事件标题 |
| description | 事件描述 |
| option1_text | 选项1文字 |
| option1_effect | 选项1效果 |
| option1_success_rate | 选项1成功率 |
| ... | ... |

## 使用方法

1. 在 `xlsx/` 中编辑 `.xlsx` 文件
2. 运行 `python tools/xlsx_to_csv.py` 自动导出 CSV
3. Godot 游戏启动时自动加载所有 CSV 到全局配置
