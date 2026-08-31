// 由 Claude 团队生成 | Monster Word App
import 'package:flutter/material.dart';

import 'package:word_app/core/di/service_locator.dart';
import 'package:word_app/core/router/nav_utils.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/core/repositories/word_repository.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_page.dart';

/// 按单词名深链进入词典（P2-7）。
///
/// 背景：词典页 [DictionaryPage] 只接受完整的 [Word] 对象参数；外部深链（uri 或
/// 序列化路径）往往只携带一个单词原文 `wordName`。此页负责把「单词名 → Word」
/// 的异步解析封装在路由入口处：
/// - 解析中：展示加载态，AppBar 提供 [NavUtils.safePop] 安全返回；
/// - 命中：渲染 [DictionaryPage]；
/// - 未命中 / 查询异常：展示友好错误态，可安全返回或逐级回首页。
///
/// 路由入口见 `lib/core/router/content_routes.dart`（`RouteNames.dictionaryByName`）。
class DictionaryByNamePage extends StatefulWidget {
  final String wordName;

  const DictionaryByNamePage({super.key, required this.wordName});

  @override
  State<DictionaryByNamePage> createState() => _DictionaryByNamePageState();
}

class _DictionaryByNamePageState extends State<DictionaryByNamePage> {
  Word? _word;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final word = await sl<WordRepository>().getWordByText(widget.wordName);
      if (!mounted) return;
      setState(() {
        _word = word;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '返回',
            onPressed: () => NavUtils.safePop(context),
          ),
          title: Text('词典 · ${widget.wordName}'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final word = _word;
    if (word != null) {
      return DictionaryPage(word: word);
    }

    return _NotFoundScaffold(wordName: widget.wordName, failed: _failed);
  }
}

class _NotFoundScaffold extends StatelessWidget {
  final String wordName;
  final bool failed;

  const _NotFoundScaffold({required this.wordName, required this.failed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
          onPressed: () => NavUtils.safePop(context),
        ),
        title: const Text('词典'),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(failed ? Icons.error_outline : Icons.search_off, size: 56, color: const Color(0xFFB0885A)),
              SizedBox(height: 16),
              Text(
                failed ? '查询失败' : '未找到「$wordName」',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3D3630)),
              ),
              SizedBox(height: 8),
              Text(failed ? '请稍后重试' : '该单词可能不在当前词库中', style: const TextStyle(fontSize: 13, color: Color(0xFF8A8078))),
              SizedBox(height: 24),
              Builder(
                builder: (ctx) => ElevatedButton.icon(
                  onPressed: () => NavUtils.goHome(ctx),
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: const Text('返回首页'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006241),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
