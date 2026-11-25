import 'package:flutter/material.dart';

enum PantryCategory {
  crisperDrawer('Шухляда свіжості', Icons.eco_outlined),
  dairyCheese('Молочне & Сири', Icons.egg_outlined),
  meatFish('М\'ясо та риба', Icons.restaurant_outlined),
  pantrySpices('Комора & Спеції', Icons.kitchen_outlined),
  freezer('Морозилка', Icons.ac_unit_outlined);

  const PantryCategory(this.label, this.icon);
  final String label;
  final IconData icon;

  static PantryCategory fromName(String value) {
    return PantryCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PantryCategory.crisperDrawer,
    );
  }
}

@immutable
class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    required this.canonicalKey,
    required this.amountGramsOrPcs,
    required this.unit,
    required this.detailNote,
    required this.category,
    required this.daysLeft,
    required this.addedLabel,
    this.imageAsset,
    this.confidence,
  });

  final String id;
  final String name;
  final String canonicalKey;
  final double amountGramsOrPcs;
  final String unit;
  final String detailNote;
  final PantryCategory category;
  final int daysLeft;
  final String addedLabel;
  final String? imageAsset;
  final double? confidence;

  bool get isExpiringSoon => daysLeft <= 2;

  String get formattedQuantity {
    final val = amountGramsOrPcs == amountGramsOrPcs.roundToDouble()
        ? amountGramsOrPcs.toInt().toString()
        : amountGramsOrPcs.toStringAsFixed(1);
    if (detailNote.isEmpty) return '$val $unit';
    return '$val $unit • $detailNote';
  }

  String get daysLeftBadge {
    if (daysLeft <= 0) return 'Сьогодні';
    if (daysLeft == 1) return '1 день';
    if (daysLeft >= 2 && daysLeft <= 4) return '$daysLeft дні';
    return '$daysLeft днів';
  }

  PantryItem copyWith({
    String? id,
    String? name,
    String? canonicalKey,
    double? amountGramsOrPcs,
    String? unit,
    String? detailNote,
    PantryCategory? category,
    int? daysLeft,
    String? addedLabel,
    String? imageAsset,
    double? confidence,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      canonicalKey: canonicalKey ?? this.canonicalKey,
      amountGramsOrPcs: amountGramsOrPcs ?? this.amountGramsOrPcs,
      unit: unit ?? this.unit,
      detailNote: detailNote ?? this.detailNote,
      category: category ?? this.category,
      daysLeft: daysLeft ?? this.daysLeft,
      addedLabel: addedLabel ?? this.addedLabel,
      imageAsset: imageAsset ?? this.imageAsset,
      confidence: confidence ?? this.confidence,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'canonicalKey': canonicalKey,
        'amountGramsOrPcs': amountGramsOrPcs,
        'unit': unit,
        'detailNote': detailNote,
        'category': category.name,
        'daysLeft': daysLeft,
        'addedLabel': addedLabel,
        'imageAsset': imageAsset,
        'confidence': confidence,
      };

  factory PantryItem.fromJson(Map<String, dynamic> json) => PantryItem(
        id: json['id'] as String,
        name: json['name'] as String,
        canonicalKey: json['canonicalKey'] as String,
        amountGramsOrPcs: (json['amountGramsOrPcs'] as num).toDouble(),
        unit: json['unit'] as String,
        detailNote: (json['detailNote'] as String?) ?? '',
        category: PantryCategory.fromName(
          (json['category'] as String?) ?? 'crisperDrawer',
        ),
        daysLeft: (json['daysLeft'] as num).toInt(),
        addedLabel: (json['addedLabel'] as String?) ?? 'Сьогодні',
        imageAsset: json['imageAsset'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
      );
}

@immutable
class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    required this.canonicalKey,
    required this.baseAmount,
    required this.unit,
    this.prepNote = '',
    this.substituteKey,
    this.substituteTip,
  });

  final String name;
  final String canonicalKey;
  final double baseAmount;
  final String unit;
  final String prepNote;
  final String? substituteKey;
  final String? substituteTip;

  String scaledLabel(int currentServings, int defaultServings) {
    final factor =
        defaultServings > 0 ? currentServings / defaultServings : 1.0;
    final scaled = baseAmount * factor;
    final formatted = scaled == scaled.roundToDouble()
        ? scaled.toInt().toString()
        : scaled.toStringAsFixed(1);
    return '$formatted $unit';
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'canonicalKey': canonicalKey,
        'baseAmount': baseAmount,
        'unit': unit,
        'prepNote': prepNote,
        'substituteKey': substituteKey,
        'substituteTip': substituteTip,
      };

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        name: json['name'] as String,
        canonicalKey: json['canonicalKey'] as String,
        baseAmount: (json['baseAmount'] as num).toDouble(),
        unit: json['unit'] as String,
        prepNote: (json['prepNote'] as String?) ?? '',
        substituteKey: json['substituteKey'] as String?,
        substituteTip: json['substituteTip'] as String?,
      );
}

