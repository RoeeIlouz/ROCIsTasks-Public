import 'package:web/web.dart' as web;
import 'cookie_service.dart';

class PlatformCookieService implements CookieService {
  @override
  void setCookie(
    String name,
    String value, {
    Duration maxAge = const Duration(days: 365),
  }) {
    try {
      final seconds = maxAge.inSeconds;
      final encodedVal = Uri.encodeComponent(value);
      web.document.cookie =
          '$name=$encodedVal; max-age=$seconds; path=/; SameSite=Lax; Secure';
    } catch (_) {}
  }

  @override
  String? getCookie(String name) {
    try {
      final rawCookies = web.document.cookie;
      if (rawCookies.isEmpty) return null;
      final parts = rawCookies.split(';');
      for (final part in parts) {
        final trimmed = part.trim();
        final eqIdx = trimmed.indexOf('=');
        if (eqIdx != -1) {
          final k = trimmed.substring(0, eqIdx).trim();
          if (k == name) {
            final v = trimmed.substring(eqIdx + 1).trim();
            return Uri.decodeComponent(v);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  void deleteCookie(String name) {
    try {
      web.document.cookie = '$name=; max-age=0; path=/; SameSite=Lax; Secure';
    } catch (_) {}
  }

  @override
  bool get isSupported => true;
}

CookieService getCookieService() => PlatformCookieService();
