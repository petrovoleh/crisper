import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../models/kitchen_models.dart';
import '../state/kitchen_store.dart';
import '../theme/crisper_theme.dart';
import '../widgets/crisper_chrome.dart';
import 'modals/planner_and_profile_sheets.dart';

class BalanceScreen extends ConsumerWidget {
  const BalanceScreen({super.key});

  void _openAddShoppingModal(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController(text: '1');
    String unit = 'шт';
    PantryCategory cat = PantryCategory.crisperDrawer;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final p = ctx.palette;
            final inset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, inset + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Додати у список покупок',
                    style: CrisperTypography.headlineSm(p.ink),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Назва продукту',
                      hintText: 'Наприклад: Вершки 20% або Гірчиця',
                      filled: true,
                      fillColor: p.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amtCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Кількість',
                            filled: true,
                            fillColor: p.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: unit,
                          decoration: InputDecoration(
                            labelText: 'Одиниця',
                            filled: true,
                            fillColor: p.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const ['шт', 'г', 'мл', 'уп']
                              .map(
                                (u) => DropdownMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() => unit = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<PantryCategory>(
                    initialValue: cat,
                    decoration: InputDecoration(
                      labelText: 'Категорія',
                      filled: true,
                      fillColor: p.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: PantryCategory.values
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => cat = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) return;
                        ref
                            .read(kitchenProvider.notifier)
                            .addCustomShoppingItem(
                              name: nameCtrl.text,
                              amount: double.tryParse(amtCtrl.text) ?? 1,
                              unit: unit,
                              category: cat,
                            );
                        Navigator.of(ctx).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: p.primaryAction,
                        foregroundColor: p.onPrimary,
                      ),
                      child: const Text('Додати до списку'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openPlanner(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const WeeklyMealPlannerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final st = ref.watch(kitchenProvider);
    final s = st.settings;
    final checkedCount = st.shoppingList.where((e) => e.isChecked).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // Top Header + Eco-Report / Planner Button
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ваш кулінарний баланс',
                    style: CrisperTypography.headlineLg(p.ink),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: p.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Листопад 2026',
                        style: CrisperTypography.bodyMd(p.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _openPlanner(context),
              style: OutlinedButton.styleFrom(
                backgroundColor: p.surfaceContainer,
                side: BorderSide(color: p.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: Icon(Icons.menu_book_rounded, size: 16, color: p.primary),
              label: Text(
                'Меню 7 дн.',
                style: CrisperTypography.labelMd(p.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ZERO-WASTE INDEX Card
        EditorialCard(
          borderRadius: 22,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ZERO-WASTE ІНДЕКС',
                          style: CrisperTypography.labelSm(p.terracotta),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Екологічний вплив кухні',
                          style: CrisperTypography.headlineSm(p.ink),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: p.sageChipBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '↗ Топ 5% кухарів',
                      style: CrisperTypography.labelSm(p.sageChipText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 94% Balance Ring Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.surfaceLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 82,
                      height: 82,
                      child: CustomPaint(
                        painter: _BalanceRingPainter(
                          progress: s.zeroWasteScore / 100.0,
                          activeColor: p.primaryAction,
                          trackColor: p.border,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${s.zeroWasteScore}%',
                                style: CrisperTypography.tabular(
                                  p.ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'БАЛАНС',
                                style: CrisperTypography.labelSm(p.muted)
                                    .copyWith(fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Врятовано від смітника',
                            style: CrisperTypography.labelMd(p.ink),
                          ),
                          const SizedBox(height: 2),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${s.rescuedKgTotal} ',
                                  style: CrisperTypography.headlineMd(p.ink)
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(
                                  text: 'КГ їжі',
                                  style: CrisperTypography.bodyMd(p.muted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '⊕ +${s.rescuedKgThisWeek} кг цього тижня',
                            style: CrisperTypography.labelSm(p.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2-Column Savings & CO2
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: p.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: p.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: p.border),
                            ),
                            child: Icon(
                              Icons.payments_outlined,
                              size: 18,
                              color: p.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Збережено бюджет',
                            style: CrisperTypography.labelSm(p.muted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.savedUahTotal} ₴',
                            style: CrisperTypography.tabular(
                              p.ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'уникнуто повторних покупок',
                            style: CrisperTypography.bodySm(p.muted)
                                .copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: p.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: p.peachChipBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.energy_savings_leaf_outlined,
                              size: 18,
                              color: p.terracotta,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Зниження CO₂',
                            style: CrisperTypography.labelSm(p.muted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '~${s.co2SavedKg.round()} кг',
                            style: CrisperTypography.tabular(
                              p.ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'еквівалент 120 км на авто',
                            style: CrisperTypography.bodySm(p.muted)
                                .copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.sageChipBg.withValues(alpha: p.isDark ? 0.45 : 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: p.sageChipText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '«Неймовірна турбота: жодного шматочка сиру та зелені не було втрачено.»',
                        style: CrisperTypography.bodySm(p.ink).copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Rescued Products Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Врятовані продукти',
              style: CrisperTypography.headlineSm(p.ink),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: p.sageChipBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${st.rescuedLogs.length} страв з залишків',
                style: CrisperTypography.labelSm(p.sageChipText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Hero Triumph Card
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 145,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/images/img_13.jpg', fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Головний тріумф місяця',
                        style: CrisperTypography.labelSm(
                          const Color(0xFFA1D2AD),
                        ),
                      ),
                      Text(
                        'Ароматний банановий хліб з пеканом',
                        style: CrisperTypography.titleLg(Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        EditorialCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              for (int i = 0; i < st.rescuedLogs.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: st.rescuedLogs[i].isHighlightWarn
                              ? p.peachChipBg
                              : p.surfaceLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          st.rescuedLogs[i].isHighlightWarn
                              ? Icons.bakery_dining_outlined
                              : Icons.eco_outlined,
                          size: 18,
                          color: st.rescuedLogs[i].isHighlightWarn
                              ? p.terracotta
                              : p.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              st.rescuedLogs[i].title,
                              style: CrisperTypography.titleMd(p.ink),
                            ),
                            Text(
                              st.rescuedLogs[i].dishNote,
                              style: CrisperTypography.bodySm(p.muted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: st.rescuedLogs[i].isHighlightWarn
                              ? p.peachChipBg
                              : p.sageChipBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          st.rescuedLogs[i].amountBadge,
                          style: CrisperTypography.tabular(
                            st.rescuedLogs[i].isHighlightWarn
                                ? p.peachChipText
                                : p.sageChipText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < st.rescuedLogs.length - 1)
                  Divider(color: p.border.withValues(alpha: 0.6), height: 2),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Smart Shopping List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Розумний список покупок',
                    style: CrisperTypography.headlineSm(p.ink),
                  ),
                  Text(
                    'Створено автоматично за вашими звичками та планом',
                    style: CrisperTypography.bodySm(p.muted),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Додати позицію у список покупок',
              onPressed: () => _openAddShoppingModal(context, ref),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        EditorialCard(
          child: Column(
            children: [
              if (st.shoppingList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Список покупок порожній — усе необхідне вже є у холодильнику!',
                    textAlign: TextAlign.center,
                    style: CrisperTypography.bodyMd(p.muted),
                  ),
                ),
              for (int i = 0; i < st.shoppingList.length; i++) ...[
                Builder(
                  builder: (context) {
                    final item = st.shoppingList[i];
                    return Dismissible(
                      key: ValueKey('shop_${item.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: p.peachChipBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: p.terracotta,
                        ),
                      ),
                      onDismissed: (_) {
                        ref
                            .read(kitchenProvider.notifier)
                            .removeShoppingItem(item.id);
                      },
                      child: InkWell(
                        onTap: () => ref
                            .read(kitchenProvider.notifier)
                            .toggleShoppingChecked(item.id),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  item.isChecked
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  size: 22,
                                  color: item.isChecked
                                      ? p.primaryAction
                                      : p.muted,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: CrisperTypography.titleMd(p.ink)
                                          .copyWith(
                                            decoration: item.isChecked
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                    ),
                                    if (item.statusHighlight.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        item.isUrgentLowStock
                                            ? '⚠️ ${item.statusHighlight}'
                                            : '🌿 ${item.statusHighlight}',
                                        style: CrisperTypography.bodySm(
                                          item.isUrgentLowStock
                                              ? p.terracotta
                                              : p.primary,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 2),
                                    Text(
                                      item.reasonSubtitle,
                                      style: CrisperTypography.bodySm(p.muted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: p.surfaceLow,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: p.border),
                                ),
                                child: Text(
                                  item.quantityBadge,
                                  style: CrisperTypography.labelSm(p.ink),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Видалити зі списку',
                                onPressed: () => ref
                                    .read(kitchenProvider.notifier)
                                    .removeShoppingItem(item.id),
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: p.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (i < st.shoppingList.length - 1)
                  Divider(color: p.border.withValues(alpha: 0.6), height: 8),
              ],
              if (checkedCount > 0) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      final moved = ref
                          .read(kitchenProvider.notifier)
                          .moveCheckedShoppingToPantry();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Перенесено $moved куплених продуктів прямо у ваш холодильник!',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.kitchen_rounded, size: 18),
                    label: Text(
                      'Перенести куплене ($checkedCount) у холодильник',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Bottom Share & Weekly Calendar Sync Buttons
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  text:
                      '🌿 Мій кулінарний баланс у Crisper: ${s.zeroWasteScore}% Zero-Waste! Врятовано ${s.rescuedKgTotal} кг свіжих продуктів та збережено ${s.savedUahTotal} ₴.',
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
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: Text(
              'Поділитися підсумками місяця',
              style: CrisperTypography.labelLg(p.onPrimary),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _openPlanner(context),
            style: OutlinedButton.styleFrom(
              backgroundColor: p.card,
              side: BorderSide(color: p.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(Icons.event_available_outlined, size: 19, color: p.primary),
            label: Text(
              'Синхронізувати з календарем (Меню на тиждень)',
              style: CrisperTypography.labelMd(p.ink),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Footer Eco Reassurance Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: p.sageChipBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.eco_outlined, color: p.sageChipText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Мінімум відходів — максимум смаку',
                      style: CrisperTypography.titleMd(p.ink),
                    ),
                    Text(
                      'Ви зберегли понад 85% свіжих покупок за цей сезон. Так тримати!',
                      style: CrisperTypography.bodySm(p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceRingPainter extends CustomPainter {
  const _BalanceRingPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
  });

  final double progress;
  final Color activeColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BalanceRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor;
  }
}
