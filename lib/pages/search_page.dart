// 由账号4生成
// 查词工具：下拉词典窗口
// 手机端：下拉显示 | 桌面端：首页左上按钮点击显示
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../data/example_parser.dart';
import '../data/wordbook_database.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  static const routeName = '/search';

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Word> _results = [];
  Word? _selectedWord;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results = []; _selectedWord = null; });
      return;
    }
    setState(() {});
    final results = await WordBookDatabase.instance.searchWords(query.trim(), limit: 30);
    setState(() {
      _results = results;
      _selectedWord = results.isNotEmpty ? results.first : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 搜索栏
            _buildSearchBar(),
            // 结果
            Expanded(
              child: _selectedWord != null
                  ? _buildWordDetail(_selectedWord!)
                  : _results.isNotEmpty
                      ? _buildResultList()
                      : _buildEmpty(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '输入单词查询...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                border: InputBorder.none,
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _controller.clear();
                          _search('');
                        },
                      )
                    : null,
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              onChanged: _search,
              onSubmitted: _search,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final w = _results[i];
        return ListTile(
          title: Text(w.word, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          subtitle: Text(
            w.interpret.split('\n').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          selected: _selectedWord?.word == w.word,
          selectedTileColor: Colors.green.shade50,
          onTap: () => setState(() => _selectedWord = w),
        );
      },
    );
  }

  Widget _buildWordDetail(Word word) {
    final examples = ExampleParser.parse(word.example);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 单词
          Text(word.word, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // 音标
          if (word.usPron.isNotEmpty || word.ukPron.isNotEmpty)
            Row(
              children: [
                if (word.usPron.isNotEmpty)
                  Text('美 /${word.usPron}/  ', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                if (word.ukPron.isNotEmpty)
                  Text('英 /${word.ukPron}/', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _playAudio(word.word),
                  child: Icon(Icons.volume_up, color: Colors.green.shade600, size: 22),
                ),
              ],
            ),
          const Divider(height: 32),
          // 释义
          ...word.interpretLines.map((line) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(line, style: const TextStyle(fontSize: 17, height: 1.5)),
          )),
          // 例句
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('例句', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...examples.take(3).map((ex) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                      children: ex.highlightedParts.map((p) => TextSpan(
                        text: p.text,
                        style: p.highlight
                            ? const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2FA89F))
                            : null,
                      )).toList(),
                    ),
                  ),
                  if (ex.cn.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(ex.cn, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('输入单词开始查询', style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Future<void> _playAudio(String word) async {
    try {
      final player = AudioPlayer();
      await player.play(UrlSource(
        'http://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word)}&type=2',
      ));
    } catch (_) {}
  }
}
