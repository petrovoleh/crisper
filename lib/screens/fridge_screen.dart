import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/kitchen_models.dart';
import '../state/kitchen_store.dart';
import '../theme/crisper_theme.dart';
import '../widgets/crisper_chrome.dart';
import 'modals/planner_and_profile_sheets.dart';
import 'modals/scanner_sheet.dart';
import 'modals/social_import_sheet.dart';

class FridgeScreen extends ConsumerStatefulWidget {
  const FridgeScreen({super.key});

  @override
  ConsumerState<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends ConsumerState<FridgeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openItemEditor([PantryItem? existing, bool initialBatchMode = false]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PantryItemEditorSheet(
        existing: existing,
        initialBatchMode: initialBatchMode,
      ),
    );
  }

  static String _pluralize(int n, String one, String few, String many) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return '$n $many';
    if (mod10 == 1) return '$n $one';
    if (mod10 >= 2 && mod10 <= 4) return '$n $few';
    return '$n $many';
  }

  void _openScanner([String mode = 'fridge']) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AiScannerSheet(initialMode: mode),
    );
  }

  void _openSortSheet() {
    final current = ref.read(kitchenProvider).pantrySort;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Сортування інгредієнтів',
                  style: CrisperTypography.headlineSm(p.ink),
                ),
                const SizedBox(height: 8),
                for (final sort in PantrySort.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      sort == current
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: sort == current ? p.primary : p.muted,
                    ),
                    title: Text(
                      sort.label,
                      style: CrisperTypography.bodyMd(p.ink),
                    ),
                    onTap: () {
                      ref.read(kitchenProvider.notifier).setPantrySort(sort);
                      Navigator.of(ctx).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final st = ref.watch(kitchenProvider);
    final expiring = st.expiringItems;
    final filtered = st.filteredPantry;

    final crisperItems = filtered
        .where(
          (e) =>
              e.category == PantryCategory.crisperDrawer &&
              e.imageAsset != null,
        )
        .toList();

    final rescueRecipeCount = st.recipes
        .map(st.matchForRecipe)
        .where((m) => m.rescuedItems.isNotEmpty)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // Editorial Top Banner & Mission
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: p.sageChipBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco_outlined, size: 14, color: p.sageChipText),
                const SizedBox(width: 5),
                Text(
                  'Нуль відходів • ${st.pantry.length} продуктів у наявності',
                  style: CrisperTypography.labelSm(p.sageChipText),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Готуй з того, що є.',
          style: CrisperTypography.headlineLg(p.ink),
        ),
        Text(
          'Без зайвого.',
          style: CrisperTypography.displayItalic(p.muted),
        ),
        const SizedBox(height: 16),

        // Prominent TikTok / Reels / YouTube Import CTA Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.primaryAction,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: p.primaryAction.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '🎬 TikTok • Instagram Reels • YouTube',
                      style: CrisperTypography.labelSm(p.onPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Побачили смачний рецепт у TikTok?',
                style: CrisperTypography.headlineSm(p.onPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Вставте посилання — Crisper сам витягне список продуктів, грамовки, кроки та звірить із вашим холодильником.',
                style: CrisperTypography.bodySm(
                  p.onPrimary.withValues(alpha: 0.86),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const SocialImportSheet(),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFFFFF),
                    foregroundColor: const Color(0xFF144227),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: const Icon(
                    Icons.play_circle_fill_rounded,
                    size: 21,
                    color: Color(0xFFB33B1A),
                  ),
                  label: Text(
                    'Імпортувати рецепт із TikTok / Reels',
                    style: CrisperTypography.labelLg(const Color(0xFF144227))
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Urgent "Use Soon" Card
        if (expiring.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surfaceLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.border),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  p.peachChipBg.withValues(alpha: p.isDark ? 0.35 : 0.55),
                  p.surfaceLow,
                ],
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: p.terracotta,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ВИКОРИСТАТИ СКОРО',
                          style: CrisperTypography.labelLg(p.terracotta)
                              .copyWith(letterSpacing: 0.7),
                        ),
                      ],
                    ),
                    Text(
                      _pluralize(
                        expiring.length,
                        'позиція',
                        'позиції',
                        'позицій',
                      ),
                      style: CrisperTypography.labelSm(p.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final item in expiring.take(3)) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: p.card,
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        onTap: () => _openItemEditor(item),
                        borderRadius: BorderRadius.circular(13),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: p.border),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: item.imageAsset != null
                                    ? Image.asset(
                                        item.imageAsset!,
                                        width: 42,
                                        height: 42,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 42,
                                        height: 42,
                                        color: p.peachChipBg,
                                        child: Icon(
                                          item.category.icon,
                                          size: 20,
                                          color: p.terracotta,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: CrisperTypography.titleMd(p.ink),
                                    ),
                                    Text(
                                      item.formattedQuantity,
                                      style: CrisperTypography.tabular(
                                        p.muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: p.peachChipBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.daysLeftBadge,
                                  style: CrisperTypography.labelSm(
                                    p.peachChipText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: () {
                      ref.read(kitchenProvider.notifier).openRescueRecipes();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: p.primaryAction,
                      foregroundColor: p.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(
                      'Знайти рецепт з ними (${_pluralize(rescueRecipeCount, 'страва', 'страви', 'страв')})',
                      style: CrisperTypography.labelLg(p.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // Search & Filter Bar
        Container(
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) =>
                ref.read(kitchenProvider.notifier).setPantrySearch(v),
            style: CrisperTypography.bodyMd(p.ink),
            decoration: InputDecoration(
              hintText: 'Пошук серед ваших інгредієнтів...',
              hintStyle: CrisperTypography.bodyMd(p.muted),
              prefixIcon: Icon(Icons.search_rounded, color: p.muted, size: 21),
              suffixIcon: IconButton(
                tooltip: 'Сортування',
                onPressed: _openSortSheet,
                icon: Icon(Icons.tune_rounded, color: p.muted, size: 20),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Category Filter Chips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _CategoryPill(
                label: 'Усе',
                countBadge: '${st.pantry.length}',
                active: st.selectedCategory == null,
                onTap: () =>
                    ref.read(kitchenProvider.notifier).setCategoryFilter(null),
              ),
              for (final cat in PantryCategory.values) ...[
                const SizedBox(width: 8),
                _CategoryPill(
                  label: cat.label,
                  icon: cat.icon,
                  active: st.selectedCategory == cat,
                  onTap: () =>
                      ref.read(kitchenProvider.notifier).setCategoryFilter(cat),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Section 1: Шухляда свіжості (Crisper Drawer 2-col photo grid)
        if (crisperItems.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.spa_outlined, size: 20, color: p.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Шухляда свіжості',
                    style: CrisperTypography.headlineSm(p.ink),
                  ),
                ],
              ),
              Text(
                'Оптимальна вологість 85%',
                style: CrisperTypography.labelSm(p.muted).copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: crisperItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.96,
            ),
            itemBuilder: (context, idx) {
              final item = crisperItems[idx];
              return EditorialCard(
                padding: const EdgeInsets.all(10),
                borderRadius: 16,
                onTap: () => _openItemEditor(item),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(item.imageAsset!, fit: BoxFit.cover),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: item.isExpiringSoon
                                      ? p.peachChipBg
                                      : p.card.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.daysLeftBadge,
                                  style: CrisperTypography.labelSm(
                                    item.isExpiringSoon
                                        ? p.peachChipText
                                        : p.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CrisperTypography.titleMd(p.ink),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${item.amountGramsOrPcs.toInt()} ${item.unit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CrisperTypography.tabular(
                              p.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          item.addedLabel,
                          style: CrisperTypography.bodySm(p.muted).copyWith(
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],

        // Section 2: Полиці холодильника (Grouped shelves)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Полиці холодильника',
              style: CrisperTypography.headlineSm(p.ink),
            ),
            Text(
              't° +3.5°C',
              style: CrisperTypography.tabular(
                p.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final shelfCat in [
          PantryCategory.dairyCheese,
          PantryCategory.meatFish,
          PantryCategory.pantrySpices,
          PantryCategory.freezer,
          PantryCategory.crisperDrawer,
        ]) ...[
          Builder(
            builder: (context) {
              final shelfItems = filtered.where((e) {
                if (shelfCat == PantryCategory.crisperDrawer) {
                  return e.category == shelfCat && e.imageAsset == null;
                }
                return e.category == shelfCat;
              }).toList();

              if (shelfItems.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: EditorialCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(shelfCat.icon, size: 18, color: p.primary),
                              const SizedBox(width: 8),
                              Text(
                                shelfCat.label,
                                style: CrisperTypography.labelLg(p.ink),
                              ),
                            ],
                          ),
                          Text(
                            '${shelfItems.length} позиц.',
                            style: CrisperTypography.bodySm(p.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final item in shelfItems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Dismissible(
                            key: ValueKey('shelf_${item.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: p.peachChipBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: p.terracotta,
                              ),
                            ),
                            onDismissed: (_) {
                              ref
                                  .read(kitchenProvider.notifier)
                                  .removePantryItem(item.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '«${item.name}» прибрано з холодильника',
                                  ),
                                ),
                              );
                            },
                            child: InkWell(
                              onTap: () => _openItemEditor(item),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: p.surfaceLow,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: p.border.withValues(alpha: 0.7),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: item.isExpiringSoon
                                            ? p.peachChipBg
                                            : p.surfaceContainer,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        shelfCat.icon,
                                        size: 17,
                                        color: item.isExpiringSoon
                                            ? p.terracotta
                                            : p.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: CrisperTypography.titleMd(
                                              p.ink,
                                            ),
                                          ),
                                          Text(
                                            item.formattedQuantity,
                                            style: CrisperTypography.tabular(
                                              p.muted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      item.daysLeftBadge,
                                      style: CrisperTypography.tabular(
                                        item.isExpiringSoon
                                            ? p.terracotta
                                            : p.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
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
            },
          ),
        ],

        const SizedBox(height: 8),
        // Dual Action Row (+ Додати продукт | Списком / Голос | Чек / Фото)
        Row(
          children: [
            Expanded(
              flex: 5,
              child: SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => _openItemEditor(),
                  style: FilledButton.styleFrom(
                    backgroundColor: p.primaryAction,
                    foregroundColor: p.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
                  label: Text(
                    'Додати',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CrisperTypography.labelLg(p.onPrimary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _openItemEditor(null, true),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: p.surfaceContainer,
                    foregroundColor: p.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    side: BorderSide(color: p.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(Icons.mic_none_rounded, size: 18, color: p.terracotta),
                  label: Text(
                    'Списком',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CrisperTypography.labelMd(p.ink),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _openScanner('receipt'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: p.surfaceContainer,
                    foregroundColor: p.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    side: BorderSide(color: p.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    Icons.camera_alt_outlined,
                    size: 18,
                    color: p.primary,
                  ),
                  label: Text(
                    'Чек / Фото',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CrisperTypography.labelMd(p.ink),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.countBadge,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final String? countBadge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active ? p.primaryAction : p.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? p.primaryAction : p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: active ? p.onPrimary : p.primary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: CrisperTypography.labelMd(active ? p.onPrimary : p.ink),
            ),
            if (countBadge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.2)
                      : p.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  countBadge!,
                  style: CrisperTypography.labelSm(
                    active ? p.onPrimary : p.muted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
