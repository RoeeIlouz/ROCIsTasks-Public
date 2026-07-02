import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/security_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class TaskUnlockDialog extends StatefulWidget {
  const TaskUnlockDialog({super.key});

  @override
  State<TaskUnlockDialog> createState() => _TaskUnlockDialogState();
}

class _TaskUnlockDialogState extends State<TaskUnlockDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _showPinInput = false;
  String? _errorMessage;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptBiometricAuth();
    });
  }

  Future<void> _attemptBiometricAuth() async {
    final privateModeService = Provider.of<PrivateModeService>(context, listen: false);
    final subscriptionService = Provider.of<SubscriptionService>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    // Check if biometric is enabled, supported, and the user is premium
    final bool isPremium = subscriptionService.isPremium;
    final bool canCheck = await privateModeService.canUseBiometrics();

    if (isPremium && privateModeService.isBiometricEnabled && canCheck) {
      setState(() {
        _isAuthenticating = true;
        _errorMessage = null;
      });

      final authenticated = await privateModeService.authenticateWithBiometrics(
        l10n.biometricAuthReason,
      );

      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });

        if (authenticated) {
          Navigator.pop(context, true);
        } else {
          // Automatic fallback to PIN input
          setState(() {
            _showPinInput = true;
          });
        }
      }
    } else {
      // Direct PIN input if biometrics are not enabled/available
      if (mounted) {
        setState(() {
          _showPinInput = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final privateModeService = Provider.of<PrivateModeService>(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock Icon Header
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  color: theme.colorScheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                l10n.privateTask,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                l10n.privateTaskSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              if (_isAuthenticating) ...[
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Authenticating...',
                  style: theme.textTheme.bodySmall,
                ),
              ] else if (_showPinInput) ...[
                // PIN input decoration
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    errorText: _errorMessage,
                  ),
                  autofocus: true,
                  onSubmitted: (_) => _verifyPin(privateModeService, l10n),
                ),
                const SizedBox(height: 20),

                // Action buttons for PIN
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        l10n.cancel,
                        style: GoogleFonts.outfit(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _verifyPin(privateModeService, l10n),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l10n.unlock,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Fallback / Start biometric manually
                FilledButton.icon(
                  onPressed: _attemptBiometricAuth,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: Text(l10n.useBiometrics),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showPinInput = true;
                    });
                  },
                  child: Text(
                    l10n.usePinInstead,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verifyPin(PrivateModeService privateModeService, AppLocalizations l10n) async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;

    final success = await privateModeService.unlockWithPin(pin);
    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _errorMessage = l10n.wrongPin;
          _pinController.clear();
        });
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }
}
