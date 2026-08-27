/// 正式复习展示组件的兼容聚合入口。
///
/// 具体实现按布局、顶部操作、题目控件、候选卡片和状态视图拆分为独立文件；
/// 页面可继续只依赖本入口，避免展示层的内部文件结构泄漏到路由协调层。
library;

export 'formal_review_choice_card.dart';
export 'formal_review_header.dart';
export 'formal_review_question.dart';
export 'formal_review_session_layout.dart';
export 'formal_review_state_views.dart';
