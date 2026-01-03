import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'package:rocis_tasks/core/theme/theme_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/trash_screen.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final user = authService.currentUser;
    return ListView(
      children: [
        _buildSectionHeader(context, l10n.account),
        if (user != null)
          ListTile(
            leading: CircleAvatar(
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : null,
              child: user.photoURL == null
                  ? Text(user.displayName?[0].toUpperCase() ?? 'U')
                  : null,
            ),
            title: Text(user.displayName ?? 'User'),
            subtitle: Text(user.email ?? ''),
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
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.palette),
          title: Text(l10n.materialTheme),
          subtitle: Text(l10n.useSystemColors),
          value: themeService.useMaterialTheme,
          onChanged: (value) => themeService.toggleMaterialTheme(value),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.brightness_2),
          title: Text(l10n.amoledDarkMode),
          subtitle: Text(l10n.pureBlackBackground),
          value: themeService.useAmoledTheme,
          onChanged: themeService.isDarkMode
              ? (value) => themeService.toggleAmoledTheme(value)
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
              context: context,
              builder: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(l10n.english),
                    onTap: () {
                      themeService.setLocale(const Locale('en'));
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
                      Navigator.pop(context);
                    },
                    trailing: themeService.locale?.languageCode == 'he'
                        ? const Icon(Icons.check)
                        : null,
                  ),
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
            await taskProvider.syncWithCloud();
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
        _buildSectionHeader(context, 'Debug & Tools'),
        ListTile(
          leading: const Icon(Icons.notifications_active),
          title: const Text('Send Test Immediate'),
          subtitle: const Text('Verify basic system notifications'),
          onTap: () async {
            await NotificationService().testImmediateNotification();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Test immediate notification sent!'),
                ),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.timer),
          title: const Text('Schedule Test (1 min)'),
          subtitle: const Text('Verify if scheduling is working correctly'),
          onTap: () async {
            await NotificationService().testScheduledNotification();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Test notification scheduled for 1 minute from now!',
                  ),
                ),
              );
            }
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
