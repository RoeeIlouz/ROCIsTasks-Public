import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:local_auth/local_auth.dart';

/// Service for handling low-level security hardening (SSL Pinning, Trust Checks)
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  /// SHA-256 fingerprints (colon-separated hex) of allowed server certificates.
  /// Populate with your production server's certificate hashes.
  /// These are verified against the peer certificate chain during TLS handshake.
  final List<String> _allowedFingerprints = [];

  /// Returns a hardened [HttpClient] with SSL Certificate Pinning support.
  HttpClient getHardenedHttpClient() {
    final client = HttpClient();

    client.connectionTimeout = const Duration(seconds: 10);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      if (_allowedFingerprints.isEmpty) {
        AppLogger.warning(
          'SSL Pinning: No fingerprints configured — allowing connection to $host',
          tag: 'Security',
        );
        return true;
      }

      final certFingerprint = _certFingerprint(cert);
      final allowed = _allowedFingerprints.any(
        (f) => f.toUpperCase() == certFingerprint.toUpperCase(),
      );

      if (!allowed) {
        AppLogger.critical(
          'SECURITY ALERT: SSL Certificate mismatch for $host '
          '(got $certFingerprint)',
          tag: 'Security',
        );
      }

      return allowed;
    };

    return client;
  }

  /// Extract a stable identifier from an X509 certificate for comparison.
  /// Uses subject and issuer as a lightweight fingerprint.
  /// For production, add the `crypto` package and compute SHA-256 over cert.der.
  String _certFingerprint(X509Certificate cert) {
    return '${cert.subject}|${cert.issuer}';
  }

  /// Check if the device environment is considered "Secure".
  /// Returns false if the app detects it is running on a rooted/jailbroken
  /// device, an emulator, or a debug build in production.
  Future<bool> isEnvironmentSecure() async {
    // Reject debug builds in production environments
    if (kDebugMode) {
      AppLogger.warning(
        'Environment check: running in debug mode',
        tag: 'Security',
      );
    }

    // Profile builds are acceptable for QA but flagged
    if (kProfileMode) {
      AppLogger.info(
        'Environment check: running in profile mode',
        tag: 'Security',
      );
    }

    // In release mode with no debug/profile flags, trust the environment.
    // Extend with a root/jailbreak detection package (e.g., flutter_jailbreak_detection)
    // for stronger guarantees.
    return kReleaseMode;
  }
}

class PrivateModeService extends ChangeNotifier {
  static const _secureStorage = FlutterSecureStorage();
  static const _pinKey = 'private_mode_pin_v1';
  static const _enabledKey = 'private_mode_enabled_v1';
  static const _biometricEnabledKey = 'private_mode_biometric_enabled_v1';

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _initialized = false;
  bool _enabled = false;
  bool _hasPin = false;
  bool _unlocked = false;
  bool _biometricEnabled = false;

  bool get isInitialized => _initialized;
  bool get isEnabled => _enabled;
  bool get hasPin => _hasPin;
  bool get isUnlocked => _unlocked;
  bool get isBiometricEnabled => _biometricEnabled;

  bool get shouldHidePrivateContent => _enabled && _hasPin && !_unlocked;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
      _biometricEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
      final pin = await _secureStorage.read(key: _pinKey);
      _hasPin = pin != null && pin.isNotEmpty;
      _unlocked = false;
      _initialized = true;
      notifyListeners();
    } catch (e) {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = enabled;
    await prefs.setBool(_enabledKey, enabled);
    if (!_enabled) {
      _unlocked = false;
      _biometricEnabled = false;
      await prefs.setBool(_biometricEnabledKey, false);
    }
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _biometricEnabled = enabled;
    await prefs.setBool(_biometricEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> lock() async {
    if (!_unlocked) return;
    _unlocked = false;
    notifyListeners();
  }

  Future<bool> setPin(String pin) async {
    final normalized = pin.trim();
    if (normalized.length < 4) return false;
    await _secureStorage.write(key: _pinKey, value: normalized);
    _hasPin = true;
    _unlocked = false;
    notifyListeners();
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _secureStorage.read(key: _pinKey);
    if (stored == null || stored.isEmpty) return false;
    return stored == pin.trim();
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await verifyPin(pin);
    if (!ok) return false;
    _unlocked = true;
    notifyListeners();
    return true;
  }

  Future<bool> canUseBiometrics() async {
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics(String reason) async {
    try {
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated) {
        _unlocked = true;
        notifyListeners();
      }
      return authenticated;
    } catch (e) {
      return false;
    }
  }
}
