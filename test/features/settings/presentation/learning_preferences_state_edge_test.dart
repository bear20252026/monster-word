// P2-14（架构审计 2026-11-12）：LearningPreferencesState 失败分支补测。
// 原 learning_preferences_test 只测 domain copyWith；此处补状态类：
// initialize 加载失败记录 loadError、复位 isLoading、保留默认值；
// _update 在 writer 抛错时先更新状态再吞错（界面不回滚）、identical 短路不写。
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/settings/application/settings_reader.dart';
import 'package:word_app/features/settings/application/settings_writer.dart';
import 'package:word_app/features/settings/domain/learning_preferences.dart';
import 'package:word_app/features/settings/presentation/learning_preferences_state.dart';

class _FakeReader implements SettingsReader {
  _FakeReader({this.result, this.error});
  LearningPreferences? result;
  Object? error;
  int loadCalls = 0;

  @override
  Future<LearningPreferences> load() async {
    loadCalls++;
    if (error != null) throw error!;
    return result ?? const LearningPreferences.defaults();
  }
}

class _FakeWriter implements SettingsWriter {
  _FakeWriter({this.throwError = false});
  final bool throwError;
  final List<LearningPreferences> saved = [];

  @override
  Future<void> save(LearningPreferences preferences) async {
    if (throwError) throw StateError('save boom');
    saved.add(preferences);
  }
}

void main() {
  group('initialize', () {
    test('加载成功：复位 isLoading、清 loadError、采纳读取值', () async {
      final reader = _FakeReader(result: const LearningPreferences.defaults().copyWith(learnPace: 42));
      final state = LearningPreferencesState(reader: reader, writer: _FakeWriter());

      await state.initialize();

      expect(state.isLoading, isFalse);
      expect(state.loadError, isNull);
      expect(state.learnPace, 42);
    });

    test('加载失败：记录 loadError、复位 isLoading、保留默认值', () async {
      final reader = _FakeReader(error: StateError('load boom'));
      final state = LearningPreferencesState(reader: reader, writer: _FakeWriter());

      await state.initialize();

      expect(state.isLoading, isFalse);
      expect(state.loadError, isNotNull);
      expect(state.loadError.toString(), contains('load boom'));
      expect(state.learnPace, const LearningPreferences.defaults().learnPace, reason: '失败保留默认值');
    });

    test('失败后重试成功：loadError 清空、采纳新值', () async {
      final reader = _FakeReader(error: StateError('load boom'));
      final state = LearningPreferencesState(reader: reader, writer: _FakeWriter());
      await state.initialize();
      expect(state.loadError, isNotNull);

      reader.error = null;
      reader.result = const LearningPreferences.defaults().copyWith(learnPace: 7);
      await state.initialize();

      expect(state.loadError, isNull);
      expect(state.learnPace, 7);
    });
  });

  group('_update 写路径', () {
    test('writer 抛错时状态先更新再吞错，界面不回滚', () async {
      final writer = _FakeWriter(throwError: true);
      final state = LearningPreferencesState(reader: _FakeReader(), writer: writer);
      await state.initialize();

      await state.setLearnPace(99);

      expect(state.learnPace, 99, reason: '状态已更新，不因写失败回滚');
      expect(writer.saved, isEmpty, reason: '抛错时未落盘');
    });

    test('正常写入落盘一次', () async {
      final writer = _FakeWriter();
      final state = LearningPreferencesState(reader: _FakeReader(), writer: writer);
      await state.initialize();

      await state.setLearnPace(15);

      expect(state.learnPace, 15);
      expect(writer.saved, hasLength(1));
      expect(writer.saved.single.learnPace, 15);
    });

    test('同值设置仍经 copyWith 生成新实例并写入（短路仅对同一实例生效）', () async {
      final writer = _FakeWriter();
      final state = LearningPreferencesState(reader: _FakeReader(), writer: writer);
      await state.initialize();
      final pace = state.learnPace;

      // copyWith 总返回新实例（非 const），故 identical 短路对公开 setter 不可达；
      // 同值设置仍会落盘一次——如实记录该行为，避免对不可达分支硬凑断言。
      await state.setLearnPace(pace);

      expect(state.learnPace, pace);
      expect(writer.saved, hasLength(1));
    });
  });
}
