# 三国名将抽卡布阵游戏 — 架构文档

## 项目结构

```
E:\sanguo\san-guo-recruit/
├── project.godot              # Godot项目配置
├── project.godot              # 主配置，已经设置 1920x1080
├── assets/
│   ├── images/                # 生成的资产
│   │   ├── main_background.png # 主背景
│   │   ├── ui_panel_wood.png  # UI面板木纹
│   │   ├── *.png              # 24个武将头像
├── autoload/                  # 自动加载全局节点
│   ├── idle_manager.gd
│   ├── HeroLibrary.gd         # 武将库（已拥有武将管理）
│   ├── BondManager.gd
│   ├── BattleManager.gd
│   ├── pvp_manager.gd         # PVP管理（敌方阵容生成、排名）
│   ├── SaveManager.gd         # 存档管理
│   ├── region_manager.gd
│   ├── progress_manager.gd
│   └── event_manager.gd
├── scenes/                    # 场景文件
│   ├── main.tscn              # 主菜单
│   ├── recruit.tscn           # 抽卡界面
│   ├── lineup.tscn            # 阵容编辑
│   ├── battle.tscn            # PVP战斗
│   ├── settings.tscn          # 设置界面
│   └── hero_dictionary.tscn   # 武将图鉴
├── scripts/                   # GDScript脚本
│   ├── main.gd                # 主菜单逻辑
│   ├── recruit_ui.gd          # 抽卡界面逻辑
│   ├── lineup.gd              # 阵容编辑逻辑
│   ├── battle_ui.gd           # 战斗界面逻辑
│   ├── HeroData.gd            # 武将数据定义（稀有度、势力、属性、技能）
│   ├── HeroDatabase.gd        # 完整武将数据库
│   ├── Skill.gd               # 技能基类
│   ├── Skill_*.gd             # 具体技能实现
│   └── ...
├── data/                      # 静态数据
│   └── heroes.csv             # 武将数据
└── screenshots/               # 任务QA截图（生成）
```

## 全局数据流程

1. **启动** → `SaveManager` 加载存档 → `HeroLibrary` 初始化已拥有武将 → `pvp_manager` 初始化排名

2. **主菜单** → 点击按钮进入对应场景

3. **抽卡** → `recruit_ui.gd` 根据概率 roll 武将 → 如果新武将加入 `HeroLibrary`，如果重复转碎片 → 更新 UI 九宫格显示

4. **阵容编辑** → 玩家点击右侧已拥有武将 → 点击左侧九宫格放置/移除 → 实时统计总属性 → 保存阵容到存档

5. **PVP战斗** → `pvp_manager` 根据当前排名生成敌方阵容 → `battle_ui.gd` 显示双方九宫格 → 回合制战斗 → 胜利提升排名获得声望

## UI布局规范

### 抽卡界面 recruit.tscn
- 顶部：标题 + 概率说明
- 中间：**3x3 九宫格网格容器**，每个格子大小一致
- 底部：单抽按钮 + 十连抽按钮 + 国运点显示

### 阵容编辑界面 lineup.tscn
- 左侧：**3x3 九宫格** 布局容器，占宽度 ~50%
- 右侧：VBoxContainer + ScrollContainer，可滚动已拥有武将列表，占宽度 ~50%
- 每个武将列表项显示：圆形头像 + 武将名 + 稀有度颜色
- 底部：统计信息（总勇武/总智略）+ 保存阵容按钮 + 清空按钮

### 战斗界面 battle.tscn
- 顶部：标题 "PVP 挑战" + 排名显示
- 左上：我方 **3x3 九宫格**
- 右上：敌方 **3x3 九宫格**
- 中间：战斗日志，滚动显示每回合动作
- 底部：
  - 左侧：自动战斗勾选框 + 速度滑块
  - 右侧：下一步按钮

## 节点树结构规范

所有场景：
```
root (ColorRect/Control)
├── background (TextureRect)        # 背景图片 fill entire screen
├── main_container (VBoxContainer)  # 主容器
│   ├── top_section
│   ├── middle_section (HBoxContainer)
│   └── bottom_section
└── 控件对齐都是 center + fill
```

## 九宫格实现方式
- 使用 `GridContainer` 节点，columns = 3
- 每个格子是 `TextureRect` (头像) + `ColorRect` (边框按稀有度染色)
- 使用 size_flags 确保九宫格在缩放时保持比例

## 主题风格
- 背景：水墨古风深色
- UI面板：木纹纹理
- 武将头像：圆形裁剪，边框按稀有度染色
  - 白色：普通 (70%)
  - 绿色：精英 (20%)
  - 蓝色：稀有 (7%)
  - 紫色：史诗 (2%)
  - 橙色：传说 (1%)
- 势力染色：魏 = 蓝色，蜀 = 绿色，吴 = 红色，群 = 黄色

## 数据结构
- `HeroData.gd` 定义：
  ```gdscript
  name: String
  faction: Faction (Wei/Shu/Wu/Qun)
  rarity: Rarity (White/Green/Blue/Purple/Orange)
  brawn: int       # 勇武（影响物理伤害）
  intellect: int   # 智略（影响技能强度/治疗）
  skill: Skill     # 自带技能
  ```

## 验证入口
Godot 项目已经可以编译，主场景 `res://scenes/main.tscn` 可以运行。逐个任务验证修复即可。
