// 每日学习目标滚轮选择器
// 用户可通过滚动选择每天学习的单词数量（1-200）

import 'package:flutter/material.dart';
import 'package:word_app/data/app_preferences.dart';
import 'package:word_app/hooks/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/sb_card.dart';

class DailyGoalPicker extends StatefulWidget {
  const DailyGoalPicker({super.key});

  @override
  State<DailyGoalPicker> createState() => _DailyGoalPickerState();
}

class _DailyGoalPickerState extends State<DailyGoalPicker> {
  late FixedExtentScrollController _controller;
  late int _currentValue;

  static const int _minGoal = 1;
  static const int _maxGoal = 200;

  @override
  void initState() {
    super.initState();
    _currentValue = UserPreferences().getDailyGoal();
    _controller = FixedExtentScrollController(
      initialItem: (_currentValue - _minGoal).clamp(0, _maxGoal - _minGoal),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSelected(int index) async {
    final value = index + _minGoal;
    if (value == _currentValue) return;
    setState(() => _currentValue = value);
    await UserPreferences().setDailyGoal(value);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
      child: SbCard(
        padding: EdgeInsets.symmetric(
          vertical: 12 * resp.scale,
          horizontal: 16 * resp.scale,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '每日学习目标',
              style: TextStyle(
                fontSize: 14 * resp.fontScale,
                fontWeight: FontWeight.w600,
                color: skin.colors.text1,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: 40,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: _onSelected,
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _maxGoal - _minGoal + 1,
                  builder: (context, index) {
                    final value = index + _minGoal;
                    final isSelected = value == _currentValue;
                    return Center(
                      child: Text(
                        '$value',
                        style: TextStyle(
                          fontSize: (isSelected ? 24 : 18) * resp.fontScale,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected ? skin.colors.accent : skin.colors.text3,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Text(
              '个单词 / 天',
              style: TextStyle(
                fontSize: 12 * resp.fontScale,
                color: skin.colors.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
