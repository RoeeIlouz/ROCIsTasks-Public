import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/security_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _deviceSupportsBiometrics = false;
  bool _checkingHardware = true;

  @override
  void initState() {
    super.initState();
    _checkHardware();
  }

  Future<void> _checkHardware() async {
    final privateModeService = Provider.of<PrivateModeService>(
      context,
      listen: false,
    );
    final supports = await privateModeService.canUseBiometrics();
    if (mounted) {
      setState(() {
        _deviceSupportsBiometrics = supports;
        _checkingHardware = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final privateModeService = Provider.of<PrivateModeService>(context);
    final subscriptionService = Provider.of<SubscriptionService>(context);

    final bool isPremium = subscriptionService.isPremium;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.securitySettings,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildInfoCard(context, theme, l10n),
          const SizedBox(height: 24),
          _buildSectionHeader(context, l10n.privateMode),

          // Private Mode Toggle
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: SwitchListTile(
              secondary: Icon(
                Icons.lock_rounded,
                color: privateModeService.isEnabled
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
              ),
              title: Text(
                l10n.privateMode,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(l10n.privateModeSubtitle),
              value: privateModeService.isEnabled,
              onChanged: (value) =>
                  _togglePrivateMode(context, privateModeService, l10n, value),
            ),
          ),

          if (privateModeService.isEnabled) ...[
            const SizedBox(height: 12),
            // PIN Configuration Option
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      privateModeService.hasPin
                          ? Icons.lock_reset_rounded
                          : Icons.lock_outline,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      privateModeService.hasPin
                          ? l10n.confirmPin
                          : l10n.setPinTitle,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      privateModeService.hasPin
                          ? l10n.confirmPin
                          : l10n.pinMinDigits,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        _setupOrChangePin(context, privateModeService, l10n),
                  ),
                ],
              ),
            ),

            if (!kIsWeb) ...[
              const SizedBox(height: 24),
              _buildSectionHeader(context, l10n.biometricUnlock),

              // Biometric Toggle (Premium Gated)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Opacity(
                  opacity: (isPremium && _deviceSupportsBiometrics) ? 1.0 : 0.5,
                  child: SwitchListTile(
                    secondary: Icon(
                      Icons.fingerprint_rounded,
                      color:
                          (isPremium &&
                              _deviceSupportsBiometrics &&
                              privateModeService.isBiometricEnabled)
                          ? theme.colorScheme.primary
                          : theme.disabledColor,
                    ),
                    title: Row(
                      children: [
                        Text(
                          l10n.biometricUnlock,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                        ),
                        if (!isPremium) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PRO',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[800],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      _checkingHardware
                          ? 'Checking device capabilities...'
                          : !_deviceSupportsBiometrics
                          ? l10n.biometricNotAvailable
                          : l10n.biometricUnlockSubtitle,
                    ),
                    value:
                        isPremium &&
                        _deviceSupportsBiometrics &&
                        privateModeService.isBiometricEnabled,
                    onChanged: (isPremium && _deviceSupportsBiometrics)
                        ? privateModeService.setBiometricEnabled
                        : null, // Grayed out/disabled
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, top: 8.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.privateCategorySubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.4,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePrivateMode(
    BuildContext context,
    PrivateModeService privateModeService,
    AppLocalizations l10n,
    bool value,
  ) async {
    if (value && !privateModeService.hasPin) {
      // Must set a PIN first before enabling
      await _setupOrChangePin(context, privateModeService, l10n);
      if (!privateModeService.hasPin) {
        // User cancelled PIN creation
        return;
      }
    }
    await privateModeService.setEnabled(value);
  }

  Future<void> _setupOrChangePin(
    BuildContext context,
    PrivateModeService privateModeService,
    AppLocalizations l10n,
  ) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.setPinTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.pinMinDigits),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.confirmPin),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (pinController.text != confirmController.text) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pinsDoNotMatch)));
      }
      return;
    }
    final saved = await privateModeService.setPin(pinController.text);
    if (saved && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PIN saved successfully')));
    }
  }
}