@immutable
class CookingStep {
  const CookingStep({
    required this.shortTitle,
    required this.instruction,
    required this.detailTip,
    this.heatLabel,
    this.timerSeconds = 180,
    this.isTimerEstimated = false,
    this.stepImageAsset,
  });

  final String shortTitle;
  final String instruction;
  final String detailTip;
  final String? heatLabel;
  final int timerSeconds;
  final bool isTimerEstimated;
  final String? stepImageAsset;

  int get effectiveTimerSeconds => timerSeconds > 0
      ? timerSeconds
      : estimateDurationSeconds(
          instruction: instruction,
          shortTitle: shortTitle,
          heatLabel: heatLabel,
        );

  bool get hasEstimatedTimer => isTimerEstimated || timerSeconds <= 0;

  /// Resolves `(seconds, isEstimated)` from step text:
  /// 1) Extracts explicit time if mentioned (digits or spoken words in UK/RU/EN).
  /// 2) Otherwise estimates realistic culinary step duration based on cooking technique.
  static (int, bool) resolveDuration({
    required String instruction,
    String shortTitle = '',
    String? heatLabel,
  }) {
    final explicit = extractExplicitSeconds('$instruction $shortTitle');
    if (explicit != null && explicit > 0) {
      return (explicit, false);
    }
    return (
      estimateDurationSeconds(
        instruction: instruction,
        shortTitle: shortTitle,
        heatLabel: heatLabel,
      ),
      true,
    );
  }

