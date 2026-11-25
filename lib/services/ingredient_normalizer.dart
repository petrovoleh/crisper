import '../models/kitchen_models.dart';

class IngredientNormalizer {
  static const List<(List<String>, String)> _rules = [
    (['кисломолоч', 'творог', 'домашній сир'], 'cottage_cheese'),
    (['пармезан', 'parmigiano', 'parmesan'], 'parmesan'),
    (['чеддер', 'cheddar'], 'cheddar'),
    (['моцарел', 'mozzarella'], 'mozzarella'),
    (['фета', 'бринз', 'feta'], 'feta'),
    (['вершковий сир', 'філадельф', 'cream cheese', 'маскарпоне'], 'cream_cheese'),
    (['твердий сир', 'сир твердий', 'голландськ', 'гауда'], 'hard_cheese'),
    (['плавлен'], 'processed_cheese'),
    (['сир', 'cheese', 'curd'], 'cottage_cheese'),
    (['йогурт', 'yogurt'], 'greek_yogurt'),
    (['сметан', 'sour cream'], 'sour_cream'),
    (['кефір', 'ряжанк'], 'kefir'),
    (['вершкове масл', 'масло вершк', 'масло 82', 'масла', 'масло', 'butter'], 'butter'),
    (['вершк', 'cream'], 'heavy_cream'),
    (['молок', 'milk'], 'milk'),
    (['яйц', 'яєц', 'жовт', 'білк', 'egg'], 'eggs'),
    (['ванільн', 'ванілін', 'vanilla'], 'vanilla_sugar'),
    (['цукров', 'пудр'], 'powdered_sugar'),
    (['цукор', 'цукру', 'sugar'], 'sugar'),
    (['мед', 'меду', 'honey'], 'honey'),
    (['борошн', 'мука', 'муки', 'flour'], 'flour'),
    (['крохмал', 'starch'], 'starch'),
    (['розпушувач', 'сода', 'baking powder'], 'baking_powder'),
    (['манк', 'манна', 'semolina'], 'semolina'),
    (['вівсян', 'пластівц', 'oats'], 'oats'),
    (['гречк', 'гречан', 'buckwheat'], 'buckwheat'),
    (['рис', 'рису', 'rice'], 'rice'),
    (['паст', 'макарон', 'спагет', 'пенне', 'фузіл', 'тальятел', 'pasta'], 'pasta'),
    (['хліб', 'батон', 'лаваш', 'тортиль', 'bread'], 'bread'),
    (['шпинат', 'spinach'], 'spinach'),
    (['томат', 'помідор', 'чері', 'tomato'], 'cherry_tomatoes'),
    (['огір', 'cucumber'], 'cucumber'),
    (['перець солодк', 'болгарськ', 'паприк', 'bell pepper'], 'bell_pepper'),
    (['цукін', 'кабач', 'zucchini'], 'zucchini'),
    (['баклажан', 'eggplant'], 'eggplant'),
    (['брокол', 'broccoli'], 'broccoli'),
    (['цвітн', 'капуст', 'cabbage'], 'cabbage'),
    (['картопл', 'potato'], 'potato'),
    (['моркв', 'carrot'], 'carrot'),
    (['буряк', 'beet'], 'beetroot'),
    (['цибул', 'onion'], 'onion'),
    (['часник', 'garlic'], 'garlic'),
    (['базилік', 'basil'], 'basil'),
    (['кріп', 'кропу', 'петрушк', 'зелен', 'кінз', 'руккол'], 'herbs'),
    (['гриб', 'печериц', 'шампіньйон', 'mushroom'], 'mushrooms'),
    (['авокадо', 'avocado'], 'avocado'),
    (['лимон', 'лайм', 'lemon'], 'lemons'),
    (['банан', 'banana'], 'banana'),
    (['яблук', 'apple'], 'apple'),
    (['ягод', 'полуниц', 'лохин', 'малин', 'вишн', 'чорниц'], 'berries'),
    (['куряч', 'курк', 'філе', 'chicken'], 'chicken_fillet'),
    (['індич', 'turkey'], 'turkey'),
    (['ялович', 'телят', 'фарш', 'beef'], 'beef'),
    (['свинин', 'бекон', 'шинк', 'ковбас', 'сосиск', 'pork'], 'pork'),
    (['лосос', 'сьомг', 'форел', 'риб', 'тунец', 'salmon', 'fish'], 'salmon'),
    (['креветк', 'морепродукт'], 'shrimp'),
    (['оливков', 'олія', 'олії', 'oil'], 'olive_oil'),
    (['какао', 'шоколад', 'chocolate', 'cocoa'], 'chocolate'),
    (['сіль', 'солі', 'salt'], 'salt'),
  ];

