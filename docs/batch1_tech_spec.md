# 【重构37】批1技术规格：亮度拆分 / 主题持久化 / 真·跟随系统

> 输入：dark_skin_strategy.md §1.2–§1.3 三项架构债 + 本文代码实证。
> 性质：**操作级实施规格**，所有改动点精确到 文件:行号；实施者按节施工，每节末有自检。
> 涉及文件仅 4 个：`lib/theme/skin_system.dart`、`lib/main.dart`、`lib/pages/appearance_page.dart`、`lib/data/app_preferences.dart`。

---

## 一、亮度语义拆分

### 1.1 现状证据链（statusBarBrightness 被当 ThemeData.brightness 用）

| # | 位置 | 内容 | 问题 |
|---|---|---|---|
| E1 | skin_system.dart:87 | `final Brightness statusBarBrightness;` | 字段语义 = **状态栏图标明暗** |
| E2 | skin_system.dart:98 / :120 / :145 | bright→`Brightness.dark`、深邃→`Brightness.light`、极夜→`Brightness.light` | 取值是反的（亮色皮肤配深色图标），证明它是状态栏语义 |
| E3 | **main.dart:89** | `brightness: skin.currentTheme.statusBarBrightness,` | ❌ 被当作 **整个 ThemeData 的亮度** |
| E4 | **main.dart:93** | `ColorScheme.fromSeed(..., brightness: skin.currentTheme.statusBarBrightness)` | ❌ 同上，污染整套 ColorScheme |

全库 grep 证实：`statusBarBrightness` 的消费点**只有 E3/E4 两处**；且全工程**没有任何** `SystemChrome.setSystemUIOverlayStyle` / `AnnotatedRegion<SystemUiOverlayStyle>` 调用——即这个名叫"状态栏"的字段**从未真正服务过状态栏**，名字与用途双重错位。

实际后果：明亮皮肤下 `ThemeData.brightness == Brightness.dark`，Material 组件（Switch 轨道、菜单、日期选择器、软键盘等）按暗色规范渲染，与浅色 pageBg 相互打架。

### 1.2 拆分设计

ThemePreset 拆成两个独立正交的语义字段：

```dart
// skin_system.dart:87 处替换为：
/// UI 亮度：驱动 ThemeData/ColorScheme（组件按亮或暗渲染）
final Brightness uiBrightness;
/// 状态栏图标明暗：仅供未来 SystemChrome/AnnotatedRegion 使用（本批不接线）
final Brightness statusBarBrightness;
```

各主题取值（skin_system.dart:96 `themes` 表内）：

| 主题 | uiBrightness（新） | statusBarBrightness（保留原值） |
|---|---|---|
| bright (:98) | **Brightness.light** | Brightness.dark |
| dark (:120) | **Brightness.dark** | Brightness.light |
| pure_black (:145) | **Brightness.dark** | Brightness.light |

### 1.3 迁移期双轨兼容写法

两字段并存、互不复用——**不存在过渡期引用混用**，因为消费点只有 2 个，一次性切换：

```dart
// main.dart:88-96 改后
theme: ThemeData(
  brightness: skin.effectiveUiBrightness,          // ← 原 statusBarBrightness（:89 改）
  scaffoldBackgroundColor: skin.colors.pageBg,
  colorScheme: ColorScheme.fromSeed(
    seedColor: skin.colors.accent,
    brightness: skin.effectiveUiBrightness,        // ← 同步改（:93 改）
  ),
  useMaterial3: true,
),
```

> `skin.effectiveUiBrightness` 是 SkinSystem 新增 getter（见 §3.2），迁移期实现为 `currentTheme.uiBrightness`，接入跟随系统后自动升级为"按系统亮度二选一"。这样 §1 与 §3 的改动一次到位，避免二次返工。

### 1.4 引用点改法清单（全量，共 6 处）

| 文件:行号 | 动作 |
|---|---|
| skin_system.dart:87 | 字段声明旁新增 `uiBrightness` 字段（statusBarBrightness 保留） |
| skin_system.dart:89 | 构造函数参数表加 `required this.uiBrightness` |
| skin_system.dart:98 | bright 预设补 `uiBrightness: Brightness.light,` |
| skin_system.dart:120 | dark 预设补 `uiBrightness: Brightness.dark,` |
| skin_system.dart:145 | pure_black 预设补 `uiBrightness: Brightness.dark,` |
| main.dart:89、:93 | 两处 `statusBarBrightness` → `effectiveUiBrightness` |

