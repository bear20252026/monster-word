// 设置页：学习偏好 + 7 个底部弹窗交互
// 已接入 SkinSystem 主题 — 所有颜色使用 context.skin.colors
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/router/nav_utils.dart';
import 'package:word_app/core/router/route_names.dart';
import 'package:word_app/tokens/design_language.dart';
import 'package:word_app/features/settings/application/study_reminder_service.dart';
import 'package:word_app/features/settings/domain/learning_preferences.dart';
import 'package:word_app/features/settings/presentation/learning_preferences_state.dart';
import 'package:word_app/features/settings/presentation/settings_bottom_sheet.dart';
import 'package:word_app/features/settings/presentation/study_reminder_sheet.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.reminderServiceOverride});

  static const routeName = '/settings';

  /// 测试注入学习提醒服务替身（null 时从 Provider 读取）。
  final StudyReminderService? reminderServiceOverride;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  LearningPreferencesState get _preferences => context.read<LearningPreferencesState>();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.responsive.contentWidth),
            child: Column(
              children: [
                // 顶部导航栏
                Container(
                  height: 48,
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        color: skin.text1,
                        onPressed: () => NavUtils.safePop(context),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '设置',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: skin.text1),
                          ),
                        ),
                      ),
                      SizedBox(width: 48),
                    ],
                  ),
                ),
                // 内容区
                Expanded(child: _buildPreferences(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreferences(BuildContext context) {
    final resp = context.responsive;
    final settings = context.watch<LearningPreferencesState>();
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: resp.isWide ? 24 : 16, vertical: 16),
      children: [
        // --- 第一组：学习提醒 ---
        _SettingGroup([_Cell(title: '学习提醒', onTap: () => _showReminderDialog())]),
        SizedBox(height: 16),

        // --- 第二组：发音设置 ---
        _SettingGroup([
          _Cell(title: '单词发音类型', value: settings.pronunciationType, onTap: () => _showPronTypeDialog()),
          _CellWithDesc(
            title: '自动发音',
            desc: settings.autoPlayAudio
                ? (settings.autoPlayExampleAudio ? '单词、词义页面例句' : '单词')
                : (settings.autoPlayExampleAudio ? '词义页面例句' : '已关闭'),
            onTap: () => _showAutoPronDialog(),
          ),
        ]),
        SizedBox(height: 16),

        // --- 设计语言（B档：字体/圆角/间距/阴影整体风格，运行时切换） ---
        _SettingGroup([
          _Cell(
            title: '设计语言',
            value: DesignLanguages.byId(context.skin.designLanguageId).name,
            onTap: () => Navigator.pushNamed(context, RouteNames.designLanguage),
          ),
        ]),
        SizedBox(height: 16),

        // --- 第三组：拼写设置 ---
        _SettingGroup([_CellWithDesc(title: '拼写', desc: _spellDesc(settings), onTap: () => _showSpellDialog())]),
        SizedBox(height: 16),

        // --- 第四组：学习节奏 ---
        _SettingGroup([
          _Cell(title: '每日新学', value: '${settings.dailyNewWords} 词', onTap: () => _showDailyNewWordsDialog()),
          _Cell(title: '学习节奏', value: '${settings.learnPace} 词/小结', onTap: () => _showLearnPaceDialog()),
          _Cell(title: '复习节奏', value: '${settings.reviewPace} 词/组', onTap: () => _showReviewPaceDialog()),
        ]),
        SizedBox(height: 16),

        // --- 第五组：题型/助记 ---
        _SettingGroup([
          _SwitchCell('听音选义题型', value: settings.audioMeaningQuestion, onChanged: settings.setAudioMeaningQuestion),
          _Cell(title: '助记顺序', value: settings.mnemonicSegments.join(' - '), onTap: () => _showMnemonicOrderDialog()),
          _SwitchCellWithDesc(
            title: '拆分助记',
            desc: '学习时自动拆分单词',
            value: settings.splitMnemonic,
            onChanged: settings.setSplitMnemonic,
          ),
          _SwitchCellWithDesc(
            title: '混淆项辨析',
            desc: '显示选择题错误选项词义',
            value: settings.showConfusableMeanings,
            onChanged: settings.setShowConfusableMeanings,
          ),
        ]),
        SizedBox(height: 16),

        // --- 第六组：更多设置 ---
        _SettingGroup([_Cell(title: '更多学习偏好', onTap: () => _showMorePrefsDialog())]),
      ],
    );
  }

  String _spellDesc(LearningPreferencesState settings) {
    final parts = <String>[];
    if (settings.spellRightSwipe) parts.add('右滑随手拼');
    if (settings.spellReviewTip) parts.add('复习拼写提示');
    return parts.isEmpty ? '已关闭' : parts.join('、');
  }

  // ===========================================================================
  // 弹窗 1：学习提醒（真实现见 study_reminder_sheet.dart）
  // ===========================================================================
  void _showReminderDialog() {
    showStudyReminderSheet(
      context,
      preferences: _preferences,
      service: widget.reminderServiceOverride ?? context.read<StudyReminderService>(),
    );
  }

  // ===========================================================================
  // 弹窗 2：单词发音类型（英式/美式，橙色对勾）
  // ===========================================================================
  void _showPronTypeDialog() {
    _showBottomSheet(
      title: '单词发音类型',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsSheetOptionRow(
              label: '英式',
              selected: _preferences.pronunciationType == '英式',
              onTap: () async {
                await _preferences.setPronunciationType('英式');
                if (ctx.mounted) setSheetState(() {});
              },
            ),
            SettingsSheetOptionRow(
              label: '美式',
              selected: _preferences.pronunciationType == '美式',
              onTap: () async {
                await _preferences.setPronunciationType('美式');
                if (ctx.mounted) setSheetState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 弹窗 3：自动发音（单词开关 + 例句开关）
  // ===========================================================================
  void _showAutoPronDialog() {
    _showBottomSheet(
      title: '自动发音',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsSheetSwitchRow(
              title: '单词自动发音',
              value: _preferences.autoPlayAudio,
              onChanged: (v) async {
                await _preferences.setAutoPlayAudio(v);
                if (ctx.mounted) setSheetState(() {});
              },
            ),
            SettingsSheetSwitchRow(
              title: '词义页面例句自动发音',
              value: _preferences.autoPlayExampleAudio,
              onChanged: (v) async {
                await _preferences.setAutoPlayExampleAudio(v);
                if (ctx.mounted) setSheetState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 弹窗 4：拼写（右滑随手拼 + 复习拼写提示）
  // ===========================================================================
  void _showSpellDialog() {
    _showBottomSheet(
      title: '拼写',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsSheetSwitchRow(
              title: '右滑随手拼',
              value: _preferences.spellRightSwipe,
              onChanged: (v) async {
                await _preferences.setSpellRightSwipe(v);
                if (ctx.mounted) setSheetState(() {});
              },
            ),
            SettingsSheetSwitchRow(
              title: '复习拼写提示',
              value: _preferences.spellReviewTip,
              onChanged: (v) async {
                await _preferences.setSpellReviewTip(v);
                if (ctx.mounted) setSheetState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 弹窗 5：每日新学词数（滑条 1-100 + 数字输入，原为 6 个固定档位）
  // ===========================================================================
  void _showDailyNewWordsDialog() {
    // 安全审计 R2：controller 提到方法级（此前在 StatefulBuilder builder 内
    // 每次 setState 重建都会新建一个永不释放的 controller）
    final textCtrl = TextEditingController(text: '${_preferences.dailyNewWords}');
    _showBottomSheet(
      title: '每日新学',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          final value = _preferences.dailyNewWords;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 大号当前值展示
              Center(
                child: Text('$value 词', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
              ),
              Slider(
                value: value.clamp(1, 100).toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                label: '$value',
                onChanged: (v) async {
                  final n = v.round();
                  await _preferences.setDailyNewWords(n);
                  textCtrl.text = '$n';
                  if (ctx.mounted) setSheetState(() {});
                },
              ),
              // 数字输入（自由输入，1-100）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: textCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(hintText: '1-100', border: OutlineInputBorder(), isDense: true),
                  onSubmitted: (s) async {
                    final n = int.tryParse(s) ?? value;
                    if (n >= 1 && n <= 100) {
                      await _preferences.setDailyNewWords(n);
                      if (ctx.mounted) setSheetState(() {});
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
    textCtrl.dispose();
  }

  // ===========================================================================
  // 弹窗 6：学习节奏（5/10/15/20 词/小结）
  // ===========================================================================
  void _showLearnPaceDialog() {
    _showBottomSheet(
      title: '学习节奏',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [5, 10, 15, 20]
              .map(
                (n) => SettingsSheetOptionRow(
                  label: '$n 词/小结',
                  selected: _preferences.learnPace == n,
                  onTap: () async {
                    await _preferences.setLearnPace(n);
                    if (ctx.mounted) setSheetState(() {});
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ===========================================================================
  // 弹窗 6：复习节奏（新模式/旧模式 + 10/15/20/40/100 词/组）
  // ===========================================================================
  void _showReviewPaceDialog() {
    _showBottomSheet(
      title: '复习节奏',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          final skin = context.skin.colors;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 模式切换
              Text('复习模式', style: TextStyle(fontSize: 13, color: skin.text3)),
              SizedBox(height: 8),
              Row(
                children: ['新模式', '旧模式'].map((m) {
                  final on = _preferences.reviewMode == m;
                  return Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () async {
                        await _preferences.setReviewMode(m);
                        if (ctx.mounted) setSheetState(() {});
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: on ? skin.accent : skin.cardBgAlt,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: on ? skin.accent : skin.divider),
                        ),
                        child: Text(
                          m,
                          style: TextStyle(
                            fontSize: 14,
                            color: on ? Colors.white : skin.text1,
                            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
              // 词数组
              Text('每组词数', style: TextStyle(fontSize: 13, color: skin.text3)),
              SizedBox(height: 8),
              ...[10, 15, 20, 40, 100].map(
                (n) => SettingsSheetOptionRow(
                  label: '$n 词/组',
                  selected: _preferences.reviewPace == n,
                  onTap: () async {
                    await _preferences.setReviewPace(n);
                    if (ctx.mounted) setSheetState(() {});
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 弹窗 9：助记顺序（上下移动调整段落顺序，单词详情页按此排序消费）
  // ===========================================================================
  void _showMnemonicOrderDialog() {
    _showBottomSheet(
      title: '助记顺序',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          final skin = context.skin.colors;
          final segments = _preferences.mnemonicSegments;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('单词详情页助记段落的显示顺序', style: TextStyle(fontSize: 13, color: skin.text3)),
              SizedBox(height: 12),
              for (var i = 0; i < segments.length; i++)
                Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: skin.cardBgAlt, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${i + 1}. ${segments[i]}', style: TextStyle(fontSize: 15, color: skin.text1)),
                      ),
                      GestureDetector(
                        onTap: i == 0
                            ? null
                            : () async {
                                final next = List.of(segments);
                                next[i] = next[i - 1];
                                next[i - 1] = segments[i];
                                await _preferences.setMnemonicOrder(next);
                                if (ctx.mounted) setSheetState(() {});
                              },
                        child: Icon(Icons.arrow_upward, size: 20, color: i == 0 ? skin.text3 : skin.accent),
                      ),
                      SizedBox(width: 16),
                      GestureDetector(
                        onTap: i == segments.length - 1
                            ? null
                            : () async {
                                final next = List.of(segments);
                                next[i] = next[i + 1];
                                next[i + 1] = segments[i];
                                await _preferences.setMnemonicOrder(next);
                                if (ctx.mounted) setSheetState(() {});
                              },
                        child: Icon(
                          Icons.arrow_downward,
                          size: 20,
                          color: i == segments.length - 1 ? skin.text3 : skin.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 4),
              SettingsSheetOptionRow(
                label: '恢复默认顺序',
                selected: false,
                onTap: () async {
                  await _preferences.setMnemonicOrder(
                    LearningPreferences.defaultMnemonicOrder.split(',').map((s) => s.trim()).toList(),
                  );
                  if (ctx.mounted) setSheetState(() {});
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 弹窗 10：更多学习偏好（形近词 / 词根词缀显示开关）
  // ===========================================================================
  void _showMorePrefsDialog() {
    _showBottomSheet(
      title: '更多学习偏好',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsSheetSwitchRow(
              title: '显示形近词',
              value: _preferences.showSimilarWords,
              onChanged: (v) async {
                await _preferences.setShowSimilarWords(v);
                if (ctx.mounted) setSheetState(() {});
              },
            ),
            SettingsSheetSwitchRow(
              title: '显示词根词缀',
              value: _preferences.showRoots,
              onChanged: (v) async {
                await _preferences.setShowRoots(v);
                if (ctx.mounted) setSheetState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 通用底部弹窗（骨架拆至 settings_bottom_sheet.dart）
  // ===========================================================================
  void _showBottomSheet({required String title, required Widget child}) {
    showSettingsBottomSheet(context, title: title, child: child);
  }
}

// =============================================================================
// 通用组件
// =============================================================================

/// 设置项分组（16px 圆角白色卡片）
class _SettingGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingGroup(this.children);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      decoration: BoxDecoration(color: skin.cardBg, borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }
}

/// 普通设置项（标题 + 值 + 箭头）
class _Cell extends StatelessWidget {
  final String title;
  final String? value;
  final VoidCallback? onTap;
  const _Cell({required this.title, this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return ScaleDownOnPress(
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 16, color: skin.text1)),
              ),
              if (value != null)
                Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text(value!, style: TextStyle(fontSize: 14, color: skin.text3)),
                ),
              Icon(Icons.chevron_right, size: 20, color: skin.text3),
            ],
          ),
        ),
      ),
    );
  }
}

/// 带描述的设置项
class _CellWithDesc extends StatelessWidget {
  final String title;
  final String desc;
  final VoidCallback? onTap;
  const _CellWithDesc({required this.title, required this.desc, this.onTap});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return ScaleDownOnPress(
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, color: skin.text1)),
                    SizedBox(height: 4),
                    Text(desc, style: TextStyle(fontSize: 12, color: skin.text3)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: skin.text3),
            ],
          ),
        ),
      ),
    );
  }
}

/// 开关设置项
class _SwitchCell extends StatelessWidget {
  final String title;
  final bool value;
  final Future<void> Function(bool)? onChanged;
  const _SwitchCell(this.title, {required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 16, color: skin.text1)),
          ),
          Switch(
            value: value,
            onChanged: onChanged == null ? null : (next) => onChanged!(next),
            activeThumbColor: Colors.white,
            activeTrackColor: skin.accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: skin.text3,
          ),
        ],
      ),
    );
  }
}

/// 带描述的开关设置项
class _SwitchCellWithDesc extends StatelessWidget {
  final String title;
  final String desc;
  final bool value;
  final Future<void> Function(bool)? onChanged;
  const _SwitchCellWithDesc({required this.title, required this.desc, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, color: skin.text1)),
                SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 12, color: skin.text3)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged == null ? null : (next) => onChanged!(next),
            activeThumbColor: Colors.white,
            activeTrackColor: skin.accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: skin.text3,
          ),
        ],
      ),
    );
  }
}
