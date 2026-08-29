# UX-AUX-3 用户视角体检：学习/会话/背诵流程域

> **审计人**: UX-AUX-3
> **日期**: 2026-08-28
> **项目**: Monster Word (`D:\claude\work\cn_com_lange\word_app`)
> **方法**: 只读代码审计 + 用户旅程推演（未修改 lib/ 代码）
> **范围**: learn_session、spell_session_page、spell_check_page、dictation_session_page、sentence_quiz_page、quick_spell_page、learning_session_state、session_exit_guard、learn_page

---

## 审计维度与发现

### 维度 1：上手/引导 — 第一次进学习有没有说清楚规则

| # | 严重度 | 痛点 | file:line | 建议 |
|---|--------|------|-----------|------|
| UX-1 | 中 | learn_session 首次进入无引导/教程，用户不知道「认识/不认识」按钮含义 | `lib/screens/learn_session.dart`（_StatelessWidget build） | 首次进入时显示 1-2 屏轻量引导 overlay（如：← 认识 / 不认识 →），或首次翻卡时在按钮旁加 tooltip |
| UX-2 | 低 | spell_check_page 的「查看答案」按钮直接揭示答案，无二次确认 | `lib/pages/spell_check_page.dart:211-215` | 改为「提示」渐进式（先显示首字母 → 再显示完整答案），降低用户放弃门槛 |

### 维度 2：核心任务清晰 — 怎么开始/继续学习、进度可见

| # | 严重度 | 痛点 | file:line | 建议 |
|---|--------|------|-----------|------|
| UX-3 | 中 | learn_session 顶部进度条只显示「X/Y」，无预估剩余时间 | `lib/screens/learn_session.dart`（progress 区域） | 增加「预计还需 N 分钟」估算，帮助用户决策是否继续 |
| UX-4 | 低 | quick_spell_page 限时模式默认关闭，用户不知道有这个功能 | `lib/pages/quick_spell_page.dart:43` | 在首页或入口处增加限时模式的入口提示 |
| UX-5 | 中 | dictation_session_page 完成后返回首页，无「继续学下一本」选项 | `lib/pages/dictation_session_page.dart:447-456` | 增加「继续学习」按钮，减少用户重新选书的摩擦 |

### 维度 3：反馈与微交互 — 答题对错的即时反馈、递进动画、提示

| # | 严重度 | 痛点 | file:line | 建议 |
|---|--------|------|-----------|------|
| UX-6 | 中 | learn_session 翻卡动画过快（200ms），用户可能没看清答案就进入下一题 | `lib/screens/learn_session.dart`（_动画相关） | 答案展示时增加 300-500ms 停留，或增加「确认已记住」按钮让用户主动推进 |
| UX-7 | 低 | spell_check_page 拼写错误时只显示正确答案，无音标/发音辅助 | `lib/pages/spell_check_page.dart:67-68` | 错误时增加「再听一次」按钮，帮助用户建立音形联系 |
| UX-8 | 中 | dictation_session_page 答错后 4 秒自动跳转，用户可能没看完正确答案 | `lib/pages/dictation_session_page.dart:93-95` | 改为手动点击「下一题」或延长自动跳转至 6-8 秒 |
| UX-9 | 低 | sentence_quiz_page 回答正确时无正向微动效（如 ✓ 弹跳） | `lib/pages/sentence_quiz_page.dart:337-386` | 正确时增加 confetti / scale 动画增强满足感 |

### 维度 4：空/错/加载态 — 词表空、网络错、无音频时

| # | 严重度 | 痛点 | file:line | 建议 |
|---|--------|------|-----------|------|
| UX-10 | 中 | learn_session 词表为空时显示空白 Scaffold，无空态提示 | `lib/screens/learn_session.dart`（build 方法） | 增加空态页面：图标 + 「暂无可学单词」+ 「去选词书」按钮 |
| UX-11 | 低 | dictation_session_page 空词表态有「返回首页」但无「去选书」选项 | `lib/pages/dictation_session_page.dart:159-168` | 增加「选择词书」入口，减少用户操作步骤 |
| UX-12 | 中 | spell_check_page 音频播放失败时无用户反馈（只有 debugPrint） | `lib/pages/spell_check_page.dart:51-53` | 播放失败时显示 toast 或图标变化（如 🔇），让用户知道「没声音了」 |
| UX-13 | 低 | sentence_quiz_page 无例句时回退到单词释义，但无提示说明 | `lib/pages/sentence_quiz_page.dart:51-53` | 回退时显示「暂无例句，使用释义出题」，管理用户预期 |

