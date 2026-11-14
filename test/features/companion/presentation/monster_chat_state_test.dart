// 学习伴侣 AI 化 · 聊天状态单测。
// fake LLM 往返/不耗主动预算/记忆沉淀/历史与清空/空输入忽略。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/core/application/llm_client.dart';
import 'package:word_app/core/application/monster_memory_curator.dart';
import 'package:word_app/core/application/monster_memory_port.dart';
import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/features/companion/presentation/monster_chat_state.dart';

class _FakeLlm implements LlmClient {
  _FakeLlm({this.reply = '喵~收到', this.fail = false});
  final String reply;
  final bool fail;
  List<LlmMessage>? lastMessages;
  @override
  bool get isLive => true;
  @override
  Future<String> complete(List<LlmMessage> messages) async {
    lastMessages = messages;
    if (fail) throw const LlmException('fake fail');
    return reply;
  }
}

/// 内存记忆端口（不触 DB，验证沉淀调用）。
class _FakeMemory implements MonsterMemoryPort {
  final Map<String, MemoryEntry> store = {};
  @override
  Future<void> put(MemoryKind kind, String key, String content) async {
    store['${kind.name}:$key'] = MemoryEntry(kind: kind, key: key, content: content, updatedAt: 0);
  }

  @override
  Future<List<MemoryEntry>> read(MemoryKind kind) async => store.values.where((e) => e.kind == kind).toList();

  @override
  Future<MemoryEntry?> get(MemoryKind kind, String key) async => store['${kind.name}:$key'];

  @override
  Future<void> remove(MemoryKind kind, String key) async => store.remove('${kind.name}:$key');

  @override
  Future<void> trimRecent(int limit) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MonsterSpeech.resetForTest();
  });

  test('send 往返：用户+助手入历史，返回回复', () async {
    final llm = _FakeLlm(reply: '一起加油喵~');
    final state = MonsterChatState(llm: llm, memory: MonsterMemoryCurator(_FakeMemory()));
    final reply = await state.send('你好');
    expect(reply, '一起加油喵~');
    expect(state.history.length, 2);
    expect(state.history.first.role, LlmRole.user);
    expect(state.history.last.role, LlmRole.assistant);
    expect(state.busy, isFalse);
  });

  test('system prompt 含性格人设与红线', () async {
    final llm = _FakeLlm();
    final state = MonsterChatState(llm: llm, memory: MonsterMemoryCurator(_FakeMemory()));
    await state.send('hi');
    final system = llm.lastMessages!.first;
    expect(system.role, LlmRole.system);
    expect(system.content, contains('小怪兽'));
    expect(system.content, contains('不指责'));
  });

  test('对话不消耗每日主动预算', () async {
    final speech = MonsterSpeech();
    final before = speech.canSpeak();
    final state = MonsterChatState(llm: _FakeLlm(), memory: MonsterMemoryCurator(_FakeMemory()));
    await state.send('你好');
    await state.send('再来');
    expect(speech.canSpeak(), before, reason: '聊天不耗主动预算');
  });

  test('用户消息沉淀近期层记忆', () async {
    final mem = _FakeMemory();
    final state = MonsterChatState(llm: _FakeLlm(), memory: MonsterMemoryCurator(mem));
    await state.send('我喜欢猫');
    final recent = await mem.read(MemoryKind.recent);
    expect(recent.any((e) => e.content.contains('我喜欢猫')), isTrue);
  });

  test('LLM 失败外抛 LlmException，busy 复位', () async {
    final state = MonsterChatState(llm: _FakeLlm(fail: true), memory: MonsterMemoryCurator(_FakeMemory()));
    await expectLater(state.send('hi'), throwsA(isA<LlmException>()));
    expect(state.busy, isFalse);
  });

  test('空输入忽略，clear 清空历史', () async {
    final state = MonsterChatState(llm: _FakeLlm(), memory: MonsterMemoryCurator(_FakeMemory()));
    await state.send('   ');
    expect(state.history, isEmpty);
    await state.send('你好');
    expect(state.history.length, 2);
    state.clear();
    expect(state.history, isEmpty);
  });
}
