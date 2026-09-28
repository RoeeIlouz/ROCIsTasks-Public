import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/utils/haptic_utils.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/services/task_share_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

enum ShareMode { offline, cloud }

class ShareTaskQrSheet extends StatefulWidget {
  final Task task;

  const ShareTaskQrSheet({
    super.key,
    required this.task,
  });

  static Future<void> show(BuildContext context, Task task) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareTaskQrSheet(task: task),
    );
  }

  @override
  State<ShareTaskQrSheet> createState() => _ShareTaskQrSheetState();
}

class _ShareTaskQrSheetState extends State<ShareTaskQrSheet> {
  final TaskShareService _shareService = TaskShareService();
  ShareMode _mode = ShareMode.offline;

  String? _offlinePayload;
  String? _cloudPayload;
  bool _isLoadingCloud = false;
  String? _cloudError;

  @override
  void initState() {
    super.initState();
    _initOfflinePayload();
  }

  void _initOfflinePayload() {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    String? categoryName;
    if (widget.task.categoryId != null) {
      final cat = taskProvider.getCategoryById(widget.task.categoryId!);
      categoryName = cat?.name;
    }
    _offlinePayload = _shareService.generateOfflinePayload(
      widget.task,
      categoryName: categoryName,
    );
  }

  Future<void> _fetchOrUploadCloudPayload() async {
    if (_cloudPayload != null) return;

    setState(() {
      _isLoadingCloud = true;
      _cloudError = null;
    });

    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      String? categoryName;
      if (widget.task.categoryId != null) {
        final cat = taskProvider.getCategoryById(widget.task.categoryId!);
        categoryName = cat?.name;
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      final authorId = authService.currentUser?.uid;

      final cloudUri = await _shareService.uploadCloudTask(
        widget.task,
        categoryName: categoryName,
        authorId: authorId,
      );

      if (mounted) {
        setState(() {
          _cloudPayload = cloudUri;
          _isLoadingCloud = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cloudError = e.toString();
          _isLoadingCloud = false;
        });
      }
    }
  }

  void _onModeChanged(ShareMode newMode) {
    if (_mode == newMode) return;
    HapticUtils.throttledLightImpact();
    setState(() {
      _mode = newMode;
    });

    if (newMode == ShareMode.cloud && _cloudPayload == null) {
      _fetchOrUploadCloudPayload();
    }
  }

  void _copyToClipboard(String data, AppLocalizations l10n) {
    Clipboard.setData(ClipboardData(text: data));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.qrDataCopied),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final primary = theme.colorScheme.primary;

    final activePayload =
        _mode == ShareMode.offline ? _offlinePayload : _cloudPayload;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        tintColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.shareTaskQr,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Segmented Toggle: Offline Direct vs Cloud Link
              SegmentedButton<ShareMode>(
                segments: [
                  ButtonSegment<ShareMode>(
                    value: ShareMode.offline,
                    label: Text(l10n.offlineDirect),
                    icon: const Icon(Icons.offline_bolt_outlined, size: 18),
                  ),
                  ButtonSegment<ShareMode>(
                    value: ShareMode.cloud,
                    label: Text(l10n.cloudShare7Days),
                    icon: const Icon(Icons.cloud_outlined, size: 18),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (set) => _onModeChanged(set.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: 20),

              // QR Box Card
              Container(
                width: 250,
                height: 250,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _mode == ShareMode.cloud && _isLoadingCloud
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: primary),
                            const SizedBox(height: 12),
                            Text(
                              l10n.syncingLabel,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _mode == ShareMode.cloud && _cloudError != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                _cloudError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                        : (activePayload != null
                            ? QrImageView(
                                data: activePayload,
                                version: QrVersions.auto,
                                size: 218,
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: primary,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.black87,
                                ),
                              )
                            : const SizedBox.shrink()),
              ),
              const SizedBox(height: 16),

              // Mode Description Banner
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _mode == ShareMode.offline
                          ? Icons.shield_outlined
                          : Icons.access_time_rounded,
                      size: 20,
                      color: primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _mode == ShareMode.offline
                            ? l10n.offlineDirectDesc
                            : l10n.cloudShareDesc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(l10n.copyQrPayload),
                      onPressed: activePayload != null
                          ? () => _copyToClipboard(activePayload, l10n)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
