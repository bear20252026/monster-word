# 组件规格手册（星巴克模式 → Monster Word Flutter 实现）

> 来源：项目根 `DESIGN.md`（§4 组件 / §6 阴影 / §9 Agent Prompt Guide）。v2 共 10 类组件：§1–4 核心四件 + §5–10 增补件。颜色统一映射进 `theme/skin_system.dart` 的 `ThemeVars`（accent / pageBg / cardBg），勿在页面散落硬编码。页面落点参考 `docs/ui_inventory.md`。

---

## 1. 胶囊主按钮 PillButton（50px 全胶囊）

**规格值表**

| 属性 | 值 |
|---|---|
| 圆角 | `BorderRadius.circular(50)`（= StadiumBorder） |
| 主款 | 填充 `#00754A` + 白字 + `1px solid #00754A` 描边 |
| 变体 | 描边款=透明底绿框绿字；黑款=`#000000` 底白字；深绿底反白款=白底 `#00754A` 字；深底描边款=透明底白框白字 |
| 内边距 | 竖 7 × 横 16（移动端建议总高 ≥44px 满足触控） |
| 文字 | 16px / w600 / letterSpacing −0.01em |
| 按压态 | `scale(0.95)` + `all 0.2s ease` —— 全体系统一微交互 |

```dart
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color fill, textColor;
  final BorderSide side;
  const PillButton({super.key, required this.label, this.onTap,
      this.fill = const Color(0xFF00754A), // 描边款：transparent + 绿/白 side
      this.textColor = Colors.white,
      this.side = BorderSide.none});

  @override
  Widget build(BuildContext context) {
    bool pressed = false; // 注意：必须在 StatefulBuilder 外声明，否则重建即归零
    return StatefulBuilder(builder: (context, setState) {
      void end() => setState(() => pressed = false);
      return GestureDetector(
        onTapDown: (_) => setState(() => pressed = true),
        onTapUp: (_) => end(),
        onTapCancel: end,
        child: AnimatedScale( // ★ 按压 scale(0.95) + 0.2s ease
          scale: pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
          child: Material(
            color: fill, shape: StadiumBorder(side: side),
            child: InkWell(
              customBorder: const StadiumBorder(), onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                child: Text(label, style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w600, letterSpacing: -0.16,
                    color: textColor)))))));
    });
  }
}
```

---

## 2. 内容卡片 ContentCard（12px 圆角 + 双层低透明阴影）

**规格值表**

| 属性 | 值 |
|---|---|
| 背景 | `#FFFFFF` 白卡浮在奶油画布 `#F2F0EB` 上（画布禁用纯白） |
| 圆角 | `12px` |
| 阴影层1 贴地晕 | CSS `0 0 .5px rgba(0,0,0,.14)` → Flutter `Offset.zero, blurRadius 0.5` |
| 阴影层2 方向光 | CSS `0 1px 1px rgba(0,0,0,.24)` → Flutter `Offset(0,1), blurRadius 1` |
| 内边距 | 16–24；卡片间距 16 |

```dart
class ContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const ContentCard({super.key, required this.child,
      this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(offset: Offset.zero, blurRadius: 0.5, color: Color(0x24000000)),
          BoxShadow(offset: Offset(0, 1), blurRadius: 1, color: Color(0x3D000000)),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
```

> 用于单词卡、书单 tile、统计面板。画布必须是奶油色（scaffoldBackgroundColor），白卡才有「浮起」感。

---

## 3. Frap 悬浮圆钮（56px，「开始学习」悬浮入口）

**规格值表**

| 属性 | 值 |
|---|---|
| 尺寸/形状 | 56 × 56 圆形 |
| 填充/图标 | `#00754A` / 白 icon |
| 阴影·基础光环 | CSS `0 0 6px rgba(0,0,0,.24)` → Flutter `Offset.zero, blurRadius 6` |
| 阴影·环境投影 | CSS `0 8px 12px rgba(0,0,0,.14)` → `Offset(0,8), blurRadius 12`，按压时淡出 |
| 触控外扩 | 视觉边缘外扩 8px（外包一层 Padding(8) 补足命中区） |
| 位置/按压 | 固定右下角；按压 `scale(0.95)` 同 §1 |

**App 映射**：学习首页（HomeScreen）底部常驻「开始学习」入口，替代普通大按钮。

```dart
class FrapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const FrapFab({super.key,
      this.icon = Icons.play_arrow_rounded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding( // 触控外扩 8px
      padding: const EdgeInsets.all(8),
      child: Container(
        width: 56, height: 56,
        decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [
          BoxShadow(blurRadius: 6, color: Color(0x3D000000)), // 基础光环 .24
          BoxShadow(offset: Offset(0, 8), blurRadius: 12, color: Color(0x24000000)),
        ]),
        child: Material(
          color: const Color(0xFF00754A), shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap,
              child: Icon(icon, size: 30, color: Colors.white)),
        ),
      ),
    );
  }
}
```

