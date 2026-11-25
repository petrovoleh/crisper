import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/kitchen_models.dart';
import '../../services/ingredient_normalizer.dart';
import '../../state/kitchen_store.dart';
import '../../theme/crisper_theme.dart';

class PantryItemEditorSheet extends ConsumerStatefulWidget {
  const PantryItemEditorSheet({
    super.key,
    this.existing,
    this.initialBatchMode = false,
  });

  final PantryItem? existing;
  final bool initialBatchMode;

  @override
  ConsumerState<PantryItemEditorSheet> createState() =>
      _PantryItemEditorSheetState();
}

class _PantryItemEditorSheetState extends ConsumerState<PantryItemEditorSheet> {
  late bool _batchMode = widget.existing == null && widget.initialBatchMode;
  final TextEditingController _batchCtrl = TextEditingController();
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _amountCtrl = TextEditingController(
    text: widget.existing != null
        ? widget.existing!.amountGramsOrPcs.toInt().toString()
        : '200',
  );
  late final TextEditingController _noteCtrl = TextEditingController(
    text: widget.existing?.detailNote ?? '',
  );
  late String _unit = widget.existing?.unit ?? 'г';
  late PantryCategory _category =
      widget.existing?.category ?? PantryCategory.crisperDrawer;
  late int _daysLeft = widget.existing?.daysLeft ?? 5;