**自检**：改完后 `grep -r "statusBarBrightness" lib/` 应只剩 skin_system.dart 的声明+3 个赋值，main.dart 零命中。

---

## 二、主题持久化

### 2.1 现状

- skin_system.dart:172 `String _themeId = 'bright';` —— **硬编码初值，无任何读写**；
- 项目已有成熟存储设施：lib/data/app_preferences.dart:10-49 `BaseSharedPreferences` 封装 + :52 `AppPreferences` 单例（应用级配置，对应原版 sysData）；
- 注意陷阱：app_preferences.dart:65 已有 key `uiTheme = 'ui_theme'`，且 app_preferences_ext.dart:263-264 以 **int** 类型读写它（getUITheme/setUITheme）。若我们往同一 key 写 String，SharedPreferences 将出现类型冲突（读 int 得到异常）。**禁止复用该 key。**

### 2.2 选型裁定

| 方案 | 结论 |
|---|---|
| 直接用裸 `shared_preferences` 包（learning_state.dart:52 等处的散用风格） | ❌ 不采纳：散装 getInstance 是待治理的历史风格，新代码不再扩散 |
| ✅ **复用 `AppPreferences` 单例封装** | 项目规范入口（settings_page.dart:40 等新代码均已走它）；单例已建、init 模式现成；Windows/Android 双端由插件保证 |
| 复用旧 key `ui_theme` | ❌ int 类型冲突（见上），新建专用 key |

新增两个 key + 存取方法（加在 AppPreferences 类内，app_preferences.dart:76 `keyUserTrackEnable` 之后）：

```dart
static const String skinThemeId = 'skin_theme_id';         // 'bright'|'dark'|'pure_black'
static const String skinFollowSystem = 'skin_follow_system'; // bool

String getSkinThemeId() => getString(skinThemeId);           // 空=未设置
Future<bool> setSkinThemeId(String v) => setString(skinThemeId, v);
bool isSkinFollowSystem() => getBool(skinFollowSystem);
Future<bool> setSkinFollowSystem(bool v) => setBool(skinFollowSystem, v);
```

### 2.3 读写时机与默认值策略

**读（启动路径）**——main.dart:64-70 改造，runApp 前完成初始化，杜绝首帧闪白：

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WordBookDatabase.ensurePlatform();      // ← 原有 :66
  await WordBookDatabase.instance.initialize(); // ← 原有 :67
  await UserDatabase.instance.initialize();     // ← 原有 :68
  await AppPreferences().init();                // ← 新增：主题读取的前置依赖
  runApp(const WordApp());
}
```

**SkinSystem 初始化**（skin_system.dart:171-179 改造）：

```dart
class SkinSystem extends ChangeNotifier {
  SkinSystem() {
    final saved = AppPreferences().getSkinThemeId();
    _themeId = themes.containsKey(saved) ? saved : 'bright';   // 非法值兜底
    _followSystem = AppPreferences().isSkinFollowSystem();
  }
  String _themeId = 'bright';                    // :172 保留为兜底默认
  ...
}
```

**写时机**：`setTheme()`（:177-179）与新的 `setFollowSystem()` 在 notifyListeners 后 fire-and-forget 落盘（不 await，UI 不卡顿；写失败无碍下次启动兜底）。

**默认值策略**：首启（无存储记录）→ `_followSystem = false`？——否。产品语义"首启跟随系统"，故首启默认 `isSkinFollowSystem()==false` 时**不能**简单当 false：约定 **`getSkinThemeId()==''` 且从未写过 follow 标记 ⇒ 视为首启**，此时 effective 行为 = 跟随系统（见 §3.3 effectiveTheme 计算）。用户一旦手动选过主题，即脱离首启态，此后严格按存储值。

---

## 三、真·跟随系统开关

### 3.1 假开关现状

appearance_page.dart:255-262：

```dart
Switch(
  value: true,            // ← 写死 true
  onChanged: (v) {},      // ← 空实现
  ...
)
```

### 3.2 SkinSystem 接线设计（skin_system.dart）

新增成员与方法（插在 :173-175 getter 区之后）：

```dart
bool _followSystem = false;
bool get followSystem => _followSystem;

