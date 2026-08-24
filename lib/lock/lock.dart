// 由 Claude 团队生成 | 锁屏学习模块 barrel 文件
// 移植自 v3.2 lock/ 包

/// 锁屏学习模块
///
/// 核心功能：在手机锁屏界面显示单词卡片，支持滑动、翻页等交互。
///
/// 架构说明：
/// - [LockPresenter] / [LockPresenterImp] - 业务逻辑层（MVP Presenter）
/// - [LockView] - 视图接口（MVP View）
/// - [LockScreenPage] - 锁屏主界面（Flutter Widget）
/// - [LockService] - Platform Channel 接口
/// - [ScrollTopBottomLayout] - 上下滚动交互组件
///
/// 使用方式：
/// ```dart
/// import 'package:word_app/lock/lock.dart';
///
/// // 显示锁屏
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const LockScreenPage(),
/// ));
/// ```
library lock;

// 核心接口
export 'lock_presenter.dart';
export 'lock_view.dart';

// 核心实现
export 'lock_presenter_imp.dart';
export 'lock_screen_page.dart';

// 服务
export 'lock_service.dart';

// 工具类
export 'date_time_constants.dart';
export 'number_utils.dart';
export 'view_dimens.dart';
export 'spring_interpolator.dart';
export 'my_element_animator.dart';
export 'lock_webview_cache.dart';

// 视图组件
export 'view/down_callback.dart';
export 'view/scroll_top_bottom_layout.dart';
export 'view/line_indicator.dart';