  static String canonicalize(String rawName, [List<PantryItem>? pantry]) {
    final l = rawName.trim().toLowerCase();
    if (l.isEmpty) return 'ingredient';

    for (final rule in _rules) {
      for (final keyword in rule.$1) {
        if (l.contains(keyword)) {
          return rule.$2;
        }
      }
    }

    if (pantry != null) {
      for (final p in pantry) {
        final pLower = p.name.toLowerCase();
        if (pLower.contains(l) || l.contains(pLower)) {
          return p.canonicalKey;
        }
        final words = l.split(RegExp(r'\s+')).where((w) => w.length >= 4);
        for (final w in words) {
          final stem = w.substring(0, w.length - 1);
          if (pLower.contains(stem)) {
            return p.canonicalKey;
          }
        }
      }
    }

    return l
        .replaceAll(RegExp(r'[^a-zа-яіїєґ0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// Suggests a smart kitchen substitution if an ingredient is missing but a compatible item exists in the fridge.
  static (String? subKey, String? tip) suggestSubstitution(
    String canonicalKey,
    Set<String> ownedKeys,
  ) {
    if (canonicalKey == 'heavy_cream' && ownedKeys.contains('greek_yogurt')) {
      return (
        'greek_yogurt',
        'Замість вершків використайте грецький йогурт, який вже є у вашому холодильнику!',
      );
    }
    if (canonicalKey == 'sour_cream' && ownedKeys.contains('greek_yogurt')) {
      return (
        'greek_yogurt',
        'Замість сметани ідеально підійде ваш грецький йогурт для подачі!',
      );
    }
    if (canonicalKey == 'butter' && ownedKeys.contains('olive_oil')) {
      return (
        'olive_oil',
        'Для обсмажування замість вершкового масла можна використати оливкову олію з комори.',
      );
    }
    if (canonicalKey == 'cottage_cheese' &&
        ownedKeys.contains('greek_yogurt')) {
      return (
        null,
        'Порада: при подачі додайте ложку вашого охолодженого грецького йогурту замість сметани!',
      );
    }
    return (null, null);
  }

  static const Set<String> _meatKeys = {
    'chicken_fillet',
    'turkey',
    'beef',
    'pork',
  };

  static const Set<String> _fishSeafoodKeys = {
    'salmon',
    'shrimp',
  };

  static const Set<String> _dairyKeys = {
    'cottage_cheese',
    'parmesan',
    'cheddar',
    'mozzarella',
    'feta',
    'cream_cheese',
    'hard_cheese',
    'processed_cheese',
    'greek_yogurt',
    'sour_cream',
    'kefir',
    'butter',
    'heavy_cream',
    'milk',
  };

  static const Set<String> _glutenKeys = {
    'flour',
    'semolina',
    'pasta',
    'bread',
  };

  static const Set<String> _highProteinKeys = {
    'chicken_fillet',
    'turkey',
    'beef',
    'salmon',
    'shrimp',
    'eggs',
    'cottage_cheese',
    'greek_yogurt',
    'feta',
    'parmesan',
    'cheddar',
    'mozzarella',
    'tofu',
  };

  static const Set<String> _crisperProduceKeys = {
    'spinach',
    'cherry_tomatoes',
    'cucumber',
    'bell_pepper',
    'zucchini',
    'eggplant',
    'broccoli',
    'cabbage',
    'potato',
    'carrot',
    'beetroot',
    'onion',
    'basil',
    'herbs',
    'mushrooms',
    'avocado',
    'lemons',
    'banana',
    'apple',
    'berries',
  };

  static bool isMeat(String key, [String rawName = '']) {
    if (_meatKeys.contains(key)) return true;
    final l = rawName.toLowerCase();
    return RegExp(
      r'(?:курк|куряч|індич|ялович|телят|свинин|бекон|ковбас|сосиск|шинк|фарш)',
    ).hasMatch(l);
  }

  static bool isFishOrSeafood(String key, [String rawName = '']) {
    if (_fishSeafoodKeys.contains(key)) return true;
    final l = rawName.toLowerCase();
    return RegExp(
      r'(?:лосос|сьомг|форел|риб|тунец|оселед|креветк|морепродукт|міді|кальмар)',
    ).hasMatch(l);
  }

  static bool containsGluten(String key, [String rawName = '']) {
    if (_glutenKeys.contains(key)) return true;
    final l = rawName.toLowerCase();
    return RegExp(r'(?:борошн|пшенич|манк|макарон|паст|спагет|хліб|батон|лаваш)').hasMatch(l);
  }

  static bool containsLactose(String key, [String rawName = '']) {
    if (_dairyKeys.contains(key)) return true;
    final l = rawName.toLowerCase();
    return RegExp(r'(?:молок|вершк|сметан|сир|творог|йогурт|кефір|масло вершк)').hasMatch(l);
  }

  static bool isHighProtein(String key) => _highProteinKeys.contains(key);

  static bool matchesAllergy(
    String allergyCode,
    String canonicalKey,
    String rawName,
  ) {
    final l = rawName.toLowerCase();
    return switch (allergyCode) {
      'lactose' => containsLactose(canonicalKey, rawName),
      'gluten' => containsGluten(canonicalKey, rawName),
      'eggs' => canonicalKey == 'eggs' || l.contains('яйц') || l.contains('жовт'),
      'nuts' => l.contains('горіх') ||
          l.contains('мигдал') ||
          l.contains('арахіс') ||
          l.contains('пекан') ||
          l.contains('кеш\'ю') ||
          l.contains('фундук'),
      'seafood' => isFishOrSeafood(canonicalKey, rawName),
      _ => false,
    };
  }

  /// Infers accurate fridge/pantry storage zone from canonical ingredient key.
  static PantryCategory inferCategory(String canonicalKey, [String rawName = '']) {
    final l = rawName.toLowerCase();
    if (l.contains('заморож') || l.contains('морозил')) {
      return PantryCategory.freezer;
    }
    if (_crisperProduceKeys.contains(canonicalKey)) {
      return PantryCategory.crisperDrawer;
    }
    if (_dairyKeys.contains(canonicalKey) || canonicalKey == 'eggs') {
      return PantryCategory.dairyCheese;
    }
    if (_meatKeys.contains(canonicalKey) ||
        _fishSeafoodKeys.contains(canonicalKey)) {
      return PantryCategory.meatFish;
    }
    return PantryCategory.pantrySpices;
  }

  /// Freshness Guard: realistic default shelf life in days by category & ingredient.
  static int inferDefaultShelfDays(String canonicalKey, PantryCategory category) {
    if (canonicalKey == 'spinach' ||
        canonicalKey == 'basil' ||
        canonicalKey == 'herbs' ||
        canonicalKey == 'berries' ||
        canonicalKey == 'avocado') {
      return 4;
    }
    if (canonicalKey == 'eggs') return 14;
    if (canonicalKey == 'butter' ||
        canonicalKey == 'parmesan' ||
        canonicalKey == 'hard_cheese') {
      return 20;
    }
    return switch (category) {
      PantryCategory.meatFish => 3,
      PantryCategory.crisperDrawer => 6,
      PantryCategory.dairyCheese => 7,
      PantryCategory.pantrySpices => 90,
      PantryCategory.freezer => 120,
    };
  }

  static String formatCompactAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(1);
  }

  /// Parses voice-dictated or comma/newline-separated quick list of products into PantryItems:
  /// e.g. "молоко 1 л, два авокадо, сир фета 180 г, 300 г курячого філе"
  static List<PantryItem> parseQuickBatchInput(
    String rawInput,
    List<PantryItem> existingPantry,
  ) {
    final normalized = rawInput
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(пів\s*кіло|півкіло)(?![а-яіїєґa-z])', caseSensitive: false),
          (_) => '500 г',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(один|одна|одне|одну)(?=\s+[а-яіїєґa-z])', caseSensitive: false),
          (_) => '1',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(два|дві|пару)(?=\s+[а-яіїєґa-z])', caseSensitive: false),
          (_) => '2',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(три)(?=\s+[а-яіїєґa-z])', caseSensitive: false),
          (_) => '3',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(чотири)(?=\s+[а-яіїєґa-z])', caseSensitive: false),
          (_) => '4',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(п\x27ять|пять)(?=\s+[а-яіїєґa-z])', caseSensitive: false),
          (_) => '5',
        );

    final parts = normalized
        .replaceAll(RegExp(r'^(?:додай|додати|купив|купила)\s+', caseSensitive: false), '')
        .split(RegExp(r'[,;\n]+|\s+(?:та|і|й)\s+'))
        .map((s) => s.trim())
        .where((s) => s.length >= 2)
        .toList();

    final ts = DateTime.now().millisecondsSinceEpoch;
    final out = <PantryItem>[];
    for (int i = 0; i < parts.length; i++) {
      final chunk = parts[i];
      double amount = 1;
      String unit = 'шт';
      String name = chunk;

      // Pattern A: "200 г сиру фета" or "2 авокадо"
      final lead = RegExp(
        r'^(\d+(?:[.,]\d+)?)\s*(кг|г|гр|мл|л|шт\.?|уп\.?)?\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(chunk);

      // Pattern B: "сир фета 200 г" or "молоко 1 л"
      final trail = RegExp(
        r'^(.+?)\s+(\d+(?:[.,]\d+)?)\s*(кг|г|гр|мл|л|шт\.?|уп\.?)?$',
        caseSensitive: false,
      ).firstMatch(chunk);

      if (lead != null) {
        amount = double.tryParse(lead.group(1)!.replaceAll(',', '.')) ?? 1;
        unit = _normalizeQuickUnit(lead.group(2), amount);
        if (lead.group(2)?.toLowerCase() == 'кг') {
          amount *= 1000;
          unit = 'г';
        } else if (lead.group(2)?.toLowerCase() == 'л') {
          amount *= 1000;
          unit = 'мл';
        }
        name = lead.group(3)!.trim();
      } else if (trail != null) {
        name = trail.group(1)!.trim();
        amount = double.tryParse(trail.group(2)!.replaceAll(',', '.')) ?? 1;
        unit = _normalizeQuickUnit(trail.group(3), amount);
        if (trail.group(3)?.toLowerCase() == 'кг') {
          amount *= 1000;
          unit = 'г';
        } else if (trail.group(3)?.toLowerCase() == 'л') {
          amount *= 1000;
          unit = 'мл';
        }
      } else {
        // Default sensible amount/unit when user only named the item ("молоко, шпинат, сир фета")
        final keyGuess = canonicalize(name, existingPantry);
        if (keyGuess == 'milk' || keyGuess == 'kefir') {
          amount = 900;
          unit = 'мл';
        } else if (keyGuess == 'heavy_cream' || keyGuess == 'olive_oil') {
          amount = 200;
          unit = 'мл';
        } else if (keyGuess == 'eggs') {
          amount = 6;
          unit = 'шт';
        } else if (keyGuess == 'avocado' ||
            keyGuess == 'lemons' ||
            keyGuess == 'banana' ||
            keyGuess == 'apple' ||
            keyGuess == 'cucumber' ||
            keyGuess == 'onion') {
          amount = 2;
          unit = 'шт';
        } else {
          amount = 200;
          unit = 'г';
        }
      }

      final cleanName = name.isEmpty
          ? chunk
          : '${name[0].toUpperCase()}${name.substring(1)}';
      final key = canonicalize(cleanName, existingPantry);
      final cat = inferCategory(key, cleanName);
      final days = inferDefaultShelfDays(key, cat);

      out.add(
        PantryItem(
          id: 'quick_${ts}_$i',
          name: cleanName,
          canonicalKey: key,
          amountGramsOrPcs: amount,
          unit: unit,
          detailNote: 'Швидке додавання',
          category: cat,
          daysLeft: days,
          addedLabel: 'Дод: сьогодні',
        ),
      );
    }
    return out;
  }

  static String _normalizeQuickUnit(String? raw, double amount) {
    if (raw == null || raw.trim().isEmpty) {
      return amount >= 30 ? 'г' : 'шт';
    }
    final l = raw.toLowerCase().replaceAll('.', '');
    if (l == 'гр' || l == 'г') return 'г';
    if (l == 'мл') return 'мл';
    if (l == 'уп') return 'уп';
    return 'шт';
  }
}
