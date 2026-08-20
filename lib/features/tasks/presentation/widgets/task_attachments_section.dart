import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rocis_tasks/core/utils/attachment_utils.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';

class TaskAttachmentsSection extends StatelessWidget {
  final List<String> attachmentPaths;
  final VoidCallback onAddAttachment;
  final ValueChanged<int> onRemoveAttachment;

  const TaskAttachmentsSection({
    super.key,
    required this.attachmentPaths,
    required this.onAddAttachment,
    required this.onRemoveAttachment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n?.attachments ?? 'Attachments',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.primary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.attach_file, size: 20),
              onPressed: onAddAttachment,
              tooltip: l10n?.attachments ?? 'Add Attachment',
            ),
          ],
        ),
        if (attachmentPaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(attachmentPaths.length, (index) {
              final path = attachmentPaths[index];
              final isImage = AttachmentUtils.isImageFile(path);
              final filename = AttachmentUtils.getFilename(path);
              final ext = filename.contains('.') ? filename.split('.').last.toUpperCase() : '';

              return Material(
                color: Colors.transparent,
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => AttachmentUtils.openAttachment(context, path),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isImage && !kIsWeb && File(path).existsSync())
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(path),
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    AttachmentUtils.getFileIcon(path),
                                    size: 22,
                                    color: theme.colorScheme.primary,
                                  ),
                                  if (ext.isNotEmpty && ext.length <= 4) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        ext,
                                        style: GoogleFonts.outfit(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 110),
                              child: Text(
                                filename,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      // 48x48dp interactive touch target for removal
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => onRemoveAttachment(index),
                        child: const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Icon(Icons.close, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
