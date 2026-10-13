// 词表导出页面
// 支持导出为 TXT / CSV / 分享文本
import 'package:word_app/widgets/common/mw_feedback.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:word_app/core/parsers/example_parser.dart';
import 'package:word_app/core/parsers/phrase_parser.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/book/application/book_word_list_reader.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/mw_nav_bar.dart';

enum ExportFormat { txt, csv, markdown }

class WordExportPage extends StatefulWidget {
  final int bookId;
  final String bookName;

  const WordExportPage({super.key, required this.bookId, this.bookName = ''});

  static const routeName = RouteNames.wordExport;

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
                        Text('导出词表', style: MwTypography.heading4.copyWith(color: skin.colors.text1)),
                        const SizedBox(height: 8),
                        Text(
                          widget.bookName.isNotEmpty ? widget.bookName : '当前词书',
                          style: MwTypography.body.copyWith(color: skin.colors.text3),
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
    // 审计 I1：实现收敛至 MwNavBar 单一真相
    return MwNavBar(title: '导出词表', onBack: () => Navigator.pop(context), height: 56);
  }

  Widget _buildSectionTitle(String title, SkinSystem skin) {
    return Text(title, style: MwTypography.bodyBold.copyWith(color: skin.colors.text1));
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
      selectedColor: context.skin.colors.accent,
      labelStyle: MwTypography.bodySm.copyWith(color: selected ? AppColors.white100 : skin.colors.text1),
      backgroundColor: skin.colors.cardBgAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.design.radius.lg),
        side: BorderSide(color: selected ? context.skin.colors.accent : skin.colors.divider),
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
      title: Text(title, style: MwTypography.body.copyWith(color: skin.colors.text1)),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      activeColor: context.skin.colors.accent,
      checkColor: AppColors.white100,
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
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: skin.colors.text2),
                  )
                : const Icon(Icons.download, size: 18),
            label: Text(_exporting ? '导出中...' : '保存文件'),
            style: OutlinedButton.styleFrom(
              foregroundColor: skin.colors.text1,
              side: BorderSide(color: skin.colors.divider),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.lg)),
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
              backgroundColor: context.skin.colors.accent,
              foregroundColor: AppColors.white100,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.lg)),
            ),
          ),
        ),
      ],
    );
  }

  Future<List<Word>> _loadWords() {
    return context.read<BookWordListReader>().loadWords(widget.bookId);
  }

  /// MW-31：RFC 4180 CSV 单元格——内部双引号必须编码为两个双引号，
  /// 否则原始 JSON 释义中的 " 会破坏列结构（Excel 拆列错乱）。
  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  /// MW-30：Markdown 单元格——竖线与换行必须转义，否则多出表格列。
  String _mdCell(String value) => value.replaceAll('|', '\\|').replaceAll('\n', '<br>');

  String _generateContent(List<Word> words) {
    final buffer = StringBuffer();

    switch (_format) {
      case ExportFormat.txt:
        for (final w in words) {
          buffer.write(w.word);
          if (_includePhonetic && w.usPron.isNotEmpty) buffer.write('  ${w.usPron}');
          // MW-30：导出可读释义（cleanInterpret 已把结构化 JSON 转人话），
          // 不再输出原始 interpret JSON。
          buffer.write('  ${w.cleanInterpret}');
          if (_includePhrase && PhraseParser.hasData(w.phrase)) {
            buffer.write('\n  短语:');
            for (final p in PhraseParser.flatItems(w.phrase)) {
              buffer.write('\n    ${p.en}　${p.cn}');
              if (p.exams.isNotEmpty) buffer.write(' [${p.exams.join(', ')}]');
            }
          }
          if (_includeExample && ExampleParser.parse(w.example).isNotEmpty) {
            buffer.write('\n  例句:');
            for (final ex in ExampleParser.parse(w.example)) {
              buffer.write('\n    ${ex.cleanEn}');
              if (ex.cn.isNotEmpty) buffer.write(' — ${ex.cn}');
              if (ex.source.isNotEmpty) buffer.write(' (${ex.source})');
            }
          }
          buffer.writeln('\n');
        }
        break;

      case ExportFormat.csv:
        buffer.writeln('单词,音标,释义${_includePhrase ? ",短语" : ""}${_includeExample ? ",例句" : ""}');
        for (final w in words) {
          // MW-31：所有列统一走 _csvCell（内部引号双写转义）。
          // R2-10：列之间必须有分隔符——此前只 write 单元格本身，产出
          // `"apple""ˈæpl""苹果"` 这种无效 CSV（Excel 会并成一列，且与上面
          // 用逗号写的表头行对不上）。改为先收集再 join(',')，以后加列也
          // 不会再漏写逗号。
          final cells = <String>[
            _csvCell(w.word),
            _includePhonetic ? _csvCell(w.usPron) : _csvCell(''),
            _csvCell(w.cleanInterpret),
          ];
          if (_includePhrase) {
            final phrases = PhraseParser.flatItems(w.phrase);
            cells.add(_csvCell(phrases.map((p) => '${p.en}　${p.cn}').join('; ')));
          }
          if (_includeExample) {
            final examples = ExampleParser.parse(w.example);
            cells.add(_csvCell(examples.map((ex) => ex.cleanEn).join('; ')));
          }
          buffer.writeln(cells.join(','));
        }
        break;

      case ExportFormat.markdown:
        buffer.writeln('# ${widget.bookName.isNotEmpty ? widget.bookName : '词表导出'}');
        buffer.writeln();
        buffer.writeln('| 单词 | 音标 | 释义 |${_includePhrase ? ' 短语 |' : ''}${_includeExample ? ' 例句 |' : ''}');
        buffer.writeln('|------|------|------|${_includePhrase ? '------|' : ''}${_includeExample ? '------|' : ''}');
        for (final w in words) {
          buffer.write('| ${_mdCell(w.word)} | ');
          buffer.write(_includePhonetic ? _mdCell(w.usPron.isEmpty ? '-' : w.usPron) : '-');
          buffer.write(' | ${_mdCell(w.cleanInterpret)} |');
          if (_includePhrase) {
            final phrases = PhraseParser.flatItems(w.phrase);
            final text = phrases.map((p) => '${p.en}　${p.cn}').join('<br>');
            buffer.write(text.isEmpty ? ' - |' : ' ${_mdCell(text)} |');
          }
          if (_includeExample) {
            final examples = ExampleParser.parse(w.example);
            final text = examples.map((ex) => ex.cleanEn).join('<br>');
            buffer.write(text.isEmpty ? ' - |' : ' ${_mdCell(text)} |');
          }
          buffer.writeln();
        }
        break;
    }

    return buffer.toString();
  }

  String _getExtension() {
    switch (_format) {
      case ExportFormat.txt:
        return 'txt';
      case ExportFormat.csv:
        return 'csv';
      case ExportFormat.markdown:
        return 'md';
    }
  }

  String _getFileName() {
    final name = widget.bookName.isNotEmpty ? widget.bookName : '词表';
    final ext = _getExtension();
    // 文件名消毒：Windows/Android 非法字符与控制符替换为下划线
    //（词书名可能含斜杠/冒号/引号等）。
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
    return '${safeName}_导出.$ext';
  }

  Future<void> _exportAsFile() async {
    setState(() => _exporting = true);
    try {
      final words = await _loadWords();
      if (words.isEmpty) {
        if (mounted) {
          showMwSnackBar(context, const SnackBar(content: Text('该词书暂无单词可导出')));
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
        showMwSnackBar(
          context,
          SnackBar(
            content: Text('已导出 ${words.length} 个单词到文档目录'),
            action: SnackBarAction(label: '分享', onPressed: () => Share.shareXFiles([XFile(filePath)])),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showMwSnackBar(context, SnackBar(content: Text('导出失败: $e')));
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
          showMwSnackBar(context, const SnackBar(content: Text('该词书暂无单词可导出')));
        }
        return;
      }

      final content = _generateContent(words);
      final fileName = _getFileName();

      // 保存到临时目录并分享
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(content);

      await Share.shareXFiles([XFile(file.path)], subject: '${widget.bookName.isNotEmpty ? widget.bookName : "词表"}导出');
      // 安全审计 P3-2：临时文件含用户学习数据，分享完成后立即删除
      // （系统 Temp 目录不会主动清理子文件，多账户机器可被枚举）。
      try {
        if (file.existsSync()) await file.delete();
      } catch (_) {
        // C 级豁免：清理失败仅残留临时文件，无功能影响
      }
    } catch (e) {
      if (mounted) {
        showMwSnackBar(context, SnackBar(content: Text('分享失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
