// 设置页：学习偏好 + 7 个底部弹窗交互
// 已接入 SkinSystem 主题 — 所有颜色使用 context.skin.colors
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/skin_system.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  static const routeName = '/settings';

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 设置状态
  bool _wechatReminder = false;
  bool _systemReminder = true;
  String _pronType = '美式'; // 英式/美式
  bool _autoPronWord = true;
  bool _autoPronExample = false;
  bool _spellRightSwipe = true;
  bool _spellReviewTip = true;
  int _learnPace = 10; // 5/10/15/20
  String _reviewMode = '新模式';
  int _reviewPace = 10; // 10/15/20/40/100
  int _dailyNewWords = 10; // 每日新学词数：5/10/15/20/30/50

  static const _dailyNewWordsPrefKey = 'daily_new_words_v1';

  @override
  void initState() {
    super.initState();
    _loadDailyNewWords();
  }

  Future<void> _loadDailyNewWords() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_dailyNewWordsPrefKey);
    if (saved != null && mounted) {
      setState(() => _dailyNewWords = saved);
    }
  }

  Future<void> _saveDailyNewWords(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyNewWordsPrefKey, value);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
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
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '学习偏好',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: skin.text1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // 内容区
            Expanded(
              child: _buildPreferences(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferences(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // --- 第一组：学习提醒 ---
        _SettingGroup([
          _Cell(
            title: '学习提醒',
            onTap: () => _showReminderDialog(),
          ),
        ]),
        const SizedBox(height: 16),

        // --- 第二组：发音设置 ---
        _SettingGroup([
          _Cell(
            title: '单词发音类型',
            value: _pronType,
            onTap: () => _showPronTypeDialog(),
          ),
          _CellWithDesc(
            title: '自动发音',
            desc: _autoPronWord
                ? (_autoPronExample ? '单词、词义页面例句' : '单词')
                : (_autoPronExample ? '词义页面例句' : '已关闭'),
            onTap: () => _showAutoPronDialog(),
          ),
        ]),
        const SizedBox(height: 16),

        // --- 第三组：拼写设置 ---
        _SettingGroup([
          _CellWithDesc(
            title: '拼写',
            desc: _spellDesc,
            onTap: () => _showSpellDialog(),
          ),
        ]),
        const SizedBox(height: 16),

        // --- 第四组：学习节奏 ---
        _SettingGroup([
          _Cell(
            title: '每日新学',
            value: '$_dailyNewWords 词',
            onTap: () => _showDailyNewWordsDialog(),
          ),
          _Cell(
            title: '学习节奏',
            value: '$_learnPace 词/小结',
            onTap: () => _showLearnPaceDialog(),
          ),
          _Cell(
            title: '复习节奏',
            value: '$_reviewPace 词/组',
            onTap: () => _showReviewPaceDialog(),
          ),
        ]),
        const SizedBox(height: 16),

        // --- 第五组：题型/助记 ---
        _SettingGroup([
          _SwitchCell('听音选义题型'),
          _Cell(title: '助记顺序', value: '派生词 - 词组搭配 - 特殊变形 - …'),
          _SwitchCellWithDesc(title: '拆分助记', desc: '学习时自动拆分单词', defaultValue: true),
          _SwitchCellWithDesc(title: '混淆项辨析', desc: '显示选择题错误选项词义', defaultValue: true),
        ]),
        const SizedBox(height: 16),

        // --- 第六组：更多设置 ---
        _SettingGroup([
          _Cell(title: '更多学习偏好'),
        ]),
      ],
    );
  }

  String get _spellDesc {
    final parts = <String>[];
    if (_spellRightSwipe) parts.add('右滑随手拼');
    if (_spellReviewTip) parts.add('复习拼写提示');
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
              value: _wechatReminder,
              onChanged: (v) => setSheetState(() => setState(() => _wechatReminder = v)),
            ),
            _SheetSwitchRow(
              title: '系统提醒',
              value: _systemReminder,
              onChanged: (v) => setSheetState(() => setState(() => _systemReminder = v)),
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
              selected: _pronType == '英式',
              onTap: () => setSheetState(() => setState(() => _pronType = '英式')),
            ),
            _SheetOptionRow(
              label: '美式',
              selected: _pronType == '美式',
              onTap: () => setSheetState(() => setState(() => _pronType = '美式')),
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
              value: _autoPronWord,
              onChanged: (v) => setSheetState(() => setState(() => _autoPronWord = v)),
            ),
            _SheetSwitchRow(
              title: '词义页面例句自动发音',
              value: _autoPronExample,
              onChanged: (v) => setSheetState(() => setState(() => _autoPronExample = v)),
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
              value: _spellRightSwipe,
              onChanged: (v) => setSheetState(() => setState(() => _spellRightSwipe = v)),
            ),
            _SheetSwitchRow(
              title: '复习拼写提示',
              value: _spellReviewTip,
              onChanged: (v) => setSheetState(() => setState(() => _spellReviewTip = v)),
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
          children: [5, 10, 15, 20, 30, 50].map((n) => _SheetOptionRow(
            label: '$n 词',
            selected: _dailyNewWords == n,
            onTap: () {
              setSheetState(() => setState(() => _dailyNewWords = n));
              _saveDailyNewWords(n);
            },
          )).toList(),
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
          children: [5, 10, 15, 20].map((n) => _SheetOptionRow(
            label: '$n 词/小结',
            selected: _learnPace == n,
            onTap: () => setSheetState(() => setState(() => _learnPace = n)),
          )).toList(),
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
                  final on = _reviewMode == m;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setSheetState(() => setState(() => _reviewMode = m)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: on ? skin.accent : skin.cardBgAlt,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: on ? skin.accent : skin.divider,
                          ),
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
              ...[10, 15, 20, 40, 100].map((n) => _SheetOptionRow(
                label: '$n 词/组',
                selected: _reviewPace == n,
                onTap: () => setSheetState(() => setState(() => _reviewPace = n)),
              )),
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
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽条
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 标题
            Text(title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: skin.text1)),
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
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
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
    return GestureDetector(
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
            Icon(Icons.chevron_right, size: 20, color: skin.text3),
          ],
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
    return GestureDetector(
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
    );
  }
}

/// 开关设置项
class _SwitchCell extends StatelessWidget {
  final String title;
  const _SwitchCell(this.title);

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
            value: false,
            onChanged: (v) {},
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
  final bool defaultValue;
  const _SwitchCellWithDesc({required this.title, required this.desc, this.defaultValue = false});

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
            value: defaultValue,
            onChanged: (v) {},
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
    return Container(
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
      child: Container(
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
            if (selected)
              Icon(Icons.check, size: 22, color: skin.accent),
          ],
        ),
      ),
    );
  }
}