---

## 4. 深绿特性横幅 FeatureBand（#1E3932 白字）

**规格值表**

| 属性 | 值 |
|---|---|
| 背景/主文字 | `#1E3932` / `#FFFFFF`；副文案 `rgba(255,255,255,.70)` |
| 标题/正文 | 24px w600 / 14–16px w400 行高 1.5 |
| 圆角 | 首页内嵌横幅 `12px`；全宽通栏版直角 |
| 内边距 | 24；CTA 配对 = 反白主钮（白底绿字）+ 深底白描边次钮 |
| 禁止渐变 | 本系统全为实色色块 |

**App 映射**：首页顶部「连续打卡 N 天」横幅——标题+副文案+行动钮组，右侧留插画位；窄屏纵向堆叠。

```dart
class StreakBanner extends StatelessWidget {
  const StreakBanner({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF1E3932),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('连续打卡 7 天', style: TextStyle(fontSize: 24,
            fontWeight: FontWeight.w600, color: Colors.white)),
        Text('再坚持 3 天解锁本周全部奖励', style: TextStyle(fontSize: 14,
            color: Colors.white.withOpacity(0.70))), // Text White Soft
        const SizedBox(height: 16),
        Wrap(spacing: 12, children: [
          PillButton(label: '继续学习', onTap: () {},
              fill: Colors.white, textColor: const Color(0xFF00754A)), // 反白主钮
          PillButton(label: '查看记录', onTap: () {}, fill: Colors.transparent,
              textColor: Colors.white,
              side: const BorderSide(color: Colors.white)), // 深底描边次钮
        ]),
      ]),
    );
  }
}
```

---

## 5. 金色胶囊徽章 GoldPillBadge（#cba258，"200★ item"式）

**规格值表**

| 属性 | 值 |
|---|---|
| 形状 | 50px 全胶囊；填充透明 |
| 描边/文字 | `1px solid #cba258` / `#cba258`（原文 Rewards Cost Pill） |
| 内边距 | 竖 4 × 横 12；文字 13 / w700 |
| 按压态 | scale(0.95) 同 §1（可选） |
| 使用纪律 | 金色仅限成就/星标/奖励场景，**禁止**作通用强调色 |

```dart
class GoldPillBadge extends StatelessWidget {
  final String label; // 如 '128 ★' 或 '黄金段位'
  final VoidCallback? onTap;
  const GoldPillBadge(this.label, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(
          side: BorderSide(width: 1, color: Color(0xFFCBA258))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Text(label, style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w700, color: Color(0xFFCBA258))),
        ),
      ),
    );
  }
}
```

**App 映射**：落点建议新建 `lib/widgets/gold_pill_badge.dart`。用于 `profile_screen.dart`（Tab3 成就/酷币区，替代现金色渐变）、`word_detail_page.dart`（星标单词计数）、`home_screen.dart`（打卡奖励角标）。

---

## 6. 浮动标签输入框 FloatingLabelField

**规格值表**

| 属性 | 值 |
|---|---|
| 底框 | 白底 + `1px solid #d6dbde` + 圆角 12（App 版取卡片圆角；原版定制流为 4px 直角框）+ §2 双层阴影 |
| 标签浮起 | 移动端 16px → 聚焦/有值时 13px/w700 骑到顶边上；label 左偏移 12px；200ms ease |
| 字段内边距 | 12px |
| 校验 tint | 有效 `green-light @33%`、无效 `red @5%`（错误文案 13px 红字） |
| 勾选类控件 | 过冲曲线 cubic-bezier(.32,2.32,.61,.27) → Flutter 近似 `Curves.easeOutBack` |

```dart
class FloatingLabelField extends StatefulWidget {
  final String label;
  const FloatingLabelField({super.key, required this.label});
  @override
  State<FloatingLabelField> createState() => _FloatingLabelFieldState();
}

class _FloatingLabelFieldState extends State<FloatingLabelField> {
  final _focus = FocusNode();
  final _ctrl = TextEditingController();

  @override
  void initState() { super.initState(); _focus.addListener(() => setState(() {})); }

  @override
  Widget build(BuildContext context) {
    final bool floated = _focus.hasFocus || _ctrl.text.isNotEmpty;
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD6DBDE)),
            boxShadow: const [
              BoxShadow(offset: Offset.zero, blurRadius: 0.5, color: Color(0x24000000)),
              BoxShadow(offset: Offset(0, 1), blurRadius: 1, color: Color(0x3D000000)),
            ]),
        child: TextField(controller: _ctrl, focusNode: _focus,
            style: const TextStyle(fontSize: 16, color: Color(0xDE000000)),
            decoration: const InputDecoration(isDense: true,
                border: InputBorder.none))),
      Positioned( // ★ label 浮起骑边框：16→13px，上移至顶边
        left: 12, top: floated ? -7 : 18,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200), curve: Curves.ease,
          style: TextStyle(fontSize: floated ? 13 : 16,
              fontWeight: floated ? FontWeight.w700 : FontWeight.w400,
              color: const Color(0xDE000000)),
          child: Text(widget.label)),
      ),
    ]);
  }

  @override
  void dispose() { _focus.dispose(); _ctrl.dispose(); super.dispose(); }
}
```

