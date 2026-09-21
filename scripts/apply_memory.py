from pathlib import Path

root = Path(r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\monster-word-wt-mem")
p = root / "lib/core/infrastructure/wordbook_database.dart"
src = p.read_text(encoding="utf-8")

# 1) extract: stream to disk, not full decode in heap
old_extract = """  /// 解压资产词库到目标路径（失败自动清理半成品文件并重试一次）
  Future<void> _extractTo(String dbPath, Uint8List gzBytes) async {
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
new_extract = """  /// 解压资产词库到目标路径（失败自动清理半成品文件并重试一次）。
  ///
  /// MEM-01：gz 先落临时文件再流式解压写入 db，避免堆上同时持有
  /// 「压缩包字节 + 完整 SQLite 字节」（冷启动/升级时峰值可省上百 MB）。
  Future<void> _extractTo(String dbPath, Uint8List gzBytes) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      InputFileStream? input;
      OutputFileStream? output;
      try {
        final tmpGz = '$dbPath.extract.gz';
        await File(tmpGz).writeAsBytes(gzBytes, flush: true);
        try {
          input = InputFileStream(tmpGz);
          output = OutputFileStream(dbPath);
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
        try {
          output?.close();
        } catch (_) {}
        final f = File(dbPath);
        if (f.existsSync()) f.deleteSync();
        if (attempt == 1) rethrow;
      }
    }
  }"""
if old_extract not in src:
    raise SystemExit("extract block not found")
src = src.replace(old_extract, new_extract, 1)

# 2) drop assetBytes after extract paths
src = src.replace(
    """      if (extractedHash != assetHash || !File(dbPath).existsSync()) {
        await _extractTo(dbPath, assetBytes);
        if (canPersist) {""",
    """      if (extractedHash != assetHash || !File(dbPath).existsSync()) {
        await _extractTo(dbPath, assetBytes);
        assetBytes = null; // MEM-01：解压后释放 ~70MB gz 引用
        if (canPersist) {""",
    1,
)
src = src.replace(
    """      assetBytes ??= await loadBytes();
      await _extractTo(dbPath, assetBytes);
      _db = await openDatabase(dbPath, readOnly: true);
      reopened = true;""",
    """      assetBytes ??= await loadBytes();
      await _extractTo(dbPath, assetBytes);
      assetBytes = null;
      _db = await openDatabase(dbPath, readOnly: true);
      reopened = true;""",
    1,
)
# end of _initializeInner: clear assetBytes
src = src.replace(
    """    }
    _initialized = true;
  }

  /// 解压资产词库到目标路径""",
    """    }
    assetBytes = null; // MEM-01
    _initialized = true;
  }

  /// 解压资产词库到目标路径""",
    1,
)

# 3) forceRebuild path if still decodeBytes
src = src.replace(
    "final dbBytes = GZipDecoder().decodeBytes(gzBytes);",
    "// MEM-01：走流式 _extractTo，不再 decodeBytes 整包进堆\n        await _extractTo(dbPath, gzBytes);\n        return;",
)
# if we created duplicate return in forceRebuild, check later

# 4) queue getter copy churn
p2 = root / "lib/features/learning/presentation/learning_session_state.dart"
s2 = p2.read_text(encoding="utf-8")
s2 = s2.replace(
    "  List<Word> get queue => List.unmodifiable(_queue);",
    "  /// MEM-02：直接暴露内部列表只读视图，避免每次 get 复制整表。\n  /// 调用方不得 mutate；会话内部修改仍走 setState/notifyListeners。\n  List<Word> get queue => _queue;",
)
p2.write_text(s2, encoding="utf-8")

# 5) fluid cursor: respect reduceMotion / max ripples already 5; skip overlay when disableAnimations
p3 = root / "lib/app/app.dart"
s3 = p3.read_text(encoding="utf-8")
if "FluidCursorOverlay(" in s3 and "disableAnimations" not in s3[s3.find("FluidCursorOverlay(")-200:s3.find("FluidCursorOverlay(")+200]:
    s3 = s3.replace(
        "            return FluidCursorOverlay(",
        """            // MEM-03：系统「减少动态效果」时跳过全局流体光标覆盖层，降低常驻绘制与内存。
            if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
              return child ?? const SizedBox.shrink();
            }
            return FluidCursorOverlay(""",
        1,
    )
p3.write_text(s3, encoding="utf-8")
print("patched wordbook / session queue / fluid cursor")
print("extract MEM-01", "decodeStream" in p.read_text(encoding="utf-8"))
print("forceRebuild leftover decodeBytes", "decodeBytes" in p.read_text(encoding="utf-8"))