/// 当前系统亮度（监听刷新）
Brightness _systemBrightness = WidgetsBinding
    .instance.platformDispatcher.platformBrightness;

void setFollowSystem(bool v) {
  if (_followSystem == v) return;
  _followSystem = v;
  notifyListeners();
  AppPreferences().setSkinFollowSystem(v);            // fire-and-forget
}

void setTheme(String id) {                            // :177 原方法扩展
  if (!themes.containsKey(id)) return;
  _themeId = id;
  if (_followSystem) setFollowSystem(false);          // 手动选择即退出跟随
  notifyListeners();
  AppPreferences().setSkinThemeId(_themeId);          // ← 持久化落点
}

/// 权威计算：跟随系统时按系统亮度映射到 dark/pure_black 二选一
String get effectiveThemeId {
  if (!_followSystem) return _themeId;
  return _systemBrightness == Brightness.dark ? 'pure_black' : 'bright';
}

Brightness get effectiveUiBrightness =>
    themes[effectiveThemeId]!.uiBrightness;           // §1.3 的消费源

/// 系统亮度变化回调（由 WordApp State 触发）
void updateSystemBrightness(Brightness b) {
  if (_systemBrightness == b) return;
  _systemBrightness = b;
  if (_followSystem) notifyListeners();
}
```

### 3.3 数据流图

```
┌─────────────────────────── 启动 ───────────────────────────┐
main(): AppPreferences.init()
        └─► SkinSystem() 构造读盘 ─► _themeId/_followSystem 就位
                                    └─► effectiveThemeId/effectiveUiBrightness 可算
┌─────────────────────────── 运行期 ──────────────────────────┐
[系统深色切换]
 platformDispatcher.onPlatformBrightnessChanged ──► updateSystemBrightness(b)
                                                        │ (仅 followSystem=true 才广播)
                                                        ▼
                                              notifyListeners()
                                                        │
              ┌─────────────────────────────────────────┤
              ▼                                         ▼
   main.dart Consumer<SkinSystem>               AppearancePage(context.skin)
   theme.brightness = effectiveUiBrightness     开关 value=followSystem 重绘
   colorScheme/fromSeed 同步刷新                 圆圈选中态切到 effectiveThemeId
              │
              ▼
   MaterialApp 整体换肤（含 Scaffold/组件/ColorScheme）

[用户手动选主题] appearance_page.dart:207 setTheme(id)
   └─► 退出跟随(_followSystem=false)+落盘 ─► notifyListeners ─► 同上重绘
[用户拨动开关] appearance_page.dart Switch.onChanged ─► setFollowSystem(v)
   └─► 落盘 ─► notifyListeners ─► 立即按 effectiveThemeId 重绘
