import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import 'package:rocis_tasks/core/utils/haptic_utils.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/import_task_preview_sheet.dart';
import 'package:rocis_tasks/features/tasks/services/task_share_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

class TaskQrScannerScreen extends StatefulWidget {
  const TaskQrScannerScreen({super.key});

  static Future<bool?> open(BuildContext context) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const TaskQrScannerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<TaskQrScannerScreen> createState() => _TaskQrScannerScreenState();
}

class _TaskQrScannerScreenState extends State<TaskQrScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  final TaskShareService _shareService = TaskShareService();
  bool _isProcessing = false;

  late final AnimationController _animController;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );

    _animController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeString(String rawValue) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticUtils.throttledMediumImpact();

    final l10n = AppLocalizations.of(context)!;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    try {
      final shareData = await _shareService.resolveQrString(
        rawValue,
        taskProvider.categories,
      );

      if (!mounted) return;

      final imported = await ImportTaskPreviewSheet.show(context, shareData);

      if (imported == true && mounted) {
        Navigator.pop(context, true);
        return;
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = l10n.invalidQrCode;
        if (e is StateError && e.message == 'TASK_EXPIRED') {
          errorMsg = l10n.taskExpired;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        // Delay re-enabling scanner to prevent immediate duplicate detection
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    HapticUtils.throttledLightImpact();
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);

      if (files.isEmpty || files.first.path == null) {
        return;
      }

      final path = files.first.path!;
      final capture = await _controller.analyzeImage(path);

      if (capture == null || capture.barcodes.isEmpty) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.invalidQrCode),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final rawValue = capture.barcodes.first.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        await _handleBarcodeString(rawValue);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final primary = theme.colorScheme.primary;
    final size = MediaQuery.of(context).size;
    final scanBoxSize = (size.width * 0.72).clamp(240.0, 320.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Viewfinder
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isProcessing) return;
              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw != null && raw.isNotEmpty) {
                  _handleBarcodeString(raw);
                  break;
                }
              }
            },
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_rounded,
                        size: 64,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.cameraPermissionRequired,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => _controller.start(),
                        child: Text(l10n.grantPermission),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Translucent Cutout Overlay
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.65),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: scanBoxSize,
                    height: scanBoxSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Scan Border and Animated Laser
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: scanBoxSize,
              height: scanBoxSize,
              child: Stack(
                children: [
                  // Rounded frame border
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.8),
                        width: 3,
                      ),
                    ),
                  ),

                  // Animated scanning laser line
                  if (!_isProcessing)
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: _scanAnimation.value * (scanBoxSize - 20) + 10,
                          left: 16,
                          right: 16,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primary.withValues(alpha: 0.0),
                                  primary,
                                  primary.withValues(alpha: 0.0),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Loading spinner when processing
                  if (_isProcessing)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: CircularProgressIndicator(color: primary),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 4. Top Controls (Back, Torch, Switch Camera)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Row(
                    children: [
                      // Torch Toggle
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(
                            Icons.flash_on_rounded,
                            color: Colors.white,
                          ),
                          tooltip: l10n.flashOn,
                          onPressed: () => _controller.toggleTorch(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Camera Switch
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(
                            Icons.flip_camera_ios_rounded,
                            color: Colors.white,
                          ),
                          tooltip: l10n.flipCamera,
                          onPressed: () => _controller.switchCamera(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 5. Bottom Instructions & Gallery Button
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.scanQrCode,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        shadows: [
                          const Shadow(blurRadius: 6, color: Colors.black87),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassContainer(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.white.withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: InkWell(
                        onTap: _pickImageFromGallery,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.pickFromGallery,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
