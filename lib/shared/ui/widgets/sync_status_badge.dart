import 'package:flutter/material.dart';
import 'package:rocis_tasks/core/services/connectivity_service.dart';
import 'package:rocis_tasks/core/services/sync_status_service.dart';
import 'package:rocis_tasks/core/services/firestore_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class SyncStatusBadge extends StatelessWidget {
  final bool compact;

  const SyncStatusBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final connectivity = ConnectivityService();
    final syncStatus = SyncStatusService();

    return ListenableBuilder(
      listenable: Listenable.merge([connectivity, syncStatus]),
      builder: (context, _) {
        final isOffline = connectivity.isOffline;
        final isSyncing = syncStatus.isSyncing;
        final hasError = syncStatus.hasError;
        final isSuccess = syncStatus.state == SyncState.success;

        if (isOffline) {
          return _buildBadge(
            context,
            icon: Icons.cloud_off_rounded,
            label: compact ? null : 'Offline',
            tooltip: AppLocalizations.of(context)!.offlineTooltip,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.errorContainer.withValues(alpha: 0.25),
            foregroundColor: Theme.of(context).colorScheme.error,
            onTap: connectivity.refresh,
          );
        }

        if (isSyncing) {
          return _buildBadge(
            context,
            icon: Icons.sync_rounded,
            isSpinning: true,
            label: compact ? null : AppLocalizations.of(context)!.syncingLabel,
            tooltip: AppLocalizations.of(context)!.syncingToCloud,
            backgroundColor: const Color(0xFFF37000).withValues(alpha: 0.15),
            foregroundColor: const Color(0xFFF37000),
          );
        }

        if (hasError) {
          return _buildBadge(
            context,
            icon: Icons.sync_problem_rounded,
            label: compact
                ? null
                : AppLocalizations.of(context)!.syncErrorLabel,
            tooltip:
                syncStatus.lastErrorMessage ??
                AppLocalizations.of(context)!.syncErrorRetry,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.errorContainer.withValues(alpha: 0.3),
            foregroundColor: Theme.of(context).colorScheme.error,
            onTap: () async {
              await FirestoreService().processOfflineQueue();
            },
          );
        }

        if (isSuccess) {
          return _buildBadge(
            context,
            icon: Icons.cloud_done_rounded,
            label: compact ? null : AppLocalizations.of(context)!.syncedLabel,
            tooltip: AppLocalizations.of(context)!.allSyncedToCloud,
            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
            foregroundColor: const Color(0xFF10B981),
          );
        }

        // Idle online: subtle synced indicator
        if (compact) {
          return Tooltip(
            message: AppLocalizations.of(context)!.connectedAndSynced,
            child: Icon(
              Icons.cloud_done_outlined,
              size: 16,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBadge(
    BuildContext context, {
    required IconData icon,
    String? label,
    required String tooltip,
    required Color backgroundColor,
    required Color foregroundColor,
    bool isSpinning = false,
    VoidCallback? onTap,
  }) {
    Widget iconWidget = Icon(icon, size: 14, color: foregroundColor);

    if (isSpinning) {
      iconWidget = SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    }

    final badge = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: label != null ? 8 : 6,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: foregroundColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              if (label != null) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: foregroundColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Tooltip(message: tooltip, child: badge);
  }
}

/// App bar `bottom`: a thin indeterminate line while syncing, otherwise an
/// empty strip of the same height so the bar never changes size.
class SyncProgressLine extends StatelessWidget implements PreferredSizeWidget {
  const SyncProgressLine({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(2);

  @override
  Widget build(BuildContext context) {
    final syncStatus = SyncStatusService();
    return ListenableBuilder(
      listenable: Listenable.merge([ConnectivityService(), syncStatus]),
      builder: (context, _) {
        final show = syncStatus.isSyncing && !ConnectivityService().isOffline;
        return SizedBox(
          height: 2,
          child: AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: show
                ? Semantics(
                    label: AppLocalizations.of(context)!.syncingToCloud,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// A small dot beside the title when the last sync failed; tap to retry.
/// Nothing is shown while everything is synced.
class SyncErrorDot extends StatelessWidget {
  const SyncErrorDot({super.key});

  @override
  Widget build(BuildContext context) {
    final syncStatus = SyncStatusService();
    return ListenableBuilder(
      listenable: Listenable.merge([ConnectivityService(), syncStatus]),
      builder: (context, _) {
        if (!syncStatus.hasError || ConnectivityService().isOffline) {
          return const SizedBox.shrink();
        }
        final l10n = AppLocalizations.of(context)!;
        final color = Theme.of(context).colorScheme.error;
        return Tooltip(
          message: syncStatus.lastErrorMessage ?? l10n.syncErrorRetry,
          child: Semantics(
            button: true,
            label: l10n.syncErrorRetry,
            child: InkResponse(
              radius: 18,
              onTap: () => FirestoreService().processOfflineQueue(),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
