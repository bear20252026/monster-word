// 学习伴侣 AI 化 · 主动陪伴 LLM 增强单测。
// 未配置/规则版行为等同现状；真实客户端异步替换台词；失败保留规则；序号防过期；预算不重扣。
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/application/llm_client.dart';
import 'package:word_app/core/application/monster_memory_curator.dart';
import 'package:word_app/core/application/monster_memory_port.dart';
import 'package:word_app/core/utils/monster_initiative.dart';
import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/features/companion/presentation/monster_companion_state.dart';

class _FakeLlm implements LlmClient {
  _FakeLlm({this.reply = 'LLM个性化台词', this.fail = false, this.live = true, this.delay = Duration.zero});
  final String reply;
  final bool fail;
  final bool live;
  final Duration delay;
  int calls = 0;
  @override
  bool get isLive => live;
  @override
  Future<String> complete(List<LlmMessage> messages) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (fail) throw const LlmException('fake fail');
    return reply;
  }
}

class _FakeMemory implements MonsterMemoryPort {
  @override
  Future<void> put(MemoryKind kind, String key, String content) async {}
  @override
  Future<List<MemoryEntry>> read(MemoryKind kind) async => const [];
  @override
  Future<MemoryEntry?> get(MemoryKind kind, String key) async => null;
  @override
  Future<void> remove(MemoryKind kind, String key) async {}
  @override
  Future<void> trimRecent(int limit) async {}
}

void main() {
  setUp(MonsterSpeech.resetForTest);
  tearDown(MonsterSpeech.resetForTest);

  /// needReview 渲染后的模板集（{due}→25），供「台词来自模板」断言。
  Set<String> renderedReview() =>
      MonsterSpeech.templatesOf(SpeechSlot.needReview).map((t) => t.replaceAll('{due}', '25')).toSet();

  test('未配置 LLM：台词来自模板集，行为等同现状', () {
    final state = MonsterCompanionState();
    state.refreshInitiative(const MonsterInitiativeInput(dueCount: 25));
    expect(renderedReview(), contains(state.line));
  });

  test('规则版 LLM（isLive=false）：不触发增强，台词来自模板', () async {
    final llm = _FakeLlm(live: false);
    final state = MonsterCompanionState(llm: llm, memory: MonsterMemoryCurator(_FakeMemory()));
    state.refreshInitiative(const MonsterInitiativeInput(dueCount: 25));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(llm.calls, 0, reason: '规则版不触发 LLM 调用');
    expect(renderedReview(), contains(state.line));
  });

  test('真实 LLM：先给规则台词，异步替换为个性化台词', () async {
    final llm = _FakeLlm(reply: '复习一下好不好喵~');
    final state = MonsterCompanionState(llm: llm, memory: MonsterMemoryCurator(_FakeMemory()));
    state.refreshInitiative(const MonsterInitiativeInput(dueCount: 25));
    // 同步先给规则台词
    expect(renderedReview(), contains(state.line));
    // 异步增强完成后替换
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(state.line, '复习一下好不好喵~');
    expect(llm.calls, 1);
  });

  test('LLM 失败：保留规则台词', () async {
    final llm = _FakeLlm(fail: true);
    final state = MonsterCompanionState(llm: llm, memory: MonsterMemoryCurator(_FakeMemory()));
    state.refreshInitiative(const MonsterInitiativeInput(dueCount: 25));
    final ruleLine = state.line;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(state.line, ruleLine, reason: '失败保留规则台词');
  });

  test('序号防过期：增强途中清空建议，过期回复不覆盖', () async {
    final llm = _FakeLlm(reply: '过期回复', delay: const Duration(milliseconds: 30));
    final state = MonsterCompanionState(llm: llm, memory: MonsterMemoryCurator(_FakeMemory()));
    state.refreshInitiative(const MonsterInitiativeInput(dueCount: 25));
    // 增强在途时清空建议（序号递增）
    state.refreshInitiative(const MonsterInitiativeInput(dueCount: 0));
    expect(state.line, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(state.line, isNull, reason: '过期回复不得覆盖已清空的气泡');
  });

  test('LLM 增强不重复消耗预算（每日≤3）', () async {
    final llm = _FakeLlm();
    final state = MonsterCompanionState(llm: llm, memory: MonsterMemoryCurator(_FakeMemory()));
    final lines = <String?>[];
    for (var i = 0; i < 4; i++) {
      state.refreshInitiative(const MonsterInitiativeInput(dueCount: 25));
      lines.add(state.line);
      state.refreshInitiative(const MonsterInitiativeInput(dueCount: 0));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(lines[0], isNotNull);
    expect(lines[1], isNotNull);
    expect(lines[2], isNotNull);
    expect(lines[3], isNull, reason: '第4次预算用尽不再开口，增强不重扣');
  });
}
