import 'package:flutter/widgets.dart';

import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

/// App-wide localization helpers.
///
/// The UI language follows the device (system) language. When the system
/// language is not supported, English (US) is used as the fallback.
class L10n {
  L10n._();

  /// Fallback locale used when none of the system languages is supported.
  static const Locale fallbackLocale = Locale('en', 'US');

  static AppLocalizations _current = lookupAppLocalizations(fallbackLocale);

  /// Localizations for code that has no [BuildContext] (models, store,
  /// services). Kept in sync with the locale resolved by `MaterialApp`.
  static AppLocalizations get current => _current;

  /// Language code of the currently active localization (e.g. `en`, `uk`).
  static String get languageCode => _current.localeName.split('_').first;

  /// Picks the first system locale whose language is supported,
  /// otherwise falls back to English.
  static Locale resolve(
    List<Locale>? systemLocales,
    Iterable<Locale> supported,
  ) {
    final supportedCodes = {for (final l in supported) l.languageCode: l};
    for (final locale in systemLocales ?? const <Locale>[]) {
      final match = supportedCodes[locale.languageCode];
      if (match != null) {
        _current = lookupAppLocalizations(match);
        return match;
      }
    }
    _current = lookupAppLocalizations(fallbackLocale);
    return supportedCodes['en'] ?? fallbackLocale;
  }
}

extension L10nContext on BuildContext {
  /// Shorthand for `AppLocalizations.of(context)`.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
