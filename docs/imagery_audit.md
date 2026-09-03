# 【重构35】图片资源审计：词书封面来源与星巴克占位方案

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）· 2026-08-24 · 只读审计
> 方法：grep 全 lib/ 图片渲染调用（NetworkImage / Image.network / AssetImage / BoxFit.cover）逐一定位上下文并核对行号；数据库结构结论引自既有审计文档（未触碰 db 文件）
> 关联文档：【重构21】assets_inventory.md、【重构8】icon_plan.md、branding_assets_plan.md、content_audit.md、book_name_mapping_plan.md

---

## 一、核心调查：词书封面从哪来？

### 1.1 结论先行

**当前实际使用的选书页 `lib_select_page.dart` 的"封面"根本不是图片，而是纯代码绘制的渐变色块 + 文字。** 零图片资产、零网络请求、离线表现完美；但它是一块橙色渐变——恰好撞在星巴克迁移的枪口上（ThemeAnalyst 判定渐变全面下线）。

### 1.2 渲染代码取证（当前链路）

| 位置 | 内容 |
|---|---|
| `lib/pages/lib_select_page.dart:307-330` | 封面容器：72×88，`BorderRadius.circular(4)`，`LinearGradient(AppColors.mainBgTop → AppColors.mainBgBottom)`（橙系，begin topLeft）|
| `lib_select_page.dart:331-340` | 中央白色粗体文字：`fontSize 11, w700, #FFFFFF`，居中，最多两行 |
| `lib_select_page.dart:399-402` | `_coverText()`：书名剔除 `MonsterWord_` 前缀后取**前 4 个字符**作为封面文案 |

### 1.3 数据库侧：cover 字段存在但无人消费

- `lib/models/lib_book.dart:22`：模型有 `final String cover;`（来自 `json['cover']`）；
- `lib/data/lib_book_tag_models.dart:115`：DB 字段名常量 `fieldCover = 'cover'`；
- 但当前 UI 渲染链路**没有任何一处读取该字段显示图片**——数据在睡觉；
- `docs/content_audit.md:67`（ContentAuditor 结论）：`books.name` **191 本全部等于内部 code**（如 `HZBCET6N`），封面文字只做了前缀剔除，治标不治本；
- `docs/book_name_mapping_plan.md:102`：多套教材编码存疑（GZBX vs GZXB）"需对照封面"；`:222` 已规划"封面前 4 字改取 friendly name"。

> 判断：原版 IPA 的封面是**网络图**（见 1.4），Flutter 版重写时改用了代码绘制兜底，DB 的 cover 字段成了预留位。

### 1.4 IPA 对照组件：真正的网络封面实现（未接线）

`lib/widgets/adapter_widgets.dart` 内有一个完整还原原版的选书视图：

| 位置 | 内容 |
|---|---|
| `adapter_widgets.dart:352` | `class SelectLibraryView` 定义 |
| `adapter_widgets.dart:389-394` | `book.coverUrl != null` 时 → **`Image.network(book.coverUrl!)`**（60×80 容器，黑 12% 底）|
| `adapter_widgets.dart:395-397` | 加载失败 errorBuilder → `Icon(Icons.book)` 兜底 |
| `adapter_widgets.dart:398-399` | `coverUrl == null` → 直接 `Icon(Icons.book, black54)` 占位 |

⚠️ 该组件**未被任何页面引用**（全库仅定义处一条命中）——属备用/半成品接线。它证明了"封面走网络 URL"是原设计意图，离线兜底 = 一个书本图标，体验较粗糙。

---

## 二、其他图片位全景盘点

