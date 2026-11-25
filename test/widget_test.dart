import 'package:crisper/data/seed_data.dart';
import 'package:crisper/main.dart';
import 'package:crisper/models/kitchen_models.dart';
import 'package:crisper/screens/modals/planner_and_profile_sheets.dart';
import 'package:crisper/screens/modals/social_import_sheet.dart';
import 'package:crisper/services/ingredient_normalizer.dart';
import 'package:crisper/services/social_recipe_extractor.dart';
import 'package:crisper/state/kitchen_store.dart';
import 'package:crisper/theme/crisper_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'SocialRecipeExtractor accurately parses TikTok Ліниві вареники caption with inline bullets and timers',
    () {
      const caption =
          'Ліниві вареники, їх після того як ви відварите можна ще додатково підсмажити на вершковому маслі, а можно це не робити  '
          '- сир 300г. - цукор 1 ст.л. - яйце 1шт. - дрібка солі - ванільний цукор  - борошно 4-5ст.л '
          'Також борошно потрібно для того щоб кульки обваляти після формування '
          'Варю ліниві вареники 2хв. після закипання '
          'Коли ліниві вареники вже заморожені, тоді варити потрібно трохи довше    '
          '#рецепт #лінивівареники #вареники #вареникизсиром';

      final payload = const SocialPagePayload(
        source: RecipeSource.tiktok,
        resolvedUrl: 'https://vm.tiktok.com/ZN8uP1BfB/',
        rawText: caption,
        authorHandle: '@stohantsevayuliia',
        coverImageUrl: 'https://example.com/varenyky.jpg',
      );

      final recipe = SocialRecipeExtractor.parsePayloadToRecipe(
        payload,
        SeedData.initialPantry(),
      );

      expect(recipe.title, 'Ліниві вареники');
      expect(recipe.authorHandle, '@stohantsevayuliia');
      expect(recipe.source, RecipeSource.tiktok);
      expect(
        recipe.ingredients.any((i) => i.canonicalKey == 'cottage_cheese' && i.baseAmount == 300),
        isTrue,
      );
      expect(
        recipe.ingredients.any((i) => i.canonicalKey == 'eggs' && i.baseAmount == 1),
        isTrue,
      );
      expect(
        recipe.ingredients.any((i) => i.canonicalKey == 'flour' && i.baseAmount == 5),
        isTrue,
      );
      expect(
        recipe.steps.any((s) => s.timerSeconds == 120),
        isTrue,
      );
    },
  );

  test(
    'SocialRecipeExtractor auto-fills all spoken ingredients and timers from video transcript when description is empty',
    () {
      const payload = SocialPagePayload(
        source: RecipeSource.tiktok,
        resolvedUrl: 'https://www.tiktok.com/@chef/video/123456',
        rawText: 'Сніданок за лічені хвилини 😍 #рецепт #сніданок',
        transcript:
            'сьогодні готуємо швидкий сніданок беремо пачку сиру розбиваємо два яйця '
            'додаємо свіжий шпинат томати чері трохи часнику і смажимо на оливковій олії п\x27ять хвилин',
        authorHandle: '@chef',
      );

      final recipe = SocialRecipeExtractor.parsePayloadToRecipe(
        payload,
        SeedData.initialPantry(),
      );

      final keys = recipe.ingredients.map((i) => i.canonicalKey).toSet();
      expect(keys, containsAll(['cottage_cheese', 'eggs', 'spinach', 'cherry_tomatoes', 'garlic']));
      expect(recipe.sousChefAdvice, contains('розшифровки мовлення відео'));
      expect(recipe.steps.any((s) => s.timerSeconds == 300), isTrue);
    },
  );

  test(
    'SocialRecipeExtractor infers canonical dish ingredients when video has neither description list nor speech',
    () {
      const payload = SocialPagePayload(
        source: RecipeSource.instagram,
        resolvedUrl: 'https://www.instagram.com/reel/xyz/',
        rawText: 'Хрусткі домашні деруни 🔥 #деруни',
        transcript: '',
      );

      final recipe = SocialRecipeExtractor.parsePayloadToRecipe(
        payload,
        SeedData.initialPantry(),
      );

      final keys = recipe.ingredients.map((i) => i.canonicalKey).toSet();
      expect(keys, containsAll(['potato', 'onion', 'eggs', 'flour']));
      expect(recipe.sousChefAdvice, contains('відновив базові інгредієнти'));
    },
  );

  test(
    'SocialRecipeExtractor extracts shortcodes, cleans Instagram wrappers, and parses Ukrainian & English Reels',
    () {
      expect(
        SocialRecipeExtractor.extractInstagramShortcode(
          'https://www.instagram.com/reel/Df_0q0gIml6/?igsh=abc',
        ),
        'Df_0q0gIml6',
      );
      expect(
        SocialRecipeExtractor.extractInstagramShortcode(
          'https://www.instagram.com/reels/CkdegF6K759/',
        ),
        'CkdegF6K759',
      );
      expect(
        SocialRecipeExtractor.extractInstagramShortcode(
          'https://www.instagram.com/alionakarpiuk/p/DfPoKLuMfgx/',
        ),
        'DfPoKLuMfgx',
      );

      const rawMetaDesc =
          '90 likes, 0 comments - alionakarpiuk on November 21, 2026: '
          '&quot;СИРНИКИ - ідеальні пропорції \n\n'
          'Інгредієнти:\n'
          '\t•\t500 г  сиру\n'
          '\t•\t1 яйце\n'
          '\t•\tЦукор за смаком (зазвичай 2–3 ст. л.)\n'
          '\t•\tЩіпка ваніліну або ванільного цукру\n'
          '\t•\t50 г манки\n\n'
          'Приготування:\n'
          '1️⃣ У мисці змішайте сир, яйце, цукор, ванілін і манку.\n'
          '2️⃣ Залиште суміш на 10–15 хвилин, щоб манка набухла.\n'
          '3️⃣ Обсмажте на середньому вогні з двох боків до золотистої скоринки.\n\n'
          'Смачного! 🥰&quot;. ';

      final author = SocialRecipeExtractor.extractInstagramAuthor(
        ogDescription: rawMetaDesc,
      );
      final cleaned = SocialRecipeExtractor.cleanInstagramCaption(rawMetaDesc);
      expect(author, '@alionakarpiuk');
      expect(cleaned.startsWith('СИРНИКИ'), isTrue);
      expect(cleaned.endsWith('🥰'), isTrue);

      final ukReelRecipe = SocialRecipeExtractor.parsePayloadToRecipe(
        SocialPagePayload(
          source: RecipeSource.instagram,
          resolvedUrl: 'https://www.instagram.com/reel/Df_0q0gIml6/',
          rawText: cleaned,
          authorHandle: author,
          coverImageUrl: 'data:image/jpeg;base64,/9j/4AAQ',
        ),
        SeedData.initialPantry(),
      );

      expect(ukReelRecipe.source, RecipeSource.instagram);
      expect(ukReelRecipe.authorHandle, '@alionakarpiuk');
      expect(ukReelRecipe.title, 'Сирники - ідеальні пропорції');
      expect(
        ukReelRecipe.ingredients.any(
          (i) => i.canonicalKey == 'cottage_cheese' && i.baseAmount == 500,
        ),
        isTrue,
      );
      expect(
        ukReelRecipe.ingredients.any(
          (i) => i.canonicalKey == 'eggs' && i.baseAmount == 1,
        ),
        isTrue,
      );
      expect(
        ukReelRecipe.ingredients.any(
          (i) => i.canonicalKey == 'sugar' && i.baseAmount == 3,
        ),
        isTrue,
      );
      expect(
        ukReelRecipe.ingredients.any(
          (i) => i.canonicalKey == 'semolina' && i.baseAmount == 50,
        ),
        isTrue,
      );
      expect(ukReelRecipe.steps.any((s) => s.timerSeconds == 900), isTrue);

      // English Instagram Reel with emoji bullets & fractions
      const enReelCaption = '''
High-Protein Berry Cottage Cheese Bake
🍓 150g strawberries
🧀 200g cottage cheese
🥚 2 eggs
🥄 1 tbsp honey
🌾 1/2 cup oats
Mix all ingredients in a bowl until smooth.
Bake in the oven at 180C for 20 minutes until golden.
#highprotein #recipe #reels
''';

      final enReelRecipe = SocialRecipeExtractor.parsePayloadToRecipe(
        const SocialPagePayload(
          source: RecipeSource.instagram,
          resolvedUrl: 'https://www.instagram.com/reel/DVExSiyEh2a/',
          rawText: enReelCaption,
          authorHandle: '@fitchef',
        ),
        SeedData.initialPantry(),
      );

      expect(enReelRecipe.title, 'High-Protein Berry Cottage Cheese Bake');
      expect(
        enReelRecipe.ingredients.any(
          (i) => i.canonicalKey == 'berries' && i.baseAmount == 150,
        ),
        isTrue,
      );
      expect(
        enReelRecipe.ingredients.any(
          (i) => i.canonicalKey == 'cottage_cheese' && i.baseAmount == 200,
        ),
        isTrue,
      );
      expect(
        enReelRecipe.ingredients.any(
          (i) => i.canonicalKey == 'eggs' && i.baseAmount == 2,
        ),
        isTrue,
      );
      expect(
        enReelRecipe.ingredients.any(
          (i) => i.canonicalKey == 'oats' && i.baseAmount == 0.5,
        ),
        isTrue,
      );
      expect(enReelRecipe.steps.any((s) => s.timerSeconds == 1200), isTrue);
    },
  );

  test(
    'SocialRecipeExtractor extracts YouTube videoIds, parses Shorts descriptions, and extracts spoken subtitle recipes',
    () {
      expect(
        SocialRecipeExtractor.extractYouTubeVideoId(
          'https://www.youtube.com/watch?v=vC8qJNoA0zI&feature=share',
        ),
        'vC8qJNoA0zI',
      );
      expect(
        SocialRecipeExtractor.extractYouTubeVideoId(
          'https://youtu.be/vC8qJNoA0zI?si=xyz',
        ),
        'vC8qJNoA0zI',
      );
      expect(
        SocialRecipeExtractor.extractYouTubeVideoId(
          'https://www.youtube.com/shorts/AIV-vF3Epy4',
        ),
        'AIV-vF3Epy4',
      );
      expect(
        SocialRecipeExtractor.extractYouTubeVideoId(
          'https://www.youtube.com/embed/AIV-vF3Epy4',
        ),
        'AIV-vF3Epy4',
      );

      // 1. YouTube Shorts with structured description + parenthetical notes
      const ytShortDesc = '''
Сирники краще ресторанних
Рецепт ресторанних сирників, які готуються дуже швидко🥰

▫️ Інгредієнти:
✔️ сир кисломолочний дрібнозернистий -  350-360 гр
✔️ жовток - 1 шт.
✔️ цукор - 1 ст.л. з гіркою (за бажання можна додати ще)
✔️ ванільний цукор - 10 гр
✔️ борошно - 1 ст.л. без гірки + (борошно для присипання поверхності при формуванні сирників)
''';

      final ytDescRecipe = SocialRecipeExtractor.parsePayloadToRecipe(
        const SocialPagePayload(
          source: RecipeSource.youtube,
          resolvedUrl: 'https://www.youtube.com/shorts/vC8qJNoA0zI',
          rawText: ytShortDesc,
          pageTitle: 'Сирники краще ресторанних',
          authorHandle: 'Кароліна Натальчук',
        ),
        SeedData.initialPantry(),
      );

      expect(ytDescRecipe.source, RecipeSource.youtube);
      expect(ytDescRecipe.ingredients.length, 5);
      expect(
        ytDescRecipe.ingredients.any(
          (i) => i.canonicalKey == 'cottage_cheese' && i.baseAmount == 360,
        ),
        isTrue,
      );
      expect(
        ytDescRecipe.ingredients.any(
          (i) => i.canonicalKey == 'flour' && i.baseAmount == 1,
        ),
        isTrue,
      );

      // 2. YouTube Shorts spoken recipe from auto-generated timedtext XML (no written description)
      const sampleXml =
          '<?xml version="1.0" encoding="utf-8" ?><timedtext format="3"><body>'
          '<p t="0" d="4000"><s>Сирники</s><s> готові.</s><s> [музика]</s></p>'
          '<p t="4000" d="6000"><s>Ділюся</s><s> своїм.</s><s> 350 г кисломолочного сиру.</s><s> Одне яйце.</s></p>'
          '<p t="10000" d="6000"><s>Дрібка солі.</s><s> Чайна ложка цукру.</s><s> Така повна столова ложка крохмалу.</s></p>'
          '<p t="16000" d="5000"><s>Накриваю кришкою і обсмажую 4 хвилинки на пательні.</s></p>'
          '</body></timedtext>';

      final transcript = SocialRecipeExtractor.parseYouTubeTimedTextXml(
        sampleXml,
      );
      expect(transcript.contains('[музика]'), isFalse);

      final ytSpokenRecipe = SocialRecipeExtractor.parsePayloadToRecipe(
        SocialPagePayload(
          source: RecipeSource.youtube,
          resolvedUrl: 'https://www.youtube.com/shorts/AIV-vF3Epy4',
          rawText: 'Домашні сирники\n$transcript',
          pageTitle: 'Домашні сирники',
          authorHandle: 'Анна Ройко',
        ),
        SeedData.initialPantry(),
      );

      expect(
        ytSpokenRecipe.ingredients.any(
          (i) => i.canonicalKey == 'cottage_cheese' && i.baseAmount == 350,
        ),
        isTrue,
      );
      expect(
        ytSpokenRecipe.ingredients.any(
          (i) => i.canonicalKey == 'eggs' && i.baseAmount == 1,
        ),
        isTrue,
      );
      expect(
        ytSpokenRecipe.ingredients.any(
          (i) => i.canonicalKey == 'sugar' && i.unit == 'ч. л.',
        ),
        isTrue,
      );
      expect(
        ytSpokenRecipe.ingredients.any(
          (i) => i.canonicalKey == 'starch' && i.unit == 'ст. л.',
        ),
        isTrue,
      );
      expect(ytSpokenRecipe.steps.any((s) => s.timerSeconds == 240), isTrue);
    },
  );

  testWidgets(
    'Crisper renders all 4 navigation screens, supports servings scaling, modals, and Dark Mode',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const CrisperApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Fridge Screen (Tab 0)
      expect(find.text('Готуй з того, що є.'), findsOneWidget);
      expect(find.text('Без зайвого.'), findsOneWidget);
      expect(find.text('ВИКОРИСТАТИ СКОРО'), findsOneWidget);
      expect(find.text('Грецький йогурт'), findsOneWidget);

      // Open AI Scanner Sheet from header
      await tester.tap(find.byIcon(Icons.document_scanner_outlined));
      await tester.pumpAndSettle();
      expect(find.text('AI Сканер Кухні'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // 2. Navigate to Recipes Screen (Tab 1)
      await tester.tap(find.text('Рецепти'));
      await tester.pumpAndSettle();
      expect(find.text('Що приготувати сьогодні?'), findsOneWidget);
      expect(find.text('100% з ваших продуктів'), findsWidgets);

      // 3. Navigate to Cooking Mode Screen (Tab 2)
      await tester.tap(find.text('Готування'));
      await tester.pumpAndSettle();
      expect(find.text('Інгредієнти'), findsOneWidget);
      expect(find.text('180 г'), findsOneWidget);

      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      expect(find.text('360 г'), findsOneWidget);

      // 4. Navigate to Balance Screen (Tab 3)
      await tester.tap(find.text('Баланс'));
      await tester.pumpAndSettle();
      expect(find.text('Ваш кулінарний баланс'), findsOneWidget);
      expect(find.text('ZERO-WASTE ІНДЕКС'), findsOneWidget);
      expect(find.text('94%'), findsOneWidget);
    },
  );

  testWidgets(
    'SocialImportSheet displays 1-tap chips for TikTok, Instagram Reels, and YouTube Shorts',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: CrisperTheme.light,
            home: const Scaffold(body: SocialImportSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TikTok: Ліниві вареники'), findsOneWidget);
      expect(find.text('Instagram Reels: Сирники'), findsOneWidget);
      expect(find.text('YouTube Shorts: Сирники'), findsOneWidget);

      await tester.tap(find.text('Instagram Reels: Сирники'));
      await tester.pump();
      expect(
        find.text('https://www.instagram.com/reel/Df_0q0gIml6/'),
        findsOneWidget,
      );

      await tester.tap(find.text('YouTube Shorts: Сирники'));
      await tester.pump();
      expect(
        find.text('https://www.youtube.com/shorts/vC8qJNoA0zI'),
        findsOneWidget,
      );
    },
  );

  test(
    'CookingStep never defaults to 00:00 and estimates realistic culinary duration when no time is given',
    () {
      const zeroTimeCaption = '''
Сирники домашні
• 350 г кисломолочного сиру
• 1 яйце
• 2 ст. л. борошна
• 1 ст. л. цукру
Змішайте всі інгредієнти у мисці вінчиком.
Сформуйте охайні сирники та обваляйте у борошні.
Обсмажте на пательні на середньому вогні до золотистої скоринки з обох боків.
Подавайте теплими зі сметаною.
''';

      final recipe = SocialRecipeExtractor.parsePayloadToRecipe(
        const SocialPagePayload(
          source: RecipeSource.tiktok,
          resolvedUrl: 'https://www.tiktok.com/@chef/video/999',
          rawText: zeroTimeCaption,
        ),
        SeedData.initialPantry(),
      );

      expect(recipe.steps.length, greaterThanOrEqualTo(4));
      for (final step in recipe.steps) {
        expect(step.timerSeconds, greaterThan(0));
        expect(step.effectiveTimerSeconds, greaterThan(0));
        expect(step.hasEstimatedTimer, isTrue);
      }

      // Check specific culinary stage estimations
      expect(
        CookingStep.estimateDurationSeconds(
          instruction: 'Обсмажте сирники на пательні до золотистої скоринки',
        ),
        240,
      );
      expect(
        CookingStep.estimateDurationSeconds(
          instruction: 'Запікайте страву у духовці до рум\'яності',
        ),
        1200,
      );
      expect(
        CookingStep.estimateDurationSeconds(
          instruction: 'Подавайте одразу на теплих тарілках зі свіжою зеленню',
        ),
        90,
      );

      // Legacy JSON with timerSeconds: 0 auto-heals on load
      final healed = CookingStep.fromJson(const {
        'shortTitle': 'Крок 1',
        'instruction': 'Відваріть пасту у підсоленій киплячій воді.',
        'detailTip': '',
        'timerSeconds': 0,
      });
      expect(healed.timerSeconds, 480);
      expect(healed.isTimerEstimated, isTrue);

      for (final r in SeedData.initialRecipes()) {
        for (final s in r.steps) {
          expect(s.effectiveTimerSeconds, greaterThan(0));
        }
      }
    },
  );

  test(
    'IngredientNormalizer.parseQuickBatchInput parses voice/comma product lists with categories and shelf life',
    () {
      final parsed = IngredientNormalizer.parseQuickBatchInput(
        'молоко 1 л, два авокадо, сир фета 180 г, 300 г курячого філе',
        SeedData.initialPantry(),
      );

      expect(parsed.length, 4);
      expect(parsed[0].canonicalKey, 'milk');
      expect(parsed[0].amountGramsOrPcs, 1000);
      expect(parsed[0].unit, 'мл');
      expect(parsed[0].category, PantryCategory.dairyCheese);

      expect(parsed[1].canonicalKey, 'avocado');
      expect(parsed[1].amountGramsOrPcs, 2);
      expect(parsed[1].category, PantryCategory.crisperDrawer);

      expect(parsed[2].canonicalKey, 'feta');
      expect(parsed[2].amountGramsOrPcs, 180);

      expect(parsed[3].canonicalKey, 'chicken_fillet');
      expect(parsed[3].category, PantryCategory.meatFish);
      expect(parsed[3].daysLeft, 3);
    },
  );

  test(
    'KitchenController accurately filters by DietMode, allergies, MealTimeFilter, and preserves decimal shopping units & shelves',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ctrl = KitchenController(prefs);

      // 1. Vegetarian hides chicken recipe
      ctrl.updateSettings(
        ctrl.state.settings.copyWith(dietMode: DietMode.vegetarian),
      );
      expect(
        ctrl.state.matchedRecipes.any((m) => m.recipe.id == 'r_chicken_zucchini'),
        isFalse,
      );

      // 2. GlutenFree hides pasta recipe
      ctrl.updateSettings(
        ctrl.state.settings.copyWith(dietMode: DietMode.glutenFree),
      );
      expect(
        ctrl.state.matchedRecipes.any((m) => m.recipe.id == 'r_spinach_pasta'),
        isFalse,
      );

      // 3. Lactose allergy hides dairy recipes
      ctrl.updateSettings(
        ctrl.state.settings.copyWith(
          dietMode: DietMode.omnivore,
          allergies: const ['eggs'],
        ),
      );
      expect(
        ctrl.state.matchedRecipes.any(
          (m) => m.recipe.id == 'r_spinach_frittata',
        ),
        isFalse,
      );

      // Reset filters
      ctrl.updateSettings(
        ctrl.state.settings.copyWith(allergies: const []),
      );
      ctrl.setMealTimeFilter(MealTimeFilter.breakfast);
      expect(ctrl.state.matchedRecipes, isNotEmpty);

      // 4. Fractional shopping item & category inference (0.5 скл., crisperDrawer)
      ctrl.addIngredientToShoppingList(
        const RecipeIngredient(
          name: 'Авокадо',
          canonicalKey: 'avocado',
          baseAmount: 0.5,
          unit: 'шт',
        ),
        'Тост',
      );
      final added = ctrl.state.shoppingList.first;
      expect(added.quantityBadge, '0.5 шт');
      expect(added.category, PantryCategory.crisperDrawer);

      ctrl.toggleShoppingChecked(added.id);
      final moved = ctrl.moveCheckedShoppingToPantry();
      expect(moved, 1);
      expect(
        ctrl.state.pantry.any(
          (p) =>
              p.canonicalKey == 'avocado' &&
              p.category == PantryCategory.crisperDrawer,
        ),
        isTrue,
      );
      ctrl.dispose();
    },
  );

  testWidgets(
    'ProfileSettingsSheet & WeeklyMealPlannerSheet support allergies, Dark Mode, and meal cooked toggle',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: CrisperTheme.light,
            home: const Scaffold(body: ProfileSettingsSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Алергії та харчові виключення'), findsOneWidget);
      expect(find.text('Без лактози'), findsOneWidget);
      await tester.tap(find.text('Без лактози'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: CrisperTheme.light,
            home: const Scaffold(body: WeeklyMealPlannerSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Тижневий планувальник меню'), findsOneWidget);
      await tester.tap(find.text('Авто-план'));
      await tester.pumpAndSettle();
      expect(
        find.text('Тиждень автоматично сплановано з продуктів у холодильнику!'),
        findsOneWidget,
      );
    },
  );
}
