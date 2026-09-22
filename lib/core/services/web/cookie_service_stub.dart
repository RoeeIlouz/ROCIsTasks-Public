import 'cookie_service.dart';

class PlatformCookieService implements CookieService {
  @override
  void setCookie(
    String name,
    String value, {
    Duration maxAge = const Duration(days: 365),
  }) {}

  @override
  String? getCookie(String name) => null;

  @override
  void deleteCookie(String name) {}

  @override
  bool get isSupported => false;
}

CookieService getCookieService() => PlatformCookieService();
