# 【重构56】13 个活页面星巴克风格 UI 线框图规格

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 日期：2026-08-24
> 依据：docs/live_route_map.md（活页面地图）、docs/ui_inventory.md（改造量级）、docs/live_pages_hardcode_map.md（硬编码行号）、docs/component_spec.md（10 类组件）、docs/starbucks_tokens_draft.md（Token 草案）
> 方法：只读代码静态分析 + 文档交叉引用
> 约束：只新建本文件；不改代码；中文

---

## 目录

1. [MainShell — 三 Tab 框架](#1-mainshell)
2. [HomeScreen — Tab1 学习首页](#2-homescreen)
3. [LibSelectPage — Tab2 词库选择](#3-libselectpage)
4. [ProfileScreen — Tab3 我的](#4-profilescreen)
5. [SearchPage — 查词](#5-searchpage)
6. [DictionaryPage — 词典结果](#6-dictionarypage)
7. [WordMachinePage — 单词机](#7-wordmachinepage)
8. [ImmersiveSwipePage — 沉浸刷词](#8-immersiveswipepage)
9. [LearnPage — 4选1 学习](#9-learnpage)
10. [ReviewSession — 复习会话](#10-reviewsession)
11. [AppearancePage — 外观设置](#11-appearancepage)
12. [MoreSettingsPage — 更多设置](#12-moresettingspage)
13. [WordDetailPage — 单词详情](#13-worddetailpage)

---

## 1. MainShell

**文件**：`lib/shell/main_shell.dart`（199 行）｜**量级**：S｜**估算**：30 分钟

### 1.1 当前布局

```
┌─────────────────────────┐
│      当前 Tab 内容       │ ← Positioned.fill，全屏铺满
│                         │
│                         │
│                         │
├─────────────────────────┤ ← Positioned bottom，透明悬浮底栏
│  🏠 学习  📚 词库  👤 我的 │ ← 三 Tab 图标，选中 #1F1F1F / 未选 #999999
│  ─── (AnimatedContainer) │ ← 下划线动画指示条
└─────────────────────────┘
```

- 框架：`Scaffold > Stack > [Positioned.fill(内容), Positioned bottom(TabBar)]`
- 底栏：透明悬浮、仅图标、带 `AnimatedContainer` 下划线 + `SpringCurve` 弹性反馈
- 硬编码：`_selectedColor #1F1F1F`（:138）、`_unselectedColor #999999`（:139）、`Colors.white`（:155-156）

### 1.2 星巴克改造要点

| 区域 | 改造内容 | 组件映射 |
|---|---|---|
| 底栏背景 | 透明→奶油画布 `#F2F0EB` 实心 + 顶部发丝线 `rgba(0,0,0,0.08)` | 自定义 Container |
| 选中色 | `#1F1F1F` → `#006241` Starbucks Green | ThemeVars.text1 |
| 未选中色 | `#999999` → `rgba(0,0,0,0.58)` | ThemeVars.text3 |
| 指示条 | 保留 `AnimatedContainer`，色值改 `#006241` | — |
| 底栏高度 | 56dp 保留（AppTabBar.height） | — |

### 1.3 色彩方案

| 现状 | → 星巴克 | 用途 |
|---|---|---|
| `#1F1F1F` | `#006241` | 选中 Tab 图标 |
| `#999999` | `rgba(0,0,0,0.58)` | 未选中 Tab 图标 |
| `Colors.white` | `ThemeVars.onGlassText1` | 底栏文字（玻璃面） |

### 1.4 工作量：30 分钟

---

## 2. HomeScreen

**文件**：`lib/screens/home_screen.dart`（288 行）｜**量级**：M｜**估算**：75 分钟

### 2.1 当前布局

```
┌─────────────────────────┐ ← 壁纸背景（全屏图片/渐变/纯色）
│  [半透明遮罩 15%]        │
│                         │
│       ┌──────────┐      │ ← 签到卡：毛玻璃 BackdropFilter
│       │  📅 签到   │      │    160px 宽, R20, 白色55%透明
│       │  08/24 Sat│      │
│       └──────────┘      │
│                         │
│  ┌────────┐ ┌────────┐  │ ← Learn/Review 双入口：GlassEntryCard
│  │ Learn  │ │ Review │  │    毛玻璃卡片，宽度自适应
│  │  120   │ │   5    │  │
│  └────────┘ └────────┘  │
│                         │
│  ┌──────┐ ┌──────┐     │ ← 快捷入口：单词机/查词（小卡片）
│  │单词机│ │ 查词  │     │
│  └──────┘ └──────┘     │
│                         │
│              ┌────┐     │ ← 右下角：FrapFab 56px「开始学习」
│              │ ▶  │     │
│              └────┘     │
└─────────────────────────┘
```

- 背景：`_WallpaperBg` 包裹，支持 image/gradient/solid 三种壁纸
- 签到卡：毛玻璃（`BackdropFilter blur 12`），`Colors.white.withOpacity(0.55)`
- Learn/Review：`GlassEntryCard` 自定义组件
- 快捷入口：Game Boy 像素风卡片（单词机）、普通卡片（查词）
- 硬编码：奶油金 `#FFF3CD/#8B6914/#FFCC80`（打卡卡）、Game Boy 绿 `#9BBC0F/#0F380F`

### 2.2 星巴克改造要点

| 区域 | 改造内容 | 组件映射 |
|---|---|---|
| 背景 | 壁纸→奶油画布 `#F2F0EB`（方案 C：画布归品牌） | Scaffold backgroundColor |
| 签到卡 | 毛玻璃→**ContentCard** 白卡 12px 双层影 | ContentCard |
| Learn/Review | 毛玻璃→白卡 ContentCard，内含进度数字 | ContentCard |
| 单词机入口 | Game Boy 绿保留（像素风豁免），但外框改白卡 | ContentCard + GameBoy 内嵌 |
| 查词入口 | 普通卡片→ContentCard + 绿色图标 | ContentCard |
| 开始学习 | 保留 **FrapFab** 56px 圆形悬浮 | FrapFab |
| 打卡卡金色 | `#FFF3CD` → `StarGold.cream`；`#8B6914` → `StarGold.bronze` | 新 Token |

### 2.3 色彩方案

| 现状 | → 星巴克 | 用途 |
|---|---|---|
| 壁纸渐变/图片 | `#F2F0EB` 奶油画布 | 页面背景 |
| `Colors.white.withOpacity(0.55)` | `#FFFFFF` 实心白卡 | 签到卡 |
| `#FFF3CD` | `StarGold.cream` | 打卡卡底 |
| `#8B6914` | `StarGold.bronze` | 打卡图标 |
| `#FFCC80` | `StarGold.glow` | 触摸图标 |
| `#9BBC0F` / `#0F380F` | 保留（GameBoy 豁免） | 单词机入口 |
| `Colors.black` | `ThemeVars.text1` | 文字 |

### 2.4 组件映射

- 签到卡 → ContentCard（12px 圆角 + 双层影）
- Learn/Review 入口 → ContentCard
- 快捷入口 → ContentCard
- 开始学习 → FrapFab（56px 圆形 `#00754A`）
- 所有按钮 → PillButton（50px 胶囊）

### 2.5 工作量：75 分钟

---

## 3. LibSelectPage

**文件**：`lib/pages/lib_select_page.dart`（441 行）｜**量级**：M｜**估算**：40 分钟

### 3.1 当前布局

```
┌─────────────────────────┐
│ ← 🔍     词库选择    👁  │ ← 顶栏 48dp：返回+标题+搜索/眼睛
├─────────────────────────┤
│ 全部│CET4│CET6│高考│... │ ← 分类 Tab 横滚（9 个标签）
├─────────────────────────┤
│ ┌────┐ 红宝书·四级词汇    │ ← 词书列表项 120dp/项
│ │封面│ 72×88 绿底白字     │    封面：72×88 渐变+前4字
│ │    │ 3215 词           │    右侧：书名+描述+词数
│ └────┘                   │
│ ┌────┐ 恋练有词·考研      │
│ │封面│ ...               │
│ └────┘                   │
│         ...              │
│              ┌────┐      │ ← 右下：FrapFab「开始学习」
│              │ ▶  │      │
│              └────┘      │
└─────────────────────────┘
```

- 顶栏：48dp，`colors.cardBg` 背景
- 分类 Tab：水平滚动，9 个标签
- 列表项：120dp 高，封面 72×88（`LinearGradient` 橙系渐变 + R4 + 白字前 4 字）
- 右下：FrapFab「开始学习」
- 硬编码：`AppColors.mainBgTop/Bottom`（橙渐变封面）、`Colors.white`（封面字）

### 3.2 星巴克改造要点

| 区域 | 改造内容 | 组件映射 |
|---|---|---|
| 顶栏 | 保持 48dp，背景改奶油画布 | — |
| 分类 Tab | 选中态用 `#006241` 下划线 + 文字 | PillButton（描边款小型化） |
| 词书封面 | 渐变→三档绿纯色（见【重构42】）+ 白字友好名 | 自定义 Container |
| 列表项 | 整体包 ContentCard（12px + 双层影） | ContentCard |
| 开始学习 | 保留 FrapFab | FrapFab |

### 3.3 色彩方案

| 现状 | → 星巴克 | 用途 |
|---|---|---|
| `AppColors.mainBgTop/Bot` 橙渐变 | 三档绿 `#006241/#00754A/#1E3932` | 书封底色 |
| `Colors.white` 封面字 | 保留 | 书封白字 |
| `AppColors.black87` | `ThemeVars.text1` | 书名 |
| `AppColors.textTertiary` | `ThemeVars.text3` | 描述/词数 |

### 3.4 工作量：40 分钟

---

## 4. ProfileScreen

**文件**：`lib/screens/profile_screen.dart`（319 行）｜**量级**：M（重灾区）｜**估算**：120 分钟

### 4.1 当前布局

```
┌─────────────────────────┐
│              🔔 消息     │ ← 顶栏 48dp
├─────────────────────────┤
│  ░░░░░░░░░░░░░░░░░░░░░  │ ← 金色渐变头部（FFF3CD→FFF8E1→F5F5F5）
│    ┌──────────┐         │
│    │  ☺ 头像   │ 88×88   │ ← 圆形头像 + VIP 徽章
│    └──────────┘         │
│      用户昵称            │
│    连续打卡 12 天         │
├─────────────────────────┤
│ ┌────────┐ ┌────────┐   │ ← 酷币卡 + 装备卡（双列）
│ │ 🪙 1280 │ │ 🎒 装备 │   │    金色渐变底 + 金边框
│ └────────┘ └────────┘   │
├─────────────────────────┤
│  🎨 外观 & 沉浸场景  >   │ ← 菜单列表
│  ⚙️ 更多设置         >   │    图标+标题+箭头
│  📊 学习数据         >   │
│  💬 意见反馈         >   │
└─────────────────────────┘
```

- 头部：金色渐变（`#FFF3CD → #FFF8E1 → #F5F5F5`），88×88 圆形头像
- 酷币/装备：双列卡片，金色渐变底
- 菜单：图标+标题+箭头列表
- 硬编码：24 处 `Color(0x...)` + 3 处 `Colors.*`（全 App 最多）

### 4.2 星巴克改造要点

| 区域 | 改造内容 | 组件映射 |
|---|---|---|
| 头部渐变 | 金色渐变→**奶油画布 `#F2F0EB`** + 墨绿文字 | Container(solid color) |
| 头像框 | 金色渐变→白框 + 绿色 VIP 徽章 | Container + Stack |
| 酷币卡 | 金色渐变→**ContentCard** 白卡 + 金色数字 `#CBA258` | ContentCard |
| 装备卡 | 同上，四组装备图标保留（色彩归入 Token） | ContentCard |
| 菜单列表 | 硬编码图标色→统一 Token；整体用 ContentCard 包裹 | ContentCard + 列表 |
| VIP/酷币 | 金色 `#CBA258` 仅限成就场景（约束） | StarGold 系列 Token |

### 4.3 色彩方案

| 现状 | → 星巴克 | 用途 |
|---|---|---|
| `#FFF3CD/#FFF8E1/#F5F5F5` 渐变 | `#F2F0EB` 纯色 | 页面头部背景 |
| `#FFE0B2` 头像渐变 | `#FFFFFF` 白框 | 头像边框 |
| `#FFCC80` 光晕 | 移除（过度装饰） | — |
| `#8B6914` 头像图标 | `#006241` | 头像图标色 |
| `#4A6741` VIP 徽章 | `#00754A` | VIP 标识 |
| `#CC8800` 酷币金 | `#CBA258` | 酷币数字（仅成就） |
| `#4CAF50` 菜单绿 | `#00754A` | 菜单图标 |
| `#9C27B0` 紫/`#2196F3` 蓝 | `FuncColors.purple/info` | 功能色保留 |

### 4.4 组件映射

- 头部 → 纯色 Container（奶油画布）
- 酷币/装备 → ContentCard（并排双列）
- 菜单项 → ContentCard 内 `_Cell` 列表
- 按钮 → PillButton

### 4.5 工作量：120 分钟（全 App 最大改造量）

---

## 5. SearchPage

**文件**：`lib/pages/search_page.dart`（379 行）｜**量级**：S｜**估算**：45 分钟

### 5.1 当前布局

```
┌─────────────────────────┐
│ ← ┌──────────────────┐  │ ← 搜索框：胶囊 R20，灰底 #F0F0F0
│   │ 🔍 输入单词...    │  │    带扫码图标
│   └──────────────────┘  │
├─────────────────────────┤
│ 搜索历史                 │ ← 历史标签区
│ ┌─────┐ ┌─────┐ ┌────┐ │    Wrap 布局，星标 #FFCC80
│ │apple│ │book│ │test│ │
│ └─────┘ └─────┘ └────┘ │
│              清空历史     │
├─────────────────────────┤
│ 搜索结果列表              │ ← 结果 ListView
│ ┌──────────────────────┐│    点击→DictionaryPage
│ │ apple  /ˈæpəl/      ││
│ │ n. 苹果              ││
│ └──────────────────────┘│
└─────────────────────────┘
```

- 搜索框：胶囊形 `BorderRadius.circular(20)`，底色 `#F0F0F0`
- 历史标签：`Wrap` 布局，可星标
- 结果列表：点击进入 DictionaryPage

### 5.2 星巴克改造要点

| 区域 | 改造内容 | 组件映射 |
|---|---|---|
| 搜索框底色 | `#F0F0F0` → `ThemeVars.cardBgAlt` | — |
| 搜索框圆角 | R20 → `BorderRadius.circular(50)`（胶囊化） | — |
| 历史标签 | 灰底→白卡 ContentCard 内的 Chip | ContentCard |
| 结果列表项 | 包 ContentCard（12px + 双层影） | ContentCard |
| 占位文字色 | `#BBBBBB` → `MistralColors.muted` | — |

### 5.3 工作量：45 分钟

---

## 6. DictionaryPage

**文件**：`lib/pages/dictionary_page.dart`（584 行）｜**量级**：M｜**估算**：15 分钟

### 6.1 当前布局

```
┌─────────────────────────┐
│ ←    apple              │ ← 顶栏：返回+单词
│    /ˈæpəl/  🔊          │ ← 音标+发音按钮
├─────────────────────────┤
│ 释义│同反义│词根          │ ← 三 Tab 切换
├─────────────────────────┤
│ n. 苹果                  │ ← 释义列表
│   apple juice 苹果汁     │    词性色标+例句
│                         │
│ v. 申请                  │
│   apply for 申请         │
└─────────────────────────┘
```

- 最干净页面，0 处硬编码色，全用 Token
- 三 Tab 切换：释义/同反义/词根

### 6.2 星巴克改造要点

| 区域 | 改造内容 | 组件映射 |
|---|---|---|
| 单词大字 | Charter 衬线保留（heroDisplay） | — |
| 释义块 | 包 ContentCard | ContentCard |
| Tab 切换 | 选中色改 `#006241` | — |
| 整体 | 换肤即可，几乎无硬编码 | — |

### 6.3 工作量：15 分钟

---

## 7. WordMachinePage

**文件**：`lib/pages/word_machine_page.dart`（770 行）｜**量级**：M｜**估算**：45 分钟

### 7.1 当前布局

```
┌─────────────────────────┐
│                         │
│   ┌─────────────────┐   │ ← Game Boy 机身（R20 灰框）
│   │ ┌─────────────┐ │   │
│   │ │  SCREEN     │ │   │ ← 像素屏：#9BBC0F 绿底
│   │ │  abandon    │ │   │    单词展示 + 4 选项
│   │ │  □ □ □ □   │ │   │
│   │ └─────────────┘ │   │
│   │  [A] [B] [START]│   │ ← 按钮区：D-pad + A/B/Start
│   │  ◄ ▲ ▼ ►       │   │
│   └─────────────────┘   │
│                         │
│   SCORE: 120  STREAK: 5 │ ← 分数显示
└─────────────────────────┘
```

- **像素风豁免域**：Game Boy 调色板 9 色不换肤
- 仅需收敛 Material 色混用（`#4CAF50`/`Colors.red` → 并入 `_PixelColors`）

### 7.2 星巴克改造要点

| 区域 | 改造内容 | 组件映射 |
|---|---|---|
| 机身外框 | 保持灰调，可微调向绿色系靠拢 | — |
| 像素屏 | **不换肤**（设计语言保留） | — |
| 暂停对话框底 | `#2C2C2C` → 并入 `_PixelColors.dialogBg` | — |
| 开始键 | `#4CAF50` → `_PixelColors.startGo` | — |
| `_PixelColors` | 上移为 `lib/tokens/gameboy.dart` 共享 | 新 Token 文件 |

### 7.3 工作量：45 分钟（主要是 `_PixelColors` 提取 + Material 色归位）

---

## 8. ImmersiveSwipePage

**文件**：`lib/pages/immersive_swipe_page.dart`（332 行）｜**量级**：M｜**估算**：25 分钟

### 8.1 当前布局

```
┌─────────────────────────┐
│ ←         进度 3/20      │ ← 顶栏：返回+进度
├─────────────────────────┤
│                         │
│   ┌─────────────────┐   │ ← 全屏卡片（R20）
│   │                 │   │    上滑=认识，下滑=不认识
│   │     abandon     │   │    单词大字居中
│   │     /əˈbændən/  │   │
│   │                 │   │
│   └─────────────────┘   │
│                         │
│  认识 ↑    ↓ 不认识     │ ← 滑动提示
│  ┌──────────────────┐   │ ← 底部：释义预览
│  │ v. 放弃，抛弃     │   │
│  └──────────────────┘   │
└─────────────────────────┘
```

- 全屏手势驱动，`GestureDetector` 垂直滑动
- 卡片 R20，白底

### 8.2 星巴克改造要点

| 区域 | 改造内容 | 组件映射 |
|---|---|---|
| 卡片 | 白底→**ContentCard**（12px + 双层影） | ContentCard |
| 背景 | 奶油画布 `#F2F0EB` | Scaffold bg |
| 滑动提示 | 文字色改 Token | — |
| 释义区 | 包 ContentCard | ContentCard |

### 8.3 工作量：25 分钟

---

## 9. LearnPage

**文件**：`lib/pages/learn_page.dart`（362 行）｜**量级**：M｜**估算**：60 分钟

### 9.1 当前布局

```
┌─────────────────────────┐ ← 壁纸背景 + 15%黑色遮罩
│  ←   进度 5/20   ⚙️    │ ← 顶栏：返回+进度+设置
├─────────────────────────┤
│                         │
│       abandon           │ ← 单词区（flex:4）heroDisplay 40px
│       /əˈbændən/        │    音标+发音
│                         │
├─────────────────────────┤
│  ┌─────────────────┐    │ ← 四选项区（flex:6）
│  │ A. 放弃         │    │    选项卡 R14，白底
│  │ B. 离开         │    │    选错→红色边框+背景
│  │ C. 继续         │    │    选对→绿色确认
│  │ D. 坚持         │    │
│  └─────────────────┘    │
│                         │
│  ┌─────────────────────┐│ ← 底部：认识/模糊/忘记了 三键
│  │  认识  │ 模糊 │ 忘记 ││    下划线文字按钮
│  └─────────────────────┘│
└─────────────────────────┘
```

- 背景：壁纸 + `Colors.black.withOpacity(0.15)` 遮罩
- 单词区：heroDisplay 40px，Charter 衬线
- 四选项：R14 白卡，答错红 `#E8A0A0`，答对绿
- 底部三键：下划线文字按钮

### 9.2 星巴克改造要点

| 区域 | 改造内容 | 组件映射 |
|---|---|---|
| 背景 | 壁纸→奶油画布 `#F2F0EB`（移除遮罩） | Scaffold bg |
| 单词大字 | 保留 heroDisplay 40px，色改 `ThemeVars.text1` | — |
| 选项卡 | 白底→**ContentCard**（12px + 双层影） | ContentCard |
| 答错态 | `#E8A0A0` → `ThemeVars.quizWrongBg` | 新 Token |
| 答对态 | 绿色确认态组件（见【重构44】分镜） | 自定义 |
| 底部三键 | 下划线→**PillButton** 描边款 | PillButton |
| 阴影/遮罩 | `Colors.black.withOpacity(0.15)` → 移除或改 `wallpaperScrim` | — |

### 9.3 组件映射

- 选项卡 → ContentCard
- 底部操作 → PillButton（描边款，认识=绿/模糊=灰/忘记=红）
- 答对确认 → springPop 弹入动画组件（【重构44】）

### 9.4 工作量：60 分钟

---

## 10. ReviewSession

**文件**：`lib/screens/review_session.dart`（347 行）｜**量级**：M｜**估算**：20 分钟

### 10.1 当前布局

```
┌─────────────────────────┐ ← 壁纸背景 + scrim
│  ←   复习 3/20          │ ← 顶栏
├─────────────────────────┤
│                         │
│       abandon           │ ← 单词大字区
│                         │
├─────────────────────────┤
│  ┌─────────────────┐    │ ← 四选项（GlassEntryCard 毛玻璃）
│  │ A. 放弃         │    │    与 LearnPage 类似
│  │ B. 离开         │    │
│  │ C. 继续         │    │
│  │ D. 坚持         │    │
│  └─────────────────┘    │
│                         │
│  ──认识── ──模糊── ──忘了──│ ← 底部三键（下划线）
└─────────────────────────┘
```

- **最规范页面**：0 处硬编码色，全用 `glass_widgets` + `skin`
- 仅需间距归档（`SizedBox` 6→xs8 等）

### 10.2 星巴克改造要点

| 区域 | 改造内容 | 组件映射 |
|---|---|---|
| 背景 | 壁纸→奶油画布 | Scaffold bg |
| 选项卡 | 毛玻璃→**ContentCard** 白卡 | ContentCard |
| 底部三键 | 下划线→**PillButton** 描边款 | PillButton |
| 间距 | `SizedBox(h6)` → `AppleSpacing.xs8` 等 | — |

### 10.3 工作量：20 分钟（几乎纯换肤）

---

## 11. AppearancePage

**文件**：`lib/pages/appearance_page.dart`（288 行）｜**量级**：M｜**估算**：50 分钟

### 11.1 当前布局

```
┌─────────────────────────┐
│ ←    外观 & 沉浸场景     │ ← 顶栏
├─────────────────────────┤
│ ┌────────┐ ┌────────┐   │ ← 双列预览卡（壁纸+阅读模式）
│ │ 🌅 壁纸 │ │ 📖 阅读 │   │    R16，渐变预览
│ └────────┘ └────────┘   │
├─────────────────────────┤
│  ○ 明亮  ● 深邃  ○ 极夜  │ ← 主题三选一圆圈
├─────────────────────────┤
│  跟随系统          [开关]│ ← 跟随系统开关
├─────────────────────────┤
│  风格字体        现代简约 │ ← 设置行
│  沉浸场景        未开启  │
└─────────────────────────┘
```

- 预览卡：双列，R16，渐变色预览
- 主题选择：三个圆形按钮
- 硬编码：13 处 `Color(0x...)` + 12 处 `Colors.*`

### 11.2 星巴克改造要点

| 区域 | 改造内容 | 组件映射 |
|---|---|---|
| 预览卡 | 渐变→纯色预览（奶油画布/墨绿画布） | ContentCard |
| 主题圆圈 | 三选一改为「星巴克亮」「星巴克暗」两选一 | 自定义圆形选择器 |
| 跟随系统 | 接线真功能（【重构43】批1） | — |
| 选中色 | `#FF6800` → `#006241` | ThemeVars.accent |
| 设置行 | 包 ContentCard | ContentCard |

### 11.3 工作量：50 分钟

---

## 12. MoreSettingsPage

**文件**：`lib/pages/more_settings_page.dart`（322 行）｜**量级**：S｜**估算**：30 分钟

### 12.1 当前布局

```
┌─────────────────────────┐
│ ←     更多设置           │ ← 顶栏
├─────────────────────────┤
│ ┌──────────────────────┐│ ← 账号组
│ │ 👤 账号信息    微信：幸福││    图标+标题+副标题
│ └──────────────────────┘│
│ ┌──────────────────────┐│ ← 功能组
│ │ 🖼 主页壁纸随动  [开关]││    图标色：蓝/绿/橙/紫/红
│ │ ❓ 帮助中心        >  ││    每项独立图标色
│ │ ⭐ 评价应用        >  ││
│ │ 🔄 检查更新        >  ││
│ │ 📤 推荐好友        >  ││
│ └──────────────────────┘│
│ ┌──────────────────────┐│ ← 危险组
│ │ 🚪 退出登录          ││    红色图标 #E3303B
│ └──────────────────────┘│
└─────────────────────────┘
```

- 分组列表：`_SettingGroup` 容器
- 图标色：每个不同（蓝/绿/橙/紫/红），硬编码

### 12.2 星巴克改造要点

| 区域 | 改造内容 | 组件映射 |
|---|---|---|
| 分组容器 | `Colors.white` 底→**ContentCard** | ContentCard |
| 图标色 | 统一归入 Token（`FuncColors.info/purple` 等） | — |
| 退出登录 | `#E3303B` → `MistralColors.danger` | — |
| 整体 | 换肤 + Token 归位 | — |

### 12.3 工作量：30 分钟

---

## 13. WordDetailPage

**文件**：`lib/pages/word_detail_page.dart`（651 行）｜**量级**：M｜**估算**：25 分钟

### 13.1 当前布局

```
┌─────────────────────────┐
│ ←     abandon           │ ← 顶栏：返回+单词
│    /əˈbændən/  🔊       │ ← 音标+发音
│    n. 放弃；v. 抛弃      │ ← 简要释义
├─────────────────────────┤
│ ┌──────────────────────┐│ ← 详细释义区
│ │ n. [C, U] 放弃       ││    奶油底 #F2F0EB
│ │   放弃某事            ││
│ │   He abandoned his   ││
│ │   plan.              ││
│ └──────────────────────┘│
│ ┌──────────────────────┐│ ← 例句区
│ │ 例句                  ││
│ │ They abandoned the   ││
│ │ sinking ship.        ││
│ └──────────────────────┘│
│ ┌──────────────────────┐│ ← 笔记区
│ │ 📝 我的笔记    [+添加]││
│ │ 这个词很重要...       ││
│ └──────────────────────┘│
└─────────────────────────┘
```

- 已用 `MistralColors.cream/beigeDeep/creamLight`（Token 化）
- 主要是换肤

### 13.2 星巴克改造要点

| 区域 | 改造内容 | 组件映射 |
|---|---|---|
| 释义块 | 奶油底→**ContentCard** 白卡 | ContentCard |
| 例句区 | 包 ContentCard | ContentCard |
| 笔记区 | 包 ContentCard + 添加按钮改 PillButton | ContentCard + PillButton |
| 错误提示 | `Colors.red` → `MistralColors.danger` | — |

### 13.3 工作量：25 分钟

---

## 总览表

| # | 页面 | 量级 | 估算 | 核心改造 | 硬编码处数 |
|---|---|---|---|---|---|
| 1 | MainShell | S | 30 min | 底栏换色+奶油画布 | 2+3 |
| 2 | HomeScreen | M | 75 min | 壁纸→画布+毛玻璃→白卡 | 5+10 |
| 3 | LibSelectPage | M | 40 min | 封面三档绿+列表包卡 | 0+4 |
| 4 | **ProfileScreen** | **M** | **120 min** | 金色渐变→奶油+菜单归 Token | **24+3** |
| 5 | SearchPage | S | 45 min | 搜索框胶囊化+结果包卡 | 6+3 |
| 6 | DictionaryPage | M | 15 min | 纯换肤 | 0+1 |
| 7 | WordMachine | M | 45 min | PixelColors 提取+归位 | 15+9(豁免) |
| 8 | ImmersiveSwipe | M | 25 min | 卡片包 ContentCard | 0+2 |
| 9 | LearnPage | M | 60 min | 壁纸→画布+选项包卡+三键 | 2+15 |
| 10 | ReviewSession | M | 20 min | 毛玻璃→白卡+间距归档 | 0+0 |
| 11 | AppearancePage | M | 50 min | 预览卡+主题选择器+接线 | 13+12 |
| 12 | MoreSettingsPage | S | 30 min | 分组包卡+图标色归 Token | 7+2 |
| 13 | WordDetailPage | M | 25 min | 释义/例句/笔记包卡 | 0+2 |
| | **合计** | | **580 min ≈ 9.7h** | | **74+66=140** |

+20% 自测缓冲 ≈ **11.6 人时 / 约 1.5 人天**

### 施工顺序建议

1. **先落共享 Token**（StarGold / GameBoyPalette / FuncColors，~1h）
2. **重灾区优先**：ProfileScreen(120min) → LearnPage(60min) → HomeScreen(75min)
3. **中等页**：AppearancePage → SearchPage → WordMachine → LibSelectPage
4. **干净页随手收尾**：DictionaryPage(15min) → ReviewSession(20min) → WordDetailPage(25min) → MoreSettingsPage → MainShell → ImmersiveSwipe

### 跨页面组件复用总结

| 组件 | 使用页面数 | 场景 |
|---|---|---|
| **ContentCard** | 13/13 | 几乎所有卡片/列表项/内容块 |
| **PillButton** | 8/13 | 主操作按钮（开始学习/提交/添加等） |
| **FrapFab** | 3/13 | HomeScreen/LibSelectPage/ImmersiveSwipe 悬浮入口 |
| **ThemeVars** | 13/13 | 全局色彩 Token |
| **AppleSpacing** | 13/13 | 间距归档 |
