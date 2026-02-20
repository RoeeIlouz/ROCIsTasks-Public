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
          title: const Text("ROCIs Tasks Pro"),
          subtitle: Text(
            subscriptionService.isPremium
                ? "You are a Pro user!"
                : "Unlock premium features",
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
            title: const Text("Manage Subscription"),
            subtitle: const Text("Cancel or change your plan"),
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
              : null, // Disable if not dark mode
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
          subtitle: Text(
            themeService.locale?.languageCode == 'he'
                ? l10n.hebrew
                : l10n.english,
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
                    title: Text(l10n.english),
                    onTap: () {
                      themeService.setLocale(const Locale('en'));
                      analyticsService.logLanguageChanged(locale: 'en');
                      Navigator.pop(context);
                    },
                    trailing: themeService.locale?.languageCode != 'he'
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
              ).showSnackBar(const SnackBar(content: Text('Sync complete')));
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
        _buildSectionHeader(context, "Backup & Restore"),
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: const Text("Export Data (JSON)"),
          subtitle: const Text("Backup your tasks and categories"),
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
                  const SnackBar(content: Text('Backup copied to clipboard!')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text("Import Data (JSON)"),
          subtitle: const Text("Restore from a JSON backup"),
          onTap: () async {
            final controller = TextEditingController();
            final backupService = Provider.of<BackupService>(
              context,
              listen: false,
            );
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Import Backup'),
                content: TextField(
                  controller: controller,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Paste JSON backup here...',
                    border: OutlineInputBorder(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Import'),
                  ),
                ],
              ),
            );

            if (confirmed == true && controller.text.isNotEmpty) {
              try {
                await backupService.importData(controller.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Import complete!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
                }
              }
            }
          },
        ),
        const Divider(),
        _buildSectionHeader(context, "Privacy & GDPR"),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text("Privacy Policy"),
          subtitle: const Text("Read our data security terms"),
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
            "Delete My Account & Data",
            style: TextStyle(color: Colors.red[700]),
          ),
          subtitle: const Text("Permanently remove all your data"),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Account?'),
                content: const Text(
                  'This action is permanent and will remove all your tasks, categories, and settings from our servers.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete Everything'),
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
                    const SnackBar(
                      content: Text(
                        'Deletion failed. You may need to sign out and back in first for security.',
                      ),
                    ),
                  );
                }
              }
            }
          },
        ),
        const Divider(),
        _buildSectionHeader(context, "About"),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text("About ROCI's Tasks"),
          subtitle: const Text("App version, support, and info"),
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
                const Text(
                  "ROCI's Tasks is designed to help you stay organized and productive. Built with Flutter, it provides a seamless experience for managing your daily tasks, categories, and schedule.",
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language),
                  title: const Text("Visit our Website"),
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
                  title: const Text("Contact Support"),
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