```

### 3.4 监听器挂载与拆除（生命周期正确性）

SkinSystem 不是 Widget，不能混入 WidgetsBindingObserver。在 main.dart 给 WordApp 加一个内部 State 承担监听：

```dart
class WordApp extends StatefulWidget { ... }          // :72 Stateless→Stateful
class _WordAppState extends State<WordApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
        () => context.read<SkinSystem>()               // provider 可用
              .updateSystemBrightness(
                  WidgetsBinding.instance.platformDispatcher.platformBrightness);
  }
  @override
  void didChangePlatformBrightness() {                 // 双保险（部分平台只走这里）
    context.read<SkinSystem>().updateSystemBrightness(
        WidgetsBinding.instance.platformDispatcher.platformBrightness);
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged = null;
    super.dispose();
  }
  @override
  Widget build(BuildContext context) { /* 原 :77-137 的 MultiProvider 树 */ }
}
```

### 3.5 外观页开关改造

appearance_page.dart:255-257 替换为：

```dart
Switch(
  value: skin.followSystem,                            // ← 真·状态
  onChanged: (v) => skin.setFollowSystem(v),
  ...                                                  // :258-261 配色不动（批2再治硬编码色）
)
```

同时建议（可选，同批顺手）：`:205 isSelected` 判断从 `skin.themeId == preset.id` 改为 `skin.effectiveThemeId == preset.id`，跟随系统时圆圈选中态反映实际生效皮肤。

### 3.6 main.dart themeMode 说明

本方案**不引入** `MaterialApp.darkTheme + ThemeMode`：三皮肤的暗色（dark/pure_black）是自定义 vars 全量配色，不是标准 Material darkTheme 能表达的；继续走单一 `theme:` + `Consumer` 整体重建（现有架构），`effectiveUiBrightness` 已能正确驱动 ColorScheme。此决策写入代码注释，防止后人画蛇添足。

---

## 四、验收标准（可测三条）

| # | 验收项 | 操作步骤 | 通过判据 |
|---|---|---|---|
| A1 | **持久化** | 设置页选「极夜」→ 杀进程 → 冷启动 | 启动即为极夜皮肤；`grep` 确认 SharedPreferences 中 `skin_theme_id=pure_black`；再选「明亮」重复一次同样成立 |
| A2 | **跟随系统响应** | 打开「跟随系统」开关 → 在系统设置里切换深色/浅色 | 应用 **1s 内**整体换肤（Scaffold 背景+组件+ColorScheme 一致），无需重启；切回手动模式后再切系统深浅，应用纹丝不动 |
| A3 | **语义正确性** | 分别停在 明亮/深邃/极夜 三皮肤 | 明亮下 `ThemeData.brightness==light`（Switch/弹窗等 M3 组件呈浅色规范）、深邃/极夜下 ==dark；状态栏图标颜色不受影响仍按 statusBarBrightness 语义（本批仅验证无回归，接线属后续批次） |

附加回归面：外观页圆圈选中态、主题切换动画无闪烁（首启不闪白——由 §2.3 启动前读盘保证）。

---

## 五、工时估算与风险点

### 5.1 工时（净编码 + 自测）

| 子任务 | 估时 |
|---|---|
| §1 亮度拆分（6 处改动 + 编译修复） | 0.5h |
| §2 持久化（AppPreferences 扩展 + main/SkinSystem 初始化 + 首启策略） | 1.5h |
| §3 跟随系统（SkinSystem 状态机 + WordApp 监听 + 外观页开关） | 2h |
| §4 三条验收实测（Windows + Android 各跑一遍） | 1h |
| 缓冲（平台差异调试，尤其 Windows 亮度监听行为） | 1h |
| **合计** | **约 0.75 人日** |

### 5.2 风险点

| # | 风险 | 缓解 |
|---|---|---|
| R1 | **ui_theme 键类型冲突**：误往 `'ui_theme'` 写 String 会炸掉 ext 层 getInt（app_preferences_ext.dart:263） | 本规格已定新键 `skin_theme_id`；评审时重点盯这一条 |
| R2 | **首帧闪白**：若 SkinSystem 读盘晚于首帧 | 读盘放 main() await 段（§2.3），构造函数同步取缓存值；禁止在 build 里异步 setState 补救 |
| R3 | **onPlatformBrightnessChanged 平台差异**：桌面端 Windows 上触发时机与移动端不完全一致，可能只走 didChangePlatformBrightness | §3.4 双通道挂接（dispatcher 回调 + observer 回调），任一到达都幂等更新 |
| R4 | **effectiveThemeId 与 _themeId 心智分裂**：跟随模式下用户看到的"当前皮肤"≠存储值 | 外观页选中态一律显示 effective（§3.5）；setTheme 即刻退出跟随，两者只在跟随态短暂共存，注释已说明 |
| R5 | 手动选主题时序 bug：setTheme 内先置 _followSystem=false 再落盘，两次写盘竞争 | 顺序执行无并发入口（UI 单线程），fire-and-forget 写同 key 无需事务；测试覆盖 A1/A2 交叉场景 |
| R6 | 批2 会大规模治理硬编码色，本批在 appearance_page 只动开关不动颜色，避免合并冲突扩大 | 改动范围锁死 §1.4 清单 + §3.5，勿越界顺手改色 |

*制定人：BuildScout（【重构37】）· 2026-08-24 · 基于 commit 实测行号，若批1开工前主干有前置合码请先校准偏移*
