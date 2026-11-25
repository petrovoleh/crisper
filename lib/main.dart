import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/l10n.dart';
import 'screens/balance_screen.dart';
import 'screens/cooking_mode_screen.dart';
import 'screens/fridge_screen.dart';
import 'screens/modals/planner_and_profile_sheets.dart';
import 'screens/modals/scanner_sheet.dart';
import 'screens/modals/social_import_sheet.dart';
import 'screens/recipes_screen.dart';
import 'state/kitchen_store.dart';
import 'theme/crisper_theme.dart';
import 'widgets/crisper_chrome.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const CrisperApp(),
    ),
  );
}

class CrisperApp extends ConsumerWidget {
  const CrisperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      kitchenProvider.select((s) => s.settings.themeMode),
    );

    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      // UI language follows the system language; English (US) is the fallback.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: L10n.resolve,
      theme: CrisperTheme.light,
      darkTheme: CrisperTheme.dark,
      themeMode: themeMode,
      home: const CrisperShell(),
    );
  }
}

class CrisperShell extends ConsumerWidget {
  const CrisperShell({super.key});

  static const _subtitles = [
    'Fridge Inventory',
    'Recipes Matcher',
    'Cooking Mode Hub',
    'Zero Waste Balance',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(kitchenProvider.select((s) => s.pendingSharedUrl), (
      previous,
      next,
    ) {
      if (next != null && next.isNotEmpty) {
        ref.read(kitchenProvider.notifier).clearPendingSharedUrl();
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => SocialImportSheet(initialUrl: next),
        );
      }
    });

    ref.listen<String?>(kitchenProvider.select((s) => s.pendingQuickAction), (
      previous,
      next,
    ) {
      if (next != null && next.isNotEmpty) {
        ref.read(kitchenProvider.notifier).clearPendingQuickAction();
        if (next == 'openScanner') {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const AiScannerSheet(),
          );
        } else if (next == 'openImport') {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const SocialImportSheet(),
          );
        }
      }
    });

    final activeTab = ref.watch(kitchenProvider.select((s) => s.activeTab));
    final expiringCount = ref.watch(
      kitchenProvider.select((s) => s.expiringItems.length),
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: CrisperTopBar(
          subtitle: _subtitles[activeTab],
          onImportTap: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const SocialImportSheet(),
            );
          },
          onScanTap: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const AiScannerSheet(),
            );
          },
          onProfileTap: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const ProfileSettingsSheet(),
            );
          },
        ),
      ),
      body: IndexedStack(
        index: activeTab,
        children: const [
          FridgeScreen(),
          RecipesScreen(),
          CookingModeScreen(),
          BalanceScreen(),
        ],
      ),
      bottomNavigationBar: CrisperBottomNav(
        currentIndex: activeTab,
        expiringCount: expiringCount,
        onSelected: (index) => ref.read(kitchenProvider.notifier).setTab(index),
      ),
    );
  }
}
