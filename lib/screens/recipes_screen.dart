import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/kitchen_models.dart';
import '../services/ai_kitchen_service.dart';
import '../state/kitchen_store.dart';
import '../theme/crisper_theme.dart';
import '../widgets/crisper_chrome.dart';
import 'modals/planner_and_profile_sheets.dart';
import 'modals/social_import_sheet.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  bool _isGeneratingAiRecipe = false;

  Future<void> _generateCustomAiRecipe() async {
    setState(() => _isGeneratingAiRecipe = true);
    final st = ref.read(kitchenProvider);
    final recipe = await AiKitchenService.generateAiSousChefRecipe(
      pantry: st.pantry,
      settings: st.settings,
    );
    if (!mounted) return;
    setState(() => _isGeneratingAiRecipe = false);
    ref.read(kitchenProvider.notifier).addNewRecipe(recipe);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('AI-сушеф створив для вас: «${recipe.title}»!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final st = ref.watch(kitchenProvider);
    final matches = st.matchedRecipes;
    final expiring = st.expiringItems;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // Top Smart Selection Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: p.sageChipBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: p.sageChipText,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'РОЗУМНИЙ ПІДБІР',
                  style: CrisperTypography.labelSm(p.primary),
                ),
              ],
            ),
            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const WeeklyMealPlannerSheet(),
                    );
                  },
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: const Text('План'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const SocialImportSheet(),
                    );
                  },
                  icon: const Icon(Icons.add_link_rounded, size: 17),
                  label: const Text('TikTok / URL'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Що приготувати сьогодні?',
          style: CrisperTypography.headlineLg(p.ink),
        ),
        const SizedBox(height: 4),
        Text(
          'Знайдено ${matches.length} рецептів із ваших ${st.pantry.length} наявних інгредієнтів.',
          style: CrisperTypography.bodyMd(p.muted),
        ),
        const SizedBox(height: 14),

        // Prominent TikTok / Social Video Importer Card
        EditorialCard(
          padding: const EdgeInsets.all(15),
          backgroundColor: p.peachChipBg.withValues(
            alpha: p.isDark ? 0.65 : 0.72,
          ),
          borderRadius: 18,
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const SocialImportSheet(),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: p.terracotta,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Імпорт відео з TikTok, Reels та YouTube',
                          style: CrisperTypography.titleMd(p.ink),
                        ),
                        Text(
                          'Вставте лінк — ми перетворимо відео на покроковий рецепт',
                          style: CrisperTypography.bodySm(p.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const SocialImportSheet(),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: p.terracotta,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_link_rounded, size: 20),
                  label: Text(
                    'Вставити посилання з TikTok / Reels',
                    style: CrisperTypography.labelLg(Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Urgent Expiry Banner
        if (expiring.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: p.peachChipBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 20,
                    color: p.terracotta,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Зверніть увагу на терміни',
                        style: CrisperTypography.labelMd(p.terracotta),
                      ),
                      Text(
                        '${expiring.take(2).map((e) => e.name).join(' та ')} слід використати якнайшвидше',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CrisperTypography.bodySm(p.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),

        // Filter Chips
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: RecipeFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final f = RecipeFilter.values[idx];
              final active = st.recipeFilter == f;
              return InkWell(
                onTap: () =>
                    ref.read(kitchenProvider.notifier).setRecipeFilter(f),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active ? p.primaryAction : p.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active ? p.primaryAction : p.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        f.icon,
                        size: 15,
                        color: active ? p.onPrimary : p.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        f.label,
                        style: CrisperTypography.labelMd(
                          active ? p.onPrimary : p.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // Time-of-Day Meal Ideas Strip (Breakfast / Lunch / Dinner)
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: MealTimeFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final mt = MealTimeFilter.values[idx];
              final active = st.mealTimeFilter == mt;
              final suggestedNow = KitchenState.suggestedMealTimeForHour(
                DateTime.now().hour,
              );
              return InkWell(
                onTap: () =>
                    ref.read(kitchenProvider.notifier).setMealTimeFilter(mt),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: active ? p.sageChipBg : p.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active ? p.primary : p.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mt.icon,
                        size: 14,
                        color: active ? p.sageChipText : p.muted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        mt == suggestedNow ? '${mt.label} • Зараз' : mt.label,
                        style: CrisperTypography.labelSm(
                          active ? p.sageChipText : p.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),

        if (matches.isEmpty)
          EditorialCard(
            child: Column(
              children: [
                Icon(Icons.menu_book_outlined, size: 36, color: p.muted),
                const SizedBox(height: 8),
                Text(
                  'У цій категорії поки порожньо',
                  style: CrisperTypography.titleMd(p.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'Спробуйте інший фільтр, збережіть улюблену страву або імпортуйте рецепт із TikTok / Reels.',
                  textAlign: TextAlign.center,
                  style: CrisperTypography.bodySm(p.muted),
                ),
              ],
            ),
          ),

        // Recipe Cards Feed
        for (final match in matches) ...[
          _EditorialRecipeCard(match: match),
          const SizedBox(height: 18),
        ],

        // Bottom AI Sous-Chef Custom Recipe Generator Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.surfaceLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.primaryAction,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.psychology_outlined,
                      color: p.onPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Бажаєте щось унікальне?',
                          style: CrisperTypography.headlineSm(p.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Штучний інтелект створить персональну страву суто під залишки у вашому холодильнику без необхідності йти в магазин.',
                          style: CrisperTypography.bodySm(p.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed:
                      _isGeneratingAiRecipe ? null : _generateCustomAiRecipe,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.primaryAction,
                    foregroundColor: p.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isGeneratingAiRecipe
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 19),
                  label: Text(
                    _isGeneratingAiRecipe
                        ? 'AI-сушеф компонує страву...'
                        : 'Згенерувати авторський рецепт від AI-сушефа',
                    textAlign: TextAlign.center,
                    style: CrisperTypography.labelLg(p.onPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '⚡ Генерація триває лише 1–3 секунди',
                  style: CrisperTypography.labelSm(p.muted).copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditorialRecipeCard extends ConsumerWidget {
  const _EditorialRecipeCard({required this.match});

  final RecipeMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final recipe = match.recipe;

    return EditorialCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 16:10 Image + Match Overlays
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RecipePhoto(
                    imageUrl: recipe.imageUrl,
                    imageAsset: recipe.imageAsset ?? 'assets/images/img_01.jpg',
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: p.sageChipBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      match.isFullMatch
                                          ? Icons.verified_outlined
                                          : Icons.pie_chart_outline_rounded,
                                      size: 15,
                                      color: p.sageChipText,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        match.isFullMatch
                                            ? '100% з ваших продуктів'
                                            : '${match.matchPercent}% збіг (є ${match.ownedIngredients.length} з ${recipe.ingredients.length})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: CrisperTypography.labelMd(
                                          p.sageChipText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (match.rescuedItems.isNotEmpty) ...[
                                const SizedBox(height: 6),
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
                                    '⚠️ Рятує: ${match.rescuedItems.take(2).map((e) => e.name.toLowerCase()).join(', ')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: CrisperTypography.labelSm(
                                      p.peachChipText,
                                    ),
                                  ),
                                ),
                              ],
                              if (recipe.source != RecipeSource.curated) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.68),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    recipe.authorHandle != null
                                        ? '✨ ${recipe.source.label} · ${recipe.authorHandle}'
                                        : '✨ ${recipe.source.label}',
                                    style: CrisperTypography.labelSm(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (recipe.source != RecipeSource.curated)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Material(
                                  color: p.card.withValues(alpha: 0.88),
                                  shape: const CircleBorder(),
                                  child: PopupMenuButton<String>(
                                    tooltip: 'Дії з рецептом',
                                    padding: EdgeInsets.zero,
                                    icon: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.more_horiz_rounded,
                                        size: 19,
                                        color: p.ink,
                                      ),
                                    ),
                                    onSelected: (action) {
                                      if (action == 'copy' &&
                                          recipe.sourceUrl != null) {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: recipe.sourceUrl!,
                                          ),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Посилання на оригінальне відео скопійовано!',
                                            ),
                                          ),
                                        );
                                      } else if (action == 'delete') {
                                        ref
                                            .read(kitchenProvider.notifier)
                                            .removeRecipe(recipe.id);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Рецепт «${recipe.title}» видалено.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (recipe.sourceUrl != null)
                                        const PopupMenuItem(
                                          value: 'copy',
                                          child: Row(
                                            children: [
                                              Icon(Icons.link_rounded, size: 18),
                                              SizedBox(width: 8),
                                              Text('Скопіювати посилання'),
                                            ],
                                          ),
                                        ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Видалити рецепт'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Material(
                              color: p.card.withValues(alpha: 0.88),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => ref
                                    .read(kitchenProvider.notifier)
                                    .toggleBookmark(recipe.id),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    recipe.isBookmarked
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    size: 20,
                                    color: recipe.isBookmarked
                                        ? p.terracotta
                                        : p.ink,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metadata Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MetaItem(
                            icon: Icons.schedule_rounded,
                            label: '${recipe.cookMinutes} хв',
                          ),
                          Text('•', style: TextStyle(color: p.muted)),
                          _MetaItem(
                            icon: Icons.restaurant_menu_rounded,
                            label: recipe.difficulty,
                          ),
                          Text('•', style: TextStyle(color: p.muted)),
                          _MetaItem(
                            icon: Icons.group_outlined,
                            label: '${recipe.defaultServings} порції',
                          ),
                        ],
                      ),
                    ),
                    if (match.isFullMatch)
                      Text(
                        'НУЛЬ ВІДХОДІВ',
                        style: CrisperTypography.labelSm(p.primary),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  recipe.title,
                  style: CrisperTypography.headlineSm(p.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  recipe.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: CrisperTypography.bodySm(p.muted),
                ),
                const SizedBox(height: 12),

                // Pantry Matrix Chips (Owned + Missing)
                Text(
                  'АНАЛІЗ КОМОРИ:',
                  style: CrisperTypography.labelSm(p.muted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final owned in match.ownedIngredients)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: p.sageChipBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '✓ ${owned.name}',
                          style: CrisperTypography.labelSm(p.sageChipText)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    for (final miss in match.missingIngredients)
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: p.peachChipBg,
                        side: BorderSide.none,
                        label: Text(
                          '✕ ${miss.name} (+ список)',
                          style: CrisperTypography.labelSm(p.peachChipText),
                        ),
                        onPressed: () {
                          ref
                              .read(kitchenProvider.notifier)
                              .addIngredientToShoppingList(miss, recipe.title);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '«${miss.name}» додано у Розумний список покупок!',
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),

                // AI Sous-Chef Substitution Tip Box
                if (!match.isFullMatch && match.activeAiTip != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.tips_and_updates_outlined,
                          size: 18,
                          color: p.terracotta,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Порада AI-сушефа',
                                style: CrisperTypography.labelMd(p.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                match.activeAiTip!,
                                style: CrisperTypography.bodySm(p.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                // Bottom CTA Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          Icon(
                            match.isFullMatch
                                ? Icons.check_circle_outline_rounded
                                : Icons.auto_fix_high_rounded,
                            size: 17,
                            color:
                                match.isFullMatch ? p.primary : p.terracotta,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              match.isFullMatch
                                  ? 'Усе в холодильнику'
                                  : (match.missingIngredients.length == 1 &&
                                        match.activeAiTip != null)
                                  ? 'Є заміна від AI-сушефа'
                                  : 'Докупити: ${match.missingIngredients.length} інґр.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CrisperTypography.labelMd(
                                match.isFullMatch ? p.primary : p.terracotta,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        ref
                            .read(kitchenProvider.notifier)
                            .startCookingRecipe(recipe);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: p.primaryAction,
                        foregroundColor: p.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                      label: Text(
                        match.isFullMatch ? 'Готувати' : 'Переглянути',
                        style: CrisperTypography.labelMd(p.onPrimary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: p.muted),
        const SizedBox(width: 4),
        Text(label, style: CrisperTypography.bodySm(p.muted)),
      ],
    );
  }
}
