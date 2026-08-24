# 死资产清理计划

> 产出：DataEngineer（Monster world）· 2026-08-24
> 依据：docs/assets_inventory.md + 独立 grep 验证
> 性质：**仅计划，未执行任何删除**

---

## 一、验证方法

| 检查项 | 方法 | 结果 |
|---|---|---|
| 9 个 SVG 零引用 | `grep -r ".svg" lib/` | ✅ 零命中——lib/ 中无任何 .svg 加载代码 |
| 9 个 SVG 文件名零引用 | `grep -r "icons_home_classroom\|icons_home_collect\|..." lib/` | ✅ 零命中 |
| beach.jpg 引用 | `grep -r "beach\.jpg" lib/` | ⚠️ 1 处命中：`wallpaper_data.dart:108` |
| forest/city/night.jpg 引用 | `grep -r "forest\.jpg\|city\.jpg\|night\.jpg" lib/` | ⚠️ 3 处命中：`wallpaper_data.dart:118/128/138`（但文件不存在于磁盘） |
| 壁纸系统依赖链 | `grep -r "wallpaper\|WallpaperData\|WallpaperState" lib/` | ⚠️ 10 个文件引用壁纸系统 |

---

## 二、A 档：安全删除清单（零引用，可立即执行）

以下 9 个 SVG 文件在 lib/ 中无任何引用，磁盘确认存在：

| # | 文件路径 | 大小(B) | 验证状态 |
|---|---|---|---|
| 1 | `assets/icons/icons_home_classroom.svg` | 1,379 | ✅ grep 零命中 |
| 2 | `assets/icons/icons_home_collect.svg` | 1,147 | ✅ grep 零命中 |
| 3 | `assets/icons/icons_home_dashboard.svg` | 848 | ✅ grep 零命中 |
| 4 | `assets/icons/icons_home_listen.svg` | 3,104 | ✅ grep 零命中 |
| 5 | `assets/icons/icons_toolbar_learn_meaning.svg` | 779 | ✅ grep 零命中 |
| 6 | `assets/icons/icons_toolbar_learn_spell.svg` | 571 | ✅ grep 零命中 |
| 7 | `assets/icons/icons_toolbar_learn_trash.svg` | 1,178 | ✅ grep 零命中 |
| 8 | `assets/icons/ic_arrow_long_left.svg` | 524 | ✅ grep 零命中 |
| 9 | `assets/icons/ic_more_h.svg` | 396 | ✅ grep 零命中 |

**小计**：9 文件，9,926 B ≈ 9.7 KB

**附带操作**：
- 删除 `pubspec.yaml:80` 的 `- assets/icons/` 声明行（目录将变空，Flutter 构建对空目录会告警/报错）
- 删除整个 `assets/icons/` 目录

---

## 三、B 档：需确认清单（存在代码依赖，必须先改代码再删文件）

### 3.1 beach.jpg（唯一真实存在的图片壁纸）

| 项目 | 内容 |
|---|---|
| 文件路径 | `assets/wallpapers/beach.jpg` |
| 大小 | 57,861 B ≈ 56.5 KB |
| 磁盘状态 | ✅ 存在 |
| 代码引用 | `wallpaper_data.dart:108`（assetPath）+ 壁纸系统消费端 10 个文件 |
| 阻塞条件 | 必须先完成"壁纸系统下线"重构任务 |

**执行顺序（强制）**：
1. 下线壁纸选择页与 WallpaperState/WallpaperData
2. 清除全部 `assetPath` 引用与 `_WallpaperBg` 图片分支
3. 处理 `selected_wallpaper_id` 持久化值的读取降级（回退默认奶油底）
4. 删除 `assets/wallpapers/beach.jpg`
5. 移除 `pubspec.yaml:81` 的 `- assets/wallpapers/` 声明行
6. `flutter clean && flutter pub get` 重构建 + 回归验证

### 3.2 悬空引用（文件不存在但代码仍引用）

| 文件路径 | 磁盘状态 | 代码引用 | 处理方式 |
|---|---|---|---|
| `assets/wallpapers/forest.jpg` | ❌ 不存在 | `wallpaper_data.dart:118` | 随壁纸系统下线一并清除代码引用 |
| `assets/wallpapers/city.jpg` | ❌ 不存在 | `wallpaper_data.dart:128` | 同上 |
| `assets/wallpapers/night.jpg` | ❌ 不存在 | `wallpaper_data.dart:138` | 同上 |

> ⚠️ 运行时风险：若用户持久化选择了 forest/city/night 壁纸，主界面 `DecorationImage(AssetImage(...))` 无 errorBuilder 会直接崩溃。这是应尽快下线壁纸系统的额外理由。

---

## 四、C 档：待决策（不在本次清理范围）

| 资产 | 体积 | 状态 | 决策依赖 |
|---|---|---|---|
| Charter 三件套（Roman/Italic/BoldItalic） | 1,457,876 B ≈ 1.39 MB | 代码引用 `design_tokens.dart:78,82` HeroWord display 字阶 | 需 DesignOwner 拍板：星巴克风格是否弃用衬线字体 |

---

## 五、pubspec.yaml 变更汇总

| 行号 | 当前内容 | 操作 | 触发条件 |
|---|---|---|---|
| 80 | `- assets/icons/` | **删除此行** | A 档执行时 |
| 81 | `- assets/wallpapers/` | **删除此行** | B 档执行时 |
| 79 | `- assets/db/wordbook.db.gz` | 不动 | — |
| 86-94 | fonts: Inter ×4 | 不动 | — |
| 96-102 | fonts: Charter ×3 | 待定 | C 档决策后 |

---

## 六、壁纸系统依赖链（B 档参考）

以下 10 个文件引用了壁纸系统，下线时需逐一处理：

| 文件 | 引用类型 |
|---|---|
| `lib/data/wallpaper_data.dart` | 壁纸数据定义（核心，整文件处置） |
| `lib/state/wallpaper_state.dart` | 壁纸状态管理（核心，整文件处置） |
| `lib/data/app_preferences_ext.dart` | 壁纸 SP 键（currentWallpaperPre / nextWallpaperPre） |
| `lib/main.dart` | Provider 注册 WallpaperState |
| `lib/pages/wallpaper_select_page.dart` | 壁纸选择页（整文件处置） |
| `lib/pages/review_page.dart` | 壁纸背景消费 |
| `lib/tokens/design_tokens.dart` | 层级枚举含 wallpaper |
| `lib/tokens/starbucks_tokens.dart` | 可能引用壁纸相关 token |
| `lib/pages/more_settings_page.dart` | 壁纸入口 |
| `lib/theme/skin_system.dart` | wallpaperScrim 字段 |

---

## 七、执行优先级建议

| 优先级 | 操作 | 风险 | 预估工时 |
|---|---|---|---|
| P0 | A 档：删除 9 个 SVG + 移除 pubspec 声明 | 零风险 | 10 min |
| P1 | B 档：壁纸系统下线 + 删除 beach.jpg | 中（需改 10 个文件，处理老用户兼容） | 2-4h（需单独重构任务） |
| P2 | C 档：Charter 字体决策 | 低（待拍板） | 决策后 5 min |

---

*产出：DataEngineer · 2026-08-24 · 基于 assets_inventory.md 独立 grep 验证*