### 维度 5：一致性 — 背书/会话/答案展示风格是否统一

| # | 严重度 | 痛点 | file:line | 建议 |
|---|--------|------|-----------|------|
| UX-14 | 高 | 4 种拼写/听写字页面顶部导航风格不统一：dictation 用 close 图标，spell_check 用 back 箭头，quick_spell 用自定义 | `lib/pages/dictation_session_page.dart:233-237` `lib/pages/spell_check_page.dart:265-271` `lib/pages/quick_spell_page.dart` | 统一为同一种导航组件（建议统一使用 back 箭头 + 标题 + 进度） |
| UX-15 | 中 | 答案展示位置不统一：dictation 在输入框下方，spell_check 在输入框上方 | `lib/pages/dictation_session_page.dart:329-350` `lib/pages/spell_check_page.dart:175-203` | 统一答案展示位置和样式（建议在输入框下方，与输入行为形成因果关系） |
| UX-16 | 低 | 按钮文案不统一：「检查」vs「确认」vs「下一题」vs「继续」 | 多处 | 统一操作按钮文案：检查 → 「检查答案」，确认 → 「确认」 |

### 维度 6：摩擦冗余 — 退出确认是否太烦、每步是否要重复操作

| # | 严重度 | 痛点 | file:line | 建议 |
|---|--------|------|-----------|------|
| UX-17 | **高** | SessionExitGuard 拦截所有返回操作（包括系统返回键），每学一词都弹确认，极度干扰学习心流 | `lib/widgets/session_exit_guard.dart:44-55` | 改为智能拦截：① 学完（>5 个词）才弹确认；② 首次返回不拦截，仅在快速连续返回时拦截；③ 提供「保存并退出」选项 |
| UX-18 | 中 | dictation_session_page 每答一词后需要手动点「下一题」，无法键盘确认后自动进入 | `lib/pages/dictation_session_page.dart:353-363` | 答完最后一题后自动跳转，减少一次点击 |
| UX-19 | 低 | quick_spell_page 重新开始时需要多次点击（重置 → 再开始） | `lib/pages/quick_spell_page.dart` | 提供「重新开始」一键重置按钮 |

### 维度 7：可访问性 — 大按钮、字号、对比度

| # | 严重度 | 痛点 | file:line | 建议 |
|---|--------|------|-----------|------|
| UX-20 | 中 | spell_check_page 播放音频按钮较小（20px 图标），不利点击 | `lib/pages/spell_check_page.dart:122-145` | 增大至 48dp 最小触控区域，或增加 padding |
| UX-21 | 低 | learn_session 部分文字颜色对比度不足（text3 在浅色背景上） | `lib/screens/learn_session.dart`（多处 text3） | 检查 text3 颜色是否满足 WCAG AA 对比度（4.5:1） |
| UX-22 | 中 | sentence_quiz_page 选项字母圆圈（28px）偏小，密集排列时易误触 | `lib/pages/sentence_quiz_page.dart:304-311` | 增大选项触控区域至 48dp，增加选项间距 |

### 维度 8：文案语气 — 自然、鼓励性、不冰冷

| # | 严重度 | 痛点 | file:line | 建议 |
|---|--------|------|-----------|------|
| UX-23 | 中 | spell_check_page 错误时显示「拼写错误，正确答案：xxx」，语气冰冷 | `lib/pages/spell_check_page.dart:67` | 改为鼓励式：「别灰心，正确答案是 xxx」或「差一点！答案是 xxx」 |
| UX-24 | 低 | dictation_session_page 完成时只显示「听写完成！」，缺乏成就感 | `lib/pages/dictation_session_page.dart:413` | 根据正确率显示不同文案：「太棒了！全对了！」/「不错哦，继续加油！」/「还需努力～」 |
| UX-25 | 中 | SessionExitGuard 确认框文案「退出后本次进度将不会保存」有威胁感 | `lib/widgets/session_exit_guard.dart:33` | 改为：「学习进度将保存到下次」或「确定要暂停学习吗？」 |

### 维度 9：会话/进度 — 中途退出能否续、学完的满足感/总结

