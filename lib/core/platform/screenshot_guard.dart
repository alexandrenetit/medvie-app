// lib/core/platform/screenshot_guard.dart
import 'package:flutter/services.dart';

/// Bloqueio de screenshot/screen recording para telas sensíveis.
///
/// Implementação via `MethodChannel` próprio (`medvie/screenshot_guard`):
/// - Android: `FLAG_SECURE` em `enable`, `clearFlags` em `disable`.
/// - iOS: overlay opaco no `applicationDidEnterBackground` (S6.P2b).
///
/// Best-effort: falhas (canal não registrado em testes/desktop/web) são
/// engolidas — telas não devem crashar por proteção indisponível.
class ScreenshotGuard {
  static const MethodChannel _ch = MethodChannel('medvie/screenshot_guard');

  static Future<void> enable() async {
    try {
      await _ch.invokeMethod<void>('enable');
    } on PlatformException {
      // Canal indisponível — segue sem proteção.
    } on MissingPluginException {
      // Plataforma sem handler (web/desktop/testes).
    }
  }

  static Future<void> disable() async {
    try {
      await _ch.invokeMethod<void>('disable');
    } on PlatformException {
      // Canal indisponível — segue sem proteção.
    } on MissingPluginException {
      // Plataforma sem handler (web/desktop/testes).
    }
  }
}