  /// Extracts explicit timer duration in seconds if stated in text, or `null` if none.
  static int? extractExplicitSeconds(String rawText) {
    var s = rawText
        .toLowerCase()
        .replaceAllMapped(
          RegExp(
            r'(?<![а-яіїєґa-z])(пів\s*години|півгодини|полчаса|half\s+an?\s+hour)(?![а-яіїєґa-z])',
          ),
          (_) => '30 хв',
        )
        .replaceAllMapped(
          RegExp(
            r'(?<![а-яіїєґa-z])(півтор[аи]\s+хвилин[а-яіїєґ]*|полтор[аы]\s+минут[а-яіїєґ]*)(?![а-яіїєґa-z])',
          ),
          (_) => '90 сек',
        )
        .replaceAllMapped(
          RegExp(
            r'(?<![а-яіїєґa-z])(пів\s*хвилин[а-яіїєґ]*|полминут[а-яіїєґ]*|half\s+a\s+minute)(?![а-яіїєґa-z])',
          ),
          (_) => '30 сек',
        )
        .replaceAllMapped(
          RegExp(
            r'(?<![а-яіїєґa-z])(годин[ау]|час|an?\s+hour)(?![а-яіїєґa-z])',
          ),
          (_) => '60 хв',
        );

    const wordNums = <String, String>{
      'одну': '1',
      'одна': '1',
      'один': '1',
      'one': '1',
      'дві': '2',
      'два': '2',
      'две': '2',
      'пару': '2',
      'two': '2',
      'три': '3',
      'three': '3',
      'чотири': '4',
      'четыре': '4',
      'four': '4',
      "п'ять": '5',
      'пять': '5',
      'five': '5',
      'шість': '6',
      'шесть': '6',
      'six': '6',
      'сім': '7',
      'семь': '7',
      'seven': '7',
      'вісім': '8',
      'восемь': '8',
      'eight': '8',
      'десять': '10',
      'десят': '10',
      'ten': '10',
      "п'ятнадцять": '15',
      'пятнадцять': '15',
      'пятнадцать': '15',
      'fifteen': '15',
      'двадцять': '20',
      'двадцать': '20',
      'twenty': '20',
      'тридцять': '30',
      'тридцать': '30',
      'thirty': '30',
      'сорок': '40',
      'forty': '40',
    };

    wordNums.forEach((word, digit) {
      s = s.replaceAllMapped(
        RegExp(
          '(?<![а-яіїєґa-z])${RegExp.escape(word)}(?=\\s*(?:[-–]\\s*[а-яіїєґa-z0-9]+\\s*)?(?:хв|минут|сек|min|sec|год|hour))',
        ),
        (_) => digit,
      );
    });

    final m = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:[-–]\s*(\d+(?:[.,]\d+)?)(?:ри)?)?\s*(хв[а-яіїєґ]*|минут[а-яіїєґ]*|мин\.?|сек[а-яіїєґ]*|год[а-яіїєґ]*|min(?:ute)?s?|sec(?:ond)?s?|hours?|hr)(?![а-яіїєґa-z])',
      caseSensitive: false,
    ).firstMatch(s);
    if (m == null) return null;

    final rawVal = (m.group(2) ?? m.group(1)!).replaceAll(',', '.');
    final v = double.tryParse(rawVal);
    if (v == null || v <= 0) return null;
    final u = m.group(3)!.toLowerCase();
    if (u.startsWith('сек') || u.startsWith('sec')) {
      return v.round().clamp(15, 7200);
    }
    if (u.startsWith('год') || u.startsWith('hour') || u == 'hr') {
      return (v * 3600).round().clamp(60, 14400);
    }
    return (v * 60).round().clamp(30, 10800);
  }

  /// Estimates how many seconds a cooking step realistically takes when no time was stated.
  static int estimateDurationSeconds({
    required String instruction,
    String shortTitle = '',
    String? heatLabel,
  }) {
    final text = '${shortTitle.toLowerCase()} ${instruction.toLowerCase()} ${(heatLabel ?? '').toLowerCase()}';

    // 1. Preheating oven
    if (RegExp(r'(?:розігрі[а-яіїєґ]*|увімкн[а-яіїєґ]*|разогре[а-яіїєґ]*|preheat)\s+(?:духовк|печ|oven)').hasMatch(text)) {
      return 300; // 5 min
    }

    // 2. Baking / Roasting in oven
    if (RegExp(r'(?:духов[а-яіїєґ]*|запік[а-яіїєґ]*|випік[а-яіїєґ]*|запек[а-яіїєґ]*|выпек[а-яіїєґ]*|bake|roast|oven)').hasMatch(text)) {
      if (RegExp(r'(?:сирник|печив|круасан|бутерброд|тост|лаваш|cookie|toast)').hasMatch(text)) {
        return 900; // 15 min
      }
      return 1200; // 20 min
    }

    // 3. Chilling / Resting / Dough proofing / Marinating
    if (RegExp(r'(?:холодильник|морозильк|охолод[а-яіїєґ]*|настоят[а-яіїєґ]*|набух[а-яіїєґ]*|відпочит[а-яіїєґ]*|марин[а-яіїєґ]*|підійт[а-яіїєґ]*|chill|refrigerat|marinat|rest|proof)').hasMatch(text)) {
      return 600; // 10 min
    }

    // 4. Stewing / Braising / Simmering
    if (RegExp(r'(?:тушку[а-яіїєґ]*|томіт[а-яіїєґ]*|томлін[а-яіїєґ]*|тушит[а-яіїєґ]*|бульйон|рагу|борщ|simmer|braise|stew)').hasMatch(text)) {
      if (RegExp(r'(?:томат|чері|шпинат|часник|соус|вершк|йогурт)').hasMatch(text)) {
        return 240; // 4 min quick pan-simmer
      }
      return 600; // 10 min stewing
    }

    // 5. Boiling / Poaching
    if (RegExp(r'(?:відвар[а-яіїєґ]*|варіт[а-яіїєґ]*|варит[а-яіїєґ]*|варю|варемо|кипляч[а-яіїєґ]*|закип[а-яіїєґ]*|сплив[а-яіїєґ]*|boil|poach)').hasMatch(text)) {
      if (RegExp(r'(?:вареник|галушк|ньок|пельмен|сплив|яйц\w*\s+пашот|dumpling|gnocchi)').hasMatch(text)) {
        return 180; // 3 min
      }
      if (RegExp(r'(?:паст|макарон|спагет|пенне|рис|гречк|картопл|булгур|pasta|rice|potato)').hasMatch(text)) {
        return 480; // 8 min
      }
      return 300; // 5 min
    }

    // 6. Frying / Searing / Sautéing on skillet
    if (RegExp(r'(?:смаж[а-яіїєґ]*|обсмаж[а-яіїєґ]*|підсмаж[а-яіїєґ]*|підрум[а-яіїєґ\x27]*|золотист[а-яіїєґ]*|карамеліз[а-яіїєґ]*|пательн[а-яіїєґ]*|сковород[а-яіїєґ]*|припуск[а-яіїєґ]*|жар[а-яіїєґ]*|обжар[а-яіїєґ]*|fry|frying|saut[eé]|skillet|pan|sear|golden)').hasMatch(text)) {
      if (RegExp(r'(?:шпинат|зелен|часник|базилік|спеці|spinach|garlic|herbs)').hasMatch(text) &&
          !RegExp(r'(?:курк|філе|м\x27яс|сирник|дерун|котлет|картопл)').hasMatch(text)) {
        return 120; // 2 min quick aromats/greens
      }
      if (RegExp(r'(?:курк|філе|м\x27яс|ялович|свинин|риб|лосос|котлет|дерун|картопл|chicken|beef|pork|salmon)').hasMatch(text)) {
        return 360; // 6 min
      }
      return 240; // 4 min (syrnyky, pancakes, eggs, veggies, golden crust on both sides)
    }

    // 7. Serving / Plating / Garnishing (check before generic mixing so "зніміть з вогню та перемішайте перед подачею" gets 1.5m)
    if (RegExp(r'(?:подач[а-яіїєґ]*|подавай[а-яіїєґ]*|подават[а-яіїєґ]*|подаєм[а-яіїєґ]*|сервіру[а-яіїєґ]*|викладіт[а-яіїєґ]*\s+на\s+тарілк|прикрас[а-яіїєґ]*|зніміть\s+з\s+вогню|без\s+вогню|serve|plate|garnish)').hasMatch(text)) {
      return 90; // 1.5 min
    }

    // 8. Shaping / Rolling / Breading / Slicing dough
    if (RegExp(r'(?:сформуй[а-яіїєґ]*|формуєм[а-яіїєґ]*|розкача[а-яіїєґ]*|ковбаск[а-яіїєґ]*|кульк[а-яіїєґ]*|обваля[а-яіїєґ]*|паніру[а-яіїєґ]*|shape|roll|coat)').hasMatch(text)) {
      return 180; // 3 min
    }

    // 9. Whisking / Blending / Quick mixing
    if (RegExp(r'(?:збий[а-яіїєґ]*|збивай[а-яіїєґ]*|блендер[а-яіїєґ]*|віничк[а-яіїєґ]*|вінчик[а-яіїєґ]*|переміша[а-яіїєґ]*|зміша[а-яіїєґ]*|whisk|blend|mix|combine)').hasMatch(text) &&
        !RegExp(r'(?:наріж|подрібн|почист|натріт)').hasMatch(text)) {
      return 120; // 2 min
    }

    // 10. Chopping / Grating / Peeling / Full mise-en-place prep
    if (RegExp(r'(?:підготов[а-яіїєґ]*|наріж[а-яіїєґ]*|подрібн[а-яіїєґ]*|натріт[а-яіїєґ]*|натерт[а-яіїєґ]*|почист[а-яіїєґ]*|промий[а-яіїєґ]*|заміс[а-яіїєґ]*|замішув[а-яіїєґ]*|prep|chop|slice|dice|grate|peel|knead)').hasMatch(text)) {
      return 180; // 3 min
    }

    return 180; // Sensible 3-minute default for any general cooking step
  }

  /// Short Ukrainian culinary stage title based on the instruction.
  static String inferActionTitle(String instruction, {required int stepNumber}) {
    final l = instruction.toLowerCase();
    if (RegExp(r'(?:запік|випік|духовк|bake|roast|oven)').hasMatch(l)) {
      return 'Запікання';
    }
    if (RegExp(r'(?:тушку|томіт|томлін|simmer|stew|braise)').hasMatch(l)) {
      return 'Тушкування';
    }
    if (RegExp(r'(?:відвар|варіт|варит|варю|закип|кипляч|boil)').hasMatch(l)) {
      return 'Варіння';
    }
    if (RegExp(r'(?:смаж|обсмаж|підсмаж|підрум|золотист|пательн|сковород|fry|skillet|pan)').hasMatch(l)) {
      return 'Обсмажування';
    }
    if (RegExp(r'(?:сформуй|формуєм|розкача|ковбаск|кульк|обваля|shape|roll)').hasMatch(l)) {
      return 'Формування';
    }
    if (RegExp(r'(?:холодильник|охолод|настоят|набух|відпочит|марин|chill|rest|marinate)').hasMatch(l)) {
      return 'Настоювання';
    }
    if (RegExp(r'(?:подач|подавай|подават|подаєм|прикрас|сервіру|тарілк|serve|plate|garnish)').hasMatch(l)) {
      return 'Подача страви';
    }
    if (RegExp(r'(?:наріж|подрібн|натріт|почист|зміша|заміс|збий|поєдна|підготов|mix|whisk|chop|prep)').hasMatch(l)) {
      return 'Підготовка та змішування';
    }
    return 'Готування';
  }

  static String formatApproxMinutes(int seconds) {
    if (seconds < 60) return '$seconds сек';
    final mins = (seconds / 60).round().clamp(1, 240);
    return '$mins хв';
  }

  Map<String, dynamic> toJson() => {
        'shortTitle': shortTitle,
        'instruction': instruction,
        'detailTip': detailTip,
        'heatLabel': heatLabel,
        'timerSeconds': effectiveTimerSeconds,
        'isTimerEstimated': hasEstimatedTimer,
        'stepImageAsset': stepImageAsset,
      };

  factory CookingStep.fromJson(Map<String, dynamic> json) {
    final shortTitle = json['shortTitle'] as String;
    final instruction = json['instruction'] as String;
    final heatLabel = json['heatLabel'] as String?;
    final rawTimer = (json['timerSeconds'] as num?)?.toInt() ?? 0;
    final rawEst = json['isTimerEstimated'] as bool?;

    if (rawTimer > 0) {
      return CookingStep(
        shortTitle: shortTitle,
        instruction: instruction,
        detailTip: (json['detailTip'] as String?) ?? '',
        heatLabel: heatLabel,
        timerSeconds: rawTimer,
        isTimerEstimated: rawEst ?? false,
        stepImageAsset: json['stepImageAsset'] as String?,
      );
    }

    final resolved = resolveDuration(
      instruction: instruction,
      shortTitle: shortTitle,
      heatLabel: heatLabel,
    );
    return CookingStep(
      shortTitle: shortTitle,
      instruction: instruction,
      detailTip: (json['detailTip'] as String?) ?? '',
      heatLabel: heatLabel,
      timerSeconds: resolved.$1,
      isTimerEstimated: resolved.$2,
      stepImageAsset: json['stepImageAsset'] as String?,
    );
  }
}

