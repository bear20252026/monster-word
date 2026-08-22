// 由账号4生成
// 设置页：1:1 复刻原版 activity_settings.xml
// 结构：顶部导航 + 分组列表（主题/锁屏 / 学习模式/单词量/发音 / 助记/拼写/听音 / 提醒/同步/缓存 / 诊断/条款/隐私）
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBg,
      body: SafeArea(
        child: Column(
          children: [
            // ===== 顶部导航栏（原版 CustomHeadView）=====
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: AppColors.black87,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '设置',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.dividerGrey),
            // ===== 设置列表（原版分组结构）=====
            Expanded(
              child: ListView(
                children: const [
                  // 第一组：主题/锁屏
                  _SettingGroup([
                    _SubtitleCell('主题'),
                    _SwitchCell('锁屏学单词'),
                  ]),
                  // 第二组：学习模式
                  _SettingGroup([
                    _SubtitleCell('学习模式'),
                    _SubtitleCell('每组学习单词量'),
                    _SubtitleCell('单词发音类型'),
                  ]),
                  // 第三组：助记
                  _SettingGroup([
                    _SubtitleCell('助记顺序'),
                    _SwitchCell('混淆项辨析', subTitle: '显示选择题错误选项词义'),
                    _SwitchCell('拼写测试'),
                    _SwitchCell('听音选义题型'),
                    _SubtitleCell('自动发音'),
                  ]),
                  // 第四组：数据
                  _SettingGroup([
                    _SubtitleCell('学习提醒'),
                    _SubtitleCell('同步学习数据'),
                    _SubtitleCell('清除缓存'),
                    _SubtitleCell('评价应用'),
                    _SubtitleCell('帮助中心'),
                    _SubtitleCell('推荐给好友'),
                  ]),
                  // 第五组：关于
                  _SettingGroup([
                    _SubtitleCell('网络诊断'),
                    _SubtitleCell('服务条款'),
                    _SubtitleCell('隐私政策'),
                    _SubtitleCell('注销账户'),
                  ]),
                  // 底部 App 信息
                  _AppInfo(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置分组（原版 LinearLayout + foreground_color 背景）
class _SettingGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingGroup(this.children);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.cardBg,
      child: Column(children: children),
    );
  }
}

/// 子标题行（原版 SubtitleCellView）
class _SubtitleCell extends StatelessWidget {
  final String title;
  const _SubtitleCell(this.title);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pageCommonMargin),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.dividerGrey)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, color: AppColors.black87),
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

/// 开关行（原版 SwitchCellView）
class _SwitchCell extends StatelessWidget {
  final String title;
  final String? subTitle;
  const _SwitchCell(this.title, {this.subTitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pageCommonMargin),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.dividerGrey)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, color: AppColors.black87),
                ),
                if (subTitle != null)
                  Text(
                    subTitle!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
              ],
            ),
          ),
          Switch(value: false, onChanged: (v) {}),
        ],
      ),
    );
  }
}

/// 底部 App 信息（原版 monsterword_container）
class _AppInfo extends StatelessWidget {
  const _AppInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pageCommonMargin),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monster Word',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'v1.0.0',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.mainBgTop, AppColors.mainBgBottom],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.menu_book, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}
