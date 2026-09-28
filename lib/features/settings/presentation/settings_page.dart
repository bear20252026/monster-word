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
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.reminderServiceOverride});

  static const routeName = RouteNames.settings;

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
                            style: MwTypography.bodyBold.copyWith(fontWeight: FontWeight.w600, color: skin.text1),
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
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: resp.isWide ? 24 : 16, vertical: 16),
      children: [
        // --- 第一组：学习提醒 ---
        _SettingGroup([
          _Cell(title: '学习提醒', icon: Icons.notifications_active_outlined, onTap: () => _showReminderDialog()),
        ]),
        SizedBox(height: 16),

        // --- 第二组：发音设置（仅订阅发音三字段） ---
        Selector<LearningPreferencesState, (String, bool, bool)>(
          selector: (_, s) => (s.pronunciationType, s.autoPlayAudio, s.autoPlayExampleAudio),
          builder: (context, v, _) {
            final (pronType, autoPlay, autoPlayExample) = v;
            return _SettingGroup([
              _Cell(
                title: '单词发音类型',
                icon: Icons.volume_up_outlined,
                value: pronType,
                onTap: () => _showPronTypeDialog(),
              ),
              _CellWithDesc(
                title: '自动发音',
                icon: Icons.graphic_eq_outlined,
                desc: autoPlay ? (autoPlayExample ? '单词、词义页面例句' : '单词') : (autoPlayExample ? '词义页面例句' : '已关闭'),
                onTap: () => _showAutoPronDialog(),
              ),
            ]);
          },
        ),
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

        // --- 第三组：拼写设置（仅订阅拼写两开关） ---
        Selector<LearningPreferencesState, (bool, bool)>(
          selector: (_, s) => (s.spellRightSwipe, s.spellReviewTip),
          builder: (context, v, _) => _SettingGroup([
            _CellWithDesc(
              title: '拼写',
              icon: Icons.edit_outlined,
              desc: _spellDesc(v.$1, v.$2),
              onTap: () => _showSpellDialog(),
            ),
          ]),
        ),
        SizedBox(height: 16),

        // --- 第四组：学习节奏（每日新学与节奏分别订阅，互不影响） ---
        _SettingGroup([
          Selector<TodayProgressStore, int>(
            selector: (_, s) => s.goal,
            builder: (context, goal, _) => _Cell(
              title: '每日新学',
              icon: Icons.flag_outlined,
              value: '$goal 词',
              onTap: () => _showDailyNewWordsDialog(),
            ),
          ),
          Selector<LearningPreferencesState, int>(
            selector: (_, s) => s.learnPace,
            builder: (context, pace, _) => _Cell(
              title: '学习节奏',
              icon: Icons.speed_outlined,
              value: '$pace 词/小结',
              onTap: () => _showLearnPaceDialog(),
            ),
          ),
        ]),
        SizedBox(height: 16),

        // --- 第五组：题型/助记（setter 走 read，避免订阅整个 state） ---
        Selector<LearningPreferencesState, (bool, String, bool, bool)>(
          selector: (_, s) =>
              (s.audioMeaningQuestion, s.mnemonicSegments.join(' - '), s.splitMnemonic, s.showConfusableMeanings),
          builder: (context, v, _) {
            final settings = context.read<LearningPreferencesState>();
            return _SettingGroup([
              _SwitchCell(
                '听音选义题型',
                icon: Icons.headphones_outlined,
                value: v.$1,
                onChanged: settings.setAudioMeaningQuestion,
              ),
              _Cell(
                title: '助记顺序',
                icon: Icons.low_priority_outlined,
                value: v.$2,
                onTap: () => _showMnemonicOrderDialog(),
              ),
              _SwitchCellWithDesc(
                title: '拆分助记',
                icon: Icons.extension_outlined,
                desc: '学习时自动拆分单词',
                value: v.$3,
                onChanged: settings.setSplitMnemonic,
              ),
              _SwitchCellWithDesc(
                title: '混淆项辨析',
                icon: Icons.compare_arrows_outlined,
                desc: '显示选择题错误选项词义',
                value: v.$4,
                onChanged: settings.setShowConfusableMeanings,
              ),
            ]);
          },
        ),
        SizedBox(height: 16),

        // --- 第六组：更多设置 ---
        _SettingGroup([_Cell(title: '更多学习偏好', icon: Icons.tune, onTap: () => _showMorePrefsDialog())]),
      ],
    );
  }

  String _spellDesc(bool spellRightSwipe, bool spellReviewTip) {
    final parts = <String>[];
    if (spellRightSwipe) parts.add('右滑随手拼');
    if (spellReviewTip) parts.add('复习拼写提示');
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
  Future<void> _showDailyNewWordsDialog() async {
    // 内存审计 P1（I69 回归测试补刀）：控制器归属弹层内容自身的
    // StatefulWidget——由框架在路由退场动画结束、widget 树完全移除后释放。
    // 此前的两版（builder 内新建 / 方法级 await 后手动 dispose）分别有
    // 永不释放与退场动画期间 use-after-dispose 的缺陷。
    await _showBottomSheet(title: '每日新学', child: const _DailyNewWordsSheetBody());
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
              Text('单词详情页助记段落的显示顺序', style: MwTypography.caption.copyWith(color: skin.text3)),
              SizedBox(height: 12),
              for (var i = 0; i < segments.length; i++)
                Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: skin.cardBgAlt, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${i + 1}. ${segments[i]}', style: MwTypography.bodySm.copyWith(color: skin.text1)),
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
  Future<void> _showBottomSheet({required String title, required Widget child}) {
    return showSettingsBottomSheet(context, title: title, child: child);
  }
}

/// 「每日新学」弹层内容（内存审计 P1/I69：控制器归本组件所有——
/// initState 建一次，框架在弹层路由完全移除（含退场动画）后才 dispose，
/// 彻底规避方法级手动释放的 use-after-dispose 时序窗口）。
class _DailyNewWordsSheetBody extends StatefulWidget {
  const _DailyNewWordsSheetBody();

  @override
  State<_DailyNewWordsSheetBody> createState() => _DailyNewWordsSheetBodyState();
}

class _DailyNewWordsSheetBodyState extends State<_DailyNewWordsSheetBody> {
  late final TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: '${context.read<TodayProgressStore>().goal}');
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _setGoal(int n) async {
    await context.read<TodayProgressStore>().setGoal(n);
    _textCtrl.text = '$n';
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = context.read<TodayProgressStore>().goal;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 大号当前值展示
        Center(
          child: Text(
            '$value 词',
            style: const TextStyle(fontSize: AppFontSizes.stat, fontWeight: FontWeight.w700),
          ),
        ),
        Slider(
          value: value.clamp(1, 100).toDouble(),
          min: 1,
          max: 100,
          divisions: 99,
          label: '$value',
          onChanged: (v) => _setGoal(v.round()),
        ),
        // 数字输入（自由输入，1-100）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _textCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: '1-100', border: OutlineInputBorder(), isDense: true),
            onSubmitted: (s) {
              final n = int.tryParse(s) ?? value;
              if (n >= 1 && n <= 100) _setGoal(n);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
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
      decoration: BoxDecoration(color: skin.cardBg, borderRadius: BorderRadius.circular(context.design.radius.control)),
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
                child: Text(title, style: MwTypography.bodyMd.copyWith(color: skin.text1)),
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
                      style: MwTypography.bodySm.copyWith(fontWeight: FontWeight.w500, color: skin.text2),
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
      decoration: BoxDecoration(
        color: skin.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
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
                    Text(title, style: MwTypography.bodyMd.copyWith(color: skin.text1)),
                    SizedBox(height: 4),
                    Text(
                      desc,
                      style: MwTypography.micro.copyWith(fontWeight: FontWeight.w400, color: skin.text3),
                    ),
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
            child: Text(title, style: MwTypography.bodyMd.copyWith(color: skin.text1)),
          ),
          Switch(
            value: value,
            onChanged: onChanged == null ? null : (next) => onChanged!(next),
            activeThumbColor: AppColors.white100,
            activeTrackColor: skin.accent,
            inactiveThumbColor: AppColors.white100,
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
                Text(title, style: MwTypography.bodyMd.copyWith(color: skin.text1)),
                SizedBox(height: 4),
                Text(
                  desc,
                  style: MwTypography.micro.copyWith(fontWeight: FontWeight.w400, color: skin.text3),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged == null ? null : (next) => onChanged!(next),
            activeThumbColor: AppColors.white100,
            activeTrackColor: skin.accent,
            inactiveThumbColor: AppColors.white100,
            inactiveTrackColor: skin.text3,
          ),
        ],
      ),
    );
  }
}