enum RecipeSource {
  curated('Редакція Crisper'),
  aiChef('AI-сушеф'),
  tiktok('TikTok'),
  instagram('Instagram Reels'),
  youtube('YouTube'),
  web('Кулінарний блог');

  const RecipeSource(this.label);
  final String label;

  static RecipeSource fromName(String value) => RecipeSource.values.firstWhere(
        (e) => e.name == value,
        orElse: () => RecipeSource.curated,
      );
}

@immutable
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.cookMinutes,
    required this.difficulty,
    required this.defaultServings,
    required this.caloriesPerServing,
    required this.rescuedGrams,
    required this.ingredients,
    required this.steps,
    this.spiceShelfNote =
        'Оливкова олія холодного віджиму (2 ст. л.), морська сіль та свіжомелений перець за смаком.',
    this.sousChefAdvice = '',
    this.imageAsset,
    this.imageUrl,
    this.authorHandle,
    this.source = RecipeSource.curated,
    this.sourceUrl,
    this.isBookmarked = false,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final String description;
  final int cookMinutes;
  final String difficulty;
  final int defaultServings;
  final int caloriesPerServing;
  final int rescuedGrams;
  final List<RecipeIngredient> ingredients;
  final List<CookingStep> steps;
  final String spiceShelfNote;
  final String sousChefAdvice;
  final String? imageAsset;
  final String? imageUrl;
  final String? authorHandle;
  final RecipeSource source;
  final String? sourceUrl;
  final bool isBookmarked;
  final List<String> tags;

  Recipe copyWith({
    bool? isBookmarked,
    String? title,
    String? description,
  }) {
    return Recipe(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      cookMinutes: cookMinutes,
      difficulty: difficulty,
      defaultServings: defaultServings,
      caloriesPerServing: caloriesPerServing,
      rescuedGrams: rescuedGrams,
      ingredients: ingredients,
      steps: steps,
      spiceShelfNote: spiceShelfNote,
      sousChefAdvice: sousChefAdvice,
      imageAsset: imageAsset,
      imageUrl: imageUrl,
      authorHandle: authorHandle,
      source: source,
      sourceUrl: sourceUrl,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      tags: tags,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'cookMinutes': cookMinutes,
        'difficulty': difficulty,
        'defaultServings': defaultServings,
        'caloriesPerServing': caloriesPerServing,
        'rescuedGrams': rescuedGrams,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps.map((e) => e.toJson()).toList(),
        'spiceShelfNote': spiceShelfNote,
        'sousChefAdvice': sousChefAdvice,
        'imageAsset': imageAsset,
        'imageUrl': imageUrl,
        'authorHandle': authorHandle,
        'source': source.name,
        'sourceUrl': sourceUrl,
        'isBookmarked': isBookmarked,
        'tags': tags,
      };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        cookMinutes: (json['cookMinutes'] as num).toInt(),
        difficulty: (json['difficulty'] as String?) ?? 'Легко',
        defaultServings: (json['defaultServings'] as num?)?.toInt() ?? 2,
        caloriesPerServing: (json['caloriesPerServing'] as num?)?.toInt() ?? 420,
        rescuedGrams: (json['rescuedGrams'] as num?)?.toInt() ?? 150,
        ingredients: ((json['ingredients'] as List<dynamic>?) ?? [])
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        steps: ((json['steps'] as List<dynamic>?) ?? [])
            .map((e) => CookingStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        spiceShelfNote: (json['spiceShelfNote'] as String?) ?? '',
        sousChefAdvice: (json['sousChefAdvice'] as String?) ?? '',
        imageAsset: json['imageAsset'] as String?,
        imageUrl: json['imageUrl'] as String?,
        authorHandle: json['authorHandle'] as String?,
        source: RecipeSource.fromName((json['source'] as String?) ?? 'curated'),
        sourceUrl: json['sourceUrl'] as String?,
        isBookmarked: (json['isBookmarked'] as bool?) ?? false,
        tags: ((json['tags'] as List<dynamic>?) ?? []).cast<String>(),
      );
}

