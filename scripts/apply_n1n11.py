from pathlib import Path
import re

root = Path(r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\monster-word-wt-n")

# ── N1: learning_feature_providers inject shared facades ──
p = root / "lib/features/learning/presentation/learning_feature_providers.dart"
src = p.read_text(encoding="utf-8")
old_head = """Widget buildLearningFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ReviewScheduleRepository>.value(value: sl<ReviewScheduleRepository>()),"""
new_head = """Widget buildLearningFeatureScope({required Widget child}) {
  // N1：门面单实例——PresentationPrefs / TodayProgressStore 先建，注入 LearningSessionState，
  // 与页面 Provider 消费同一对象，避免 session 内直建第二实例。
  final presentationPrefs = PresentationPrefs();
  final todayProgressStore = TodayProgressStore();
  return MultiProvider(
    providers: [
      Provider<PresentationPrefs>.value(value: presentationPrefs),
      ChangeNotifierProvider<TodayProgressStore>.value(value: todayProgressStore),
      ChangeNotifierProvider<ReviewScheduleRepository>.value(value: sl<ReviewScheduleRepository>()),"""
if old_head not in src:
    raise SystemExit("providers head not found")
src = src.replace(old_head, new_head, 1)

src = src.replace(
    """      ChangeNotifierProvider(
        create: (context) => LearningSessionState(
          queuePort: context.read<LearningQueuePort>(),
          progressPort: context.read<LearningProgressPort>(),
          reviewSchedulePort: context.read<ReviewScheduleWriterPort>(),
          choicePort: context.read<ChoiceGeneratorPort>(),
        ),
      ),""",
    """      ChangeNotifierProvider(
        create: (context) => LearningSessionState(
          queuePort: context.read<LearningQueuePort>(),
          progressPort: context.read<LearningProgressPort>(),
          reviewSchedulePort: context.read<ReviewScheduleWriterPort>(),
          choicePort: context.read<ChoiceGeneratorPort>(),
          todayStore: todayProgressStore,
          prefs: presentationPrefs,
        ),
      ),""",
    1,
)

src = src.replace(
    """      // 今日进度单一事实源：订阅会话(已学/目标) + 复习调度(待复习)，全站同步。
      ChangeNotifierProxyProvider2<LearningSessionState, ReviewScheduleReader, TodayProgressStore>(
        create: (_) => TodayProgressStore(),
        update: (_, session, schedule, store) => (store ?? TodayProgressStore())..sync(due: schedule.dueCount),
      ),""",
    """      // 今日进度单一事实源：复用上方同一 TodayProgressStore 实例做 sync（N1）。
      ChangeNotifierProxyProvider2<LearningSessionState, ReviewScheduleReader, TodayProgressStore>.value(
        value: todayProgressStore,
        update: (_, session, schedule, store) => store..sync(due: schedule.dueCount),
      ),""",
    1,
)
src = src.replace(
    """      Provider<WordLookupReader>(create: (_) => RepositoryWordLookupReader(sl<WordRepository>())),
      Provider<PresentationPrefs>(create: (_) => PresentationPrefs()),""",
    """      Provider<WordLookupReader>(create: (_) => RepositoryWordLookupReader(sl<WordRepository>())),""",
    1,
)
p.write_text(src, encoding="utf-8")
print("N1 providers ok")

# ── N1 widgets: context.read PresentationPrefs ──
p = root / "lib/widgets/scare_coin_summary_cards.dart"
src = p.read_text(encoding="utf-8")
src = src.replace(
    "final redeemedCount = PresentationPrefs().redeemedBadgeCount;",
    "final redeemedCount = context.read<PresentationPrefs>().redeemedBadgeCount;",
)
p.write_text(src, encoding="utf-8")
print("N1 widgets ok")

# ── N2 H4 full wordbook script ──
p = root / "scripts/build_full_wordbook.py"
src = p.read_text(encoding="utf-8")
old = """    if os.path.exists(OUT_GZ):
        os.remove(OUT_GZ)
    with open(OUT_DB, "rb") as f, gzip.open(OUT_GZ, "wb", compresslevel=9) as g:
        shutil.copyfileobj(f, g, length=8 * 1024 * 1024)
    print("OUT_DB:", round(os.path.getsize(OUT_DB) / 1048576, 1), "MB")
    print("OUT_GZ:", round(os.path.getsize(OUT_GZ) / 1048576, 1), "MB ->", OUT_GZ)"""
new = """    # H4：默认不覆盖正式 assets；覆盖前强制 .bak（与 build_expanded_wordbook 对齐）
    if os.environ.get("ALLOW_ASSET_OVERWRITE", "").lower() not in ("1", "true", "yes"):
        dest = os.environ.get("OUT_GZ_TARGET", os.path.join(INPUTS, "wordbook_full.db.gz"))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        target = dest
    else:
        if os.path.exists(OUT_GZ):
            backup = OUT_GZ + ".bak"
            shutil.copy2(OUT_GZ, backup)
            print("H4 backup:", backup)
        target = OUT_GZ
    with open(OUT_DB, "rb") as f, gzip.open(target, "wb", compresslevel=9) as g:
        shutil.copyfileobj(f, g, length=8 * 1024 * 1024)
    print("OUT_DB:", round(os.path.getsize(OUT_DB) / 1048576, 1), "MB")
    print("OUT_GZ:", round(os.path.getsize(target) / 1048576, 1), "MB ->", target)"""
if old not in src:
    raise SystemExit("full script gzip block not found")
p.write_text(src.replace(old, new, 1), encoding="utf-8")
print("N2 full script ok")

# ── N4 FSRS load/forget observability ──
p = root / "lib/features/learning/data/review_schedule_repository.dart"
src = p.read_text(encoding="utf-8")
src = src.replace(
    """      } catch (error) {
        debugPrint('Review schedule loading error: $error');
        _cards = {};
        _dailyStats = {};
        _activeDates = {};
      }""",
    """      } catch (error, stack) {
        debugPrint('Review schedule loading error: $error');
        reportSwallowedError('ReviewScheduleSP degraded load', error, stack);
        _cards = {};
        _dailyStats = {};
        _activeDates = {};
      }""",
    1,
)
src = src.replace(
    """    if (_useSqlite && _store != null) {
      try {
        await _store!.deleteCard(word);
      } catch (error, stack) {
        reportSwallowedError('FSRS forget persist', error, stack);
      }
    } else {
      await _saveCards();
    }""",
    """    if (_useSqlite && _store != null) {
      try {
        await _store!.deleteCard(word);
      } catch (error, stack) {
        reportSwallowedError('FSRS forget persist', error, stack);
      }
    } else {
      try {
        await _saveCards();
      } catch (error, stack) {
        reportSwallowedError('FSRS forget persist (sp)', error, stack);
      }
    }""",
    1,
)
# N5 comment on class
src = src.replace(
    """/// 该仓储不持有当前学习队列，也不推进任何会话引擎；调用方必须显式提供需筛选的
/// 词条或要评分的实际词条。
class ReviewScheduleRepository extends ChangeNotifier {""",
    """/// 该仓储不持有当前学习队列，也不推进任何会话引擎；调用方必须显式提供需筛选的
/// 词条或要评分的实际词条。
///
/// N5（有意设计，非缺陷）：本类 extends ChangeNotifier，且 learning providers 以
/// 具体类型 `ChangeNotifierProvider<ReviewScheduleRepository>` 暴露给 UI——评分后
/// 直接通知 FSRS 仪表盘重建。长期若拆只读 Reader 适配器，须保持 rateWord 通知链路。
class ReviewScheduleRepository extends ChangeNotifier {""",
    1,
)
# count check consistency
src = src.replace(
    "if (count < cards.length) {",
    "if (count != cards.length) {",
)
p.write_text(src, encoding="utf-8")
print("N4/N5 fsrs ok")

# store migrate count check consistency
p = root / "lib/features/learning/data/review_schedule_store.dart"
src = p.read_text(encoding="utf-8")
src = src.replace("if (count < cards.length) {", "if (count != cards.length) {")
p.write_text(src, encoding="utf-8")

# ── N7 StarbucksTypography strip colors ──
p = root / "lib/tokens/starbucks_tokens.dart"
src = p.read_text(encoding="utf-8")
start = src.find("class StarbucksTypography {")
end = src.find("\n}", start)
if start < 0:
    raise SystemExit("StarbucksTypography missing")
block = src[start:end]
new_block = re.sub(r",\s*color:\s*StarbucksCreamColors\.\w+", "", block)
new_block = re.sub(r"color:\s*StarbucksCreamColors\.\w+,\s*", "", new_block)
new_block = re.sub(r",\s*\n\s*color: StarbucksCreamColors\.\w+", "", new_block)
# also color on separate lines
new_block = re.sub(r"\n\s*color: StarbucksCreamColors\.\w+,", "", new_block)
src = src[:start] + new_block + src[end:]
p.write_text(src, encoding="utf-8")
print("N7 starbucks typo", "CreamColors" in new_block)

# ── N8 bare typography colors ──
p = root / "lib/widgets/definition_view.dart"
src = p.read_text(encoding="utf-8")
# find bodySm without copyWith color
if "MwTypography.bodySm)" in src or "style: MwTypography.bodySm," in src:
    src = src.replace(
        "style: MwTypography.bodySm",
        "style: MwTypography.bodySm.copyWith(color: context.skin.colors.text1)",
        1,
    )
    p.write_text(src, encoding="utf-8")
    print("N8 definition_view patched")
else:
    print("N8 definition_view pattern check", "bodySm" in src)

p = root / "lib/features/scare_coin/presentation/redemption_center_page.dart"
src = p.read_text(encoding="utf-8")
# generic: any MwTypography.xxx without copyWith in this file - patch line 279 area
lines = src.splitlines()
for i, line in enumerate(lines):
    if "MwTypography." in line and "copyWith" not in line and "Text(" in line:
        lines[i] = re.sub(
            r"(MwTypography\.\w+)(?!\.copyWith)",
            r"\1.copyWith(color: context.skin.colors.text1)",
            line,
            count=1,
        )
src = "\n".join(lines) + "\n"
if "skin_system" not in src:
    src = src.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:word_app/theme/skin_system.dart';",
        1,
    )
p.write_text(src, encoding="utf-8")
print("N8 redemption patched")

print("done stage1")
