// 词表导出页面
// 支持导出为 TXT / CSV / 分享文本
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../data/wordbook_database.dart';
import '../hooks/responsive.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

enum ExportFormat { txt, csv, markdown }

class WordExportPage extends StatefulWidget {
  final int bookId;
  final String bookName;

  const WordExportPage({
    super.key,
    required this.bookId,
    this.bookName = '',
  });

  static const routeName = '/word_export';

  @override
  State<WordExportPage> createState() => _WordExportPageState();
}

class _WordExportPageState extends State<WordExportPage> {
  ExportFormat _format = ExportFormat.txt;
  bool _includePhonetic = true;
  bool _includeExample = true;
  bool _includePhrase = false;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: resp.contentMaxWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: resp.horizontalPadding),
                    child: ListView(
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          '导出词表',
                          style: MistralTypography.heading4.copyWith(color: skin.colors.text1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.bookName.isNotEmpty ? widget.bookName : '当前词书',
                          style: MistralTypography.body.copyWith(color: skin.colors.text3),
                        ),
                        const SizedBox(height: 32),
                        // 格式选择
                        _buildSectionTitle('导出格式', skin),
                        const SizedBox(height: 8),
                        _buildFormatSelector(skin),
                        const SizedBox(height: 24),
                        // 内容选项
                        _buildSectionTitle('包含内容', skin),
                        const SizedBox(height: 8),
                        _buildContentOptions(skin),
                        const SizedBox(height: 40),
                        // 导出按钮
                        _buildExportButtons(skin, resp),
                      ],
                    ),
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
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('导出词表', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, SkinSystem skin) {
    return Text(
      title,
      style: MistralTypography.bodyBold.copyWith(color: skin.colors.text1),
    );
  }

  Widget _buildFormatSelector(SkinSystem skin) {
    return Wrap(
      spacing: 8,
      children: [
        _formatChip('纯文本 (.txt)', ExportFormat.txt, skin),
        _formatChip('CSV表格 (.csv)', ExportFormat.csv, skin),
        _formatChip('Markdown (.md)', ExportFormat.markdown, skin),
      ],
    );
  }

  Widget _formatChip(String label, ExportFormat format, SkinSystem skin) {
    final selected = _format == format;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _format = format),
      selectedColor: MistralColors.primary,
      labelStyle: MistralTypography.bodySm.copyWith(
        color: selected ? Colors.white : skin.colors.text1,
      ),
      backgroundColor: skin.colors.cardBgAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: selected ? MistralColors.primary : skin.colors.divider),
      ),
    );
  }

  Widget _buildContentOptions(SkinSystem skin) {
    return Column(
      children: [
        _checkboxTile('包含音标', _includePhonetic, (v) => setState(() => _includePhonetic = v), skin),
        _checkboxTile('包含例句', _includeExample, (v) => setState(() => _includeExample = v), skin),
        _checkboxTile('包含短语', _includePhrase, (v) => setState(() => _includePhrase = v), skin),
      ],
    );
  }

  Widget _checkboxTile(String title, bool value, ValueChanged<bool> onChanged, SkinSystem skin) {
    return CheckboxListTile(
      title: Text(title, style: MistralTypography.body.copyWith(color: skin.colors.text1)),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      activeColor: MistralColors.primary,
      checkColor: Colors.white,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildExportButtons(SkinSystem skin, AppResponsive resp) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _exporting ? null : _exportAsFile,
            icon: _exporting
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: skin.colors.text2))
                : const Icon(Icons.download, size: 18),
            label: Text(_exporting ? '导出中...' : '保存文件'),
            style: OutlinedButton.styleFrom(
              foregroundColor: skin.colors.text1,
              side: BorderSide(color: skin.colors.divider),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _exporting ? null : _shareAsText,
            icon: const Icon(Icons.share, size: 18),
            label: const Text('分享文本'),
            style: ElevatedButton.styleFrom(
              backgroundColor: MistralColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
          ),
        ),
      ],
    );
  }

  Future<List<Word>> _loadWords() async {
    final learningState = context.read<LearningState>();
    return learningState.getWordsByBook(widget.bookId);
  }

  String _generateContent(List<Word> words) {
    final buffer = StringBuffer();

    switch (_format) {
      case ExportFormat.txt:
        for (final w in words) {
          buffer.write(w.word);
          if (_includePhonetic && w.usPron.isNotEmpty) buffer.write('  ${w.usPron}');
          buffer.write('  ${w.interpret}');
          if (_includePhrase && w.phrase.isNotEmpty) buffer.write('\n  短语: ${w.phrase}');
          if (_includeExample && w.example.isNotEmpty) buffer.write('\n  例句: ${w.example}');
          buffer.writeln('\n');
        }
        break;

      case ExportFormat.csv:
        buffer.writeln('单词,音标,释义${_includePhrase ? ",短语" : ""}${_includeExample ? ",例句" : ""}');
        for (final w in words) {
          buffer.write('"${w.word}"');
          buffer.write(_includePhonetic ? ',"${w.usPron}"' : ',""');
          buffer.write(',"${w.interpret}"');
          if (_includePhrase) buffer.write(',"${w.phrase}"');
          if (_includeExample) buffer.write(',"${w.example}"');
          buffer.writeln();
        }
        break;

      case ExportFormat.markdown:
        buffer.writeln('# ${widget.bookName.isNotEmpty ? widget.bookName : '词表导出'}');
        buffer.writeln();
        buffer.writeln('| 单词 | 音标 | 释义 |${_includePhrase ? ' 短语 |' : ''}${_includeExample ? ' 例句 |' : ''}');
        buffer.writeln('|------|------|------|${_includePhrase ? '------|' : ''}${_includeExample ? '------|' : ''}');
        for (final w in words) {
          buffer.write('| ${w.word} | ');
          buffer.write(_includePhonetic ? (w.usPron.isNotEmpty ? w.usPron : '-') : '-');
          buffer.write(' | ${w.interpret} |');
          if (_includePhrase) buffer.write(' ${w.phrase.isNotEmpty ? w.phrase : "-"} |');
          if (_includeExample) buffer.write(' ${w.example.isNotEmpty ? w.example : "-"} |');
          buffer.writeln();
        }
        break;
    }

    return buffer.toString();
  }

  String _getExtension() {
    switch (_format) {
      case ExportFormat.txt: return 'txt';
      case ExportFormat.csv: return 'csv';
      case ExportFormat.markdown: return 'md';
    }
  }

  String _getFileName() {
    final name = widget.bookName.isNotEmpty ? widget.bookName : '词表';
    final ext = _getExtension();
    return '${name}_导出.$ext';
  }

  Future<void> _exportAsFile() async {
    setState(() => _exporting = true);
    try {
      final words = await _loadWords();
      if (words.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('该词书暂无单词可导出')),
          );
        }
        return;
      }

      final content = _generateContent(words);
      final fileName = _getFileName();

      // 保存到文档目录
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);
      await file.writeAsString(content);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导出 ${words.length} 个单词到文档目录'),
            action: SnackBarAction(
              label: '分享',
              onPressed: () => Share.shareXFiles([XFile(filePath)]),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareAsText() async {
    setState(() => _exporting = true);
    try {
      final words = await _loadWords();
      if (words.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('该词书暂无单词可导出')),
          );
        }
        return;
      }

      final content = _generateContent(words);
      final fileName = _getFileName();

      // 保存到临时目录并分享
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(content);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${widget.bookName.isNotEmpty ? widget.bookName : "词表"}导出',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
