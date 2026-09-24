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
      final isHttps = web.window.location.protocol == 'https:';
      final secureFlag = isHttps ? '; Secure' : '';
      web.document.cookie =
          '$name=$encodedVal; max-age=$seconds; path=/; SameSite=Lax$secureFlag';
    } catch (_) {}
    try {
      web.window.localStorage.setItem('cookie_$name', value);
    } catch (_) {}
  }

  @override
  String? getCookie(String name) {
    try {
      final rawCookies = web.document.cookie;
      if (rawCookies.isNotEmpty) {
        final parts = rawCookies.split(';');
        for (final part in parts) {
          final trimmed = part.trim();
          final eqIdx = trimmed.indexOf('=');
          if (eqIdx != -1) {
            final k = trimmed.substring(0, eqIdx).trim();
            if (k == name) {
              final v = trimmed.substring(eqIdx + 1).trim();
              final decoded = Uri.decodeComponent(v);
              if (decoded.isNotEmpty) return decoded;
            }
          }
        }
      }
    } catch (_) {}
    try {
      final lsVal = web.window.localStorage.getItem('cookie_$name');
      if (lsVal != null && lsVal.isNotEmpty) return lsVal;
    } catch (_) {}
    return null;
  }

  @override
  void deleteCookie(String name) {
    try {
      final isHttps = web.window.location.protocol == 'https:';
      final secureFlag = isHttps ? '; Secure' : '';
      web.document.cookie = '$name=; max-age=0; path=/; SameSite=Lax$secureFlag';
    } catch (_) {}
    try {
      web.window.localStorage.removeItem('cookie_$name');
    } catch (_) {}
  }

  @override
  bool get isSupported => true;
}

CookieService getCookieService() => PlatformCookieService();
