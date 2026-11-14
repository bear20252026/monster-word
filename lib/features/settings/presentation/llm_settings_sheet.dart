// 学习伴侣 AI 化 · AI 伙伴设置 sheet（独立文件，避 more_settings 行数棘轮）。
//
// 配置 LLM 服务：开关 + OpenAI 兼容 base URL + 模型名 + API key。
// 开关/URL/模型经 PresentationPrefs 门面（R-prefs）；key 经 LlmCredentials 安全存储
//（仅平台安全存储，不落明文、不进日志、不回显）。未配置时小怪兽行为等同现状。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/application/presentation_prefs.dart';
import 'package:word_app/core/infrastructure/llm_credentials.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/mw_modal.dart';

/// 弹出 AI 伙伴设置底部 sheet。
Future<void> showLlmSettingsSheet(BuildContext context) {
  return MwModal.show(context, mode: MwModalMode.bottom, title: 'AI 伙伴设置', child: const _LlmSettingsBody());
}

class _LlmSettingsBody extends StatefulWidget {
  const _LlmSettingsBody();
  @override
  State<_LlmSettingsBody> createState() => _LlmSettingsBodyState();
}

class _LlmSettingsBodyState extends State<_LlmSettingsBody> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _keyCtrl;
  late bool _enabled;
  bool _keyLoaded = false;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<PresentationPrefs>();
    _enabled = prefs.llmEnabled;
    _urlCtrl = TextEditingController(text: prefs.llmBaseUrl);
    _modelCtrl = TextEditingController(text: prefs.llmModel);
    _keyCtrl = TextEditingController();
    unawaited(_loadKey());
  }

  Future<void> _loadKey() async {
    final key = await LlmCredentials().readKey();
    if (!mounted) return;
    // 已配置 key 时以占位符示意（不回显真实密钥）；用户清空占位符即视为删除。
    _keyCtrl.text = key.isEmpty ? '' : '••••••••';
    setState(() => _keyLoaded = true);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _modelCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = context.read<PresentationPrefs>();
    await prefs.setLlmEnabled(_enabled);
    await prefs.setLlmBaseUrl(_urlCtrl.text.trim());
    await prefs.setLlmModel(_modelCtrl.text.trim());
    // 占位符未改动 → 不覆写已存密钥；用户输入新值或清空 → 写入/删除。
    final keyText = _keyCtrl.text;
    if (_keyLoaded && keyText != '••••••••') {
      await LlmCredentials().writeKey(keyText.trim());
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile.adaptive(
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            title: Text('启用 AI 伙伴', style: TextStyle(color: colors.text1)),
            subtitle: Text('关闭时小怪兽保持原有台词，不联网', style: TextStyle(color: colors.text3)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: '服务地址（OpenAI 兼容 base URL）',
              hintText: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(
              labelText: '模型名',
              hintText: 'qwen-plus',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key（仅存本机安全存储）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
