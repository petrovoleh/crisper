import 'package:flutter/services.dart';

class PlatformBridge {
  static const MethodChannel _channel = MethodChannel(
    'dev.olehpetrov.crisper/platform',
  );

  static void setPlatformListeners({
    required void Function(String sharedText) onSharedText,
    void Function(String action)? onQuickAction,
  }) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedText') {
        final text = call.arguments as String?;
        if (text != null && text.trim().isNotEmpty) {
          onSharedText(text.trim());
        }
      } else if (call.method == 'onQuickAction') {
        final action = call.arguments as String?;
        if (action != null && action.trim().isNotEmpty) {
          onQuickAction?.call(action.trim());
        }
      }
    });
  }

  static Future<String?> consumeInitialSharedText() async {
    try {
      final res = await _channel.invokeMethod<String>(
        'consumeInitialSharedText',
      );
      if (res != null && res.trim().isNotEmpty) {
        return res.trim();
      }
    } on MissingPluginException {
      // Ignored in widget tests or unsupported desktop hosts.
    } on PlatformException {
      // Ignored safely.
    }
    return null;
  }

  static Future<String?> consumeInitialQuickAction() async {
    try {
      final res = await _channel.invokeMethod<String>(
        'consumeInitialQuickAction',
      );
      if (res != null && res.trim().isNotEmpty) {
        return res.trim();
      }
    } on MissingPluginException {
      // Ignored in widget tests.
    } on PlatformException {
      // Ignored safely.
    }
    return null;
  }

  static Future<void> setKeepScreenOn(bool enabled) async {
    try {
      await _channel.invokeMethod<bool>('setKeepScreenOn', {
        'enabled': enabled,
      });
    } on MissingPluginException {
      // Ignored in tests.
    } on PlatformException {
      // Ignored safely.
    }
  }

  static Future<void> updateHomeWidget({
    required int expiringCount,
    required String topUrgentLabel,
    required int pantryCount,
  }) async {
    try {
      await _channel.invokeMethod<bool>('updateHomeWidget', {
        'expiringCount': expiringCount,
        'topUrgentLabel': topUrgentLabel,
        'pantryCount': pantryCount,
      });
    } on MissingPluginException {
      // Ignored in tests.
    } on PlatformException {
      // Ignored safely.
    }
  }
}
