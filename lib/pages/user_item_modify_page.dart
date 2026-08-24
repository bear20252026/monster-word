// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 UserItemModifyActivity
// 用户信息修改：单独字段修改页（通用）
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class UserItemModifyPage extends StatefulWidget {
  final String title;
  final String initialValue;
  final String? hintText;

  const UserItemModifyPage({
    super.key,
    required this.title,
    required this.initialValue,
    this.hintText,
  });

  static const routeName = '/user_item_modify';

  @override
  State<UserItemModifyPage> createState() => _UserItemModifyPageState();
}

class _UserItemModifyPageState extends State<UserItemModifyPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin),
            Container(height: 1, color: skin.colors.divider),
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: MistralTypography.body.copyWith(color: skin.colors.text1),
                decoration: InputDecoration(
                  hintText: widget.hintText ?? '请输入${widget.title}',
                  hintStyle: MistralTypography.body.copyWith(color: skin.colors.text3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: skin.colors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: MistralColors.primary, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () => _controller.clear(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: skin.colors.text3)),
          ),
          const Spacer(),
          Text(widget.title, style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
            child: Text('保存', style: TextStyle(color: MistralColors.primary)),
          ),
        ],
      ),
    );
  }
}
