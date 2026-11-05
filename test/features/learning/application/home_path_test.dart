// 今日路线纯函数：三态节点、当前步骤、封顶与脏数据。
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/application/home_path.dart';

void main() {
  group('buildHomePathNodes', () {
    test('空数据：只有热身是当前，其余待解锁', () {
      final nodes = buildHomePathNodes(goal: 10, learned: 0, due: 5);

      expect(nodes, hasLength(4));
      expect(nodes[0].status, HomePathNodeStatus.current);
      expect(nodes[1].status, HomePathNodeStatus.upcoming);
      expect(nodes[2].status, HomePathNodeStatus.upcoming);
      expect(nodes[3].status, HomePathNodeStatus.upcoming);
      expect(nodes[1].detail, '还差 10 个');
      expect(nodes[2].detail, '待复习 5 个');
      expect(nodes.first.label, '热身 3 词');
      expect(homePathCurrentStep(nodes), 1);
    });

    test('部分完成：学完热身 → 新词变当前；没有到期 → 复习已完成', () {
      final nodes = buildHomePathNodes(goal: 10, learned: 3, due: 0);

      expect(nodes[0].status, HomePathNodeStatus.done);
      expect(nodes[1].status, HomePathNodeStatus.current);
      expect(nodes[2].status, HomePathNodeStatus.done);
      expect(nodes[3].status, HomePathNodeStatus.upcoming);
      expect(nodes[1].detail, '还差 7 个');
      expect(nodes[2].detail, '今天没有到期词');
      expect(homePathCurrentStep(nodes), 2);
    });

    test('全部完成：无当前节点，宝箱打勾', () {
      final nodes = buildHomePathNodes(goal: 10, learned: 10, due: 0);

      expect(nodes.every((node) => node.status == HomePathNodeStatus.done), isTrue);
      expect(nodes[3].detail, '今日路线已走完');
      expect(homePathCurrentStep(nodes), isNull);
    });

    test('未设目标：不制造「还差 0 个」伪任务，但目标节点仍算完成', () {
      final nodes = buildHomePathNodes(goal: 0, learned: 3, due: 0);

      expect(nodes[1].status, HomePathNodeStatus.done);
      expect(nodes[1].detail, '未设置目标');
      expect(nodes.every((node) => node.status == HomePathNodeStatus.done), isTrue);
    });

    test('脏数据兜底：负数不影响状态，时长至少 1 分钟', () {
      final nodes = buildHomePathNodes(goal: -5, learned: -1, due: -2);

      expect(nodes, hasLength(4));
      for (final node in nodes) {
        expect(node.minutes, greaterThanOrEqualTo(1));
      }
      expect(nodes[0].status, HomePathNodeStatus.current, reason: '热身未做仍是当前');
    });
  });

  group('开关默认值', () {
    test('kPathHome 默认关闭（灰度）', () {
      expect(kPathHome, isFalse);
    });
  });
}