**App 映射**：落点建议新建 `lib/widgets/floating_label_field.dart`。用于 `search_page.dart`（查词主输入）、`login_page.dart`（手机号/验证码）、`lib_select_page.dart`（书库搜索框）、`user_item_modify_page.dart`（资料编辑，若启用）。

---

## 7. 下拉菜单 SbDropdown

**规格值表**

| 属性 | 值 |
|---|---|
| 面 | `#F9F9F9`（Neutral Cool），**无边框**——仅靠面色与白色导航区分 |
| 圆角 | 12px（继承 --cardBorderRadius）；阴影同 §2 双层低透款 |
| 条目 | 行高 44；原版桌面为 24px/w400 大字，App 内建议 **16px/w400** 黑 87%（等比缩小保可读性） |
| 高亮态 | 选中项 = 绿字 `#00754A` w600 + `green-light @33%` tint 底；悬停/按压 = ceramic `#edebe9` |

```dart
Future<T?> showSbDropdown<T>({
  required BuildContext context,
  required RenderBox anchor, // 触发行：final box = key.currentContext!.findRenderObject() as RenderBox
  required Map<T, String> items,
  T? selected,
}) {
  final size = MediaQuery.of(context).size;
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(
        anchor.localToGlobal(Offset(0, anchor.size.height)) &
            Size(anchor.size.width, 0),
        Offset.zero & size),
    color: const Color(0xFFF9F9F9), // Neutral Cool 无边框
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    constraints: BoxConstraints(minWidth: anchor.size.width),
    items: [
      for (final e in items.entries)
        PopupMenuItem<T>(value: e.key, height: 44,
          child: Text(e.value, style: TextStyle(fontSize: 16,
              fontWeight: e.key == selected ? FontWeight.w600 : FontWeight.w400,
              color: e.key == selected
                  ? const Color(0xFF00754A) : const Color(0xDE000000)))),
    ]);
}
```

**App 映射**：落点建议新建 `lib/widgets/sb_dropdown.dart`。用于 `more_settings_page.dart` 与 `settings_page.dart`（播放顺序/字体等设置选择器，合并后只接一处）、`play_order_page.dart`（单选列表改造）、`appearance_page.dart`。

---

## 8. 模态框 SbModal（居中款 + 底部弹出版）

**规格值表**

| 属性 | 值 |
|---|---|
| 表面 | 白卡 `#FFFFFF`，圆角 12px（底部版仅顶角 12） |
| 内边距 | 四周 24；**顶部预留 88** 给关闭钮/标题区（--modalTopPadding） |
| 遮罩 | `rgba(0,0,0,.55)`（规范未定值，取系统惯例，全局统一即可） |
| 关闭钮 | 右上角 32px 圆形描边 IconButton，置于顶部预留区内 |
| 弹出动画 | 底部版滑入 200ms ease；禁止缩放弹跳 |

```dart
// 居中模态：白卡 12px 圆角 + 88px 顶部预留 + padding 24
Future<T?> sbShowDialog<T>(BuildContext context, {required Widget child}) =>
    showDialog<T>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(padding: const EdgeInsets.fromLTRB(24, 88, 24, 24),
              child: child))));

// 底部弹出版：顶角 12px 圆角，贴 SafeArea，供设置类批量复用
Future<T?> sbShowSheet<T>(BuildContext context, {required Widget child}) =>
    showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.55),
      shape: const RoundedRectangleBorder(borderRadius:
          BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 88, 24, 24), child: child)));
```

**App 映射**：落点建议新建 `lib/widgets/sb_dialog.dart`。用于 `home_screen.dart` 复习确认弹窗、`more_settings_page.dart`（7 个底部弹窗批量换装）、`settings_page.dart`（若保留）、`word_lookup_popup` / `word_dictionary_popup`（学习页查词浮层）。

---

## 9. 分段控件 SbSegmented（学习模式切换等）

**规格值表**

