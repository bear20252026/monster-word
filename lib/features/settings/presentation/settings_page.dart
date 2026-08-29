// 设置页：学习偏好 + 7 个底部弹窗交互
// 已接入 SkinSystem 主题 — 所有颜色使用 context.skin.colors
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/nav_utils.dart';
import 'learning_preferences_state.dart';
import '../../../hooks/responsive.dart';
import '../../../theme/skin_system.dart';
import '../../../widgets/scale_down_on_press.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  static const routeName = '/settings';

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
                  padding: const EdgeInsets.symmetric(horizontal: 4),
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
                      const SizedBox(width: 48),
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

  /// 「即将上线」标签
  Widget _comingSoonBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('即将上线', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w500)),
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
        const SizedBox(height: 16),

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
        const SizedBox(height: 16),

        // --- 第三组：拼写设置 ---
        _SettingGroup([_CellWithDesc(title: '拼写', desc: _spellDesc(settings), onTap: () => _showSpellDialog())]),
        const SizedBox(height: 16),

        // --- 第四组：学习节奏 ---
        _SettingGroup([
          _Cell(title: '每日新学', value: '${settings.dailyNewWords} 词', onTap: () => _showDailyNewWordsDialog()),
          _Cell(title: '学习节奏', value: '${settings.learnPace} 词/小结', onTap: () => _showLearnPaceDialog()),
          _Cell(title: '复习节奏', value: '${settings.reviewPace} 词/组', onTap: () => _showReviewPaceDialog()),
        ]),
        const SizedBox(height: 16),

        // --- 第五组：题型/助记 ---
        _SettingGroup([
          _SwitchCell('听音选义题型', value: settings.audioMeaningQuestion, onChanged: settings.setAudioMeaningQuestion),
          _Cell(
            title: '助记顺序',
            value: '派生词 - 词组搭配 - 特殊变形 - …',
            trailing: _comingSoonBadge(),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('助记顺序设置即将上线，敬请期待'), duration: Duration(seconds: 1)),
              );
            },
          ),
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
        const SizedBox(height: 16),

        // --- 第六组：更多设置 ---
        _SettingGroup([
          _Cell(
            title: '更多学习偏好',
            trailing: _comingSoonBadge(),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('更多学习偏好即将上线，敬请期待'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ]),
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
  // 弹窗 1：学习提醒
  // ===========================================================================
  void _showReminderDialog() {
    _showBottomSheet(
      title: '学习提醒',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetSwitchRow(
              title: '微信提醒',
              value: _preferences.wechatReminder,
              onChanged: (v) async {
                await _preferences.setWechatReminder(v);
                if (ctx.mounted) setSheetState(() {});
              },
            ),
            _SheetSwitchRow(
              title: '系统提醒',
              value: _preferences.systemReminder,
              onChanged: (v) async {
                await _preferences.setSystemReminder(v);
                if (ctx.mounted) setSheetState(() {});
              },
            ),
          ],
        ),
      ),
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
            _SheetOptionRow(
              label: '英式',
              selected: _preferences.pronunciationType == '英式',
              onTap: () async {
                await _preferences.setPronunciationType('英式');
                if (ctx.mounted) setSheetState(() {});
              },
            ),
            _SheetOptionRow(
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
            _SheetSwitchRow(
              title: '单词自动发音',
              value: _preferences.autoPlayAudio,
              onChanged: (v) async {
                await _preferences.setAutoPlayAudio(v);
                if (ctx.mounted) setSheetState(() {});
              },
            ),
            _SheetSwitchRow(
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
            _SheetSwitchRow(
              title: '右滑随手拼',
              value: _preferences.spellRightSwipe,
              onChanged: (v) async {
                await _preferences.setSpellRightSwipe(v);
                if (ctx.mounted) setSheetState(() {});
              },
            ),
            _SheetSwitchRow(
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
  // 弹窗 5：每日新学词数（5/10/15/20/30/50 词）
  // ===========================================================================
  void _showDailyNewWordsDialog() {
    _showBottomSheet(
      title: '每日新学',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [5, 10, 15, 20, 30, 50]
              .map(
                (n) => _SheetOptionRow(
                  label: '$n 词',
                  selected: _preferences.dailyNewWords == n,
                  onTap: () async {
                    await _preferences.setDailyNewWords(n);
                    if (ctx.mounted) {
                      setSheetState(() {});
                    }
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
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
                (n) => _SheetOptionRow(
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
              const SizedBox(height: 8),
              Row(
                children: ['新模式', '旧模式'].map((m) {
                  final on = _preferences.reviewMode == m;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () async {
                        await _preferences.setReviewMode(m);
                        if (ctx.mounted) setSheetState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              const SizedBox(height: 16),
              // 词数组
              Text('每组词数', style: TextStyle(fontSize: 13, color: skin.text3)),
              const SizedBox(height: 8),
              ...[10, 15, 20, 40, 100].map(
                (n) => _SheetOptionRow(
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
  // 通用底部弹窗
  // ===========================================================================
  void _showBottomSheet({required String title, required Widget child}) {
    final skin = context.skin.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: skin.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽条 + 关闭按钮
            Row(
              children: [
                const SizedBox(width: 36),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(color: skin.divider, borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => NavUtils.safePop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: Icon(Icons.close, size: 20, color: skin.text3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 标题
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: skin.text1),
            ),
            const SizedBox(height: 16),
            // 内容
            child,
          ],
        ),
      ),
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
  final Widget? trailing;
  const _Cell({required this.title, this.value, this.onTap, this.trailing});

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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 16, color: skin.text1)),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(value!, style: TextStyle(fontSize: 14, color: skin.text3)),
                ),
              if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, color: skin.text1)),
                    const SizedBox(height: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, color: skin.text1)),
                const SizedBox(height: 4),
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

// =============================================================================
// 弹窗内部组件
// =============================================================================

/// 弹窗开关行
class _SheetSwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SheetSwitchRow({required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 15, color: skin.text1)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
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

/// 弹窗选项行（橙色对勾）
class _SheetOptionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SheetOptionRow({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: selected ? skin.accent : skin.text1,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 22, color: skin.accent),
          ],
        ),
      ),
    );
  }
}
