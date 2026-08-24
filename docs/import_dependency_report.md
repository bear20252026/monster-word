# Import 依赖检查报告

> 检查时间：2026-08-24
> 检查范围：lib/pages/、lib/screens/、lib/widgets/

## 一、总体统计

- **总文件数**：104
- **有依赖的文件**：77
- **总依赖数**：235
- **无效导入**：59
- **循环依赖**：0

## 二、无效导入

以下导入路径无法解析：

| 文件 | 导入路径 | 问题 |
|---|---|---|
| lib\pages\books_page.dart | dashboard_page.dart | unknown import format |
| lib\pages\books_page.dart | lib_select_page.dart | unknown import format |
| lib\pages\books_page.dart | my_space_page.dart | unknown import format |
| lib\pages\books_page.dart | review_page.dart | unknown import format |
| lib\pages\book_words_page.dart | list_words_page.dart | unknown import format |
| lib\pages\courses_page.dart | class_checkin_page.dart | unknown import format |
| lib\pages\courses_page.dart | class_activity_page.dart | unknown import format |
| lib\pages\exam_quick_review_page.dart | dart:async | unknown import format |
| lib\pages\foot_mark_page.dart | my_words_page.dart | unknown import format |
| lib\pages\foot_mark_page.dart | new_words_page.dart | unknown import format |
| lib\pages\foot_mark_page.dart | mastered_words_page.dart | unknown import format |
| lib\pages\foot_mark_page.dart | not_learned_words_page.dart | unknown import format |
| lib\pages\foot_mark_page.dart | reviewing_words_page.dart | unknown import format |
| lib\pages\lib_select_page.dart | learn_page.dart | unknown import format |
| lib\pages\lib_select_page.dart | search_page.dart | unknown import format |
| lib\pages\mastered_words_page.dart | list_words_page.dart | unknown import format |
| lib\pages\my_content_page.dart | my_fav_page.dart | unknown import format |
| lib\pages\my_space_page.dart | message_page.dart | unknown import format |
| lib\pages\my_space_page.dart | settings_page.dart | unknown import format |
| lib\pages\my_words_page.dart | list_words_page.dart | unknown import format |
| lib\pages\net_diagnosis_page.dart | dart:async | unknown import format |
| lib\pages\new_words_page.dart | list_words_page.dart | unknown import format |
| lib\pages\not_learned_words_page.dart | list_words_page.dart | unknown import format |
| lib\pages\reviewing_words_page.dart | list_words_page.dart | unknown import format |
| lib\pages\search_page.dart | dictionary_page.dart | unknown import format |
| lib\pages\splash_page.dart | dart:async | unknown import format |
| lib\pages\splash_page.dart | login_page.dart | unknown import format |
| lib\pages\uri_scheme_page.dart | base_web_page.dart | unknown import format |
| lib\pages\word_machine_page.dart | dart:async | unknown import format |
| lib\pages\word_machine_page.dart | dart:math | unknown import format |
| lib\widgets\animations.dart | dart:math | unknown import format |
| lib\widgets\card_widgets.dart | animations.dart | unknown import format |
| lib\widgets\card_widgets.dart | learn_widgets.dart | unknown import format |
| lib\widgets\cell_list_widgets.dart | input_controls.dart | unknown import format |
| lib\widgets\cell_widgets.dart | input_controls.dart | unknown import format |
| lib\widgets\check_in_widgets.dart | dart:ui | unknown import format |
| lib\widgets\check_in_widgets.dart | scale_down_on_press.dart | unknown import format |
| lib\widgets\custom_dialog_widgets.dart | animations.dart | unknown import format |
| lib\widgets\custom_text_widgets.dart | animations.dart | unknown import format |
| lib\widgets\glass_widgets.dart | dart:ui | unknown import format |
| lib\widgets\guide_widgets.dart | animations.dart | unknown import format |
| lib\widgets\indicator_widgets.dart | animations.dart | unknown import format |
| lib\widgets\input_controls.dart | animations.dart | unknown import format |
| lib\widgets\layout_widgets.dart | animations.dart | unknown import format |
| lib\widgets\learn_widgets.dart | animations.dart | unknown import format |
| lib\widgets\list_widgets.dart | animations.dart | unknown import format |
| lib\widgets\misc_widgets.dart | dart:math | unknown import format |
| lib\widgets\pager_widgets.dart | animations.dart | unknown import format |
| lib\widgets\progress_indicators.dart | animations.dart | unknown import format |
| lib\widgets\progress_widgets.dart | dart:math | unknown import format |
| lib\widgets\sb_badge.dart | scale_down_on_press.dart | unknown import format |
| lib\widgets\sb_banner.dart | scale_down_on_press.dart | unknown import format |
| lib\widgets\sb_button.dart | scale_down_on_press.dart | unknown import format |
| lib\widgets\sb_card.dart | scale_down_on_press.dart | unknown import format |
| lib\widgets\sb_fab.dart | scale_down_on_press.dart | unknown import format |
| lib\widgets\text_widgets.dart | animations.dart | unknown import format |
| lib\widgets\transition_widgets.dart | animations.dart | unknown import format |
| lib\widgets\widget_utils.dart | animations.dart | unknown import format |
| lib\widgets\word_lookup_popup.dart | dart:ui | unknown import format |

## 三、循环依赖

✅ 未发现循环依赖

## 四、依赖统计

### 依赖最多的文件（Top 10）

| 文件 | 依赖数 |
|---|---|
| lib\pages\review_page.dart | 9 |
| lib\screens\home_screen.dart | 9 |
| lib\screens\learn_session.dart | 9 |
| lib\screens\review_session.dart | 9 |
| lib\pages\word_detail_page.dart | 8 |
| lib\pages\dictionary_page.dart | 7 |
| lib\pages\learn_page.dart | 7 |
| lib\pages\search_page.dart | 7 |
| lib\screens\profile_screen.dart | 7 |
| lib\pages\more_settings_page.dart | 6 |

### 被依赖最多的文件（Top 10）

| 文件 | 被引用数 |
|---|---|
| lib\theme\skin_system.dart | 67 |
| lib\tokens\design_tokens.dart | 49 |
| lib\state\learning_state.dart | 27 |
| lib\hooks\responsive.dart | 15 |
| lib\models\word.dart | 8 |
| lib\data\wordbook_database.dart | 8 |
| lib\data\example_parser.dart | 7 |
| lib\engine\srs_engine.dart | 6 |
| lib\widgets\animations.dart | 4 |
| lib\theme\app_theme.dart | 3 |

## 五、建议

### 无效导入处理

1. 检查导入路径是否正确
2. 确认文件是否存在
3. 修正路径或删除无效导入

