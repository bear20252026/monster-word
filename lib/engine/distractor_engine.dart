// 由账号4生成
// 干扰项生成引擎：基于编辑距离+首字母+尾字母+词长+LCS 的纯算法实现
// 参考：ISSR (2025) + Edit Distance ADG + 用户洞察（首尾字母相同最易混淆）
// 无需大模型，全部本地 O(N) 计算

import 'dart:math';

/// 干扰项候选词（带综合评分）
class DistractorCandidate {
  final String word;
  final String interpret;
  final double score; // 综合混淆度评分（越高越容易混淆）

  DistractorCandidate({
    required this.word,
    required this.interpret,
    required this.score,
  });
}

/// 干扰项生成引擎（纯算法，无外部依赖）
class DistractorEngine {
  static final DistractorEngine _instance = DistractorEngine._();
  factory DistractorEngine() => _instance;
  DistractorEngine._();

  /// 从词库中生成 3 个干扰项（原版 confuseItemsForChoice 逻辑 1:1 替代）
  /// 输入：目标单词 + 全部候选词列表
  /// 输出：按混淆度排序的前 3 个干扰项
  List<DistractorCandidate> generate({
    required String targetWord,
    required String targetInterpret,
    required List<Map<String, String>> allWords, // [{word, interpret}]
    int count = 3,
  }) {
    if (allWords.isEmpty) return [];

    final target = targetWord.toLowerCase();

    // 计算每个候选词的综合混淆度评分
    final candidates = <DistractorCandidate>[];
    for (final w in allWords) {
      final word = w['word'] ?? '';
      final interpret = w['interpret'] ?? '';
      if (word.isEmpty || word.toLowerCase() == target) continue;
      if (interpret.isEmpty) continue;
      // 排除释义完全相同的词（同义词不算干扰项）
      if (interpret == targetInterpret) continue;

      final score = _calculateConfusionScore(target, word.toLowerCase());
      candidates.add(DistractorCandidate(
        word: word,
        interpret: interpret,
        score: score,
      ));
    }

    // 按混淆度降序排序
    candidates.sort((a, b) => b.score.compareTo(a.score));

    // 取前 N 个，但要确保首字母多样性（避免 4 个选项首字母都一样）
    return _selectDiverse(candidates, count);
  }

  /// 综合混淆度评分（多维度加权）
  /// 核心洞察：首字母相同 + 尾字母相同 + 编辑距离小 = 最容易混淆
  double _calculateConfusionScore(String target, String candidate) {
    double score = 0;

    // 1. 首字母相同（权重最高：+30）
    if (target.isNotEmpty && candidate.isNotEmpty) {
      if (target[0] == candidate[0]) score += 30;
    }

    // 2. 尾字母相同（权重次高：+20）
    if (target.length > 1 && candidate.length > 1) {
      if (target[target.length - 1] == candidate[candidate.length - 1]) score += 20;
    }

    // 3. 编辑距离（Levenshtein）—— 距离越小越容易混淆
    final ed = _editDistance(target, candidate);
    final maxLen = max(target.length, candidate.length).toDouble();
    if (maxLen > 0) {
      final edScore = (1 - ed / maxLen); // 归一化到 0-1
      score += edScore * 25; // 权重 +25
    }

    // 4. 词长相似度（长度越接近越容易混淆）
    final lenDiff = (target.length - candidate.length).abs();
    final lenScore = max(0, 1 - lenDiff / 5.0); // 差 5 个字母以内都有分
    score += lenScore * 15; // 权重 +15

    // 5. LCS（最长公共子序列）—— 共享字母越多越容易混淆
    final lcs = _lcsLength(target, candidate);
    if (maxLen > 0) {
      final lcsScore = lcs / maxLen;
      score += lcsScore * 20; // 权重 +20
    }

    // 6. 中间字母相同（额外加分：+10）
    if (target.length >= 3 && candidate.length >= 3) {
      final targetMid = target.substring(1, target.length - 1);
      final candMid = candidate.substring(1, candidate.length - 1);
      final midLcs = _lcsLength(targetMid, candMid);
      final midMax = max(targetMid.length, candMid.length).toDouble();
      if (midMax > 0) {
        score += (midLcs / midMax) * 10;
      }
    }

    return score;
  }

  /// Levenshtein 编辑距离（经典动态规划）
  int _editDistance(String a, String b) {
    final m = a.length;
    final n = b.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (var i = 0; i <= m; i++) { dp[i][0] = i; }
    for (var j = 0; j <= n; j++) { dp[0][j] = j; }

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,      // 删除
          dp[i][j - 1] + 1,      // 插入
          dp[i - 1][j - 1] + cost, // 替换
        ].reduce(min);
      }
    }
    return dp[m][n];
  }

  /// 最长公共子序列长度（LCS）
  int _lcsLength(String a, String b) {
    final m = a.length;
    final n = b.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }
    return dp[m][n];
  }

  /// 选择多样化的干扰项（确保首字母不全相同）
  List<DistractorCandidate> _selectDiverse(List<DistractorCandidate> sorted, int count) {
    if (sorted.length <= count) return sorted;

    final selected = <DistractorCandidate>[];
    final usedFirstLetters = <String>{};

    // 第一轮：优先选首字母不同的高分候选
    for (final c in sorted) {
      if (selected.length >= count) break;
      final fl = c.word.isNotEmpty ? c.word[0].toLowerCase() : '';
      if (!usedFirstLetters.contains(fl)) {
        selected.add(c);
        usedFirstLetters.add(fl);
      }
    }

    // 第二轮：如果不够，用最高分的补齐
    for (final c in sorted) {
      if (selected.length >= count) break;
      if (!selected.contains(c)) {
        selected.add(c);
      }
    }

    return selected.take(count).toList();
  }

  /// 快速生成干扰项（简化版，用于 UI 直接调用）
  /// 从已加载的单词列表中快速取 3 个干扰项
  List<Map<String, String>> quickGenerate({
    required String targetWord,
    required String targetInterpret,
    required List<Map<String, String>> pool,
    int count = 3,
  }) {
    final result = generate(
      targetWord: targetWord,
      targetInterpret: targetInterpret,
      allWords: pool,
      count: count,
    );
    return result.map((c) => {'word': c.word, 'interpret': c.interpret}).toList();
  }
}
