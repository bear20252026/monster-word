from pathlib import Path

p = Path(r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\monster-word-wt-mem\lib\core\infrastructure\wordbook_database.dart")
src = p.read_text(encoding="utf-8")
old = """  Future<void> _extractTo(String dbPath, Uint8List gzBytes) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final dbBytes = GZipDecoder().decodeBytes(gzBytes);
        await File(dbPath).writeAsBytes(dbBytes, flush: true);
        return;
      } catch (e) {
        debugPrint('[WordBookDatabase] 解压失败 (attempt ${attempt + 1}): $e');
        final f = File(dbPath);
        if (f.existsSync()) f.deleteSync();
        if (attempt == 1) rethrow;
      }
    }
  }"""
new = """  Future<void> _extractTo(String dbPath, Uint8List gzBytes) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final tmpGz = '$dbPath.extract.gz';
        await File(tmpGz).writeAsBytes(gzBytes, flush: true);
        try {
          final input = InputFileStream(tmpGz);
          final output = OutputFileStream(dbPath);
          await GZipDecoder().decodeStream(input, output);
          await output.close();
        } finally {
          try {
            await File(tmpGz).delete();
          } catch (_) {}
        }
        return;
      } catch (e) {
        debugPrint('[WordBookDatabase] 解压失败 (attempt ${attempt + 1}): $e');
        final f = File(dbPath);
        if (f.existsSync()) f.deleteSync();
        if (attempt == 1) rethrow;
      }
    }
  }"""
if old not in src:
    # try to find actual body
    idx = src.find("Future<void> _extractTo")
    print("extract idx", idx)
    print(repr(src[idx:idx+400]))
else:
    src = src.replace(old, new, 1)
    p.write_text(src, encoding="utf-8")
    print("extract replaced")

# forceRebuild cleanup messy comments
src = p.read_text(encoding="utf-8")
src = src.replace(
    "        // MEM-01：走流式 _extractTo，不再 decodeBytes 整包进堆\n        await _extractTo(dbPath, gzBytes);\n        return;\n    await _extractTo(dbPath, gzBytes);",
    "    await _extractTo(dbPath, gzBytes);",
)
# also drop gzBytes ref after extract in forceRebuild - can't if used for hash
# hash uses gzBytes after extract - compute hash first then extract then done
src = src.replace(
    """    await _extractTo(dbPath, gzBytes);

    // 4) 记录哈希，避免下次自动更新重复重建
    final assetHash = base64.encode(md5.convert(gzBytes).bytes);""",
    """    final assetHash = base64.encode(md5.convert(gzBytes).bytes);
    await _extractTo(dbPath, gzBytes);
    // MEM-01：重建路径同样走流式解压（_extractTo），gz 引用随函数返回释放。

    // 4) 记录哈希，避免下次自动更新重复重建""",
)
p.write_text(src, encoding="utf-8")
print("decodeBytes left", src.count("decodeBytes"))
print("decodeStream", src.count("decodeStream"))
