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
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rocis_tasks/core/services/backup_service.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rocis_tasks/core/config/app_config.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
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
      return l10n.english;
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
        SwitchListTile(
          secondary: const Icon(Icons.dark_mode),
          title: Text(l10n.darkMode),
          value: themeService.isDarkMode,
          onChanged: (value) {
            themeService.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
            analyticsService.logThemeChanged(
              themeMode: value ? 'dark' : 'light',
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
                    trailing: themeService.locale?.languageCode == 'en' ||
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
                  const SizedBox(height: 24),
                ],
              ),
            );
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.backupCopied)),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.importComplete)),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
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

            if (confirmed == true) {
              final success = await authService.deleteAccount();
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
        const Divider(),
        _buildSectionHeader(context, l10n.about),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.aboutApp),
          subtitle: Text(l10n.aboutAppSubtitle),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: AppConfig.appName,
              applicationVersion: AppConfig.appVersion,
              applicationIcon: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/images/logo.png', width: 60),
              ),
              children: [
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
              ],
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
