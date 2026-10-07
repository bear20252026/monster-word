// Monster Word — 词书分组规则（领域层）。
//
// 此前分组正则散落在 lib_select 页面里，UI 替数据层"猜"分类；
// 收敛到领域层后，新增词书 code 只要命中规则即自动归组，UI 只消费结果。

/// 用户可见的词书分组（下标即排序，0 = 全部为 UI 虚拟组）。
const List<String> kBookGroupNames = ['全部', '四级六级', '高考考研', '雅思托福', '专业出国', '专题精选', '其他'];

/// 词书分组下标常量。
abstract final class BookGroup {
  static const all = 0;
  static const cet = 1;
  static const highschoolPostgrad = 2;
  static const ieltsToefl = 3;
  static const professional = 4;
  static const special = 5;
  static const others = 6;
}

/// 词书分组正则（static final：编译一次。每次调用现编译最多 5 个 RegExp，
/// tab 切换/列表重建的重复编译是纯浪费）。
final List<RegExp> _specialPatterns = [RegExp(r'^(PHRASEIDIOM|ROOTAFFIX|SYNNOTE|COLLOC|USAGENOTE)$')];
final List<RegExp> _cetPatterns = [RegExp(r'CET4|四级|CET6|六级')];
final List<RegExp> _highschoolPatterns = [RegExp(r'GK|高考|KAOYAN|考研|KY|LLYC')];
final List<RegExp> _ieltsPatterns = [RegExp(r'IELTS|雅思|TOEFL|托福|GDTOEFL')];
final List<RegExp> _professionalPatterns = [
  RegExp(r'GRE|GMAT|SAT|BEC|TEM|专四|专八|PRO4|PRO8|XHPRO|PETS|AWL|BARRONSAT|BIZLAW'),
];

bool _anyMatch(List<RegExp> patterns, String code) => patterns.any((p) => p.hasMatch(code));

/// 词书 code → 分组下标（[BookGroup.others] 兜底）。
int bookGroupOf(String code) {
  if (_anyMatch(_specialPatterns, code)) return BookGroup.special;
  if (_anyMatch(_cetPatterns, code)) return BookGroup.cet;
  if (_anyMatch(_highschoolPatterns, code)) return BookGroup.highschoolPostgrad;
  if (_anyMatch(_ieltsPatterns, code)) return BookGroup.ieltsToefl;
  if (_anyMatch(_professionalPatterns, code)) return BookGroup.professional;
  return BookGroup.others;
}
