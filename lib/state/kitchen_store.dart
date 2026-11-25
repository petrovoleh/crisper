import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/seed_data.dart';
import '../models/kitchen_models.dart';
import '../services/ingredient_normalizer.dart';
import '../services/platform_bridge.dart';

enum MealTimeFilter {
  all('Усі прийоми', Icons.restaurant_rounded),
  breakfast('Сніданок', Icons.wb_twilight_rounded),
  lunch('Обід', Icons.wb_sunny_outlined),
  dinner('Вечеря', Icons.nights_stay_outlined);

  const MealTimeFilter(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum RecipeFilter {
  zeroWaste('Найвищий збіг (Zero-Waste)', Icons.eco_outlined),
  quick('Швидкі (< 25 хв)', Icons.schedule_outlined),
  rescue('Рятують термінові', Icons.priority_high_rounded),
  saved('Збережені', Icons.bookmark_outline_rounded),
  imported('Імпорт & AI', Icons.auto_awesome_outlined);

  const RecipeFilter(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum PantrySort {
  expiry('За свіжістю (спочатку термінові)'),
  alphabetical('За алфавітом (А–Я)'),
  quantity('За кількістю');

  const PantrySort(this.label);
  final String label;
}

@immutable
class KitchenState {
  const KitchenState({
    required this.pantry,
    required this.recipes,
    required this.rescuedLogs,
    required this.shoppingList,
    required this.mealPlan,
    required this.settings,
    this.activeTab = 0,
    this.pantrySearch = '',
    this.selectedCategory,
    this.pantrySort = PantrySort.expiry,
    this.recipeFilter = RecipeFilter.zeroWaste,
    this.mealTimeFilter = MealTimeFilter.all,
    this.activeRecipeId = 'r_spinach_pasta',
    this.cookingStepIndex = 1,
    this.cookingServings = 2,
    this.checkedIngredientKeys = const <String>{'pasta'},
    this.timerSecondsLeft = 225,
    this.isTimerRunning = false,
    this.pendingSharedUrl,
    this.pendingQuickAction,
  });

  final List<PantryItem> pantry;
  final List<Recipe> recipes;
  final List<RescuedItemLog> rescuedLogs;
  final List<ShoppingListItem> shoppingList;
  final List<MealPlanEntry> mealPlan;
  final KitchenSettings settings;

  final int activeTab;
  final String pantrySearch;
  final PantryCategory? selectedCategory;
  final PantrySort pantrySort;
  final RecipeFilter recipeFilter;
  final MealTimeFilter mealTimeFilter;

  final String activeRecipeId;
  final int cookingStepIndex;
  final int cookingServings;
  final Set<String> checkedIngredientKeys;
  final int timerSecondsLeft;
  final bool isTimerRunning;
  final String? pendingSharedUrl;
  final String? pendingQuickAction;

  static MealTimeFilter suggestedMealTimeForHour(int hour) {
    if (hour >= 5 && hour < 11) return MealTimeFilter.breakfast;
    if (hour >= 11 && hour < 17) return MealTimeFilter.lunch;
    return MealTimeFilter.dinner;
  }

  static bool _recipeFitsMealTime(Recipe r, MealTimeFilter slot) {
    if (slot == MealTimeFilter.all) return true;
    final tagSet = r.tags.map((t) => t.toLowerCase()).toSet();
    if (tagSet.contains(slot.name)) return true;
    final t = r.title.toLowerCase();
    final isSweetOrEggDish = RegExp(
      r'(?:сирник|фріттат|омлет|скрембл|вівсян|млинц|олад|вареник|банан|снідан|тост|йогурт)',
    ).hasMatch(t);
    return switch (slot) {
      MealTimeFilter.breakfast => isSweetOrEggDish || r.cookMinutes <= 18,
      MealTimeFilter.lunch => !t.contains('снідан') || r.caloriesPerServing >= 300,
      MealTimeFilter.dinner =>
        tagSet.contains('dinner') || !t.contains('сніданкова'),
      MealTimeFilter.all => true,
    };
  }

  List<PantryItem> get expiringItems {
    final list = pantry.where((e) => e.daysLeft <= 2).toList()
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return list;
  }

  List<PantryItem> get filteredPantry {
    final q = pantrySearch.trim().toLowerCase();
    final filtered = pantry.where((item) {
      if (selectedCategory != null && item.category != selectedCategory) {
        return false;
      }
      if (q.isNotEmpty &&
          !item.name.toLowerCase().contains(q) &&
          !item.detailNote.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    switch (pantrySort) {
      case PantrySort.expiry:
        filtered.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
      case PantrySort.alphabetical:
        filtered.sort((a, b) => a.name.compareTo(b.name));
      case PantrySort.quantity:
        filtered.sort(
          (a, b) => b.amountGramsOrPcs.compareTo(a.amountGramsOrPcs),
        );
    }
    return filtered;
  }

  Recipe get activeRecipe {
    return recipes.firstWhere(
      (r) => r.id == activeRecipeId,
      orElse: () => recipes.first,
    );
  }

  RecipeMatch matchForRecipe(Recipe recipe) {
    final byKey = <String, PantryItem>{
      for (final item in pantry) item.canonicalKey: item,
    };
    final owned = <RecipeIngredient>[];
    final missing = <RecipeIngredient>[];
    final rescued = <PantryItem>[];
    String? dynamicTip;

    for (final ing in recipe.ingredients) {
      final found = byKey[ing.canonicalKey];
      if (found != null && found.amountGramsOrPcs > 0) {
        owned.add(ing);
        if (found.daysLeft <= 2 && !rescued.any((r) => r.id == found.id)) {
          rescued.add(found);
        }
      } else {
        missing.add(ing);
        if (ing.substituteKey != null && byKey.containsKey(ing.substituteKey)) {
          dynamicTip ??= ing.substituteTip;
        }
      }
    }

    final total = recipe.ingredients.isEmpty ? 1 : recipe.ingredients.length;
    int pct = ((owned.length / total) * 100).round();
    if (missing.length == 1 && dynamicTip != null && pct < 92) {
      pct = 92;
    }

    return RecipeMatch(
      recipe: recipe,
      ownedIngredients: owned,
      missingIngredients: missing,
      rescuedItems: rescued,
      matchPercent: pct.clamp(0, 100),
      activeAiTip: dynamicTip ??
          (recipe.sousChefAdvice.isNotEmpty ? recipe.sousChefAdvice : null),
    );
  }

  List<RecipeMatch> get matchedRecipes {
    final dietFiltered = recipes.where((r) {
      // 1. Check allergies
      for (final allergy in settings.allergies) {
        if (r.ingredients.any(
          (i) => IngredientNormalizer.matchesAllergy(
            allergy,
            i.canonicalKey,
            i.name,
          ),
        )) {
          return false;
        }
      }

      // 2. Check DietMode
      switch (settings.dietMode) {
        case DietMode.omnivore:
          break;
        case DietMode.vegetarian:
          if (r.ingredients.any(
            (i) =>
                IngredientNormalizer.isMeat(i.canonicalKey, i.name) ||
                IngredientNormalizer.isFishOrSeafood(i.canonicalKey, i.name),
          )) {
            return false;
          }
        case DietMode.pescatarian:
          if (r.ingredients.any(
            (i) => IngredientNormalizer.isMeat(i.canonicalKey, i.name),
          )) {
            return false;
          }
        case DietMode.glutenFree:
          if (!r.tags.contains('glutenFree') &&
              r.ingredients.any(
                (i) =>
                    IngredientNormalizer.containsGluten(i.canonicalKey, i.name),
              )) {
            return false;
          }
        case DietMode.highProtein:
          final hasProtein = r.tags.contains('highProtein') ||
              r.ingredients.any(
                (i) => IngredientNormalizer.isHighProtein(i.canonicalKey),
              );
          if (!hasProtein) return false;
      }

      // 3. Check MealTimeFilter
      if (!_recipeFitsMealTime(r, mealTimeFilter)) {
        return false;
      }
      return true;
    });

    var matches = dietFiltered.map(matchForRecipe).toList();

    switch (recipeFilter) {
      case RecipeFilter.zeroWaste:
        break;
      case RecipeFilter.quick:
        matches = matches.where((m) => m.recipe.cookMinutes <= 25).toList();
      case RecipeFilter.rescue:
        matches = matches.where((m) => m.rescuedItems.isNotEmpty).toList();
      case RecipeFilter.saved:
        matches = matches.where((m) => m.recipe.isBookmarked).toList();
      case RecipeFilter.imported:
        matches = matches
            .where((m) => m.recipe.source != RecipeSource.curated)
            .toList();
    }

    final suggestedNow = suggestedMealTimeForHour(DateTime.now().hour);
    matches.sort((a, b) {
      final timeBoostA = mealTimeFilter == MealTimeFilter.all &&
              _recipeFitsMealTime(a.recipe, suggestedNow)
          ? 4
          : 0;
      final timeBoostB = mealTimeFilter == MealTimeFilter.all &&
              _recipeFitsMealTime(b.recipe, suggestedNow)
          ? 4
          : 0;
      final scoreA = a.matchPercent + (a.rescuedItems.length * 8) + timeBoostA;
      final scoreB = b.matchPercent + (b.rescuedItems.length * 8) + timeBoostB;
      return scoreB.compareTo(scoreA);
    });
    return matches;
  }

  KitchenState copyWith({
    List<PantryItem>? pantry,
    List<Recipe>? recipes,
    List<RescuedItemLog>? rescuedLogs,
    List<ShoppingListItem>? shoppingList,
    List<MealPlanEntry>? mealPlan,
    KitchenSettings? settings,
    int? activeTab,
    String? pantrySearch,
    PantryCategory? selectedCategory,
    bool clearSelectedCategory = false,
    PantrySort? pantrySort,
    RecipeFilter? recipeFilter,
    MealTimeFilter? mealTimeFilter,
    String? activeRecipeId,
    int? cookingStepIndex,
    int? cookingServings,
    Set<String>? checkedIngredientKeys,
    int? timerSecondsLeft,
    bool? isTimerRunning,
    String? pendingSharedUrl,
    bool clearPendingSharedUrl = false,
    String? pendingQuickAction,
    bool clearPendingQuickAction = false,
  }) {
    return KitchenState(
      pantry: pantry ?? this.pantry,
      recipes: recipes ?? this.recipes,
      rescuedLogs: rescuedLogs ?? this.rescuedLogs,
      shoppingList: shoppingList ?? this.shoppingList,
      mealPlan: mealPlan ?? this.mealPlan,
      settings: settings ?? this.settings,
      activeTab: activeTab ?? this.activeTab,
      pantrySearch: pantrySearch ?? this.pantrySearch,
      selectedCategory: clearSelectedCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      pantrySort: pantrySort ?? this.pantrySort,
      recipeFilter: recipeFilter ?? this.recipeFilter,
      mealTimeFilter: mealTimeFilter ?? this.mealTimeFilter,
      activeRecipeId: activeRecipeId ?? this.activeRecipeId,
      cookingStepIndex: cookingStepIndex ?? this.cookingStepIndex,
      cookingServings: cookingServings ?? this.cookingServings,
      checkedIngredientKeys:
          checkedIngredientKeys ?? this.checkedIngredientKeys,
      timerSecondsLeft: timerSecondsLeft ?? this.timerSecondsLeft,
      isTimerRunning: isTimerRunning ?? this.isTimerRunning,
      pendingSharedUrl: clearPendingSharedUrl
          ? null
          : (pendingSharedUrl ?? this.pendingSharedUrl),
      pendingQuickAction: clearPendingQuickAction
          ? null
          : (pendingQuickAction ?? this.pendingQuickAction),
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

final kitchenProvider =
    StateNotifierProvider<KitchenController, KitchenState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return KitchenController(prefs);
});

class KitchenController extends StateNotifier<KitchenState> {
  KitchenController(this._prefs) : super(_loadInitialState(_prefs)) {
    _initShareHandling();
  }

  static const String _storageKey = 'crisper_kitchen_v1';
  final SharedPreferences _prefs;
  Timer? _countdownTimer;

  static KitchenState _loadInitialState(SharedPreferences prefs) {
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final pantry = ((m['pantry'] as List<dynamic>?) ?? [])
            .map((e) => PantryItem.fromJson(e as Map<String, dynamic>))
            .toList();
        final recipes = ((m['recipes'] as List<dynamic>?) ?? [])
            .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
            .toList();
        final rescued = ((m['rescuedLogs'] as List<dynamic>?) ?? [])
            .map((e) => RescuedItemLog.fromJson(e as Map<String, dynamic>))
            .toList();
        final shopping = ((m['shoppingList'] as List<dynamic>?) ?? [])
            .map((e) => ShoppingListItem.fromJson(e as Map<String, dynamic>))
            .toList();
        final mealPlan = ((m['mealPlan'] as List<dynamic>?) ?? [])
            .map((e) => MealPlanEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        final settings = m['settings'] != null
            ? KitchenSettings.fromJson(m['settings'] as Map<String, dynamic>)
            : const KitchenSettings();

        if (recipes.isNotEmpty) {
          final firstRecipe = recipes.first;
          final initialStepIdx =
              firstRecipe.steps.length > 1 ? 1 : 0;
          final initialSec = firstRecipe.steps.isNotEmpty
              ? firstRecipe.steps[initialStepIdx].effectiveTimerSeconds
              : 180;
          return KitchenState(
            pantry: pantry,
            recipes: recipes,
            rescuedLogs: rescued,
            shoppingList: shopping,
            mealPlan: mealPlan,
            settings: settings,
            activeRecipeId: firstRecipe.id,
            cookingStepIndex: initialStepIdx,
            timerSecondsLeft: initialSec,
          );
        }
      } catch (_) {
        // Fallback to seed data if schema changed
      }
    }

    return KitchenState(
      pantry: SeedData.initialPantry(),
      recipes: SeedData.initialRecipes(),
      rescuedLogs: SeedData.initialRescuedLogs(),
      shoppingList: SeedData.initialShoppingList(),
      mealPlan: SeedData.initialMealPlan(),
      settings: const KitchenSettings(),
    );
  }

  Future<void> _persist() async {
    final payload = jsonEncode({
      'pantry': state.pantry.map((e) => e.toJson()).toList(),
      'recipes': state.recipes.map((e) => e.toJson()).toList(),
      'rescuedLogs': state.rescuedLogs.map((e) => e.toJson()).toList(),
      'shoppingList': state.shoppingList.map((e) => e.toJson()).toList(),
      'mealPlan': state.mealPlan.map((e) => e.toJson()).toList(),
      'settings': state.settings.toJson(),
    });
    await _prefs.setString(_storageKey, payload);
    _syncHomeWidget();
  }

  void _syncHomeWidget() {
    if (!mounted) return;
    final exp = state.expiringItems;
    final topLabel = exp.isNotEmpty
        ? '${exp.first.name} (${exp.first.daysLeftBadge})'
        : 'Усі продукти свіжі';
    PlatformBridge.updateHomeWidget(
      expiringCount: exp.length,
      topUrgentLabel: topLabel,
      pantryCount: state.pantry.length,
    );
  }

  Future<void> _initShareHandling() async {
    PlatformBridge.setPlatformListeners(
      onSharedText: (sharedText) {
        state = state.copyWith(pendingSharedUrl: sharedText);
      },
      onQuickAction: (action) {
        state = state.copyWith(pendingQuickAction: action);
      },
    );
    final initial = await PlatformBridge.consumeInitialSharedText();
    if (initial != null && mounted) {
      state = state.copyWith(pendingSharedUrl: initial);
    }
    final quick = await PlatformBridge.consumeInitialQuickAction();
    if (quick != null && mounted) {
      state = state.copyWith(pendingQuickAction: quick);
    }
    _syncHomeWidget();
  }

  void clearPendingSharedUrl() {
    state = state.copyWith(clearPendingSharedUrl: true);
  }

  void clearPendingQuickAction() {
    state = state.copyWith(clearPendingQuickAction: true);
  }

  void setTab(int index) {
    if (index == 2) {
      PlatformBridge.setKeepScreenOn(true);
    } else if (state.activeTab == 2 && index != 2) {
      PlatformBridge.setKeepScreenOn(false);
    }
    state = state.copyWith(activeTab: index);
  }

  void openRescueRecipes() {
    state = state.copyWith(
      activeTab: 1,
      recipeFilter: RecipeFilter.rescue,
    );
  }

  void setPantrySearch(String query) {
    state = state.copyWith(pantrySearch: query);
  }

  void setCategoryFilter(PantryCategory? category) {
    if (category == null) {
      state = state.copyWith(clearSelectedCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
  }

  void setPantrySort(PantrySort sort) {
    state = state.copyWith(pantrySort: sort);
  }

  void setRecipeFilter(RecipeFilter filter) {
    state = state.copyWith(recipeFilter: filter);
  }

  void setMealTimeFilter(MealTimeFilter filter) {
    state = state.copyWith(mealTimeFilter: filter);
  }

  // --- Pantry Operations ---
  void addOrMergePantryItems(List<PantryItem> incoming) {
    final updated = [...state.pantry];
    for (final item in incoming) {
      final idx = updated.indexWhere(
        (e) =>
            e.canonicalKey == item.canonicalKey && e.unit == item.unit,
      );
      if (idx >= 0) {
        final existing = updated[idx];
        updated[idx] = existing.copyWith(
          amountGramsOrPcs: existing.amountGramsOrPcs + item.amountGramsOrPcs,
          daysLeft: item.daysLeft < existing.daysLeft
              ? item.daysLeft
              : existing.daysLeft,
        );
      } else {
        updated.insert(0, item);
      }
    }
    state = state.copyWith(pantry: updated);
    _persist();
  }

  void savePantryItem(PantryItem item) {
    final idx = state.pantry.indexWhere((e) => e.id == item.id);
    final updated = [...state.pantry];
    if (idx >= 0) {
      updated[idx] = item;
    } else {
      updated.insert(0, item);
    }
    state = state.copyWith(pantry: updated);
    _persist();
  }

  void removePantryItem(String id) {
    state = state.copyWith(
      pantry: state.pantry.where((e) => e.id != id).toList(),
    );
    _persist();
  }

  // --- Recipe & Cooking Operations ---
  void toggleBookmark(String recipeId) {
    final updated = state.recipes.map((r) {
      if (r.id == recipeId) return r.copyWith(isBookmarked: !r.isBookmarked);
      return r;
    }).toList();
    state = state.copyWith(recipes: updated);
    _persist();
  }

  void removeRecipe(String recipeId) {
    final remaining = state.recipes.where((r) => r.id != recipeId).toList();
    if (remaining.isEmpty) return;
    final nextActiveId = state.activeRecipeId == recipeId
        ? remaining.first.id
        : state.activeRecipeId;
    final nextMealPlan = state.mealPlan
        .where((m) => m.recipeId != recipeId)
        .toList();
    state = state.copyWith(
      recipes: remaining,
      activeRecipeId: nextActiveId,
      cookingStepIndex: 0,
      mealPlan: nextMealPlan,
    );
    _persist();
  }

  void addNewRecipe(Recipe recipe, {bool openImmediately = true}) {
    final updated = [recipe, ...state.recipes];
    final firstTimer = recipe.steps.isNotEmpty
        ? recipe.steps.first.effectiveTimerSeconds
        : 180;
    final initialServings = state.settings.householdSize != 2
        ? state.settings.householdSize
        : recipe.defaultServings;
    _stopTimerInternal();
    state = state.copyWith(
      recipes: updated,
      activeRecipeId: openImmediately ? recipe.id : state.activeRecipeId,
      cookingStepIndex: openImmediately ? 0 : state.cookingStepIndex,
      cookingServings:
          openImmediately ? initialServings : state.cookingServings,
      checkedIngredientKeys:
          openImmediately ? const <String>{} : state.checkedIngredientKeys,
      timerSecondsLeft:
          openImmediately ? firstTimer : state.timerSecondsLeft,
      isTimerRunning: false,
      activeTab: openImmediately ? 2 : state.activeTab,
    );
    if (openImmediately) {
      PlatformBridge.setKeepScreenOn(true);
    }
    _persist();
  }

  void startCookingRecipe(Recipe recipe, {int startStep = 0}) {
    _stopTimerInternal();
    final stepIdx = startStep.clamp(0, recipe.steps.length - 1);
    final sec = recipe.steps[stepIdx].effectiveTimerSeconds;
    final initialServings = state.settings.householdSize != 2
        ? state.settings.householdSize
        : recipe.defaultServings;
    PlatformBridge.setKeepScreenOn(true);
    state = state.copyWith(
      activeTab: 2,
      activeRecipeId: recipe.id,
      cookingStepIndex: stepIdx,
      cookingServings: initialServings,
      checkedIngredientKeys: const <String>{},
      timerSecondsLeft: sec,
      isTimerRunning: false,
    );
  }

  void setCookingServings(int servings) {
    state = state.copyWith(cookingServings: servings.clamp(1, 12));
  }

  void toggleIngredientPrepared(String canonicalKey) {
    final next = {...state.checkedIngredientKeys};
    if (next.contains(canonicalKey)) {
      next.remove(canonicalKey);
    } else {
      next.add(canonicalKey);
    }
    state = state.copyWith(checkedIngredientKeys: next);
  }

  void toggleAllIngredientsPrepared(Recipe recipe) {
    final allKeys = recipe.ingredients.map((e) => e.canonicalKey).toSet();
    final allChecked = allKeys.every(state.checkedIngredientKeys.contains);
    state = state.copyWith(
      checkedIngredientKeys: allChecked ? const <String>{} : allKeys,
    );
  }

  void setCookingStep(int stepIndex) {
    final recipe = state.activeRecipe;
    if (stepIndex < 0 || stepIndex >= recipe.steps.length) return;
    _stopTimerInternal();
    state = state.copyWith(
      cookingStepIndex: stepIndex,
      timerSecondsLeft: recipe.steps[stepIndex].effectiveTimerSeconds,
      isTimerRunning: false,
    );
  }

  // --- Kitchen Countdown Timer ---
  void toggleTimer() {
    if (state.isTimerRunning) {
      _stopTimerInternal();
      state = state.copyWith(isTimerRunning: false);
      return;
    }
    if (state.timerSecondsLeft <= 0) {
      final defaultSec = state
          .activeRecipe
          .steps[state.cookingStepIndex]
          .effectiveTimerSeconds;
      state = state.copyWith(timerSecondsLeft: defaultSec);
    }
    state = state.copyWith(isTimerRunning: true);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (state.timerSecondsLeft <= 1) {
        timer.cancel();
        state = state.copyWith(timerSecondsLeft: 0, isTimerRunning: false);
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      } else {
        state = state.copyWith(timerSecondsLeft: state.timerSecondsLeft - 1);
      }
    });
  }

  void addOneMinuteToTimer() {
    state = state.copyWith(timerSecondsLeft: state.timerSecondsLeft + 60);
  }

  void resetStepTimer() {
    _stopTimerInternal();
    final step = state.activeRecipe.steps[state.cookingStepIndex];
    state = state.copyWith(
      timerSecondsLeft: step.effectiveTimerSeconds,
      isTimerRunning: false,
    );
  }

  void _stopTimerInternal() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// Auto-deducts cooked ingredients from fridge inventory & updates Zero-Waste Eco Balance.
  void finishCookingAndDeduct({
    required Recipe recipe,
    required Set<String> keysToDeduct,
  }) {
    _stopTimerInternal();
    PlatformBridge.setKeepScreenOn(false);

    final factor = recipe.defaultServings > 0
        ? state.cookingServings / recipe.defaultServings
        : 1.0;

    final nextPantry = <PantryItem>[];
    final rescuedNames = <String>[];

    for (final p in state.pantry) {
      final matchingIng = recipe.ingredients
          .where((i) => i.canonicalKey == p.canonicalKey)
          .firstOrNull;
      if (matchingIng != null && keysToDeduct.contains(p.canonicalKey)) {
        if (p.isExpiringSoon) {
          rescuedNames.add(p.name);
        }
        if (p.unit == matchingIng.unit) {
          final remaining = p.amountGramsOrPcs - (matchingIng.baseAmount * factor);
          if (remaining > 5) {
            nextPantry.add(
              p.copyWith(amountGramsOrPcs: remaining.roundToDouble()),
            );
          }
        } else {
          final remaining = p.amountGramsOrPcs * 0.65;
          if (remaining >= 1) {
            nextPantry.add(
              p.copyWith(amountGramsOrPcs: remaining.roundToDouble()),
            );
          }
        }
      } else {
        nextPantry.add(p);
      }
    }

    final rescuedGrams = (recipe.rescuedGrams * factor).round();
    final rescuedKgDelta = rescuedGrams / 1000.0;
    final newLog = RescuedItemLog(
      id: 'res_${DateTime.now().millisecondsSinceEpoch}',
      title: rescuedNames.isNotEmpty
          ? rescuedNames.join(', ')
          : recipe.ingredients.first.name,
      dishNote: 'Приготовано: ${recipe.title}',
      amountBadge: '$rescuedGrams г',
      iconName: 'leaf',
    );

    final s = state.settings;
    final nextSettings = s.copyWith(
      rescuedKgTotal:
          double.parse((s.rescuedKgTotal + rescuedKgDelta).toStringAsFixed(2)),
      rescuedKgThisWeek: double.parse(
        (s.rescuedKgThisWeek + rescuedKgDelta).toStringAsFixed(2),
      ),
      savedUahTotal: s.savedUahTotal + (rescuedGrams * 0.45).round().clamp(45, 220),
      co2SavedKg:
          double.parse((s.co2SavedKg + rescuedKgDelta * 2.2).toStringAsFixed(1)),
      zeroWasteScore: (s.zeroWasteScore + 1).clamp(0, 99),
    );

    state = state.copyWith(
      pantry: nextPantry,
      rescuedLogs: [newLog, ...state.rescuedLogs],
      settings: nextSettings,
      isTimerRunning: false,
      activeTab: 3,
    );
    _persist();
  }

  // --- Shopping List Operations ---
  void addIngredientToShoppingList(RecipeIngredient ing, String recipeTitle) {
    final exists =
        state.shoppingList.any((s) => s.canonicalKey == ing.canonicalKey);
    if (exists) return;
    final amtStr = IngredientNormalizer.formatCompactAmount(ing.baseAmount);
    final item = ShoppingListItem(
      id: 'sh_${DateTime.now().millisecondsSinceEpoch}',
      name: ing.name,
      canonicalKey: ing.canonicalKey,
      quantityBadge: '$amtStr ${ing.unit}',
      numericAmount: ing.baseAmount,
      unit: ing.unit,
      statusHighlight: 'Відсутній у коморі',
      isUrgentLowStock: true,
      reasonSubtitle: 'Потрібний для: $recipeTitle',
      category: IngredientNormalizer.inferCategory(ing.canonicalKey, ing.name),
    );
    state = state.copyWith(shoppingList: [item, ...state.shoppingList]);
    _persist();
  }

  void removeShoppingItem(String id) {
    state = state.copyWith(
      shoppingList: state.shoppingList.where((e) => e.id != id).toList(),
    );
    _persist();
  }

  void addCustomShoppingItem({
    required String name,
    required double amount,
    required String unit,
    required PantryCategory category,
  }) {
    final key =
        name.trim().toLowerCase().replaceAll(RegExp(r'[^a-zа-яіїєґ0-9]+'), '_');
    final amtStr =
        amount == amount.roundToDouble() ? amount.toInt().toString() : '$amount';
    final item = ShoppingListItem(
      id: 'sh_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      canonicalKey: key,
      quantityBadge: '$amtStr $unit',
      numericAmount: amount,
      unit: unit,
      statusHighlight: 'Додано вручну',
      reasonSubtitle: 'Для поповнення домашніх запасів',
      category: category,
    );
    state = state.copyWith(shoppingList: [item, ...state.shoppingList]);
    _persist();
  }

  void toggleShoppingChecked(String id) {
    final updated = state.shoppingList.map((e) {
      if (e.id == id) return e.copyWith(isChecked: !e.isChecked);
      return e;
    }).toList();
    state = state.copyWith(shoppingList: updated);
    _persist();
  }

  int moveCheckedShoppingToPantry() {
    final bought = state.shoppingList.where((e) => e.isChecked).toList();
    if (bought.isEmpty) return 0;

    final toAdd = bought
        .map(
          (b) => PantryItem(
            id: 'bought_${b.id}',
            name: b.name,
            canonicalKey: b.canonicalKey,
            amountGramsOrPcs: b.numericAmount,
            unit: b.unit,
            detailNote: 'Зі списку покупок',
            category: b.category,
            daysLeft: IngredientNormalizer.inferDefaultShelfDays(
              b.canonicalKey,
              b.category,
            ),
            addedLabel: 'Дод: сьогодні',
          ),
        )
        .toList();

    addOrMergePantryItems(toAdd);
    state = state.copyWith(
      shoppingList: state.shoppingList.where((e) => !e.isChecked).toList(),
    );
    _persist();
    return bought.length;
  }

  // --- Weekly Meal Planner ---
  void setMealPlanSlot({
    required int dayIndex,
    required MealSlot slot,
    required String recipeId,
  }) {
    final filtered = state.mealPlan
        .where((e) => !(e.dayIndex == dayIndex && e.slot == slot))
        .toList();
    filtered.add(
      MealPlanEntry(
        id: 'mp_${dayIndex}_${slot.name}',
        dayIndex: dayIndex,
        slot: slot,
        recipeId: recipeId,
      ),
    );
    state = state.copyWith(mealPlan: filtered);
    _persist();
  }

  void removeMealPlanEntry(String id) {
    state = state.copyWith(
      mealPlan: state.mealPlan.where((e) => e.id != id).toList(),
    );
    _persist();
  }

  void toggleMealPlanCooked(String id) {
    final updated = state.mealPlan.map((e) {
      if (e.id == id) return e.copyWith(isCooked: !e.isCooked);
      return e;
    }).toList();
    state = state.copyWith(mealPlan: updated);
    _persist();
  }

  void autoFillWeeklyPlan() {
    if (state.recipes.isEmpty) return;
    final ranked = state.matchedRecipes.map((m) => m.recipe).toList();
    final pool = ranked.isNotEmpty ? ranked : state.recipes;
    final generated = <MealPlanEntry>[];
    int cursor = 0;
    for (int day = 0; day < 7; day++) {
      for (final slot in [MealSlot.breakfast, MealSlot.dinner]) {
        final r = pool[cursor % pool.length];
        cursor++;
        generated.add(
          MealPlanEntry(
            id: 'mp_${day}_${slot.name}',
            dayIndex: day,
            slot: slot,
            recipeId: r.id,
          ),
        );
      }
    }
    state = state.copyWith(mealPlan: generated);
    _persist();
  }

  int syncMealPlanMissingToShopping() {
    int added = 0;
    final nextShopping = [...state.shoppingList];
    final ownedKeys = state.pantry.map((e) => e.canonicalKey).toSet();

    for (final entry in state.mealPlan) {
      final recipe =
          state.recipes.where((r) => r.id == entry.recipeId).firstOrNull;
      if (recipe == null) continue;
      for (final ing in recipe.ingredients) {
        if (!ownedKeys.contains(ing.canonicalKey) &&
            !nextShopping.any((s) => s.canonicalKey == ing.canonicalKey)) {
          added++;
          final amtStr = IngredientNormalizer.formatCompactAmount(
            ing.baseAmount,
          );
          nextShopping.insert(
            0,
            ShoppingListItem(
              id: 'sh_plan_${DateTime.now().millisecondsSinceEpoch}_$added',
              name: ing.name,
              canonicalKey: ing.canonicalKey,
              quantityBadge: '$amtStr ${ing.unit}',
              numericAmount: ing.baseAmount,
              unit: ing.unit,
              statusHighlight: 'Для тижневого меню',
              isUrgentLowStock: true,
              reasonSubtitle: 'Заплановано: ${recipe.title}',
              category: IngredientNormalizer.inferCategory(
                ing.canonicalKey,
                ing.name,
              ),
            ),
          );
        }
      }
    }
    if (added > 0) {
      state = state.copyWith(shoppingList: nextShopping);
      _persist();
    }
    return added;
  }

  // --- Settings ---
  void updateSettings(KitchenSettings next) {
    state = state.copyWith(settings: next);
    _persist();
  }

  Future<void> resetDemoData() async {
    _stopTimerInternal();
    await _prefs.remove(_storageKey);
    state = KitchenState(
      pantry: SeedData.initialPantry(),
      recipes: SeedData.initialRecipes(),
      rescuedLogs: SeedData.initialRescuedLogs(),
      shoppingList: SeedData.initialShoppingList(),
      mealPlan: SeedData.initialMealPlan(),
      settings: state.settings,
    );
  }

  @override
  void dispose() {
    _stopTimerInternal();
    super.dispose();
  }
}
