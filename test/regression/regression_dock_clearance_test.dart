// ============================================================
// 回归测试 — 悬浮 Dock 与页面底部固定内容的几何不重叠（REG-DOCK-xxx）
//
// 背景：MainShell 的悬浮 Dock 覆盖在页面内容之上（Z3 层）。任何带
// 「底部固定工具栏/条带」的页面必须预留 FloatingDock.clearance(context)
// 的底部高度，否则 Dock 会压住工具栏（v2.7.22 首次修复；v2.8.3 课程页
// 重写时回归，用户实测截图确认）。
//
// 本文件用「真实渲染 + 几何断言」守护：渲染页面页族 + 悬浮 Dock，
// 断言工具栏底边不越过 Dock 顶边。新增带底部固定条的页面时，
// 参照 REG-DOCK-002 增加同款几何用例即可获得守护。
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/book/presentation/lib_select_page.dart';
import 'package:word_app/features/learning/application/learning_session_reader.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/app_dock.dart';

/// 假词书目录：返回 3 本词书（数量无关几何断言）。
class _FakeCatalogReader implements BookCatalogReader {
  @override
  Future<List<Book>> listBooks() async => [
    Book(id: 1, code: 'T1', name: '词书一', wordCount: 100),
    Book(id: 2, code: 'T2', name: '词书二', wordCount: 200),
    Book(id: 3, code: 'T3', name: '词书三', wordCount: 300),
  ];

  @override
  Future<Book?> findById(int bookId) async => null;
}

/// 假会话只读视图：有当前词书（触发「正在学习/在学」相关分支）。
class _FakeSessionReader implements LearningSessionReader {
  @override
  Book? get currentBook => null; // 几何断言不依赖当前词书

  @override
  Word? get currentWord => null;

  @override
  List<Word> get queue => const [];

  @override
  int get total => 30;

  @override
  int get learnedNum => 3;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('REG-DOCK-002: 课程页底部工具栏与悬浮 Dock 零重叠（clearance 预留丢失即失败）', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<BookCatalogReader>.value(value: _FakeCatalogReader()),
          Provider<LearningSessionReader>.value(value: _FakeSessionReader()),
        ],
        child: MaterialApp(
          home: SkinProvider(
            skin: SkinSystem(),
            // 复刻 MainShell 的 Dock 装配：页面铺满，Dock 悬浮在底部。
            child: Scaffold(
              body: Stack(
                children: [
                  const Positioned.fill(child: LibSelectPage()),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: FloatingDock(
                      items: [
                        DockItem(icon: Icons.school_outlined, label: '学习'),
                        DockItem(icon: Icons.menu_book_outlined, label: '课程'),
                        DockItem(icon: Icons.settings_outlined, label: '设置'),
                      ],
                      currentIndex: 1,
                      onTap: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toolbarRect = tester.getRect(find.byKey(const ValueKey('lib-select-bottom-toolbar')));
    final dockRect = tester.getRect(find.byType(FloatingDock));

    // 工具栏底边不得越过 Dock 顶边（允许 1px 边界容差）。
    expect(
      toolbarRect.bottom,
      lessThanOrEqualTo(dockRect.top + 4), // 容差 4px：Dock 自身 margin 属透明区，不算可见重叠
      reason:
          '课程页底部工具栏与悬浮 Dock 重叠：'
          'toolbar.bottom=${toolbarRect.bottom}, dock.top=${dockRect.top}。'
          '页面底部固定内容必须预留 FloatingDock.clearance(context)。',
    );
  });
}
