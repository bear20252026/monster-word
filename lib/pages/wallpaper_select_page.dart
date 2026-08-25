// 壁纸选择页面：展示可用壁纸列表，支持预览、选择和自定义上传
// 对应原版 App 的"外观&沉浸场景"设置
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../data/wallpaper_data.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已切换为「${item.name}」壁纸'),
          duration: const Duration(seconds: 1),
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('壁纸上传成功！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败：$e')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除自定义壁纸')),
      );
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
            _buildPreview(preview),
            // 壁纸列表
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 自定义壁纸上传按钮
                    _buildUploadButton(skin),
                    const SizedBox(height: 20),
                    // 自定义壁纸列表
                    if (_customWallpapers.isNotEmpty) ...[
                      _buildSectionTitle(skin, '我的自定义壁纸'),
                      const SizedBox(height: 8),
                      _buildCustomGrid(skin),
                      const SizedBox(height: 20),
                    ],
                    _buildSectionTitle(skin, '纯色'),
                    const SizedBox(height: 8),
                    _buildColorTile(skin, WallpaperData.defaultWallpaper),
                    const SizedBox(height: 20),
                    _buildSectionTitle(skin, '渐变'),
                    const SizedBox(height: 8),
                    ...WallpaperData.gradientWallpapers.map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildGradientTile(skin, w),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle(skin, '壁纸'),
                    const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            '外观 & 沉浸场景',
            style: MistralTypography.heading5.copyWith(color: skin.text1),
          ),
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
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: skin.divider, width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 32, color: skin.accent),
              const SizedBox(height: 4),
              Text('上传自定义壁纸',
                  style: MistralTypography.bodyMd.copyWith(color: skin.accent)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(WallpaperItem wallpaper) {
    return Container(
      width: double.infinity,
      height: 180,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: MistralColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildWallpaperDecoration(wallpaper, height: 180),
    );
  }

  Widget _buildWallpaperDecoration(WallpaperItem wallpaper, {double? height}) {
    // 自定义壁纸（本地文件）
    if (wallpaper.type == WallpaperType.custom && wallpaper.filePath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(wallpaper.filePath!),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [MistralColors.cream, MistralColors.slate],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Icon(Icons.wallpaper, size: 48, color: MistralColors.white54),
              ),
            ),
          ),
          // 半透明遮罩 + 模拟首页内容
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, MistralColors.black15],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Monster',
                  style: MistralTypography.heading1.copyWith(
                    color: AppColors.white100,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: MistralColors.black26, blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.white100.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Learn 10  ·  Review 0',
                    style: MistralTypography.bodySm.copyWith(color: AppColors.white100),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // assets 图片壁纸
    if (wallpaper.type == WallpaperType.image && wallpaper.assetPath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            wallpaper.assetPath!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: wallpaper.colors ?? [MistralColors.cream],
                  begin: wallpaper.begin ?? Alignment.topCenter,
                  end: wallpaper.end ?? Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Icon(Icons.wallpaper, size: 48, color: MistralColors.white54),
              ),
            ),
          ),
          // 半透明遮罩 + 模拟首页内容
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, MistralColors.black15],
              ),
            ),
          ),
          // 模拟 HeroWord
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Monster',
                  style: MistralTypography.heading1.copyWith(
                    color: AppColors.white100,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: MistralColors.black26, blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.white100.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Learn 10  ·  Review 0',
                    style: MistralTypography.bodySm.copyWith(color: AppColors.white100),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 纯色/渐变
    return Container(
      decoration: BoxDecoration(
        gradient: wallpaper.colors != null && wallpaper.colors!.length > 1
            ? LinearGradient(
                colors: wallpaper.colors!,
                begin: wallpaper.begin ?? Alignment.topCenter,
                end: wallpaper.end ?? Alignment.bottomCenter,
              )
            : null,
        color: wallpaper.colors?.first,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Monster',
              style: MistralTypography.heading1.copyWith(
                color: wallpaper.id == 'default'
                    ? MistralColors.ink
                    : AppColors.white100.withValues(alpha: 0.9),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: (wallpaper.id == 'default'
                        ? MistralColors.ink
                        : AppColors.white100)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                'Learn 10  ·  Review 0',
                style: MistralTypography.bodySm.copyWith(
                  color: wallpaper.id == 'default'
                      ? MistralColors.slate
                      : MistralColors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeVars skin, String title) {
    return Text(
      title,
      style: MistralTypography.bodyBold.copyWith(color: skin.text1),
    );
  }

  Widget _buildColorTile(ThemeVars skin, WallpaperItem wallpaper) {
    final isSelected = _selected.id == wallpaper.id;
    return GestureDetector(
      onTap: () => _selectWallpaper(wallpaper),
      onTapDown: (_) => setState(() => _previewing = wallpaper),
      onTapUp: (_) => setState(() => _previewing = null),
      onTapCancel: () => setState(() => _previewing = null),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: wallpaper.colors?.first,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? MistralColors.primary : skin.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              wallpaper.name,
              style: MistralTypography.bodyMd.copyWith(
                color: MistralColors.ink,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: MistralColors.primary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientTile(ThemeVars skin, WallpaperItem wallpaper) {
    final isSelected = _selected.id == wallpaper.id;
    return GestureDetector(
      onTap: () => _selectWallpaper(wallpaper),
      onTapDown: (_) => setState(() => _previewing = wallpaper),
      onTapUp: (_) => setState(() => _previewing = null),
      onTapCancel: () => setState(() => _previewing = null),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: wallpaper.colors!,
            begin: wallpaper.begin ?? Alignment.centerLeft,
            end: wallpaper.end ?? Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? MistralColors.primary : MistralColors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              wallpaper.name,
              style: MistralTypography.bodyMd.copyWith(
                color: AppColors.white100,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                shadows: [Shadow(color: MistralColors.black26, blurRadius: 4)],
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.white100, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(ThemeVars skin) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: WallpaperData.imageWallpapers.map((wallpaper) {
        final isSelected = _selected.id == wallpaper.id;
        return GestureDetector(
          onTap: () => _selectWallpaper(wallpaper),
          onTapDown: (_) => setState(() => _previewing = wallpaper),
          onTapUp: (_) => setState(() => _previewing = null),
          onTapCancel: () => setState(() => _previewing = null),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isSelected ? MistralColors.primary : skin.divider,
                width: isSelected ? 3 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 壁纸图片（带 fallback）
                Image.asset(
                  wallpaper.assetPath!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: wallpaper.colors!,
                        begin: wallpaper.begin ?? Alignment.topCenter,
                        end: wallpaper.end ?? Alignment.bottomCenter,
                      ),
                    ),
                    child: Icon(Icons.wallpaper, size: 36, color: MistralColors.white54),
                  ),
                ),
                // 底部名称 + 选中标记
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, MistralColors.black54],
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          wallpaper.name,
                          style: MistralTypography.bodySm.copyWith(color: AppColors.white100),
                        ),
                        const Spacer(),
                        if (isSelected)
                          Icon(Icons.check_circle, color: AppColors.white100, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomGrid(ThemeVars skin) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: _customWallpapers.map((wallpaper) {
        final isSelected = _selected.id == wallpaper.id;
        return GestureDetector(
          onTap: () => _selectWallpaper(wallpaper),
          onTapDown: (_) => setState(() => _previewing = wallpaper),
          onTapUp: (_) => setState(() => _previewing = null),
          onTapCancel: () => setState(() => _previewing = null),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isSelected ? MistralColors.primary : skin.divider,
                width: isSelected ? 3 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 自定义壁纸图片
                if (wallpaper.filePath != null)
                  Image.file(
                    File(wallpaper.filePath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: MistralColors.slate,
                      child: Icon(Icons.wallpaper, size: 36, color: MistralColors.white54),
                    ),
                  )
                else
                  Container(
                    color: MistralColors.slate,
                    child: Icon(Icons.wallpaper, size: 36, color: MistralColors.white54),
                  ),
                // 底部名称 + 选中标记 + 删除按钮
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, MistralColors.black54],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            wallpaper.name,
                            style: MistralTypography.bodySm.copyWith(color: AppColors.white100),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, color: AppColors.white100, size: 18),
                      ],
                    ),
                  ),
                ),
                // 删除按钮
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _deleteCustomWallpaper(wallpaper),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: MistralColors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
