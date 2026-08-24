// 由 Claude 团队生成 | Monster Word App

// 工具层统一导出
// 翻译自 v3.2 cn.com.langeasy.LangEasyLexis.util 包（50个类）

// ==================== 核心工具 ====================
// 翻译自: SecurityUtils.java, StrUtils.java, Tools.java, PronounceUtils.java
export 'app_utils.dart';

// ==================== 加密/安全 ====================
// 翻译自: SecurityUtils.java (DES/MD5), SHA1.java, WDTransAction.java
export 'crypto_utils.dart' hide CodeDeal;

// ==================== 数据处理 ====================
// 翻译自: GsonUtils.java, WordTokenizer.java, FileUtils.java
export 'data_utils.dart';

// ==================== 日期时间 ====================
// 翻译自: DateUtils.java (完整版)
export 'date_utils.dart';

// ==================== 文件系统 ====================
// 翻译自: LexisFileSystem.java, ZpkUtils.java (路径部分)
export 'file_system_utils.dart';

// ==================== 网络 ====================
// 翻译自: NetworkUtils.java
export 'network_utils.dart';

// ==================== 屏幕 ====================
// 翻译自: ScreenUtils.java
export 'screen_utils.dart';

// ==================== 移植状态 ====================
// 以下 util 类已完整移植:
//   [✓] SecurityUtils    → app_utils.dart + crypto_utils.dart
//   [✓] StrUtils         → app_utils.dart
//   [✓] DateUtils        → date_utils.dart
//   [✓] Tools            → app_utils.dart (核心方法)
//   [✓] SHA1             → crypto_utils.dart
//   [✓] WDTransAction    → crypto_utils.dart
//   [✓] CodeDeal         → app_utils.dart + crypto_utils.dart
//   [✓] GsonUtils        → data_utils.dart
//   [✓] FileUtils        → data_utils.dart
//   [✓] WordTokenizer    → data_utils.dart
//   [✓] NetworkUtils     → network_utils.dart
//   [✓] ScreenUtils      → screen_utils.dart
//   [✓] LexisFileSystem  → file_system_utils.dart
//   [✓] PronounceUtils   → app_utils.dart
//   [✓] ZpkUtils (路径)  → file_system_utils.dart
//
// 以下 util 类需要在业务层按需实现:
//   [ ] ZpkUtils (下载/解密逻辑) → 需要 webservice + protobuf 依赖
//   [ ] SecurePreferences → 用 flutter_secure_storage 包
//   [ ] ThreadPool → 用 Dart Isolate / compute
//   [ ] WeakHandler → 用 Timer + WeakReference 或省略
//   [ ] StatisticUtils → 用 Flutter analytics SDK (友盟等)
//   [ ] LoginUtils → 需要 webservice 层
//   [ ] TransActionHelper → 需要业务层 (widget/webservice/database)
//   [ ] ImageUtils → 用 Flutter Image widget + cached_network_image
//   [ ] AnimUtils → 用 Flutter AnimationController
//   [ ] AudioUtils → 用 audioplayers 包
//   [ ] DialogUtils → 用 Flutter showDialog
//   [ ] ToastUtils → 用 fluttertoast 包
//   [ ] KeyboardListener → 用 Flutter FocusNode
//   [ ] ScreenUtils (完整) → 用 MediaQuery
//   [ ] LocalUserInfoUtils → 需要 SharedPreferences
//   [ ] MarketUtils → 需要 url_launcher
//   [ ] ProcessUtils → Dart 不需要
//   [ ] MigrateUtils / Migrate2V3Util → 数据库迁移，按需实现
//   [ ] BBBackgroundUtil → 需要 widget 层
//   [ ] CalendarReminderUtils → 需要 platform channel
//   [ ] CMCCAuthUtils / HMSAuthUtils / UmengAuthUtils → 第三方 SDK，按需
//   [ ] ShareHelper → 需要 share_plus 包
//   [ ] SplashAnimation → 需要 widget 层
//   [ ] Log / LogHelper → 用 logger 包
//   [ ] SafeDialog → 需要 widget 层
//   [ ] ABTestUtils → 空实现，不需要
//   [ ] GlobalBitmapCache → 用 Flutter 缓存机制
//   [ ] ListViewDragUtil → 用 Flutter ReorderableListView
//   [ ] OpenActivityUtils → Flutter 路由
//   [ ] LRCustomeDialogUtils → 需要 widget 层
//   [ ] TextLayoutUtil → 用 Flutter TextPainter
//   [ ] UserActionRecordUtils → 需要数据库层
//   [ ] WDTransAction (完整) → crypto_utils.dart
//   [ ] PremireLogoUtils → 需要 widget 层
//   [ ] Crop → 用 image 包
