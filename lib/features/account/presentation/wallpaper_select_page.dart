// 壁纸选择页面：展示可用壁纸列表，支持预览、选择和自定义上传
// 对应原版 App 的"外观&沉浸场景"设置
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../data/wallpaper_data.dart';
import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';

class WallpaperSelectPage extends StatefulWidget {
  const WallpaperSelectPage({super.key});

  static const routeName = '/wallpaper_select';

  @override
  State<WallpaperSelectPage> createState() => _WallpaperSelectPageState();
}

class _WallpaperSelectPageState extends State<WallpaperSelectPage> {
  WallpaperItem _selected = WallpaperData.defaultWallpaper;
  WallpaperItem? _previewing;
  List<WallpaperItem> _customWallpapers = [];

  @override
  void initState() {
    super.initState();
    _loadCurrent();
    _loadCustomWallpapers();
  }

  Future<void> _loadCurrent() async {
    final current = await WallpaperData.loadSelected();
    if (mounted) setState(() => _selected = current);
  }

  Future<void> _loadCustomWallpapers() async {
    final custom = await WallpaperData.loadCustomWallpapers();
    if (mounted) setState(() => _customWallpapers = custom);
  }

  Future<void> _selectWallpaper(WallpaperItem item) async {
    setState(() {
      _selected = item;
      _previewing = null;
    });
    await WallpaperData.saveSelected(item.id);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已切换为「${item.name}」壁纸'), duration: const Duration(seconds: 1)));
    }
  }

  /// 上传自定义壁纸
  Future<void> _uploadCustomWallpaper() async {
    try {
      const typeGroup = XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp']);
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;

      final filePath = file.path;
      if (filePath.isEmpty) return;

      // 创建自定义壁纸
      final customItem = WallpaperItem(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: '自定义壁纸',
        type: WallpaperType.custom,
        filePath: filePath,
      );

      await WallpaperData.addCustomWallpaper(customItem);
      await _loadCustomWallpapers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('壁纸上传成功！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败：$e')));
      }
    }
  }

  /// 删除自定义壁纸
  Future<void> _deleteCustomWallpaper(WallpaperItem item) async {
    await WallpaperData.removeCustomWallpaper(item.id);
    // 如果当前选中的是被删除的壁纸，切换到默认
    if (_selected.id == item.id) {
      await _selectWallpaper(WallpaperData.defaultWallpaper);
    }
    await _loadCustomWallpapers();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除自定义壁纸')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final preview = _previewing ?? _selected;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin),
            Container(height: 1, color: skin.divider),
            // 预览区
            _buildPreview(skin, preview),
            // 壁纸列表
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 自定义壁纸上传按钮
                    _buildUploadButton(skin),
                    SizedBox(height: 20),
                    // 自定义壁纸列表
                    if (_customWallpapers.isNotEmpty) ...[
                      _buildSectionTitle(skin, '我的自定义壁纸'),
                      SizedBox(height: 8),
                      _buildCustomGrid(skin),
                      SizedBox(height: 20),
                    ],
                    _buildSectionTitle(skin, '纯色'),
                    SizedBox(height: 8),
                    _buildColorTile(skin, WallpaperData.defaultWallpaper),
                    SizedBox(height: 20),
                    _buildSectionTitle(skin, '渐变'),
                    SizedBox(height: 8),
                    ...WallpaperData.gradientWallpapers.map(
                      (w) => Padding(padding: EdgeInsets.only(bottom: 8), child: _buildGradientTile(skin, w)),
                    ),
                    SizedBox(height: 20),
                    _buildSectionTitle(skin, '壁纸'),
                    SizedBox(height: 8),
                    _buildImageGrid(skin),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(ThemeVars skin) {
    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.text1,
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 4),
          Text('外观 & 沉浸场景', style: MistralTypography.heading5.copyWith(color: skin.text1)),
        ],
      ),
    );
  }

  Widget _buildUploadButton(ThemeVars skin) {
    return GestureDetector(
      onTap: _uploadCustomWallpaper,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: skin.cardBg,
          borderRadius: BorderRadius.circular(context.design.radius.lg),
          border: Border.all(color: skin.divider, width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 32, color: skin.accent),
              SizedBox(height: 4),
              Text('上传自定义壁纸', style: MistralTypography.bodyMd.copyWith(color: skin.accent)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(ThemeVars skin, WallpaperItem item) {
    return Container(
      width: double.infinity,
      height: 200,
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.design.radius.xl),
        color: (item.colors != null && item.colors!.isNotEmpty) ? item.colors!.first : Colors.grey.shade200,
        gradient: item.type == WallpaperType.gradient && item.colors != null && item.colors!.length > 1
            ? LinearGradient(
                colors: item.colors!,
                begin: item.begin ?? Alignment.topCenter,
                end: item.end ?? Alignment.bottomCenter,
              )
            : null,
      ),
      child: item.type == WallpaperType.image && (item.assetPath != null || item.filePath != null)
          ? ClipRRect(
              borderRadius: BorderRadius.circular(context.design.radius.xl),
              child: item.filePath != null
                  ? Image.file(File(item.filePath!), fit: BoxFit.cover)
                  : Image.asset(item.assetPath!, fit: BoxFit.cover),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wallpaper, size: 48, color: skin.text3),
                  SizedBox(height: 8),
                  Text(
                    item.name,
                    style: TextStyle(color: skin.text1, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(ThemeVars skin, String title) {
    return Text(title, style: MistralTypography.bodyBold.copyWith(color: skin.text1));
  }

  Widget _buildColorTile(ThemeVars skin, WallpaperItem item) {
    final isSelected = _selected.id == item.id;
    return GestureDetector(
      onTap: () => _selectWallpaper(item),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: (item.colors != null && item.colors!.isNotEmpty) ? item.colors!.first : Colors.white,
          borderRadius: BorderRadius.circular(context.design.radius.md),
          border: Border.all(
            color: isSelected ? skin.accent : skin.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 16),
            Icon(Icons.color_lens, color: skin.text3),
            SizedBox(width: 12),
            Text(item.name, style: MistralTypography.body.copyWith(color: skin.text1)),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: skin.accent),
            SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientTile(ThemeVars skin, WallpaperItem item) {
    final isSelected = _selected.id == item.id;
    return GestureDetector(
      onTap: () => _selectWallpaper(item),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: (item.colors != null && item.colors!.length > 1)
              ? LinearGradient(
                  colors: item.colors!,
                  begin: item.begin ?? Alignment.topCenter,
                  end: item.end ?? Alignment.bottomCenter,
                )
              : null,
          borderRadius: BorderRadius.circular(context.design.radius.md),
          border: Border.all(
            color: isSelected ? skin.accent : skin.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 16),
            Text(item.name, style: MistralTypography.body.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomGrid(ThemeVars skin) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _customWallpapers.map((item) {
        final isSelected = _selected.id == item.id;
        return GestureDetector(
          onTap: () => _selectWallpaper(item),
          onLongPress: () => _showDeleteDialog(item),
          child: Container(
            width: 100,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.design.radius.md),
              border: Border.all(
                color: isSelected ? skin.accent : skin.divider,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.design.radius.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.filePath != null) Image.file(File(item.filePath!), fit: BoxFit.cover),
                  if (isSelected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(color: skin.accent, shape: BoxShape.circle),
                        child: const Icon(Icons.check, size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageGrid(ThemeVars skin) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: WallpaperData.imageWallpapers.length,
      itemBuilder: (context, index) {
        final item = WallpaperData.imageWallpapers[index];
        final isSelected = _selected.id == item.id;
        return GestureDetector(
          onTap: () => _selectWallpaper(item),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.design.radius.md),
              border: Border.all(
                color: isSelected ? skin.accent : Colors.transparent,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.design.radius.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.assetPath != null
                      ? Image.asset(item.assetPath!, fit: BoxFit.cover)
                      : Container(color: skin.cardBg),
                  if (isSelected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(color: skin.accent, shape: BoxShape.circle),
                        child: const Icon(Icons.check, size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(WallpaperItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除壁纸'),
        content: Text('确定要删除「${item.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCustomWallpaper(item);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
