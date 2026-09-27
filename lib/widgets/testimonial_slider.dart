// 首页每日一句数据（原 Testimonial Slider 组件的遗留数据类）
import 'package:flutter/material.dart';

// 死代码清理（2026-09-27 审计）：TestimonialSlider 组件零引用已删除，
// 仅保留 home_header 仍在使用的 TestimonialItem / TestimonialData。

class TestimonialItem {
  final String text;
  final String? author;
  final String? source;
  final IconData? icon;
  final Color? color;

  const TestimonialItem({required this.text, this.author, this.source, this.icon, this.color});
}

class TestimonialData {
  static const List<TestimonialItem> defaults = [
    TestimonialItem(text: '学习改变命运，每一天的积累都是未来的基石。', author: 'Monster Word', icon: Icons.auto_stories),
    TestimonialItem(
      text: 'The limits of my language mean the limits of my world.',
      author: 'Ludwig Wittgenstein',
      source: '哲学家',
      icon: Icons.format_quote,
    ),
    TestimonialItem(text: '背单词不是一场苦旅，而是一次次征服的成就感。', author: 'Monster Word', icon: Icons.emoji_events),
    TestimonialItem(text: '千里之行，始于足下。每天进步一点点，终将抵达远方。', author: '老子', source: '《道德经》', icon: Icons.landscape),
    TestimonialItem(
      text: 'Consistency is what transforms average into excellence.',
      source: 'Unknown',
      icon: Icons.star_outline,
    ),
  ];
}
