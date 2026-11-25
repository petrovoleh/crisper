import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/crisper_theme.dart';

class CrisperTopBar extends StatelessWidget {
  const CrisperTopBar({
    super.key,
    required this.subtitle,
    required this.onScanTap,
    required this.onImportTap,
    required this.onProfileTap,
  });

  final String subtitle;
  final VoidCallback onScanTap;
  final VoidCallback onImportTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: p.headerGlass,
            border: Border(
              bottom: BorderSide(color: p.border.withValues(alpha: 0.75)),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 62,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/crisper_icon.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crisper',
                            style: CrisperTypography.headlineSm(p.primary)
                                .copyWith(height: 1.05),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subtitle,
                            style: CrisperTypography.labelSm(p.muted).copyWith(
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: 'Імпорт рецепта з TikTok / Reels / YouTube',
                      child: Material(
                        color: p.peachChipBg,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          onTap: onImportTap,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: p.terracotta.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 17,
                                  color: p.terracotta,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'TikTok',
                                  style: CrisperTypography.labelMd(
                                    p.peachChipText,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    _HeaderIconButton(
                      tooltip: 'AI Скан холодильника або чека',
                      icon: Icons.document_scanner_outlined,
                      onTap: onScanTap,
                    ),
                    const SizedBox(width: 7),
                    Semantics(
                      button: true,
                      label: 'Профіль та налаштування',
                      child: InkWell(
                        onTap: onProfileTap,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: p.primaryAction,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: p.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: 19,
                            color: p.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: p.surfaceContainer,
            shape: BoxShape.circle,
            border: Border.all(color: p.border),
          ),
          child: Icon(icon, size: 19, color: p.primary),
        ),
      ),
    );
  }
}

class CrisperBottomNav extends StatelessWidget {
  const CrisperBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.expiringCount,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final int expiringCount;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const items = [
      (Icons.kitchen_outlined, Icons.kitchen_rounded, 'Холодильник'),
      (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Рецепти'),
      (Icons.timer_outlined, Icons.timer_rounded, 'Готування'),
      (Icons.eco_outlined, Icons.eco_rounded, 'Баланс'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.32 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              final item = items[i];
              final color = selected ? p.primary : p.muted;
              return Expanded(
                child: InkWell(
                  onTap: () => onSelected(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? p.sageChipBg
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Icon(
                              selected ? item.$2 : item.$1,
                              size: 22,
                              color: color,
                            ),
                          ),
                          if (i == 0 && expiringCount > 0)
                            Positioned(
                              right: 6,
                              top: 1,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: p.terracotta,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$3,
                        style: CrisperTypography.labelSm(color).copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class EditorialCard extends StatelessWidget {
  const EditorialCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderRadius = 18,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? p.card,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C1917).withValues(
              alpha: p.isDark ? 0.22 : 0.035,
            ),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );
  }
}

class RecipePhoto extends StatelessWidget {
  const RecipePhoto({
    super.key,
    this.imageUrl,
    this.imageAsset,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final String? imageAsset;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = imageAsset ?? 'assets/images/img_01.jpg';
    final url = imageUrl;
    if (url != null && url.startsWith('data:image/')) {
      final comma = url.indexOf(',');
      if (comma > 0) {
        try {
          final bytes = base64Decode(url.substring(comma + 1));
          return Image.memory(
            bytes,
            fit: fit,
            errorBuilder: (_, _, _) => Image.asset(fallback, fit: fit),
          );
        } catch (_) {}
      }
    }
    if (url != null && url.startsWith('http')) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(fallback, fit: fit),
          Image.network(
            url,
            fit: fit,
            headers: const {
              'User-Agent': 'Mozilla/5.0',
              'Referer': 'https://www.tiktok.com/',
            },
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      );
    }
    return Image.asset(fallback, fit: fit);
  }
}