@immutable
class RecipeMatch {
  const RecipeMatch({
    required this.recipe,
    required this.ownedIngredients,
    required this.missingIngredients,
    required this.rescuedItems,
    required this.matchPercent,
    this.activeAiTip,
  });

  final Recipe recipe;
  final List<RecipeIngredient> ownedIngredients;
  final List<RecipeIngredient> missingIngredients;
  final List<PantryItem> rescuedItems;
  final int matchPercent;
  final String? activeAiTip;

  bool get isFullMatch => missingIngredients.isEmpty;
}

@immutable
class RescuedItemLog {
  const RescuedItemLog({
    required this.id,
    required this.title,
    required this.dishNote,
    required this.amountBadge,
    this.isHighlightWarn = false,
    this.iconName = 'eco',
  });

  final String id;
  final String title;
  final String dishNote;
  final String amountBadge;
  final bool isHighlightWarn;
  final String iconName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dishNote': dishNote,
        'amountBadge': amountBadge,
        'isHighlightWarn': isHighlightWarn,
        'iconName': iconName,
      };

  factory RescuedItemLog.fromJson(Map<String, dynamic> json) => RescuedItemLog(
        id: json['id'] as String,
        title: json['title'] as String,
        dishNote: json['dishNote'] as String,
        amountBadge: json['amountBadge'] as String,
        isHighlightWarn: (json['isHighlightWarn'] as bool?) ?? false,
        iconName: (json['iconName'] as String?) ?? 'eco',
      );
}

