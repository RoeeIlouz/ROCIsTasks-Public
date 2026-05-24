import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

/// Service for handling low-level security hardening (SSL Pinning, Trust Checks)
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  /// List of allowed SHA-256 fingerprints for SSL Pinning
  /// Add your server's certificate hashes here.
  final List<String> _allowedFingerprints = [
    // Example: "EE:AA:BB..." (Use 256-bit hashes)
  ];

  /// Returns a hardened [HttpClient] with optional Certificate Pinning support
  HttpClient getHardenedHttpClient() {
    final client = HttpClient();
    
    // 1. Basic Hardening: Connection Timeout
    client.connectionTimeout = const Duration(seconds: 10);

    // 2. SSL Pinning Scaffold
    if (_allowedFingerprints.isNotEmpty) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        AppLogger.critical('SECURITY ALERT: SSL Certificate mismatch for $host', tag: 'Security');
        return false; // Reject all bad certificates
      };
    }

    return client;
  }

  /// Check if the device environment is considered "Secure"
  /// (e.g., could be extended with root/jailbreak detection packages)
  Future<bool> isEnvironmentSecure() async {
    // Scaffold for future root/emulator detection
    return true; 
  }
}

class PrivateModeService extends ChangeNotifier {
  static const _secureStorage = FlutterSecureStorage();
  static const _pinKey = 'private_mode_pin_v1';
  static const _enabledKey = 'private_mode_enabled_v1';

  bool _initialized = false;
  bool _enabled = false;
  bool _hasPin = false;
  bool _unlocked = false;

  bool get isInitialized => _initialized;
  bool get isEnabled => _enabled;
  bool get hasPin => _hasPin;
  bool get isUnlocked => _unlocked;

  bool get shouldHidePrivateContent => _enabled && _hasPin && !_unlocked;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
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
    }
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
}