  @override
  void dispose() {
    _batchCtrl.dispose();
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _saveBatch() {
    final text = _batchCtrl.text.trim();
    if (text.isEmpty) return;
    final parsed = IngredientNormalizer.parseQuickBatchInput(
      text,
      ref.read(kitchenProvider).pantry,
    );
    if (parsed.isEmpty) return;
    ref.read(kitchenProvider.notifier).addOrMergePantryItems(parsed);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Додано ${parsed.length} позицій у холодильник із розумними строками свіжості!',
        ),
      ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 100;
    final key = widget.existing?.canonicalKey ??
        IngredientNormalizer.canonicalize(
          name,
          ref.read(kitchenProvider).pantry,
        );

    final item = PantryItem(
      id: widget.existing?.id ??
          'manual_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      canonicalKey: key,
      amountGramsOrPcs: amount.clamp(1, 10000),
      unit: _unit,
      detailNote: _noteCtrl.text.trim().isEmpty
          ? 'Домашній запас'
          : _noteCtrl.text.trim(),
      category: _category,
      daysLeft: _daysLeft,
      addedLabel: widget.existing?.addedLabel ?? 'Дод: сьогодні',
      imageAsset: widget.existing?.imageAsset,
    );

    ref.read(kitchenProvider.notifier).savePantryItem(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existing == null
                      ? 'Додати продукт у холодильник'
                      : 'Редагувати інгредієнт',
                  style: CrisperTypography.headlineSm(p.ink),
                ),
                if (widget.existing != null)
                  IconButton(
                    tooltip: 'Видалити з холодильника',
                    onPressed: () {
                      ref
                          .read(kitchenProvider.notifier)
                          .removePantryItem(widget.existing!.id);
                      Navigator.of(context).pop();
                    },
                    icon: Icon(Icons.delete_outline_rounded, color: p.terracotta),
                  ),
              ],
            ),
            if (widget.existing == null) ...[
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.add_box_outlined, size: 16),
                    label: Text('Один продукт'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.mic_none_rounded, size: 16),
                    label: Text('Списком / Голос'),
                  ),
                ],
                selected: {_batchMode},
                onSelectionChanged: (s) => setState(() => _batchMode = s.first),
              ),
            ],
            if (_batchMode) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.sageChipBg.withValues(alpha: p.isDark ? 0.45 : 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.graphic_eq_rounded, size: 18, color: p.sageChipText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Надиктуйте на клавіатурі або напишіть через кому — Crisper сам розбере кількості, полиці та строки зберігання.',
                        style: CrisperTypography.bodySm(p.sageChipText),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _batchCtrl,
                minLines: 2,
                maxLines: 4,
                style: CrisperTypography.bodyMd(p.ink),
                decoration: InputDecoration(
                  hintText:
                      'Напр.: молоко 1 л, два авокадо, сир фета 180 г, 300 г курячого філе',
                  filled: true,
                  fillColor: p.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ActionChip(
                avatar: Icon(Icons.bolt_rounded, size: 16, color: p.primary),
                label: const Text(
                  'Приклад: молоко 1 л, два авокадо, сир фета 180 г',
                ),
                onPressed: () {
                  setState(() {
                    _batchCtrl.text =
                        'молоко 1 л, два авокадо, сир фета 180 г';
                  });
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _saveBatch,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.primaryAction,
                    foregroundColor: p.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  label: Text(
                    'Розібрати та додати у холодильник',
                    style: CrisperTypography.labelLg(p.onPrimary),
                  ),
                ),
              ),
            ] else ...[
              if (widget.existing == null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final preset in [
                      ('Вершки 20%', '200', 'мл', PantryCategory.dairyCheese, 5),
                      ('Вершкове масло', '180', 'г', PantryCategory.dairyCheese, 18),
                      ('Авокадо стигле', '2', 'шт', PantryCategory.crisperDrawer, 2),
                    ])
                      ActionChip(
                        label: Text('+ ${preset.$1}'),
                        onPressed: () {
                          setState(() {
                            _nameCtrl.text = preset.$1;
                            _amountCtrl.text = preset.$2;
                            _unit = preset.$3;
                            _category = preset.$4;
                            _daysLeft = preset.$5;
                          });
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                style: CrisperTypography.bodyMd(p.ink),
                decoration: InputDecoration(
                  labelText: 'Назва продукту',
                  hintText: 'Наприклад: Вершки 20% або Авокадо',
                  filled: true,
                  fillColor: p.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      style: CrisperTypography.tabular(p.ink),
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
                      initialValue: _unit,
                      decoration: InputDecoration(
                        labelText: 'Од.',
                        filled: true,
                        fillColor: p.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const ['г', 'мл', 'шт', 'уп', 'кг']
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _unit = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PantryCategory>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: 'Зона зберігання',
                  filled: true,
                  fillColor: p.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: PantryCategory.values
                    .map(
                      (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                    )
                    .toList(),
                onChanged: (c) {
                  if (c != null) setState(() => _category = c);
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Термін свіжості:',
                    style: CrisperTypography.labelMd(p.ink),
                  ),
                  Text(
                    _daysLeft == 0 ? 'Використати сьогодні' : '$_daysLeft дн.',
                    style: CrisperTypography.labelMd(
                      _daysLeft <= 2 ? p.terracotta : p.primary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _daysLeft.toDouble().clamp(0, 30),
                min: 0,
                max: 30,
                divisions: 30,
                activeColor: _daysLeft <= 2 ? p.terracotta : p.primaryAction,
                onChanged: (v) => setState(() => _daysLeft = v.round()),
              ),
              TextField(
                controller: _noteCtrl,
                style: CrisperTypography.bodyMd(p.ink),
                decoration: InputDecoration(
                  labelText: 'Примітка (необов\'язково)',
                  hintText: 'Баночка, пучок, фермерське...',
                  filled: true,
                  fillColor: p.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.primaryAction,
                    foregroundColor: p.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Зберегти продукт',
                    style: CrisperTypography.labelLg(p.onPrimary),
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

class WeeklyMealPlannerSheet extends ConsumerStatefulWidget {
  const WeeklyMealPlannerSheet({super.key});

  @override
  ConsumerState<WeeklyMealPlannerSheet> createState() =>
      _WeeklyMealPlannerSheetState();
}

class _WeeklyMealPlannerSheetState
    extends ConsumerState<WeeklyMealPlannerSheet> {
  int _selectedDay = 0;
  static const _dayShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];
  static const _dayNums = ['25', '26', '27', '28', '29', '30', '01'];

  Future<void> _pickRecipeForSlot(MealSlot slot) async {
    final st = ref.read(kitchenProvider);
    final chosen = await showModalBottomSheet<Recipe>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Оберіть страву на ${slot.label.toLowerCase()}',
                  style: CrisperTypography.headlineSm(p.ink),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: st.matchedRecipes.map((m) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          m.recipe.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CrisperTypography.titleMd(p.ink),
                        ),
                        subtitle: Text(
                          '${m.matchPercent}% збіг • ${m.recipe.cookMinutes} хв',
                          style: CrisperTypography.bodySm(p.muted),
                        ),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => Navigator.of(ctx).pop(m.recipe),
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
    if (chosen != null) {
      ref.read(kitchenProvider.notifier).setMealPlanSlot(
            dayIndex: _selectedDay,
            slot: slot,
            recipeId: chosen.id,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final st = ref.watch(kitchenProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Тижневий планувальник меню',
                            style: CrisperTypography.headlineSm(p.ink),
                          ),
                          Text(
                            '25 лист. – 1 груд. • Zero-Waste графік',
                            style: CrisperTypography.bodySm(p.muted),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        ref.read(kitchenProvider.notifier).autoFillWeeklyPlan();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Тиждень автоматично сплановано з продуктів у холодильнику!',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: const Text('Авто-план'),
                    ),
                  ],
                ),
              ),
              // 7-day strip
              SizedBox(
                height: 68,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 7,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, d) {
                    final active = d == _selectedDay;
                    final hasMeals = st.mealPlan.any((e) => e.dayIndex == d);
                    return InkWell(
                      onTap: () => setState(() => _selectedDay = d),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 52,
                        decoration: BoxDecoration(
                          color: active ? p.primaryAction : p.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: active ? p.primaryAction : p.border,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _dayShort[d],
                              style: CrisperTypography.labelSm(
                                active ? p.onPrimary : p.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _dayNums[d],
                              style: CrisperTypography.tabular(
                                active ? p.onPrimary : p.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: hasMeals
                                    ? (active ? p.onPrimary : p.primary)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  children: [
                    for (final slot in MealSlot.values) ...[
                      Builder(
                        builder: (context) {
                          final entry = st.mealPlan
                              .where(
                                (e) =>
                                    e.dayIndex == _selectedDay &&
                                    e.slot == slot,
                              )
                              .firstOrNull;
                          final recipe = entry == null
                              ? null
                              : st.recipes
                                    .where((r) => r.id == entry.recipeId)
                                    .firstOrNull;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: p.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: p.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          slot.label.toUpperCase(),
                                          style: CrisperTypography.labelSm(
                                            p.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '🔔 ${slot.defaultReminder}',
                                          style: CrisperTypography.bodySm(
                                            p.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (entry != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            tooltip: entry.isCooked
                                                ? 'Приготовано!'
                                                : 'Позначити приготованим',
                                            onPressed: () {
                                              ref
                                                  .read(
                                                    kitchenProvider.notifier,
                                                  )
                                                  .toggleMealPlanCooked(
                                                    entry.id,
                                                  );
                                            },
                                            icon: Icon(
                                              entry.isCooked
                                                  ? Icons.check_circle_rounded
                                                  : Icons
                                                        .check_circle_outline_rounded,
                                              size: 19,
                                              color: entry.isCooked
                                                  ? p.primaryAction
                                                  : p.muted,
                                            ),
                                          ),
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () {
                                              ref
                                                  .read(
                                                    kitchenProvider.notifier,
                                                  )
                                                  .removeMealPlanEntry(
                                                    entry.id,
                                                  );
                                            },
                                            icon: Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                              color: p.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                if (recipe == null) ...[
                                  const SizedBox(height: 6),
                                  OutlinedButton.icon(
                                    onPressed: () => _pickRecipeForSlot(slot),
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: Text(
                                      'Додати страву на ${slot.label.toLowerCase()}',
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    recipe.title,
                                    style: CrisperTypography.headlineSm(p.ink)
                                        .copyWith(
                                          fontSize: 18,
                                          decoration: entry?.isCooked == true
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${recipe.cookMinutes} хв • ${st.matchForRecipe(recipe).matchPercent}% продуктів є вдома',
                                        style: CrisperTypography.bodySm(p.muted),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          ref
                                              .read(kitchenProvider.notifier)
                                              .startCookingRecipe(recipe);
                                        },
                                        child: const Text('Готувати'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () {
                        final count = ref
                            .read(kitchenProvider.notifier)
                            .syncMealPlanMissingToShopping();
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              count > 0
                                  ? 'Додано $count відсутні інгредієнти у Розумний список покупок!'
                                  : 'Усі інгредієнти для тижневого плану вже є у вашому холодильнику!',
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
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: Text(
                        'Сформувати дельта-список покупок на тиждень',
                        style: CrisperTypography.labelLg(p.onPrimary),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProfileSettingsSheet extends ConsumerStatefulWidget {
  const ProfileSettingsSheet({super.key});

  @override
  ConsumerState<ProfileSettingsSheet> createState() =>
      _ProfileSettingsSheetState();
}

class _ProfileSettingsSheetState extends ConsumerState<ProfileSettingsSheet> {
  late final TextEditingController _apiKeyCtrl;

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl = TextEditingController(
      text: ref.read(kitchenProvider).settings.geminiApiKey,
    );
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final st = ref.watch(kitchenProvider);
    final s = st.settings;
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
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
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: p.primaryAction,
                  child: Icon(Icons.person_rounded, color: p.onPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Профіль та Кухня Crisper',
                        style: CrisperTypography.headlineSm(p.ink),
                      ),
                      Text(
                        'Гостьовий офлайн-режим • Дані захищено локально',
                        style: CrisperTypography.bodySm(p.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Тема оформлення (Warm Culinary Editorial)',
              style: CrisperTypography.labelMd(p.ink),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.wb_sunny_outlined, size: 17),
                  label: Text('Світла'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined, size: 17),
                  label: Text('Темна'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined, size: 17),
                  label: Text('Авто'),
                ),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (sel) {
                ref
                    .read(kitchenProvider.notifier)
                    .updateSettings(s.copyWith(themeMode: sel.first));
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Харчові вподобання',
              style: CrisperTypography.labelMd(p.ink),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DietMode.values.map((mode) {
                final selected = s.dietMode == mode;
                return ChoiceChip(
                  label: Text(mode.label),
                  selected: selected,
                  onSelected: (_) {
                    ref
                        .read(kitchenProvider.notifier)
                        .updateSettings(s.copyWith(dietMode: mode));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Алергії та харчові виключення',
              style: CrisperTypography.labelMd(p.ink),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const [
                  ('lactose', 'Без лактози'),
                  ('gluten', 'Без глютену'),
                  ('eggs', 'Без яєць'),
                  ('nuts', 'Без горіхів'),
                  ('seafood', 'Без риби'),
                ])
                  FilterChip(
                    label: Text(entry.$2),
                    selected: s.allergies.contains(entry.$1),
                    onSelected: (on) {
                      final next = [...s.allergies];
                      if (on) {
                        if (!next.contains(entry.$1)) next.add(entry.$1);
                      } else {
                        next.remove(entry.$1);
                      }
                      ref
                          .read(kitchenProvider.notifier)
                          .updateSettings(s.copyWith(allergies: next));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Базова кількість порцій для сім\'ї',
                  style: CrisperTypography.labelMd(p.ink),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        ref.read(kitchenProvider.notifier).updateSettings(
                              s.copyWith(
                                householdSize:
                                    (s.householdSize - 1).clamp(1, 8),
                              ),
                            );
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '${s.householdSize}',
                      style: CrisperTypography.tabular(
                        p.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        ref.read(kitchenProvider.notifier).updateSettings(
                              s.copyWith(
                                householdSize:
                                    (s.householdSize + 1).clamp(1, 8),
                              ),
                            );
                      },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyCtrl,
              obscureText: true,
              style: CrisperTypography.bodyMd(p.ink),
              onChanged: (v) {
                ref
                    .read(kitchenProvider.notifier)
                    .updateSettings(s.copyWith(geminiApiKey: v.trim()));
              },
              decoration: InputDecoration(
                labelText: 'Gemini 2.5 Flash API Key (опціонально)',
                helperText:
                    'Без ключа працює вбудований локальний AI-двигун Crisper.',
                filled: true,
                fillColor: p.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(kitchenProvider.notifier)
                          .resetDemoData();
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Демо-дані кухні успішно відновлено!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Скинути демо-дані'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.primaryAction,
                      foregroundColor: p.onPrimary,
                    ),
                    child: const Text('Готово'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