@immutable
class ShoppingListItem {
  const ShoppingListItem({
    required this.id,
    required this.name,
    required this.canonicalKey,
    required this.quantityBadge,
    required this.numericAmount,
    required this.unit,
    required this.reasonSubtitle,
    this.statusHighlight = '',
    this.isUrgentLowStock = false,
    this.isChecked = false,
    this.category = PantryCategory.pantrySpices,
  });

  final String id;
  final String name;
  final String canonicalKey;
  final String quantityBadge;
  final double numericAmount;
  final String unit;
  final String reasonSubtitle;
  final String statusHighlight;
  final bool isUrgentLowStock;
  final bool isChecked;
  final PantryCategory category;

  ShoppingListItem copyWith({bool? isChecked}) => ShoppingListItem(
        id: id,
        name: name,
        canonicalKey: canonicalKey,
        quantityBadge: quantityBadge,
        numericAmount: numericAmount,
        unit: unit,
        reasonSubtitle: reasonSubtitle,
        statusHighlight: statusHighlight,
        isUrgentLowStock: isUrgentLowStock,
        isChecked: isChecked ?? this.isChecked,
        category: category,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'canonicalKey': canonicalKey,
        'quantityBadge': quantityBadge,
        'numericAmount': numericAmount,
        'unit': unit,
        'reasonSubtitle': reasonSubtitle,
        'statusHighlight': statusHighlight,
        'isUrgentLowStock': isUrgentLowStock,
        'isChecked': isChecked,
        'category': category.name,
      };

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) =>
      ShoppingListItem(
        id: json['id'] as String,
        name: json['name'] as String,
        canonicalKey: json['canonicalKey'] as String,
        quantityBadge: json['quantityBadge'] as String,
        numericAmount: (json['numericAmount'] as num?)?.toDouble() ?? 1,
        unit: (json['unit'] as String?) ?? 'шт',
        reasonSubtitle: (json['reasonSubtitle'] as String?) ?? '',
        statusHighlight: (json['statusHighlight'] as String?) ?? '',
        isUrgentLowStock: (json['isUrgentLowStock'] as bool?) ?? false,
        isChecked: (json['isChecked'] as bool?) ?? false,
        category: PantryCategory.fromName(
          (json['category'] as String?) ?? 'pantrySpices',
        ),
      );
}

