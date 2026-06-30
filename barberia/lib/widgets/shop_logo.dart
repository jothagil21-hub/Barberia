import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class ShopLogo extends StatelessWidget {
  const ShopLogo({
    super.key,
    this.logoPath,
    this.cacheKey,
    this.radius = 24,
    this.iconSize,
  });

  final String? logoPath;
  final String? cacheKey;
  final double radius;
  final double? iconSize;

  static void evictCache(String? logoPath) {
    if (logoPath == null || logoPath.isEmpty) return;
    final file = File(logoPath);
    if (file.existsSync()) {
      imageCache.evict(FileImage(file));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = iconSize ?? radius;
    final path = logoPath;

    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      final image = FileImage(File(path));
      return CircleAvatar(
        key: cacheKey != null ? ValueKey(cacheKey) : null,
        radius: radius,
        backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
        backgroundImage: image,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
      child: Icon(
        Icons.content_cut,
        color: AppTheme.accent,
        size: size,
      ),
    );
  }
}
