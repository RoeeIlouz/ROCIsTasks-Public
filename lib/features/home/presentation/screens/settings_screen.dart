import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/trash_screen.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/core/services/analytics_service.dart';
import 'package:rocis_tasks/features/premium/presentation/screens/premium_screen.dart';
import 'package:rocis_tasks/features/categories/presentation/screens/categories_screen.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rocis_tasks/core/services/backup_service.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:rocis_tasks/shared/ui/widgets/snackbars.dart';
import 'package:rocis_tasks/features/home/presentation/screens/app_guide_screen.dart';
import 'package:rocis_tasks/shared/ui/widgets/easter_egg_spinner.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:rocis_tasks/features/auth/presentation/screens/security_settings_screen.dart';
import 'package:rocis_tasks/features/auth/presentation/screens/login_screen.dart';
import 'package:rocis_tasks/core/services/timezone_service.dart';
import 'package:rocis_tasks/features/home/presentation/screens/widget_customization_screen.dart';
import 'package:rocis_tasks/shared/ui/widgets/app_color_picker_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = Provider.of<ThemeService>(context);
    final timezoneService = Provider.of<TimezoneService>(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: true);
    final calendarProvider = Provider.of<CalendarProvider>(
      context,
      listen: false,
    );
    final l10n = AppLocalizations.of(context)!;
    final user = authService.currentUser;
    final subscriptionService = Provider.of<SubscriptionService>(context);
    final analyticsService = Provider.of<AnalyticsService>(
      context,
      listen: false,
    );

    String _currentLanguageLabel() {
      final code = themeService.locale?.languageCode;
      if (code == 'hi') return '🇮🇳 ${l10n.hindi}';
      if (code == 'he') return '🇮🇱 ${l10n.hebrew}';
      if (code == 'es') return '🇪🇸 ${l10n.spanish}';
      if (code == 'ar') return '🇸🇦 ${l10n.arabic}';
      if (code == 'sv') return '🇸🇪 ${l10n.swedish}';
      if (code == 'de') return '🇩🇪 ${l10n.german}';
      if (code == 'fr') return '🇫🇷 ${l10n.french}';
      return '🇺🇸 ${l10n.english}';
    }

    String _formatMinutes(int minutes) {
      return '${minutes}m';
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _buildSectionHeader(context, l10n.account),
        _buildSectionCard(context, [
          if (user != null) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: themeService.isDarkMode
                    ? Colors.grey[800]
                    : Colors.grey[200],
                backgroundImage: user.photoURL != null
                    ? CachedNetworkImageProvider(user.photoURL!)
                    : null,
                child: user.photoURL == null
                    ? Text(
                        (user.displayName != null &&
                                user.displayName!.isNotEmpty)
                            ? user.displayName![0].toUpperCase()
                            : (user.email != null && user.email!.isNotEmpty
                                  ? user.email![0].toUpperCase()
                                  : 'U'),
                      )
                    : null,
              ),
              title: Text(
                (user.displayName != null && user.displayName!.isNotEmpty)
                    ? user.displayName!
                    : 'User',
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (user.email != null && user.email!.isNotEmpty)
                    Text(user.email!),
                  const SizedBox(height: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: user.uid));
                      HapticFeedback.lightImpact();
                      showSuccessSnackBar(context, l10n.copiedToClipboard);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'UID: ${user.uid}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.8),
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: _buildLeadingIcon(
                context,
                Icons.cloud_done_rounded,
                Colors.teal,
              ),
              title: Text(l10n.cloudSync),
              subtitle: Text(l10n.cloudSyncActive),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLeadingIcon(
                        context,
                        Icons.person_outline_rounded,
                        Colors.orangeAccent,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.guestAccount,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.guestModeSubtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.login_rounded, size: 18),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      label: Text(l10n.signInOrRegister),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ListTile(
            leading: _buildLeadingIcon(
              context,
              Icons.stars_rounded,
              Colors.amber,
            ),
            title: Text(l10n.rocisTasksPro),
            subtitle: Text(
              subscriptionService.isPremium
                  ? l10n.youAreProUser
                  : l10n.unlockPremiumFeatures,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PremiumScreen()),
              );
            },
          ),
          if (subscriptionService.isPremium)
            ListTile(
              leading: _buildLeadingIcon(
                context,
                Icons.settings_suggest_rounded,
                Colors.blue,
              ),
              title: Text(l10n.manageSubscription),
              subtitle: Text(l10n.manageSubscriptionSubtitle),
              onTap: () async {
                await analyticsService.logSubscriptionManagementClicked();
                await subscriptionService.manageSubscription();
              },
            ),
          if (user != null)
            ListTile(
              leading: _buildLeadingIcon(
                context,
                Icons.logout,
                Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.signOut,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () async {
                await authService.signOut();
                if (context.mounted) {
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              },
            ),
        ]),
        _buildSectionHeader(context, l10n.appearance),
        _buildSectionCard(context, [
          ListTile(
            leading: _buildLeadingIcon(
              context,
              Icons.brightness_medium,
              theme.colorScheme.primary,
            ),
            title: Text(l10n.theme),
            subtitle: Text(
              themeService.themeMode == ThemeMode.system
                  ? l10n.systemDefault
                  : themeService.themeMode == ThemeMode.dark
                  ? l10n.darkMode
                  : l10n.lightMode,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showModalBottomSheet(
                useSafeArea: true,
                context: context,
                builder: (context) {
                  final themeMode = themeService.themeMode;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.theme,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          selected: themeMode == ThemeMode.system,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          selectedColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: _buildLeadingIcon(
                            context,
                            Icons.brightness_auto,
                            Colors.grey,
                          ),
                          title: Text(l10n.systemDefault),
                          onTap: () {
                            themeService.setThemeMode(ThemeMode.system);
                            analyticsService.logThemeChanged(
                              themeMode: 'system',
                            );
                            Navigator.pop(context);
                          },
                          trailing: themeMode == ThemeMode.system
                              ? const Icon(Icons.check)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          selected: themeMode == ThemeMode.light,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          selectedColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: _buildLeadingIcon(
                            context,
                            Icons.light_mode,
                            Colors.amber,
                          ),
                          title: Text(l10n.lightMode),
                          onTap: () {
                            themeService.setThemeMode(ThemeMode.light);
                            analyticsService.logThemeChanged(
                              themeMode: 'light',
                            );
                            Navigator.pop(context);
                          },
                          trailing: themeMode == ThemeMode.light
                              ? const Icon(Icons.check)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          selected: themeMode == ThemeMode.dark,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          selectedColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: _buildLeadingIcon(
                            context,
                            Icons.dark_mode,
                            Colors.indigo,
                          ),
                          title: Text(l10n.darkMode),
                          onTap: () {
                            themeService.setThemeMode(ThemeMode.dark);
                            analyticsService.logThemeChanged(themeMode: 'dark');
                            Navigator.pop(context);
                          },
                          trailing: themeMode == ThemeMode.dark
                              ? const Icon(Icons.check)
                              : null,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          SwitchListTile(
            secondary: _buildLeadingIcon(context, Icons.palette, Colors.pink),
            title: Text(l10n.materialTheme),
            subtitle: Text(l10n.useSystemColors),
            value: themeService.useMaterialTheme,
            onChanged: (value) {
              themeService.toggleMaterialTheme(value);
              analyticsService.logThemeChanged(
                themeMode: value ? 'material_on' : 'material_off',
              );
            },
          ),
          if (!kIsWeb)
            SwitchListTile(
              secondary: _buildLeadingIcon(context, Icons.blur_on, Colors.teal),
              title: Row(
                children: [
                  Text(l10n.glassmorphismEffects),
                  if (!subscriptionService.isPremium) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.lock_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
              subtitle: Text(l10n.glassmorphismEffectsSubtitle),
              value:
                  themeService.useGlassmorphism &&
                  subscriptionService.isPremium,
              onChanged: (value) {
                if (value && !subscriptionService.isPremium) {
                  subscriptionService.showPaywall();
                  return;
                }
                themeService.toggleGlassmorphism(value);
                analyticsService.logThemeChanged(
                  themeMode: value ? 'glassmorphism_on' : 'glassmorphism_off',
                );
              },
            ),
          ListTile(
            leading: _buildLeadingIcon(
              context,
              Icons.color_lens_outlined,
              Colors.orange,
            ),
            title: Text(l10n.accentColor),
            subtitle: Text(l10n.accentColorSubtitle),
            trailing: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    subscriptionService.isPremium &&
                        themeService.useCustomSeedColor &&
                        themeService.customSeedColorValue != null
                    ? Color(themeService.customSeedColorValue!)
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            onTap: () async {
              if (!subscriptionService.isPremium) {
                await subscriptionService.showPaywall();
                return;
              }
              final colors = <Color>[
                const Color(0xFF6366F1),
                const Color(0xFF10B981),
                const Color(0xFFF59E0B),
                const Color(0xFFEF4444),
                const Color(0xFF8B5CF6),
                const Color(0xFF06B6D4),
                const Color(0xFF22C55E),
                const Color(0xFF3B82F6),
                const Color(0xFFEC4899),
                const Color(0xFF64748B),
              ];
              final currentColor = themeService.customSeedColorValue != null
                  ? Color(themeService.customSeedColorValue!)
                  : Theme.of(context).colorScheme.primary;

              await AppColorPickerSheet.show(
                context: context,
                initialColor: currentColor,
                title: l10n.accentColor,
                presetColors: colors,
                resetLabel: l10n.systemDefault,
                onResetToDefault: () async {
                  await themeService.setCustomSeedColorValue(null);
                },
                onColorChanged: (newColor) async {
                  await themeService.setCustomSeedColorValue(
                    newColor.toARGB32(),
                  );
                },
              );
            },
          ),
          SwitchListTile(
            secondary: _buildLeadingIcon(
              context,
              Icons.brightness_2,
              Colors.indigo,
            ),
            title: Text(l10n.amoledDarkMode),
            subtitle: Text(l10n.pureBlackBackground),
            value: themeService.useAmoledTheme,
            onChanged: themeService.isDarkMode
                ? (value) {
                    themeService.toggleAmoledTheme(value);
                    analyticsService.logThemeChanged(
                      themeMode: value ? 'amoled_on' : 'amoled_off',
                    );
                  }
                : null,
          ),
          SwitchListTile(
            secondary: _buildLeadingIcon(
              context,
              Icons.access_time,
              Colors.blueGrey,
            ),
            title: Text(l10n.timeFormat24h),
            value: themeService.use24HourFormat,
            onChanged: themeService.toggle24HourFormat,
          ),
          ListTile(
            leading: _buildLeadingIcon(context, Icons.language, Colors.blue),
            title: Text(l10n.language),
            subtitle: Text(_currentLanguageLabel()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showModalBottomSheet(
                useSafeArea: true,
                context: context,
                builder: (context) {
                  final currentLocaleCode = themeService.locale?.languageCode;
                  final isEnSelected =
                      currentLocaleCode == 'en' || themeService.locale == null;
                  final isHiSelected = currentLocaleCode == 'hi';
                  final isHeSelected = currentLocaleCode == 'he';
                  final isEsSelected = currentLocaleCode == 'es';
                  final isArSelected = currentLocaleCode == 'ar';
                  final isSvSelected = currentLocaleCode == 'sv';
                  final isDeSelected = currentLocaleCode == 'de';
                  final isFrSelected = currentLocaleCode == 'fr';

                  Widget buildLanguageTile({
                    required String flag,
                    required String name,
                    required bool isSelected,
                    required VoidCallback onTap,
                  }) {
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      selectedColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Text(flag, style: const TextStyle(fontSize: 24)),
                      title: Text(name),
                      onTap: onTap,
                      trailing: isSelected ? const Icon(Icons.check) : null,
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.language,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          buildLanguageTile(
                            flag: '🇺🇸',
                            name: l10n.english,
                            isSelected: isEnSelected,
                            onTap: () async {
                              await themeService.setLocale(const Locale('en'));
                              analyticsService.logLanguageChanged(locale: 'en');
                              taskProvider.updateAllWidgets();
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                          const SizedBox(height: 8),
                          buildLanguageTile(
                            flag: '🇮🇳',
                            name: l10n.hindi,
                            isSelected: isHiSelected,
                            onTap: () async {
                              await themeService.setLocale(const Locale('hi'));
                              analyticsService.logLanguageChanged(locale: 'hi');
                              taskProvider.updateAllWidgets();
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                          const SizedBox(height: 8),
                          buildLanguageTile(
                            flag: '🇮🇱',
                            name: l10n.hebrew,
                            isSelected: isHeSelected,
                            onTap: () async {
                              await themeService.setLocale(const Locale('he'));
                              analyticsService.logLanguageChanged(locale: 'he');
                              taskProvider.updateAllWidgets();
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                          const SizedBox(height: 8),
                          buildLanguageTile(
                            flag: '🇪🇸',
                            name: l10n.spanish,
                            isSelected: isEsSelected,
                            onTap: () async {
                              await themeService.setLocale(const Locale('es'));
                              analyticsService.logLanguageChanged(locale: 'es');
                              taskProvider.updateAllWidgets();
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                          const SizedBox(height: 8),
                          buildLanguageTile(
                            flag: '🇸🇦',
                            name: l10n.arabic,
                            isSelected: isArSelected,
                            onTap: () async {
                              await themeService.setLocale(const Locale('ar'));
                              analyticsService.logLanguageChanged(locale: 'ar');
                              taskProvider.updateAllWidgets();
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                          const SizedBox(height: 8),
                          buildLanguageTile(
                            flag: '🇸🇪',
                            name: l10n.swedish,
                            isSelected: isSvSelected,
                            onTap: () async {
                              await themeService.setLocale(const Locale('sv'));
                              analyticsService.logLanguageChanged(locale: 'sv');
                              taskProvider.updateAllWidgets();
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                          const SizedBox(height: 8),
                          buildLanguageTile(
                            flag: '🇩🇪',
                            name: l10n.german,
                            isSelected: isDeSelected,
                            onTap: () async {
                              await themeService.setLocale(const Locale('de'));
                              analyticsService.logLanguageChanged(locale: 'de');
                              taskProvider.updateAllWidgets();
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                          const SizedBox(height: 8),
                          buildLanguageTile(
                            flag: '🇫🇷',
                            name: l10n.french,
                            isSelected: isFrSelected,
                            onTap: () async {
                              await themeService.setLocale(const Locale('fr'));
                              analyticsService.logLanguageChanged(locale: 'fr');
                              taskProvider.updateAllWidgets();
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          ListTile(
            leading: _buildLeadingIcon(
              context,
              Icons.schedule_rounded,
              Colors.teal,
            ),
            title: Text(l10n.timezone),
            subtitle: Text(
              timezoneService.isAuto
                  ? '${l10n.automaticTimezone} (${timezoneService.currentTimezone} ${timezoneService.formatTimezoneOffset(timezoneService.currentTimezone)})'
                  : '${timezoneService.currentTimezone} (${timezoneService.formatTimezoneOffset(timezoneService.currentTimezone)})',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showModalBottomSheet(
                useSafeArea: true,
                isScrollControlled: true,
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) {
                  return _TimezonePickerSheet(
                    timezoneService: timezoneService,
                    calendarProvider: calendarProvider,
                    l10n: l10n,
                  );
                },
              );
            },
          ),
          if (!kIsWeb)
            ListTile(
              leading: _buildLeadingIcon(
                context,
                Icons.widgets_rounded,
                Colors.orange,
              ),
              title: Text(l10n.widgetSettings),
              subtitle: Text(l10n.widgetSettingsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WidgetCustomizationScreen(),
                  ),
                );
              },
            ),
        ]),
        _buildSectionHeader(context, l10n.productivity),
        _buildSectionCard(context, [
          SwitchListTile(
            secondary: _buildLeadingIcon(
              context,
              Icons.auto_awesome,
              Colors.amber,
            ),
            title: Text(l10n.smartAdd),
            subtitle: Text(l10n.autoRemoveNlpDatesSubtitle),
            value: themeService.autoRemoveNlpDates,
            onChanged: themeService.toggleAutoRemoveNlpDates,
          ),
          if (!kIsWeb)
            SwitchListTile(
              secondary: _buildLeadingIcon(
                context,
                Icons.vibration_rounded,
                Colors.deepOrange,
              ),
              title: const Text('Task Completion Feedback'),
              subtitle: const Text('Haptic pulse when ticking off a task'),
              value: themeService.taskCompletionFeedback,
              onChanged: themeService.toggleTaskCompletionFeedback,
            ),
          SwitchListTile(
            secondary: _buildLeadingIcon(
              context,
              Icons.help_outline_rounded,
              Colors.green,
            ),
            title: Text(l10n.showMyTasksGuideShortcut),
            subtitle: Text(l10n.showMyTasksGuideShortcutSubtitle),
            value: taskProvider.showMyTasksGuideShortcut,
            onChanged: (value) async {
              await taskProvider.setShowMyTasksGuideShortcut(value);
            },
          ),
          if (subscriptionService.isPremium) ...[
            if (!kIsWeb) ...[
              SwitchListTile(
                secondary: _buildLeadingIcon(
                  context,
                  Icons.notifications_active_outlined,
                  theme.colorScheme.primary,
                ),
                title: Text(l10n.advancedReminders),
                subtitle: Text(l10n.advancedRemindersSubtitle),
                value: taskProvider.advancedRemindersEnabled,
                onChanged: (value) async {
                  await taskProvider.setAdvancedRemindersEnabled(value);
                },
              ),
              SwitchListTile(
                secondary: _buildLeadingIcon(
                  context,
                  Icons.notification_important_outlined,
                  Colors.red,
                ),
                title: Text(l10n.nagReminders),
                subtitle: Text(l10n.nagRemindersSubtitle),
                value: taskProvider.nagRemindersEnabled,
                onChanged: (value) async {
                  await taskProvider.setNagRemindersEnabled(value);
                },
              ),
              if (taskProvider.nagRemindersEnabled) ...[
                ListTile(
                  leading: _buildLeadingIcon(
                    context,
                    Icons.schedule_outlined,
                    Colors.orange,
                  ),
                  title: Text(l10n.nagInterval),
                  subtitle: Text(
                    _formatMinutes(taskProvider.nagIntervalMinutes),
                  ),
                  onTap: () async {
                    final selected = await showDialog<int>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: Text(l10n.nagInterval),
                        children: [
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, 15),
                            child: const Text('15m'),
                          ),
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, 30),
                            child: const Text('30m'),
                          ),
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, 60),
                            child: const Text('60m'),
                          ),
                        ],
                      ),
                    );
                    if (selected == null) return;
                    await taskProvider.setNagIntervalMinutes(selected);
                  },
                ),
                ListTile(
                  leading: _buildLeadingIcon(
                    context,
                    Icons.format_list_numbered_rounded,
                    Colors.blue,
                  ),
                  title: Text(l10n.nagCount),
                  subtitle: Text('${taskProvider.nagCount}'),
                  onTap: () async {
                    final selected = await showDialog<int>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: Text(l10n.nagCount),
                        children: [
                          for (final count in [1, 2, 3, 4, 5])
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, count),
                              child: Text('$count'),
                            ),
                        ],
                      ),
                    );
                    if (selected == null) return;
                    await taskProvider.setNagCount(selected);
                  },
                ),
              ],
              SwitchListTile(
                secondary: _buildLeadingIcon(
                  context,
                  Icons.bedtime_outlined,
                  Colors.indigo,
                ),
                title: Text(l10n.quietHours),
                subtitle: Text(l10n.quietHoursSubtitle),
                value: taskProvider.quietHoursEnabled,
                onChanged: (value) async {
                  await taskProvider.setQuietHoursEnabled(value);
                },
              ),
              if (taskProvider.quietHoursEnabled) ...[
                ListTile(
                  leading: _buildLeadingIcon(
                    context,
                    Icons.nights_stay_outlined,
                    Colors.blue,
                  ),
                  title: Text(l10n.quietHoursStart),
                  subtitle: Text(
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay(
                        hour: taskProvider.quietStartMinutes ~/ 60,
                        minute: taskProvider.quietStartMinutes % 60,
                      ),
                    ),
                  ),
                  onTap: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: taskProvider.quietStartMinutes ~/ 60,
                        minute: taskProvider.quietStartMinutes % 60,
                      ),
                    );
                    if (selected == null) return;
                    await taskProvider.setQuietHoursStartMinutes(
                      selected.hour * 60 + selected.minute,
                    );
                  },
                ),
                ListTile(
                  leading: _buildLeadingIcon(
                    context,
                    Icons.wb_sunny_outlined,
                    Colors.amber,
                  ),
                  title: Text(l10n.quietHoursEnd),
                  subtitle: Text(
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay(
                        hour: taskProvider.quietEndMinutes ~/ 60,
                        minute: taskProvider.quietEndMinutes % 60,
                      ),
                    ),
                  ),
                  onTap: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: taskProvider.quietEndMinutes ~/ 60,
                        minute: taskProvider.quietEndMinutes % 60,
                      ),
                    );
                    if (selected == null) return;
                    await taskProvider.setQuietHoursEndMinutes(
                      selected.hour * 60 + selected.minute,
                    );
                  },
                ),
              ],
            ],
            ListTile(
              leading: _buildLeadingIcon(
                context,
                Icons.security_rounded,
                Colors.teal,
              ),
              title: Text(l10n.securitySettings),
              subtitle: Text(l10n.securitySettingsSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SecuritySettingsScreen(),
                  ),
                );
              },
            ),
          ],
          if (!kIsWeb)
            ListTile(
              leading: _buildLeadingIcon(
                context,
                Icons.notifications_active_outlined,
                Colors.blue,
              ),
              title: Text(l10n.showTaskCounterNotification),
              subtitle: Text(l10n.showTaskCounterNotificationSubtitle),
              onTap: () async {
                await taskProvider.updateHomeWidgetWithNotification();
                if (context.mounted) {
                  showSuccessSnackBar(context, l10n.notificationRefreshed);
                }
              },
            ),
        ]),
        _buildSectionHeader(context, l10n.dataAndSync),
        _buildSectionCard(context, [
          ListTile(
            leading: _buildLeadingIcon(context, Icons.sync, Colors.blue),
            title: Text(l10n.syncNow),
            onTap: () async {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.syncingTasks)));

              await Future.wait([
                taskProvider.performFullSync(),
                calendarProvider.loadEvents(),
              ]);

              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.syncComplete)));
              }
            },
          ),
          ListTile(
            leading: _buildLeadingIcon(
              context,
              Icons.dashboard_customize_outlined,
              Colors.orange,
            ),
            title: Text(l10n.categories),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoriesScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: _buildLeadingIcon(
              context,
              Icons.delete_outline,
              Colors.red,
            ),
            title: Text(l10n.trash),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TrashScreen()),
              );
            },
          ),
        ]),
        _buildSectionHeader(context, l10n.backupAndRestore),
        _buildSectionCard(context, [
          ListTile(
            leading: _buildLeadingIcon(context, Icons.upload_file, Colors.teal),
            title: Text(l10n.exportData),
            subtitle: Text(l10n.exportDataSubtitle),
            onTap: () async {
              try {
                final backupService = Provider.of<BackupService>(
                  context,
                  listen: false,
                );
                final json = await backupService.exportData();
                await Clipboard.setData(ClipboardData(text: json));
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.backupCopied)));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.exportFailed(e.toString()))),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: _buildLeadingIcon(context, Icons.download, Colors.blue),
            title: Text(l10n.importData),
            subtitle: Text(l10n.importDataSubtitle),
            onTap: () async {
              final controller = TextEditingController();
              final backupService = Provider.of<BackupService>(
                context,
                listen: false,
              );
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.importBackup),
                  content: TextField(
                    controller: controller,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: l10n.pasteJsonHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.import),
                    ),
                  ],
                ),
              );

              if (confirmed == true && controller.text.isNotEmpty) {
                try {
                  await backupService.importData(controller.text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.importComplete)),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.importFailed(e.toString()))),
                    );
                  }
                }
              }
            },
          ),
        ]),
        _buildSectionHeader(context, l10n.privacyAndGdpr),
        _buildSectionCard(context, [
          ListTile(
            leading: _buildLeadingIcon(
              context,
              Icons.privacy_tip_outlined,
              Colors.blue,
            ),
            title: Text(l10n.privacyPolicy),
            subtitle: Text(l10n.privacyPolicySubtitle),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () async {
              final Uri url = Uri.parse(AppConfig.privacyPolicyUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
          ListTile(
            leading: _buildLeadingIcon(
              context,
              Icons.person_remove_outlined,
              Colors.red,
            ),
            title: Text(
              l10n.deleteAccountTitle,
              style: TextStyle(color: Colors.red[700]),
            ),
            subtitle: Text(l10n.deleteAccountSubtitle),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.deleteAccountConfirmTitle),
                  content: Text(l10n.deleteAccountConfirmBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.deleteEverything),
                    ),
                  ],
                ),
              );

              if (!context.mounted) {
                return;
              }

              if (confirmed == true) {
                String? password;
                final providerIds =
                    user?.providerData.map((p) => p.providerId).toSet() ?? {};
                if (providerIds.contains('password')) {
                  final controller = TextEditingController();
                  password = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.password),
                      content: TextField(
                        controller: controller,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(labelText: l10n.password),
                        onSubmitted: (value) =>
                            Navigator.pop(context, value.trim()),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.cancel),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () =>
                              Navigator.pop(context, controller.text.trim()),
                          child: Text(l10n.deleteEverything),
                        ),
                      ],
                    ),
                  );
                  if (!context.mounted) {
                    return;
                  }
                  if (password?.isEmpty ?? true) {
                    return;
                  }
                }

                final success = await authService.deleteAccount(
                  password: password,
                );
                if (success) {
                  if (context.mounted) {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.deletionFailed)),
                    );
                  }
                }
              }
            },
          ),
        ]),
        _buildSectionHeader(context, l10n.about),
        _buildSectionCard(context, [
          ListTile(
            leading: _buildLeadingIcon(
              context,
              Icons.help_outline_rounded,
              Colors.green,
            ),
            title: Text(l10n.appGuide),
            subtitle: Text(l10n.appGuideSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AppGuideScreen()),
              );
            },
          ),
          ListTile(
            leading: _buildLeadingIcon(
              context,
              Icons.info_outline,
              Colors.blueGrey,
            ),
            title: Text(l10n.aboutApp),
            subtitle: Text(l10n.aboutAppSubtitle),
            onTap: () {
              int tapCount = 0;
              bool isDebugUnlocked = false;

              showDialog(
                context: context,
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return AlertDialog(
                        title: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: EasterEggSpinner(
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 40,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: Text(AppConfig.appName)),
                          ],
                        ),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  tapCount++;
                                  if (tapCount == 5) {
                                    setState(() {
                                      isDebugUnlocked = true;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.debugModeUnlocked),
                                      ),
                                    );
                                  }
                                },
                                child: Text(
                                  AppConfig.appVersion,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(l10n.aboutAppDescription),
                              const SizedBox(height: 16),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.language),
                                title: Text(l10n.visitWebsite),
                                subtitle: const Text('rocisapps.com'),
                                onTap: () async {
                                  final Uri url = Uri.parse(
                                    AppConfig.websiteUrl,
                                  );
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(
                                      url,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.code_rounded),
                                title: Text(l10n.viewGitHub),
                                subtitle: Text(l10n.viewGitHubSubtitle),
                                onTap: () async {
                                  final Uri url = Uri.parse(
                                    AppConfig.githubUrl,
                                  );
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(
                                      url,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.mail_outline),
                                title: Text(l10n.contactSupport),
                                subtitle: const Text(AppConfig.supportEmail),
                                onTap: () async {
                                  final Uri emailLaunchUri = Uri(
                                    scheme: 'mailto',
                                    path: AppConfig.supportEmail,
                                    queryParameters: {
                                      'subject':
                                          'Support Request - ROCIs Tasks',
                                    },
                                  );
                                  if (await canLaunchUrl(emailLaunchUri)) {
                                    await launchUrl(emailLaunchUri);
                                  }
                                },
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.bug_report_outlined),
                                title: Text(l10n.submitBugReport),
                                subtitle: Text(l10n.submitBugReportSubtitle),
                                onTap: () async {
                                  // Add google form link here
                                  final Uri url = Uri.parse(
                                    'https://forms.gle/MBakwkX3DpYfDqD26',
                                  );
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(
                                      url,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                              if (isDebugUnlocked)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.red[700],
                                  ),
                                  title: Text(
                                    l10n.testCrash,
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                  subtitle: Text(l10n.testCrashSubtitle),
                                  onTap: () {
                                    FirebaseCrashlytics.instance.crash();
                                  },
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              MaterialLocalizations.of(
                                context,
                              ).closeButtonLabel,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildSectionCard(BuildContext context, List<Widget> children) {
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.08);
    final List<Widget> dividedChildren = [];
    for (int i = 0; i < children.length; i++) {
      dividedChildren.add(children[i]);
      if (i < children.length - 1) {
        dividedChildren.add(
          Divider(
            height: 1,
            thickness: 1,
            color: dividerColor,
            indent: 64,
            endIndent: 16,
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: GlassContainer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(children: dividedChildren),
        ),
      ),
    );
  }
}

class _TimezonePickerSheet extends StatefulWidget {
  final TimezoneService timezoneService;
  final CalendarProvider calendarProvider;
  final AppLocalizations l10n;

  const _TimezonePickerSheet({
    required this.timezoneService,
    required this.calendarProvider,
    required this.l10n,
  });

  @override
  State<_TimezonePickerSheet> createState() => _TimezonePickerSheetState();
}

class _TimezonePickerSheetState extends State<_TimezonePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTimezones = TimezoneService.availableTimezones;
    final filtered = _searchQuery.isEmpty
        ? allTimezones
        : allTimezones
              .where(
                (tz) =>
                    tz.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    widget.timezoneService
                        .formatTimezoneOffset(tz)
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()),
              )
              .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                widget.l10n.selectTimezone,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: widget.l10n.searchTimezone,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length + (_searchQuery.isEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_searchQuery.isEmpty && index == 0) {
                      final isAuto = widget.timezoneService.isAuto;
                      return ListTile(
                        selected: isAuto,
                        selectedTileColor: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.3),
                        selectedColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: const Icon(Icons.auto_mode_rounded),
                        title: Text(widget.l10n.automaticTimezone),
                        subtitle: Text(
                          '${widget.timezoneService.currentTimezone} (${widget.timezoneService.formatTimezoneOffset(widget.timezoneService.currentTimezone)})',
                        ),
                        trailing: isAuto ? const Icon(Icons.check) : null,
                        onTap: () async {
                          await widget.timezoneService.setTimezone(null);
                          await widget.calendarProvider.loadEvents();
                          if (context.mounted) Navigator.pop(context);
                        },
                      );
                    }

                    final tzIndex = _searchQuery.isEmpty ? index - 1 : index;
                    final tzName = filtered[tzIndex];
                    final isSelected =
                        !widget.timezoneService.isAuto &&
                        widget.timezoneService.currentTimezone == tzName;
                    final offset = widget.timezoneService.formatTimezoneOffset(
                      tzName,
                    );

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                      selectedColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(tzName),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              offset,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check),
                          ],
                        ],
                      ),
                      onTap: () async {
                        await widget.timezoneService.setTimezone(tzName);
                        await widget.calendarProvider.loadEvents();
                        if (context.mounted) Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