enum MealSlot {
  breakfast('Сніданок', '08:30'),
  lunch('Обід', '13:30'),
  dinner('Вечеря', '19:00');

  const MealSlot(this.label, this.defaultReminder);
  final String label;
  final String defaultReminder;

  static MealSlot fromName(String v) => MealSlot.values.firstWhere(
        (e) => e.name == v,
        orElse: () => MealSlot.dinner,
      );
}

@immutable
class MealPlanEntry {
  const MealPlanEntry({
    required this.id,
    required this.dayIndex,
    required this.slot,
    required this.recipeId,
    this.reminderEnabled = true,
    this.isCooked = false,
  });

  /// 0 = Пн ... 6 = Нд
  final String id;
  final int dayIndex;
  final MealSlot slot;
  final String recipeId;
  final bool reminderEnabled;
  final bool isCooked;

  MealPlanEntry copyWith({
    String? recipeId,
    bool? reminderEnabled,
    bool? isCooked,
  }) =>
      MealPlanEntry(
        id: id,
        dayIndex: dayIndex,
        slot: slot,
        recipeId: recipeId ?? this.recipeId,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        isCooked: isCooked ?? this.isCooked,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dayIndex': dayIndex,
        'slot': slot.name,
        'recipeId': recipeId,
        'reminderEnabled': reminderEnabled,
        'isCooked': isCooked,
      };