| 属性 | 值 |
|---|---|
| 轨道 | ceramic `#edebe9` 实底、全胶囊圆角 50、内衬 4 |
| 选中段 | 白底小卡浮起（§2 双层阴影）+ 绿字 `#00754A` w600；未选 = 透明底黑 87 w400 |
| 尺寸 | 段高 44；文字 15px；选中滑块 `AnimatedAlign` 200ms ease（与按钮同一微交互语言） |
| 禁止 | 渐变、彩色轨道——保持实色克制风 |

```dart
class SbSegmented<T> extends StatelessWidget {
  final Map<T, String> segments;
  final T value;
  final ValueChanged<T> onChanged;
  const SbSegmented({super.key, required this.segments,
      required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final keys = segments.keys.toList();
    final i = keys.indexOf(value);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFEDEBE9),
          borderRadius: BorderRadius.circular(50)),
      child: LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 8) / keys.length;
        return Stack(children: [
          AnimatedAlign(
            alignment: Alignment(i * 2 / (keys.length - 1) - 1, 0),
            duration: const Duration(milliseconds: 200), curve: Curves.ease,
            child: SizedBox(width: w, height: 44,
                child: DecoratedBox(decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(50),
                    boxShadow: const [
                      BoxShadow(offset: Offset.zero, blurRadius: 0.5, color: Color(0x24000000)),
                      BoxShadow(offset: Offset(0, 1), blurRadius: 1, color: Color(0x3D000000))])))),
          Row(children: [
            for (final k in keys)
              Expanded(child: InkWell(borderRadius: BorderRadius.circular(50),
                  onTap: () => onChanged(k),
                  child: SizedBox(height: 44, child: Center(child:
                      Text(segments[k]!, style: TextStyle(fontSize: 15,
                          fontWeight: k == value ? FontWeight.w600 : FontWeight.w400,
                          color: k == value
                              ? const Color(0xFF00754A) : const Color(0xDE000000)))))))
          ]),
        ]);
      }),
    );
  }
}
```

**App 映射**：落点建议新建 `lib/widgets/sb_segmented.dart`。用于 `dictionary_page.dart`（释义/同反义/词根三 Tab 改分段）、`learn_session.dart` / `review_session.dart`(新学/复习模式切换)、`extensive_model_select_page.dart`（泛听/精听，若启用）。

---

## 10. 进度指示 SbProgress（细线进度条 + 环形进度）

**规格值表**

| 属性 | 细线进度条 | 环形进度 |
|---|---|---|
| 轨道 | 高 4px 全胶囊，ceramic `#edebe9` | stroke 6，`#e6e6e6` |
| 前景 | Green Accent `#00754A` 实色（禁渐变） | `#00754A`，`StrokeCap.round` 圆帽 |
| 动画 | Tween 200ms ease 到目标值 | Tween 400ms ease |
| 中心文案 | — | 16 / w600 黑 87（如 '72%'） |
| 完成态 | 可叠 GoldPillBadge（金仅限成就达成时刻） | 同左 |

```dart
/// 细线进度条：高 4px 胶囊，填充 Green Accent，轨道 ceramic
class SbLinearProgress extends StatelessWidget {
  final double value; // 0..1
  const SbLinearProgress({super.key, required this.value});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(50),
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 200), curve: Curves.ease,
      builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 4,
          backgroundColor: const Color(0xFFEDEBE9),
          color: const Color(0xFF00754A))));
}

/// 环形进度：stroke 6、圆帽、中心百分比
class SbRingProgress extends StatelessWidget {
  final double value;
  final String label;
  const SbRingProgress({super.key, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
    duration: const Duration(milliseconds: 400), curve: Curves.ease,
    builder: (_, v, __) => Stack(alignment: Alignment.center, children: [
      SizedBox(width: 64, height: 64, child: CircularProgressIndicator(
          value: v, strokeWidth: 6, strokeCap: StrokeCap.round,
          color: const Color(0xFF00754A), backgroundColor: const Color(0xFFE6E6E6))),
      Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
          color: Color(0xDE000000))),
    ]));
}
```

**App 映射**：落点建议新建 `lib/widgets/sb_progress.dart`。用于 `dashboard_page.dart`（统计卡进度环）、`home_screen.dart`（今日目标细线条）、`learn_page.dart` / `review_session.dart`（会话答题进度条）、`splash_page.dart`（启动加载环）。

---

## 遗留备忘

- [ ] 黑色款 / 深底描边款按钮独立示例（变体参数已列于 §1 表，按需补示例代码）
- [ ] 三层阴影全局导航条 `0 1px 3px .1 / 0 2px 2px .06 / 0 0 2px .07`（如做桌面端顶栏再补）

> v2 完成：§5–10 六类增补件全部给出规格值表 + 可抄骨架 + 落点文件与使用页面（对照 ui_inventory.md）。实现时优先接入 ThemeVars 色板，勿散落硬编码。