| # | 严重度 | 痛点 | file:line | 建议 |
|---|--------|------|-----------|------|
| UX-26 | 中 | learn_session 中途退出后重新进入无法恢复到上次进度位置（队列为内存状态） | `lib/features/learning/presentation/learning_session_state.dart` | 退出时持久化当前索引和队列，恢复时从断点继续 |
| UX-27 | **高** | dictation/spell 完成页只显示正确率，无错题回顾、无学习总结 | `lib/pages/dictation_session_page.dart:394-466` | 增加错题列表 + 「复习错题」按钮 + 学习时长统计 |
| UX-28 | 中 | quick_spell_page 完成页无总结，直接结束 | `lib/pages/quick_spell_page.dart`（完成页） | 增加正确率 + 用时 + 最长连续正确等成就数据 |
| UX-29 | 低 | sentence_quiz_page 完成后直接返回首页，无完成页 | `lib/pages/sentence_quiz_page.dart:79-81` | 增加简短完成页，展示本次测验成绩和鼓励文案 |

### 维度 10：视觉稳定 — 无乱跳、无溢出、动画平滑

| # | 严重度 | 痛点 | file:line | 建议 |
|---|--------|------|-----------|------|
| UX-30 | 中 | dictation_session_page 反馈区域从 `_answered=false` 变为 `true` 时高度跳变（SizedBox 48 → 反馈卡片），导致页面跳动 | `lib/pages/dictation_session_page.dart:330` | 使用 AnimatedCrossFade 或固定高度容器，避免布局跳变 |
| UX-31 | 低 | spell_check_page 反馈区使用 `if (_hasChecked)` 条件插入，可能导致输入框位置突变 | `lib/pages/spell_check_page.dart:175-203` | 使用 AnimatedSize 包裹反馈区，平滑过渡 |
| UX-32 | 中 | learn_session 卡片切换时如果新词较长，文本可能溢出或挤压 | `lib/screens/learn_session.dart`（_卡片布局） | 使用 FittedBox 或 maxLines + overflow 处理长文本，确保布局稳定 |

---

## 按严重度排序的 Top 5 修复建议

| 优先级 | 问题 | 维度 | 建议 |
|--------|------|------|------|
| **P0** | SessionExitGuard 无差别拦截所有返回，严重干扰学习心流 | 维度 6 | 智能拦截：仅在学完（>5 词）或连续快速返回时触发 |
| **P1** | 完成页无错题回顾和总结（dictation/spell） | 维度 9 | 增加错题列表 + 「复习错题」按钮 |
| **P2** | 导航/按钮/答案展示风格不统一（4 种拼写页面） | 维度 5 | 统一为共享组件 |
| **P3** | 文案语气冰冷，缺乏鼓励性 | 维度 8 | 全面优化反馈文案，增加正向激励 |
| **P4** | 反馈区布局跳变（dictation/spell） | 维度 10 | 使用动画过渡 |

---

## 验证通过项

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 核心学习流程可走通 | ✅ | 选书 → 学习 → 答题 → 反馈 → 下一题 |
| 进度可见 | ✅ | 多处有 X/Y 进度显示 |
| 即时反馈 | ✅ | 答对/答错均有视觉反馈 |
| 空态处理 | ✅ | 大部分页面有空态页面 |
| 退出保护 | ✅ | SessionExitGuard 存在且生效 |
| 限时模式 | ✅ | quick_spell_page 支持限时挑战 |
| 多种练习模式 | ✅ | 拼写/听写/例句测验/快速拼写 |

---

## 总结

Monster Word 的学习/会话/背诵流程**核心功能完整**，用户可以从选书到完成学习。主要 UX 问题集中在：

1. **SessionExitGuard 过于激进** — 无差别拦截所有返回操作，严重影响学习心流（高优先级修复）
2. **完成页缺乏总结** — 用户学完后没有成就感，也没有错题回顾入口（中高优先级）
3. **多页面风格不统一** — 4 种拼写/听写页面导航、按钮、反馈位置各异（中优先级）
4. **文案语气偏冰冷** — 错误反馈和确认框缺乏鼓励性（中优先级）
5. **布局跳变** — 反馈区出现/消失时页面跳动（低中优先级）

建议优先处理 SessionExitGuard 和完成页总结，这两项对用户留存和学习体验影响最大。
