import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

/// Searchable, task-oriented help: each topic is a concrete "how do I" with
/// the exact syntax or steps, collapsed until opened.
class AppGuideScreen extends StatefulWidget {
  const AppGuideScreen({super.key});

  @override
  State<AppGuideScreen> createState() => _AppGuideScreenState();
}

class _AppGuideScreenState extends State<AppGuideScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_GuideTopic> _topics(AppLocalizations l10n) => [
    _GuideTopic(
      icon: Icons.bolt_rounded,
      title: l10n.guideQuickAddTitle,
      body: l10n.guideQuickAddBody,
    ),
    _GuideTopic(
      icon: Icons.swipe_rounded,
      title: l10n.guideGesturesTitle,
      body: l10n.guideGesturesDesc,
    ),
    _GuideTopic(
      icon: Icons.checklist_rtl_rounded,
      title: l10n.subtasksAndChecklists,
      body: l10n.guideSubtasksBody,
    ),
    _GuideTopic(
      icon: Icons.repeat_rounded,
      title: l10n.guideRecurringTitle,
      body: l10n.guideRecurringBody,
      isPro: true,
    ),
    if (!kIsWeb)
      _GuideTopic(
        icon: Icons.notifications_active_rounded,
        title: l10n.guideNotificationsTitle,
        body: l10n.guideRemindersBody,
      ),
    _GuideTopic(
      icon: Icons.view_kanban_rounded,
      title: l10n.guideViewsTitle,
      body: l10n.guideViewsBody,
    ),
    _GuideTopic(
      icon: Icons.search_rounded,
      title: l10n.searchSymbols,
      body: l10n.searchSymbolsDesc,
    ),
    _GuideTopic(
      icon: Icons.qr_code_2_rounded,
      title: l10n.guideSharingTitle,
      body: l10n.guideSharingBody,
    ),
    if (!kIsWeb)
      _GuideTopic(
        icon: Icons.widgets_rounded,
        title: l10n.guideWidgetsTitle,
        body: l10n.guideWidgetsDesc,
      ),
    _GuideTopic(
      icon: Icons.lock_outline_rounded,
      title: l10n.privateMode,
      body: l10n.guidePrivacyBody,
      isPro: true,
    ),
    _GuideTopic(
      icon: Icons.cloud_sync_rounded,
      title: l10n.guideCloudSyncTitle,
      body: l10n.guideCloudSyncDesc,
    ),
    _GuideTopic(
      icon: Icons.playlist_add_check_rounded,
      title: l10n.syncWithGoogleTasks,
      body: l10n.guideGoogleTasksBody,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final topics = _topics(l10n)
        .where(
          (t) =>
              q.isEmpty ||
              t.title.toLowerCase().contains(q) ||
              t.body.toLowerCase().contains(q),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appGuideTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: l10n.guideSearchHint,
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (topics.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  l10n.guideNoResults,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          for (final topic in topics)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TopicCard(
                // Re-key on the query so a search opens matching topics.
                key: ValueKey('${topic.title}|${q.isNotEmpty}'),
                topic: topic,
                proLabel: l10n.guideProBadge,
                initiallyExpanded: q.isNotEmpty,
              ),
            ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final _GuideTopic topic;
  final String proLabel;
  final bool initiallyExpanded;

  const _TopicCard({
    super.key,
    required this.topic,
    required this.proLabel,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Theme(
        // ExpansionTile draws dividers when open; the card is the boundary.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(topic.icon, color: scheme.primary, size: 22),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  topic.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (topic.isPro) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    proLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          children: [
            Text(
              topic.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: scheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideTopic {
  final IconData icon;
  final String title;
  final String body;
  final bool isPro;

  const _GuideTopic({
    required this.icon,
    required this.title,
    required this.body,
    this.isPro = false,
  });
}