  factory MealPlanEntry.fromJson(Map<String, dynamic> json) => MealPlanEntry(
        id: json['id'] as String,
        dayIndex: (json['dayIndex'] as num).toInt(),
        slot: MealSlot.fromName((json['slot'] as String?) ?? 'dinner'),
        recipeId: json['recipeId'] as String,
        reminderEnabled: (json['reminderEnabled'] as bool?) ?? true,
        isCooked: (json['isCooked'] as bool?) ?? false,
      );
}

enum DietMode {
  omnivore('Всеїдне'),
  vegetarian('Вегетаріанське'),
  pescatarian('Пескетаріанське'),
  glutenFree('Без глютену'),
  highProtein('Високобілкове');

  const DietMode(this.label);
  final String label;

  static DietMode fromName(String v) => DietMode.values.firstWhere(
        (e) => e.name == v,
        orElse: () => DietMode.omnivore,
      );
}

@immutable
class KitchenSettings {
  const KitchenSettings({
    this.themeMode = ThemeMode.light,
    this.dietMode = DietMode.omnivore,
    this.allergies = const <String>[],
    this.householdSize = 2,
    this.geminiApiKey = '',
    this.rescuedKgTotal = 14.2,
    this.rescuedKgThisWeek = 3.4,
    this.savedUahTotal = 1850,
    this.co2SavedKg = 32.0,
    this.zeroWasteScore = 94,
  });

  final ThemeMode themeMode;
  final DietMode dietMode;
  final List<String> allergies;
  final int householdSize;
  final String geminiApiKey;
  final double rescuedKgTotal;
  final double rescuedKgThisWeek;
  final int savedUahTotal;
  final double co2SavedKg;
  final int zeroWasteScore;

  KitchenSettings copyWith({
    ThemeMode? themeMode,
    DietMode? dietMode,
    List<String>? allergies,
    int? householdSize,
    String? geminiApiKey,
    double? rescuedKgTotal,
    double? rescuedKgThisWeek,
    int? savedUahTotal,
    double? co2SavedKg,
    int? zeroWasteScore,
  }) {
    return KitchenSettings(
      themeMode: themeMode ?? this.themeMode,
      dietMode: dietMode ?? this.dietMode,
      allergies: allergies ?? this.allergies,
      householdSize: householdSize ?? this.householdSize,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      rescuedKgTotal: rescuedKgTotal ?? this.rescuedKgTotal,
      rescuedKgThisWeek: rescuedKgThisWeek ?? this.rescuedKgThisWeek,
      savedUahTotal: savedUahTotal ?? this.savedUahTotal,
      co2SavedKg: co2SavedKg ?? this.co2SavedKg,
      zeroWasteScore: zeroWasteScore ?? this.zeroWasteScore,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'dietMode': dietMode.name,
        'allergies': allergies,
        'householdSize': householdSize,
        'geminiApiKey': geminiApiKey,
        'rescuedKgTotal': rescuedKgTotal,
        'rescuedKgThisWeek': rescuedKgThisWeek,
        'savedUahTotal': savedUahTotal,
        'co2SavedKg': co2SavedKg,
        'zeroWasteScore': zeroWasteScore,
      };

  factory KitchenSettings.fromJson(Map<String, dynamic> json) {
    final tm = json['themeMode'] as String?;
    final mode = switch (tm) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    return KitchenSettings(
      themeMode: mode,
      dietMode: DietMode.fromName((json['dietMode'] as String?) ?? 'omnivore'),
      allergies: ((json['allergies'] as List<dynamic>?) ?? []).cast<String>(),
      householdSize: (json['householdSize'] as num?)?.toInt() ?? 2,
      geminiApiKey: (json['geminiApiKey'] as String?) ?? '',
      rescuedKgTotal: (json['rescuedKgTotal'] as num?)?.toDouble() ?? 14.2,
      rescuedKgThisWeek: (json['rescuedKgThisWeek'] as num?)?.toDouble() ?? 3.4,
      savedUahTotal: (json['savedUahTotal'] as num?)?.toInt() ?? 1850,
      co2SavedKg: (json['co2SavedKg'] as num?)?.toDouble() ?? 32.0,
      zeroWasteScore: (json['zeroWasteScore'] as num?)?.toInt() ?? 94,
    );
  }
}
