// 记忆兽生成器（蓝图 T3「词书图鉴」demo）——纯函数规则，零 Flutter 依赖。
//
// 一词一兽：同一骨骼模板 × 词属性，程序化生成，不抽奖、不氪金。
// 蓝图只给了定性映射（词长定体型/词性定耳朵/难度定配色稀有度），具体档位
// 是本 demo 自定的口径，全部集中在这里，改规则只动这一处：
//
// - 体型（词长）：≤4 字母 = 小巧 / 5-7 = 标准 / ≥8 = 修长；
// - 耳朵（词性，取首条释义）：名词圆耳 / 动词尖耳 / 形容词垂耳 / 副词小角耳 /
//   其余（含无结构化释义）圆耳兜底；
// - 配色稀有度：词库没有难度列，demo 用词长做难度代理（长词普遍更难记），
//   ≤5 常见苔绿 / 6-8 少见雾蓝 / ≥9 稀有色。正式接入 FSRS 难度后替换本代理。
//
// 红线（与蓝图避坑清单同口径）：稀有度只是颜色不同，不显示数值、不做评价、
// 不制造「你的兽比别人差」的比较；文案只陈述事实，零 emoji。
import 'package:word_app/models/word.dart';

/// 体型档（词长决定）。
enum BeastBuild { petite, standard, lanky }

/// 耳朵形态（词性决定）。
enum BeastEars { round, pointy, floppy, tufted }

/// 配色稀有度（demo 用词长代理难度）。
enum BeastRarity { common, uncommon, rare }

/// 一只记忆兽的生成规格（纯值对象；渲染层消费，不反查词库）。
class MemoryBeastSpec {
  const MemoryBeastSpec({
    required this.word,
    required this.build,
    required this.ears,
    required this.rarity,
    required this.bodyWidthFactor,
    required this.bodyHeightFactor,
  });

  /// 原词（图鉴卡展示用）。
  final String word;

  final BeastBuild build;
  final BeastEars ears;
  final BeastRarity rarity;

  /// 身体宽/高相对基准半径的比例（修长兽更高、小巧兽更圆）。
  final double bodyWidthFactor;
  final double bodyHeightFactor;
}

/// 体型档阈值（含边界）。
const int beastPetiteMaxLength = 4;
const int beastStandardMaxLength = 7;

/// 稀有度档阈值（词长代理难度，含边界）。
const int beastCommonMaxLength = 5;
const int beastUncommonMaxLength = 8;

/// 词长 → 体型。
BeastBuild beastBuildFor(int length) {
  if (length <= beastPetiteMaxLength) return BeastBuild.petite;
  if (length <= beastStandardMaxLength) return BeastBuild.standard;
  return BeastBuild.lanky;
}

/// 词长 → 稀有度（demo 难度代理）。
BeastRarity beastRarityFor(int length) {
  if (length <= beastCommonMaxLength) return BeastRarity.common;
  if (length <= beastUncommonMaxLength) return BeastRarity.uncommon;
  return BeastRarity.rare;
}

/// 词性 → 耳朵。取首条释义的词性串（如 "n." / "vt." / "adj."），
/// 空/未知回退圆耳——没有词性的词也有兽，不缺席。
BeastEars beastEarsFor(String? partOfSpeech) {
  final pos = (partOfSpeech ?? '').toLowerCase().trim();
  if (pos.startsWith('n')) return BeastEars.round;
  if (pos.startsWith('v')) return BeastEars.pointy;
  if (pos.startsWith('adj')) return BeastEars.floppy;
  if (pos.startsWith('adv')) return BeastEars.tufted;
  return BeastEars.round;
}

/// 由词生成一只记忆兽（demo 入口：词长 + 首条词性）。
MemoryBeastSpec memoryBeastFor(Word word) {
  final text = word.word.trim();
  final length = text.length;
  final defs = word.parsedDefinitions;
  final pos = defs.isNotEmpty ? defs.first.partOfSpeech : null;
  final build = beastBuildFor(length);
  // 体型比例：小巧更圆、修长更高（基准 1.0，渲染层乘基准半径）。
  final (w, h) = switch (build) {
    BeastBuild.petite => (1.05, 0.92),
    BeastBuild.standard => (1.0, 1.0),
    BeastBuild.lanky => (0.88, 1.14),
  };
  return MemoryBeastSpec(
    word: text,
    build: build,
    ears: beastEarsFor(pos),
    rarity: beastRarityFor(length),
    bodyWidthFactor: w,
    bodyHeightFactor: h,
  );
}

/// 稀有度展示名（只陈述档位，不做评价）。
const Map<BeastRarity, String> beastRarityLabels = {
  BeastRarity.common: '常见',
  BeastRarity.uncommon: '少见',
  BeastRarity.rare: '稀有',
};

/// 体型展示名。
const Map<BeastBuild, String> beastBuildLabels = {
  BeastBuild.petite: '小巧',
  BeastBuild.standard: '标准',
  BeastBuild.lanky: '修长',
};

/// 耳朵展示名。
const Map<BeastEars, String> beastEarsLabels = {
  BeastEars.round: '圆耳',
  BeastEars.pointy: '尖耳',
  BeastEars.floppy: '垂耳',
  BeastEars.tufted: '角耳',
};
