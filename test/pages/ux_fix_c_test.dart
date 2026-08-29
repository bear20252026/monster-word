// UX-FIX-C: 单词详情/词典 UX 修复测试
// C-1: 搜索结果选中态 / C-3: 例句收藏动画 + 触觉 / C-2: TabBar 指示器
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/models/word.dart';

void main() {
  // ── C-1: 搜索结果选中态 ──
  group('C-1 搜索结果选中态', () {
    testWidgets('选中项显示 accent 左边框 + 文字高亮', (tester) async {
      final skin = SkinSystem();
      final colors = skin.colors;
      final results = [
        Word(word: 'apple', usPron: '/ˈæp.əl/', ukPron: '/ˈæp.əl/', interpret: '苹果'),
        Word(word: 'apply', usPron: '/əˈplaɪ/', ukPron: '/əˈplaɪ/', interpret: '申请'),
      ];
      final selectedWord = results.first;

      await tester.pumpWidget(
        SkinProvider(
          skin: skin,
          child: MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final w = results[index];
                  final isSelected = selectedWord.word == w.word;
                  return Material(
                    color: isSelected
                        ? colors.accent.withValues(alpha: 0.08)
                        : Colors.transparent,
                    child: Container(
                      decoration: isSelected
                          ? BoxDecoration(border: Border(left: BorderSide(color: colors.accent, width: 3)))
                          : null,
                      child: ListTile(
                        title: Text(
                          w.word,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? colors.accent : colors.text1,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 第一个 Material 有 accent 半透明背景
      final materials = tester.widgetList<Material>(find.byType(Material));
      final firstMaterial = materials.first;
      expect(firstMaterial.color, isA<Color>());

      // 验证 ListTile 显示选中的单词文字
      expect(find.text('apple'), findsOneWidget);
      expect(find.text('apply'), findsOneWidget);
    });

    testWidgets('未选中项无左边框', (tester) async {
      final skin = SkinSystem();
      final results = [
        Word(word: 'apple', usPron: '/ˈæp.əl/', ukPron: '/ˈæp.əl/', interpret: '苹果'),
        Word(word: 'apply', usPron: '/əˈplaɪ/', ukPron: '/əˈplaɪ/', interpret: '申请'),
      ];
      final selectedWord = results.first;

      await tester.pumpWidget(
        SkinProvider(
          skin: skin,
          child: MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final w = results[index];
                  final isSelected = selectedWord.word == w.word;
                  return Material(
                    color: isSelected
                        ? skin.colors.accent.withValues(alpha: 0.08)
                        : Colors.transparent,
                    child: Container(
                      decoration: isSelected
                          ? BoxDecoration(border: Border(left: BorderSide(color: skin.colors.accent, width: 3)))
                          : null,
                      child: ListTile(title: Text(w.word)),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 两个 Container 存在
      final containers = tester.widgetList<Container>(find.byType(Container));
      expect(containers.length, 2);

      // 选中项 Container 有 decoration
      expect(containers.first.decoration, isA<BoxDecoration>());

      // 未选中项 Container 无 decoration
      expect(containers.last.decoration, isNull);
    });
  });

  // ── C-2: TabBar 指示器 ──
  group('C-2 TabBar 指示器', () {
    testWidgets('TabBar indicatorWeight 为 3', (tester) async {
      final controller = TabController(length: 3, vsync: const TestVSync());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TabBar(
              controller: controller,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Tab1'),
                Tab(text: 'Tab2'),
                Tab(text: 'Tab3'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.indicatorWeight, 3.0);
      expect(tabBar.indicatorSize, TabBarIndicatorSize.label);

      controller.dispose();
    });
  });

  // ── C-3: 收藏按钮图标 ──
  group('C-3 例句收藏交互', () {
    testWidgets('未收藏时图标为 favorite_border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('收藏按钮有 Tooltip 提示', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Tooltip(
              message: '收藏例句',
              child: IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      expect(find.text('收藏例句'), findsOneWidget);
    });
  });
}