| # | 图片位 | 位置 | 来源 | 兜底表现 | 现状评价 |
|---|---|---|---|---|---|
| 1 | 收藏例句·列表缩略图 48×48 | `adapter_widgets.dart:1768-1787` | `http://img.beingfine.cn/${sentence.image}` 明文 HTTP CDN | image 为空→`Icon(Icons.image)`；加载失败→errorBuilder 同款图标 | ⚠️ 无 loading 态、无缓存、明文协议 |
| 2 | 收藏例句·卡片大图（顶部 flex:3） | `adapter_widgets.dart:1244-1270` | 同上 CDN | 同上（48px 图标放大版） | ⚠️ 同上 |
| 3 | 应用推荐图标 | `app_ref_processor.dart:106-121` | **本地文件缓存优先** → miss 则 `NetworkImage('$baseImgUrl$iconPath')`；`:124-135` 批量预下载 | 本地缓存命中即离线可用 | ✅ 正面案例：唯一带缓存层的图片位 |
| 4 | 用户默认头像 | `avatar_processor.dart:109-124` | `AssetImage('assets/images/icon_user_none_{light/dark/black}.png')` | — | 🔴 **悬空资产**：`assets/images/` 目录不存在（【重构21】盘点确认），一旦走到默认头像分支即资源加载失败；且 `_getUserInfo()` 目前返回 null + TODO（`:126-130`），整个头像体系未接线 |
| 5 | 用户真实头像 | `avatar_processor.dart:16-70` | 本地文件 → 网络下载（photo URL） | 默认头像（见 #4 雷） | 未接线（TODO） |
| 6 | 班级域头像（签到/活动/排行） | `class_checkin_page.dart:929-931,1227-1231`、`class_activity_page.dart:833-838` | mock 数据 `CircleAvatar` 显示单个汉字（'小''学''英''勤'…） | 无需兜底 | 占位假数据，等后端 |
| 7 | 个人中心头部 | `profile_screen.dart:85`、`my_space_page.dart:84` | 头像 + VIP 徽章 + **金色渐变头部** | — | 渐变待星巴克化 |
| 8 | 空状态插画 | `helper_widgets.dart:105-145` NoDataGuide；另有 ~15 处裸 `Text('暂无XX')`（dictionary×5、learn/review/spell/book_words/message/my_equip/my_fav_sentence/word_root/sentence_quiz/lock_screen…） | `Icon(icon, 64px, text3@50%) + 文案 + 可选按钮`，默认 `Icons.inbox_outlined` | 图标即兜底 | ❌ **全站无一张插画**，空状态=灰图标+灰字 |
| 9 | 引导图 / onboarding | — | — | — | ❌ 不存在该类资产与页面 |
| 10 | 壁纸背景 | `wallpaper_data.dart` 等 | beach.jpg + 悬空 forest/city/night | errorBuilder→渐变 | 已由【重构21】判定下线，不赘述 |

**CDN 底座事实**：`baseImgUrl = 'http://img.beingfine.cn/'` 双处硬编码（`app_ref_processor.dart:22`、`api_services.dart:92`）——**明文 HTTP**。

---

## 三、星巴克方向适配建议

### 3.1 绿色系书封占位规格（替换 lib_select 橙色渐变）

**方案：纯色底 + 白字首字（延续现有代码绘制架构，零新增资产）**

| 属性 | 规格 |
|---|---|
| 底色 | 从 `AppColors.mainBgTop/Bot` 渐变换为**单色 token**。基线 `Starbucks Green #006241`；为避免 191 本书一片绿墙，建议**三档绿色系轮换**（按 book code hash 稳定分配）：`#006241` / `#00754A` / `#1E3932`，白字对比度均 ≥7:1 |
| 圆角 | `4 → AppleRadius.sm/md`（对齐现行 Apple 风格卡片体系，与 DESIGN.md 圆角令牌一致） |
| 文字 | 保留 `_coverText()` 架构，但数据源切换为 friendly name（落实 `book_name_mapping_plan.md:222`）；样式升为 Inter w600 / 11–12pt，最多 2 行 ellipsis |
| 图形升级（可选 B 版） | 底部叠一层 8% 透明白色书本轮廓线性图形（复用 icon_plan 的 `menu_book_outlined` 语义），增加"书"暗示而不引入图片 |
| 明确不做 | 真实封面网络图——除非产品要求，否则维持代码绘制：离线零成本、包体零增量、风格永不过期（星巴克官网本身也大量使用纯色+排版替代摄影图） |

### 3.2 缺失图片位的统一占位策略

1. **建立两个全局占位组件**（放 `widgets/`，替换散落的 `Icon(Icons.image/book)` 与裸 `Text('暂无')`）：
   - `BrandImagePlaceholder`：图片加载中→浅奶油底 + 20% 透明 `image` 线性图标；失败→同底 + "图片开小差了"微文案。供收藏例句图、未来任何网络图复用；
   - `BrandEmptyState`：升级版 NoDataGuide——绿色系线性图标（取自 icon_plan 映射表语义，如复习=replay、收藏=favorite_border）64px @ `#006241` 15% 透明度 + 主文案 + 可选 CTA 按钮（TextButton 绿色）。一次替换 ~15 处空状态。
