import 'cookie_service_stub.dart'
    if (dart.library.js) 'cookie_service_web.dart'
    if (dart.library.html) 'cookie_service_web.dart'
    if (dart.library.js_interop) 'cookie_service_web.dart';

abstract class CookieService {
  static final CookieService instance = getCookieService();

  void setCookie(
    String name,
    String value, {
    Duration maxAge = const Duration(days: 365),
  });
  String? getCookie(String name);
  void deleteCookie(String name);
  bool get isSupported;
}
