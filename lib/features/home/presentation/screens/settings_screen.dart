import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/trash_screen.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/core/services/analytics_service.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
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
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:rocis_tasks/features/auth/presentation/screens/security_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
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
      if (code == 'he') return l10n.hebrew;
      if (code == 'es') return l10n.spanish;
      if (code == 'ar') return l10n.arabic;
      if (code == 'sv') return l10n.swedish;
      if (code == 'de') return l10n.german;
      if (code == 'fr') return l10n.french;
      return l10n.english;
    }

    String _formatMinutes(int minutes) {
      return '${minutes}m';
    }

    return ListView(
      children: [
        _buildSectionHeader(context, l10n.account),
        if (user != null)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: themeService.isDarkMode
                  ? Colors.grey[800]
                  : Colors.grey[200],
              backgroundImage: user.photoURL != null
                  ? CachedNetworkImageProvider(user.photoURL!)
                  : null,
              child: user.photoURL == null
                  ? Text(user.displayName?[0].toUpperCase() ?? 'U')
                  : null,
            ),
            title: Text(user.displayName ?? 'User'),
            subtitle: Text(user.email ?? ''),
          ),
        ListTile(
          leading: const Icon(Icons.stars_rounded, color: Colors.amber),
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
            leading: const Icon(Icons.settings_suggest_rounded),
            title: Text(l10n.manageSubscription),
            subtitle: Text(l10n.manageSubscriptionSubtitle),
            onTap: () async {
              await analyticsService.logSubscriptionManagementClicked();
              await subscriptionService.manageSubscription();
            },
          ),
        ListTile(
          leading: Icon(
            Icons.logout,
            color: Theme.of(context).colorScheme.error,
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
        const Divider(),
        _buildSectionHeader(context, l10n.appearance),
        ListTile(
          leading: const Icon(Icons.brightness_medium),
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
              builder: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.brightness_auto),
                    title: Text(l10n.systemDefault),
                    onTap: () {
                      themeService.setThemeMode(ThemeMode.system);
                      analyticsService.logThemeChanged(themeMode: 'system');
                      Navigator.pop(context);
                    },
                    trailing: themeService.themeMode == ThemeMode.system
                        ? const Icon(Icons.check)
                        : null,
                  ),
                  ListTile(
                    leading: const Icon(Icons.light_mode),
                    title: Text(l10n.lightMode),
                    onTap: () {
                      themeService.setThemeMode(ThemeMode.light);
                      analyticsService.logThemeChanged(themeMode: 'light');
                      Navigator.pop(context);
                    },
                    trailing: themeService.themeMode == ThemeMode.light
                        ? const Icon(Icons.check)
                        : null,
                  ),
                  ListTile(
                    leading: const Icon(Icons.dark_mode),
                    title: Text(l10n.darkMode),
                    onTap: () {
                      themeService.setThemeMode(ThemeMode.dark);
                      analyticsService.logThemeChanged(themeMode: 'dark');
                      Navigator.pop(context);
                    },
                    trailing: themeService.themeMode == ThemeMode.dark
                        ? const Icon(Icons.check)
                        : null,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.palette),
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
        ListTile(
          leading: const Icon(Icons.color_lens_outlined),
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
            final selected = await showModalBottomSheet<int>(
              useSafeArea: true,
              context: context,
              builder: (context) {
                final current = themeService.customSeedColorValue;
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.accentColor,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, -1),
                            child: Text(l10n.systemDefault),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final c in colors)
                            InkWell(
                              onTap: () => Navigator.pop(context, c.toARGB32()),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c,
                                  border: Border.all(
                                    color: current == c.toARGB32()
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurface
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
            if (selected == null) return;
            if (selected == -1) {
              await themeService.setCustomSeedColorValue(null);
            } else {
              await themeService.setCustomSeedColorValue(selected);
            }
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.brightness_2),
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
          secondary: const Icon(Icons.access_time),
          title: Text(l10n.timeFormat24h),
          value: themeService.use24HourFormat,
          onChanged: (value) => themeService.toggle24HourFormat(value),
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l10n.language),
          subtitle: Text(_currentLanguageLabel()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showModalBottomSheet(
              useSafeArea: true,
              context: context,
              builder: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(l10n.english),
                    onTap: () {
                      themeService.setLocale(const Locale('en'));
                      analyticsService.logLanguageChanged(locale: 'en');
                      Navigator.pop(context);
                    },
                    trailing:
                        themeService.locale?.languageCode == 'en' ||
                            themeService.locale == null
                        ? const Icon(Icons.check)
                        : null,
                  ),
                  ListTile(
                    title: Text(l10n.hebrew),
                    onTap: () {
                      themeService.setLocale(const Locale('he'));
                      analyticsService.logLanguageChanged(locale: 'he');
                      Navigator.pop(context);
                    },
                    trailing: themeService.locale?.languageCode == 'he'
                        ? const Icon(Icons.check)
                        : null,
                  ),
                  ListTile(
                    title: Text(l10n.spanish),
                    onTap: () {
                      themeService.setLocale(const Locale('es'));
                      analyticsService.logLanguageChanged(locale: 'es');
                      Navigator.pop(context);
                    },
                    trailing: themeService.locale?.languageCode == 'es'
                        ? const Icon(Icons.check)
                        : null,
                  ),
                  ListTile(
                    title: Text(l10n.arabic),
                    onTap: () {
                      themeService.setLocale(const Locale('ar'));
                      analyticsService.logLanguageChanged(locale: 'ar');
                      Navigator.pop(context);
                    },
                    trailing: themeService.locale?.languageCode == 'ar'
                        ? const Icon(Icons.check)
                        : null,
                  ),
                  ListTile(
                    title: Text(l10n.swedish),
                    onTap: () {
                      themeService.setLocale(const Locale('sv'));
                      analyticsService.logLanguageChanged(locale: 'sv');
                      Navigator.pop(context);
                    },
                    trailing: themeService.locale?.languageCode == 'sv'
                        ? const Icon(Icons.check)
                        : null,
                  ),
                  ListTile(
                    title: Text(l10n.german),
                    onTap: () {
                      themeService.setLocale(const Locale('de'));
                      analyticsService.logLanguageChanged(locale: 'de');
                      Navigator.pop(context);
                    },
                    trailing: themeService.locale?.languageCode == 'de'
                        ? const Icon(Icons.check)
                        : null,
                  ),
                  ListTile(
                    title: Text(l10n.french),
                    onTap: () {
                      themeService.setLocale(const Locale('fr'));
                      analyticsService.logLanguageChanged(locale: 'fr');
                      Navigator.pop(context);
                    },
                    trailing: themeService.locale?.languageCode == 'fr'
                        ? const Icon(Icons.check)
                        : null,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
        const Divider(),
        _buildSectionHeader(context, l10n.productivity),
        SwitchListTile(
          secondary: const Icon(Icons.auto_awesome),
          title: Text(l10n.smartAdd),
          subtitle: Text(l10n.autoRemoveNlpDatesSubtitle),
          value: themeService.autoRemoveNlpDates,
          onChanged: (value) => themeService.toggleAutoRemoveNlpDates(value),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.help_outline_rounded),
          title: Text(l10n.showMyTasksGuideShortcut),
          subtitle: Text(l10n.showMyTasksGuideShortcutSubtitle),
          value: taskProvider.showMyTasksGuideShortcut,
          onChanged: (value) async {
            await taskProvider.setShowMyTasksGuideShortcut(value);
          },
        ),
        if (subscriptionService.isPremium) ...[
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(l10n.advancedReminders),
            subtitle: Text(l10n.advancedRemindersSubtitle),
            value: taskProvider.advancedRemindersEnabled,
            onChanged: (value) async {
              await taskProvider.setAdvancedRemindersEnabled(value);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notification_important_outlined),
            title: Text(l10n.nagReminders),
            subtitle: Text(l10n.nagRemindersSubtitle),
            value: taskProvider.nagRemindersEnabled,
            onChanged: (value) async {
              await taskProvider.setNagRemindersEnabled(value);
            },
          ),
          if (taskProvider.nagRemindersEnabled) ...[
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: Text(l10n.nagInterval),
              subtitle: Text(_formatMinutes(taskProvider.nagIntervalMinutes)),
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
              leading: const Icon(Icons.format_list_numbered_rounded),
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
            secondary: const Icon(Icons.bedtime_outlined),
            title: Text(l10n.quietHours),
            subtitle: Text(l10n.quietHoursSubtitle),
            value: taskProvider.quietHoursEnabled,
            onChanged: (value) async {
              await taskProvider.setQuietHoursEnabled(value);
            },
          ),
          if (taskProvider.quietHoursEnabled) ...[
            ListTile(
              leading: const Icon(Icons.nights_stay_outlined),
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
              leading: const Icon(Icons.wb_sunny_outlined),
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
          ListTile(
            leading: const Icon(Icons.security_rounded),
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
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(l10n.showTaskCounterNotification),
          subtitle: Text(l10n.showTaskCounterNotificationSubtitle),
          onTap: () async {
            await taskProvider.updateHomeWidgetWithNotification();
            if (context.mounted) {
              showSuccessSnackBar(context, l10n.notificationRefreshed);
            }
          },
        ),
        const Divider(),
        _buildSectionHeader(context, l10n.dataAndSync),
        ListTile(
          leading: const Icon(Icons.sync),
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
          leading: const Icon(Icons.dashboard_customize_outlined),
          title: Text(l10n.categories),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CategoriesScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: Text(l10n.trash),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TrashScreen()),
            );
          },
        ),
        const Divider(),
        _buildSectionHeader(context, l10n.backupAndRestore),
        ListTile(
          leading: const Icon(Icons.upload_file),
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
          leading: const Icon(Icons.download),
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.importComplete)));
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
        const Divider(),
        _buildSectionHeader(context, l10n.privacyAndGdpr),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
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
          leading: Icon(Icons.person_remove_outlined, color: Colors.red[700]),
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.deletionFailed)));
                }
              }
            }
          },
        ),
        const Divider(),
        _buildSectionHeader(context, l10n.about),
        ListTile(
          leading: const Icon(Icons.help_outline_rounded),
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
          leading: const Icon(Icons.info_outline),
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
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 40,
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
                              subtitle: const Text("rocisapps.ilouz.xyz"),
                              onTap: () async {
                                final Uri url = Uri.parse(AppConfig.websiteUrl);
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
                                    'subject': 'Support Request - ROCIs Tasks',
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
                                subtitle: Text(
                                  l10n.testCrashSubtitle,
                                ),
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
                            MaterialLocalizations.of(context).closeButtonLabel,
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
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
