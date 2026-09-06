// Monster Word — 精选风格目录（6 选 1 的用户可见风格）。
// 从 skin_system.dart 拆出：颜色主题与设计语言的绑定关系在此定义。

class MwStyle {
  final String id;
  final String name;
  final String desc;

  /// 绑定的 A 档颜色主题 id（[themes] 的键）
  final String themeId;

  /// 绑定的 B 档设计语言 id（[DesignLanguages.all] 的键）
  final String languageId;
  const MwStyle({
    required this.id,
    required this.name,
    required this.desc,
    required this.themeId,
    required this.languageId,
  });
}

/// 精选风格注册表：用户只做 6 选 1，不再暴露 11 主题 × 6 语言的双轴组合
/// （66 种组合对用户是选择灾难）。`themes` 色板库仍保留全部 11 套
/// （对比度守卫测试遍历全库），但非精选主题不再出现在任何用户界面。
const List<MwStyle> kMwStyles = [
  MwStyle(
    id: 'starbucks_cream',
    name: '星巴克 · 奶油',
    desc: '奶油画布与品牌绿，温润耐看（默认）',
    themeId: 'starbucks_cream',
    languageId: 'starbucks',
  ),
  MwStyle(
    id: 'starbucks_dark',
    name: '星巴克 · 墨绿',
    desc: '墨绿深夜画布，专注不刺眼',
    themeId: 'starbucks_dark',
    languageId: 'starbucks',
  ),
  MwStyle(
    id: 'apple_light',
    name: 'Apple · 简约',
    desc: '珍珠白配 Action Blue，克制精准',
    themeId: 'apple_light',
    languageId: 'apple',
  ),
  MwStyle(id: 'claude_cream', name: 'Claude · 暖调', desc: '暖纸质感与赤陶色，书卷气', themeId: 'claude_cream', languageId: 'claude'),
  MwStyle(id: 'nike_mono', name: 'Nike · 锐利', desc: '黑白单色大字，快节奏运动感', themeId: 'nike_mono', languageId: 'nike'),
  MwStyle(
    id: 'airbnb_light',
    name: 'Airbnb · 友好',
    desc: '纯白画布配珊瑚红，亲和明快',
    themeId: 'airbnb_light',
    languageId: 'airbnb',
  ),
];
