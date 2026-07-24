import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Utility for parsing, previewing, and opening task file attachments.
class AttachmentUtils {
  /// Extract filename from both Unix and Windows file paths.
  static String getFilename(String path) {
    if (path.isEmpty) return '';
    return path.replaceAll('\\', '/').split('/').last;
  }

  /// Get relevant Material icon for attachment file extension.
  static IconData getFileIcon(String path) {
    final filename = getFilename(path);
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return Icons.image_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'mp3':
      case 'wav':
      case 'm4a':
        return Icons.audiotrack_rounded;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.videocam_rounded;
      case 'txt':
      case 'log':
      case 'md':
        return Icons.article_rounded;
      default:
        return Icons.attach_file_rounded;
    }
  }

  /// Check if file extension is a supported image format.
  static bool isImageFile(String path) {
    final filename = getFilename(path);
    final ext = filename.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  /// Open or preview attachment file.
  static Future<void> openAttachment(BuildContext context, String path) async {
    if (path.trim().isEmpty) return;
    final filename = getFilename(path);
    final isWebUrl = path.startsWith('http://') || path.startsWith('https://');

    if (isImageFile(path)) {
      if (isWebUrl) {
        _showImagePreviewDialog(context, filename, Image.network(path));
        return;
      } else if (!kIsWeb) {
        final file = File(path);
        if (file.existsSync()) {
          _showImagePreviewDialog(
            context,
            filename,
            Image.file(file),
            localPath: path,
          );
          return;
        }
      } else {
        _showImagePreviewDialog(context, filename, Image.network(path));
        return;
      }
    }

    // For non-images or remote files
    if (isWebUrl) {
      final uri = Uri.parse(path);
      try {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      } catch (e) {
        if (context.mounted) {
          _showErrorSnackBar(context, 'Could not open URL: $filename');
        }
      }
      return;
    }

    if (!kIsWeb) {
      final file = File(path);
      if (!file.existsSync()) {
        _showErrorSnackBar(context, 'File not found: $filename');
        return;
      }

      final uri = Uri.file(path);
      bool launched = false;

      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }

      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (_) {
          launched = false;
        }
      }

      if (!launched && context.mounted) {
        _showErrorSnackBar(context, 'No app found to open $filename');
      }
    } else {
      _showErrorSnackBar(context, 'Cannot open local file on web');
    }
  }

  static void _showImagePreviewDialog(
    BuildContext context,
    String filename,
    Widget imageWidget, {
    String? localPath,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 550, maxWidth: 500),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      filename,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (localPath != null)
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 20),
                      tooltip: 'Open externally',
                      onPressed: () async {
                        final uri = Uri.file(localPath);
                        try {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        } catch (_) {
                          try {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.platformDefault,
                            );
                          } catch (_) {}
                        }
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: imageWidget,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
