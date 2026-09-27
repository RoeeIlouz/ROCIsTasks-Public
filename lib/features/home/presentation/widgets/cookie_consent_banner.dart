import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:rocis_tasks/core/services/web/cookie_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

/// Floating Glassmorphic Cookie & Storage Consent Banner for Web.
/// Provides GDPR-compliant 'Accept All' and 'Essential Only' choices
/// and persists the decision in both SharedPreferences and secure cookies.
///
/// Self-managing: checks consent status on mount and hides if already consented.
class CookieConsentBanner extends StatefulWidget {
  final VoidCallback? onConsentGiven;

  const CookieConsentBanner({super.key, this.onConsentGiven});

  static const String keyConsentChoice = 'cookie_consent_choice';

  /// Notifier that external code (e.g. Settings) can toggle to re-show the banner.
  static final ValueNotifier<bool> showBannerNotifier = ValueNotifier(false);

  /// Utility to check whether the user has already made a consent choice.
  static Future<bool> hasUserConsented() async {
    if (!kIsWeb) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final choice = prefs.getString(keyConsentChoice);
      if (choice != null && choice.isNotEmpty) return true;
      final cookieChoice = CookieService.instance.getCookie(keyConsentChoice);
      return cookieChoice != null && cookieChoice.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Reset cookie consent so the banner re-appears on next build.
  static Future<void> resetConsent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyConsentChoice);
      if (kIsWeb) {
        CookieService.instance.deleteCookie(keyConsentChoice);
      }
    } catch (_) {}
    showBannerNotifier.value = true;
  }

  @override
  State<CookieConsentBanner> createState() => _CookieConsentBannerState();
}

class _CookieConsentBannerState extends State<CookieConsentBanner> {
  bool _isVisible = false; // Start hidden; show after consent check

  @override
  void initState() {
    super.initState();
    _checkConsent();
    CookieConsentBanner.showBannerNotifier.addListener(_onShowBannerChanged);
  }

  @override
  void dispose() {
    CookieConsentBanner.showBannerNotifier.removeListener(_onShowBannerChanged);
    super.dispose();
  }

  void _onShowBannerChanged() {
    if (CookieConsentBanner.showBannerNotifier.value && mounted) {
      setState(() => _isVisible = true);
      CookieConsentBanner.showBannerNotifier.value = false;
    }
  }

  Future<void> _checkConsent() async {
    final consented = await CookieConsentBanner.hasUserConsented();
    if (!consented && mounted) {
      setState(() => _isVisible = true);
    }
  }

  Future<void> _handleConsent(String choice) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CookieConsentBanner.keyConsentChoice, choice);

      if (kIsWeb) {
        CookieService.instance.setCookie(
          CookieConsentBanner.keyConsentChoice,
          choice,
          maxAge: const Duration(days: 365),
        );
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isVisible = false;
      });
      widget.onConsentGiven?.call();
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_isVisible) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E2230).withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cookie_outlined,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.cookieBannerTitle,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context)!.cookieBannerBody,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.75,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _openUrl(AppConfig.privacyPolicyUrl),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.privacyPolicy,
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _openUrl(AppConfig.termsOfServiceUrl),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.termsOfService,
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: () => _handleConsent('essential'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.essentialOnly,
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: () => _handleConsent('all'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.acceptAll,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