2. **首字母头像策略**（替代悬空的 PNG 默认头像）：无头像用户渲染**底色 `#00754A` + 白色昵称首字符**的圆形占位（参考 class 域已有的汉字头像做法），彻底删除 `assets/images/icon_user_none_*.png` 三条悬空引用——零资产、零缺图风险。
3. **金色渐变头部**（profile/my_space）：随配色重构换为 House Green `#1E3932` 深色头部带 + 白字（DESIGN.md feature band 语言），不在本任务实施。

---

## 四、网络依赖风险评估

| 风险项 | 现状 | 影响 | 建议 |
|---|---|---|---|
| **主链路（选书/学习/复习）** | 封面纯代码绘制，零网络 | 弱网/无网体验无损 | ✅ 维持现状，这是当前架构最大的隐性优点 |
| 明文 HTTP CDN | `http://img.beingfine.cn` 两处硬编码 | ① iOS ATS 默认拦截明文 HTTP（需查 ios/Runner/Info.plist 是否已加例外，未查证前按"可能被拦"对待）；② Android 9+ 同理默认禁明文；③ 中间人风险 | 统一升级 https；URL 集中到一处常量（现分散 2 处） |
| 无缓存层 | 例句图每次进入页面重新下载 | 弱网下反复转圈/流量浪费/已看过的图再次失败 | 复制 `app_ref_processor` 的"本地文件缓存优先→网络→落盘"模式，或直接引入 `cached_network_image` 包（需 Leader 批准新依赖） |
| 无 loading 态 | Image.network 只有 errorBuilder | 弱网时图片区域空白突兀 | BrandImagePlaceholder 内置 shimmer/静态占位 |
| 未来封面联网假设 | 若某天启用 DB cover 字段的 URL | 无网用户看到满屏书本图标（IPA 对照组件的现状兜底） | 若启用：必须先落 §四缓存层 + 占位组件，且封面 URL 进 DB 校验清单 |

**结论**：当前 App 的图片网络面很窄（例句图 + app 推荐图标 + 未来头像），且主学习链路完全离线——星巴克化不需要为此新建任何网络图片基础设施，只需把窄面收干净。

---

## 五、缺口清单与新增资产需求汇总

| # | 缺口/需求 | 类型 | 优先级 | 去向建议 |
|---|---|---|---|---|
| G1 | 书封占位橙色渐变违规 | 改造（代码级） | 高 | 单独重构任务：lib_select 封面换绿色系纯色 token（§3.1 规格），顺接 friendly name |
| G2 | 空状态无品牌化占位（~15 处裸文本 + NoDataGuide 灰图标） | 新组件 + 替换 | 高 | `BrandEmptyState` 任务；无需美术资产（线性图标方案） |
| G3 | 默认头像悬空资产 `assets/images/icon_user_none_*.png` | Bug 级缺口 | 高（接线前必修） | 首字母头像方案（§3.2-2），删除三条死路径而非补图 |
| G4 | 例句图明文 HTTP + 无缓存 + 无 loading | 技术债 | 中 | https 化 + 缓存层 + BrandImagePlaceholder |
| G5 | baseImgUrl 双处硬编码 | 技术债 | 低 | 集中配置，随手修 |
| G6 | 启动屏/引导缺品牌视觉 | 产品决策 | 中 | 由 branding_assets_plan 启动屏章节承接，无需新图片资产（纯色+logo 方案） |
| G7 | 真实书封网络图（DB cover 字段激活） | 产品决策 | 低（暂缓） | 除非产品要求；启用前置条件见 §四结论 |
| G8 | 空状态/引导插画资产 | 美术资产 | 低（可选） | 若 G2 线性图标方案被否，再议 House Green 线性 SVG 插画母版（1-2 张通用即可） |

**新增图片资产需求合计：0 张必做**。星巴克方向的图片策略是"做减法"：代码绘制的绿色几何占位 + 线性图标 + 排版，与 DESIGN.md 的极简语言一致；唯二可能的美术件（launcher icon 母版、可选插画）分别已在【重构27】Brief 和 G8 挂账。

---
*产出：IconPlanner · 2026-08-24 · 基于 lib/ 只读 grep 取证（10 类图片位逐一定位行号）与既有 DB 审计文档引用*
