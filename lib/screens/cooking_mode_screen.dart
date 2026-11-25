import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/kitchen_models.dart';
import '../state/kitchen_store.dart';
import '../theme/crisper_theme.dart';
import '../widgets/crisper_chrome.dart';

class CookingModeScreen extends ConsumerWidget {
  const CookingModeScreen({super.key});

  String _formatTimer(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showRecipeSwitcher(BuildContext context, WidgetRef ref) {
    final st = ref.read(kitchenProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Оберіть рецепт для готування',
                  style: CrisperTypography.headlineSm(p.ink),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: st.recipes.map((r) {
                      final active = r.id == st.activeRecipeId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          active
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: active ? p.primary : p.muted,
                        ),
                        title: Text(
                          r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CrisperTypography.titleMd(p.ink),
                        ),
                        subtitle: Text(
                          '${r.cookMinutes} хв • ${r.steps.length} кроки',
                          style: CrisperTypography.bodySm(p.muted),
                        ),
                        onTap: () {
                          ref
                              .read(kitchenProvider.notifier)
                              .startCookingRecipe(r);
                          Navigator.of(ctx).pop();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFinishDeductSheet(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
  ) {
    final st = ref.read(kitchenProvider);
    final ownedKeys = st.pantry.map((e) => e.canonicalKey).toSet();
    final initialSelected = recipe.ingredients
        .map((e) => e.canonicalKey)
        .where(ownedKeys.contains)
        .toSet();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final selectedKeys = {...initialSelected};
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final p = ctx.palette;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: p.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Страву приготовано! Списати продукти?',
                      style: CrisperTypography.headlineSm(p.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Crisper автоматично оновить залишки у холодильнику та додасть +${recipe.rescuedGrams} г до вашого Zero-Waste балансу.',
                      style: CrisperTypography.bodySm(p.muted),
                    ),
                    const SizedBox(height: 12),
                    for (final ing in recipe.ingredients)
                      if (ownedKeys.contains(ing.canonicalKey))
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selectedKeys.contains(ing.canonicalKey),
                          activeColor: p.primaryAction,
                          title: Text(
                            ing.name,
                            style: CrisperTypography.titleMd(p.ink),
                          ),
                          subtitle: Text(
                            'Використано: ${ing.scaledLabel(st.cookingServings, recipe.defaultServings)}',
                            style: CrisperTypography.bodySm(p.muted),
                          ),
                          onChanged: (v) {
                            setModalState(() {
                              if (v == true) {
                                selectedKeys.add(ing.canonicalKey);
                              } else {
                                selectedKeys.remove(ing.canonicalKey);
                              }
                            });
                          },
                        ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          ref
                              .read(kitchenProvider.notifier)
                              .finishCookingAndDeduct(
                                recipe: recipe,
                                keysToDeduct: selectedKeys,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Смачного! Врятовано +${recipe.rescuedGrams} г продуктів, баланс оновлено.',
                              ),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: p.primaryAction,
                          foregroundColor: p.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.celebration_outlined, size: 19),
                        label: Text(
                          'Завершити та оновити холодильник',
                          style: CrisperTypography.labelLg(p.onPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final st = ref.watch(kitchenProvider);
    final recipe = st.activeRecipe;
    final stepIdx = st.cookingStepIndex.clamp(0, recipe.steps.length - 1);
    final step = recipe.steps[stepIdx];
    final progress = (stepIdx + 1) / recipe.steps.length;
    final isLastStep = stepIdx >= recipe.steps.length - 1;

    final pantryByKey = {
      for (final item in st.pantry) item.canonicalKey: item,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // Mode Header + Switch Recipe Link
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.soup_kitchen_outlined, size: 18, color: p.primary),
                const SizedBox(width: 6),
                Text(
                  'Режим Готування • Екран активний',
                  style: CrisperTypography.labelMd(p.muted),
                ),
              ],
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _showRecipeSwitcher(context, ref),
              icon: const Icon(Icons.swap_horiz_rounded, size: 17),
              label: const Text('Інша страва'),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Hero Recipe Banner Card
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RecipePhoto(
                  imageUrl: recipe.imageUrl,
                  imageAsset: recipe.imageAsset ?? 'assets/images/img_11.jpg',
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.18),
                        Colors.black.withValues(alpha: 0.80),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A4B2E),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '🌿 Zero-Waste 10/10',
                              style: CrisperTypography.labelSm(Colors.white),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Сезонне',
                              style: CrisperTypography.labelSm(Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recipe.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: CrisperTypography.headlineSm(Colors.white)
                            .copyWith(fontSize: 21),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recipe.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CrisperTypography.bodySm(
                          Colors.white.withValues(alpha: 0.86),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 4-Column Quick Metrics Card
        EditorialCard(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          child: Row(
            children: [
              _CookingMetricCell(
                icon: Icons.schedule_rounded,
                value: '${recipe.cookMinutes} хв',
                label: 'Загалом',
                valueColor: p.ink,
              ),
              _CookingMetricCell(
                icon: Icons.local_fire_department_outlined,
                value: '${recipe.caloriesPerServing}',
                label: 'ккал / порт.',
                valueColor: p.ink,
              ),
              _CookingMetricCell(
                icon: Icons.savings_outlined,
                value: '${recipe.rescuedGrams} г',
                label: 'Врятовано',
                valueColor: p.terracotta,
              ),
              _CookingMetricCell(
                icon: Icons.soup_kitchen_outlined,
                value: recipe.difficulty,
                label: 'Рівень',
                valueColor: p.ink,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Ingredients Card with 1 | 2 | 4 Servings Scaler
        EditorialCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Інгредієнти',
                          style: CrisperTypography.headlineSm(p.ink),
                        ),
                        InkWell(
                          onTap: () => ref
                              .read(kitchenProvider.notifier)
                              .toggleAllIngredientsPrepared(recipe),
                          borderRadius: BorderRadius.circular(6),
                          child: Text(
                            recipe.ingredients.every(
                                  (e) => st.checkedIngredientKeys.contains(
                                    e.canonicalKey,
                                  ),
                                )
                                ? '✓ Усе підготовлено (скинути)'
                                : 'Відмічайте підготовлене • Усі ✓',
                            style: CrisperTypography.bodySm(p.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: p.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final srv in <int>{
                          1,
                          2,
                          3,
                          4,
                          if (st.cookingServings > 4) st.cookingServings,
                        })
                          GestureDetector(
                            onTap: () => ref
                                .read(kitchenProvider.notifier)
                                .setCookingServings(srv),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: st.cookingServings == srv
                                    ? p.primaryAction
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                '$srv',
                                style: CrisperTypography.tabular(
                                  st.cookingServings == srv
                                      ? p.onPrimary
                                      : p.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final ing in recipe.ingredients) ...[
                Builder(
                  builder: (context) {
                    final checked = st.checkedIngredientKeys.contains(
                      ing.canonicalKey,
                    );
                    final pItem = pantryByKey[ing.canonicalKey];
                    final urgent = pItem != null && pItem.daysLeft <= 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: EdgeInsets.all(urgent ? 11 : 6),
                      decoration: BoxDecoration(
                        color: urgent
                            ? p.peachChipBg.withValues(
                                alpha: p.isDark ? 0.55 : 0.45,
                              )
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: urgent
                            ? Border.all(
                                color: p.terracotta.withValues(alpha: 0.4),
                              )
                            : null,
                      ),
                      child: InkWell(
                        onTap: () => ref
                            .read(kitchenProvider.notifier)
                            .toggleIngredientPrepared(ing.canonicalKey),
                        borderRadius: BorderRadius.circular(10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                checked
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 22,
                                color: checked
                                    ? p.primaryAction
                                    : (urgent ? p.terracotta : p.muted),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ing.name,
                                    style: CrisperTypography.titleMd(p.ink)
                                        .copyWith(
                                          decoration: checked
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                  ),
                                  if (urgent) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.terracotta,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'ВИКОРИСТАТИ ТЕРМІНОВО',
                                        style: CrisperTypography.labelSm(
                                          Colors.white,
                                        ).copyWith(fontSize: 9.5),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '⚠️ Залишилось: ${pItem.daysLeftBadge}',
                                      style: CrisperTypography.bodySm(
                                        p.terracotta,
                                      ),
                                    ),
                                  ] else if (pItem != null) ...[
                                    Text(
                                      '✓ Є в наявності • ${ing.prepNote}',
                                      style: CrisperTypography.bodySm(
                                        p.primary,
                                      ),
                                    ),
                                  ] else ...[
                                    Text(
                                      ing.prepNote.isEmpty
                                          ? 'Перевірте комору'
                                          : ing.prepNote,
                                      style: CrisperTypography.bodySm(p.muted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ing.scaledLabel(
                                st.cookingServings,
                                recipe.defaultServings,
                              ),
                              style: CrisperTypography.tabular(
                                urgent ? p.terracotta : p.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              Divider(color: p.border, height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.grain_rounded, size: 17, color: p.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: CrisperTypography.bodySm(p.muted),
                        children: [
                          TextSpan(
                            text: 'З полички спецій: ',
                            style: CrisperTypography.labelSm(p.ink),
                          ),
                          TextSpan(text: recipe.spiceShelfNote),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Sous-Chef Substitution Advice Box
        if (recipe.sousChefAdvice.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.sageChipBg.withValues(alpha: p.isDark ? 0.55 : 0.45),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: p.sageChipBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 19,
                    color: p.sageChipText,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Порада Су-шефа щодо замін',
                              style: CrisperTypography.titleMd(p.ink),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: p.card,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: p.border),
                            ),
                            child: Text(
                              'Розумна комора',
                              style: CrisperTypography.labelSm(p.ink)
                                  .copyWith(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        recipe.sousChefAdvice,
                        style: CrisperTypography.bodySm(p.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // Focus Step Mode Card + Horizontal Swipe + Live Timer
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final vx = details.primaryVelocity ?? 0;
            if (vx < -220 && !isLastStep) {
              ref
                  .read(kitchenProvider.notifier)
                  .setCookingStep(stepIdx + 1);
            } else if (vx > 220 && stepIdx > 0) {
              ref
                  .read(kitchenProvider.notifier)
                  .setCookingStep(stepIdx - 1);
            }
          },
          child: EditorialCard(
            borderRadius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: p.terracotta,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'РЕЖИМ ФОКУСУ : КРОК ${stepIdx + 1} З ${recipe.steps.length}',
                        style: CrisperTypography.labelSm(p.terracotta),
                      ),
                    ],
                  ),
                  Text(
                    '${(progress * 100).round()}% завершено',
                    style: CrisperTypography.tabular(
                      p.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: p.surfaceContainer,
                  color: p.primaryAction,
                ),
              ),
              const SizedBox(height: 14),
              if (step.stepImageAsset != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 165,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(step.stepImageAsset!, fit: BoxFit.cover),
                        if (step.heatLabel != null)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                step.heatLabel!,
                                style: CrisperTypography.labelSm(Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                step.instruction,
                style: CrisperTypography.headlineSm(p.ink).copyWith(
                  fontSize: 21,
                  height: 1.32,
                ),
              ),
              if (step.detailTip.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  step.detailTip,
                  style: CrisperTypography.bodyMd(p.muted),
                ),
              ],
              const SizedBox(height: 16),

              // Interactive Kitchen Timer Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surfaceLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: st.isTimerRunning ? p.terracotta : p.border,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          step.hasEstimatedTimer && st.timerSecondsLeft > 0
                              ? Icons.auto_awesome_outlined
                              : Icons.hourglass_bottom_rounded,
                          size: 16,
                          color: p.terracotta,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            st.timerSecondsLeft == 0
                                ? 'Таймер завершено!'
                                : step.hasEstimatedTimer
                                    ? 'Орієнтовний час кроку (оцінка Crisper)'
                                    : 'Рекомендований час за рецептом',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CrisperTypography.labelMd(p.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTimer(
                        st.timerSecondsLeft > 0 || st.isTimerRunning
                            ? st.timerSecondsLeft
                            : 0,
                      ),
                      style: CrisperTypography.tabular(
                        st.isTimerRunning ? p.terracotta : p.ink,
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        fontFamily: CrisperTypography.serif,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: FilledButton.icon(
                            onPressed: () =>
                                ref.read(kitchenProvider.notifier).toggleTimer(),
                            style: FilledButton.styleFrom(
                              backgroundColor: st.isTimerRunning
                                  ? p.terracotta
                                  : p.surfaceHigh,
                              foregroundColor: st.isTimerRunning
                                  ? Colors.white
                                  : p.ink,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            icon: Icon(
                              st.isTimerRunning
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 20,
                            ),
                            label: Text(
                              st.isTimerRunning ? 'Пауза' : 'Старт',
                              style: CrisperTypography.labelLg(
                                st.isTimerRunning ? Colors.white : p.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: OutlinedButton(
                            onPressed: () => ref
                                .read(kitchenProvider.notifier)
                                .addOneMinuteToTimer(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: p.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            child: Text(
                              '+ 1 хв',
                              style: CrisperTypography.labelMd(p.ink),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          tooltip: 'Скинути таймер',
                          onPressed: () => ref
                              .read(kitchenProvider.notifier)
                              .resetStepTimer(),
                          icon: Icon(Icons.refresh_rounded, color: p.ink),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (recipe.steps.length > 1) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '← Свайп по картці вліво або вправо для зміни кроку →',
                    style: CrisperTypography.labelSm(p.muted).copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
        const SizedBox(height: 18),

        // Primary Next Step / Finish Cooking CTA
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: () {
              if (isLastStep) {
                _openFinishDeductSheet(context, ref, recipe);
              } else {
                ref
                    .read(kitchenProvider.notifier)
                    .setCookingStep(stepIdx + 1);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: p.primaryAction,
              foregroundColor: p.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            iconAlignment: IconAlignment.end,
            icon: Icon(
              isLastStep
                  ? Icons.check_circle_outline_rounded
                  : Icons.arrow_forward_rounded,
              size: 20,
            ),
            label: Text(
              isLastStep
                  ? 'Завершити та списати продукти'
                  : 'Наступний крок (Крок ${stepIdx + 2}: ${recipe.steps[stepIdx + 1].shortTitle})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CrisperTypography.labelLg(p.onPrimary),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: stepIdx > 0
                    ? () => ref
                          .read(kitchenProvider.notifier)
                          .setCookingStep(stepIdx - 1)
                    : null,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text(
                  'Попередній крок',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Flexible(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => _openFinishDeductSheet(context, ref, recipe),
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text(
                  'Завершити готування',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CookingMetricCell extends StatelessWidget {
  const _CookingMetricCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: valueColor == p.ink ? p.primary : valueColor),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CrisperTypography.tabular(
              valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CrisperTypography.bodySm(p.muted).copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
