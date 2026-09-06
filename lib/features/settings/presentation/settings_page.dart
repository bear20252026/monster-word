// 设置页：学习偏好 + 7 个底部弹窗交互
// 已接入 SkinSystem 主题 — 所有颜色使用 context.skin.colors
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/features/settings/application/study_reminder_service.dart';
import 'package:word_app/features/settings/domain/learning_preferences.dart';
import 'package:word_app/features/settings/presentation/learning_preferences_state.dart';
import 'package:word_app/features/settings/presentation/settings_bottom_sheet.dart';
import 'package:word_app/features/settings/presentation/study_reminder_sheet.dart';
import 'package:word_app/core/application/today_progress_store.dart';
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
        _SettingGroup([
          _Cell(title: '学习提醒', icon: Icons.notifications_active_outlined, onTap: () => _showReminderDialog()),
        ]),
        SizedBox(height: 16),

        // --- 第二组：发音设置 ---
        _SettingGroup([
          _Cell(
            title: '单词发音类型',
            icon: Icons.volume_up_outlined,
            value: settings.pronunciationType,
            onTap: () => _showPronTypeDialog(),
          ),
          _CellWithDesc(
            title: '自动发音',
            icon: Icons.graphic_eq_outlined,
            desc: settings.autoPlayAudio
                ? (settings.autoPlayExampleAudio ? '单词、词义页面例句' : '单词')
                : (settings.autoPlayExampleAudio ? '词义页面例句' : '已关闭'),
            onTap: () => _showAutoPronDialog(),
          ),
        ]),
        SizedBox(height: 16),

        // --- 风格（颜色主题 + 设计语言已收敛为 6 精选风格） ---
        _SettingGroup([
          _Cell(
            title: '风格',
            icon: Icons.palette_outlined,
            value: context.skin.currentStyleName,
            onTap: () => Navigator.pushNamed(context, RouteNames.designLanguage),
          ),
        ]),
        SizedBox(height: 16),

        // --- 第三组：拼写设置 ---
        _SettingGroup([
          _CellWithDesc(
            title: '拼写',
            icon: Icons.edit_outlined,
            desc: _spellDesc(settings),
            onTap: () => _showSpellDialog(),
          ),
        ]),
        SizedBox(height: 16),

        // --- 第四组：学习节奏 ---
        _SettingGroup([
          _Cell(
            title: '每日新学',
            icon: Icons.flag_outlined,
            value: '${context.watch<TodayProgressStore>().goal} 词',
            onTap: () => _showDailyNewWordsDialog(),
          ),
          _Cell(
            title: '学习节奏',
            icon: Icons.speed_outlined,
            value: '${settings.learnPace} 词/小结',
            onTap: () => _showLearnPaceDialog(),
          ),
        ]),
        SizedBox(height: 16),

        // --- 第五组：题型/助记 ---
        _SettingGroup([
          _SwitchCell(
            '听音选义题型',
            icon: Icons.headphones_outlined,
            value: settings.audioMeaningQuestion,
            onChanged: settings.setAudioMeaningQuestion,
          ),
          _Cell(
            title: '助记顺序',
            icon: Icons.low_priority_outlined,
            value: settings.mnemonicSegments.join(' - '),
            onTap: () => _showMnemonicOrderDialog(),
          ),
          _SwitchCellWithDesc(
            title: '拆分助记',
            icon: Icons.extension_outlined,
            desc: '学习时自动拆分单词',
            value: settings.splitMnemonic,
            onChanged: settings.setSplitMnemonic,
          ),
          _SwitchCellWithDesc(
            title: '混淆项辨析',
            icon: Icons.compare_arrows_outlined,
            desc: '显示选择题错误选项词义',
            value: settings.showConfusableMeanings,
            onChanged: settings.setShowConfusableMeanings,
          ),
        ]),
        SizedBox(height: 16),

        // --- 第六组：更多设置 ---
        _SettingGroup([_Cell(title: '更多学习偏好', icon: Icons.tune, onTap: () => _showMorePrefsDialog())]),
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
    final textCtrl = TextEditingController(text: '${context.read<TodayProgressStore>().goal}');
    _showBottomSheet(
      title: '每日新学',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          final value = context.read<TodayProgressStore>().goal;
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
                  await context.read<TodayProgressStore>().setGoal(n);
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
                      await context.read<TodayProgressStore>().setGoal(n);
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: skin.cardBg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 60, color: skin.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// 普通设置项（标题 + 值 + 箭头）
class _Cell extends StatelessWidget {
  final String title;
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;
  const _Cell({required this.title, this.value, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return ScaleDownOnPress(
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _SettingIcon(icon: icon),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 16, color: skin.text1)),
              ),
              if (value != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, left: 8),
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: skin.text2),
                    ),
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

/// 设置行首图标块：淡 accent 底圆角方块（与个人中心菜单行同语言）
class _SettingIcon extends StatelessWidget {
  final IconData? icon;
  const _SettingIcon({this.icon});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    if (icon == null) return const SizedBox(width: 4);
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(color: skin.accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(9)),
      child: Icon(icon, size: 18, color: skin.accent),
    );
  }
}

/// 带描述的设置项
class _CellWithDesc extends StatelessWidget {
  final String title;
  final String desc;
  final IconData? icon;
  final VoidCallback? onTap;
  const _CellWithDesc({required this.title, required this.desc, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return ScaleDownOnPress(
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _SettingIcon(icon: icon),
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
  final IconData? icon;
  final bool value;
  final Future<void> Function(bool)? onChanged;
  const _SwitchCell(this.title, {this.icon, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _SettingIcon(icon: icon),
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
  final IconData? icon;
  final bool value;
  final Future<void> Function(bool)? onChanged;
  const _SwitchCellWithDesc({required this.title, required this.desc, this.icon, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _SettingIcon(icon: icon),
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
