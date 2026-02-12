import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

/// Cache entry with TTL
class _CacheEntry {
  final dynamic data;
  final DateTime expiry;

  _CacheEntry(this.data, this.expiry);

  bool get isExpired => DateTime.now().isAfter(expiry);
}

/// Simple in-memory caching service
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // In-memory cache
  final Map<String, _CacheEntry> _memoryCache = {};

  // Cache configuration
  static const Duration _defaultTtl = Duration(minutes: 30);
  static const int _maxMemoryCacheSize = 100;

  /// Get data from cache
  T? get<T>(String key) {
    final entry = _memoryCache[key];
    if (entry != null && !entry.isExpired) {
      if (AppConfig.enableDebugLogging) {
        AppLogger.info('Cache HIT: $key', tag: 'Cache');
      }
      return entry.data as T?;
    }

    // Remove expired entry
    if (entry?.isExpired == true) {
      _memoryCache.remove(key);
    }

    if (AppConfig.enableDebugLogging) {
      AppLogger.info('Cache MISS: $key', tag: 'Cache');
    }
    return null;
  }

  /// Store data in cache
  void set<T>(String key, T data, {Duration? ttl}) {
    final expiry = DateTime.now().add(ttl ?? _defaultTtl);
    _memoryCache[key] = _CacheEntry(data, expiry);

    // Cleanup if too large
    if (_memoryCache.length > _maxMemoryCacheSize) {
      _cleanupMemoryCache();
    }

    if (AppConfig.enableDebugLogging) {
      AppLogger.info('Cache SET: $key', tag: 'Cache');
    }
  }

  /// Remove specific cache entry
  void remove(String key) {
    _memoryCache.remove(key);
  }

  /// Clear all cache entries
  void clear() {
    _memoryCache.clear();
  }

  /// Clear expired entries
  void clearExpired() {
    _memoryCache.removeWhere((key, entry) => entry.isExpired);
  }

  /// Cleanup memory cache by removing oldest entries
  void _cleanupMemoryCache() {
    final entries = _memoryCache.entries.toList();
    entries.sort((a, b) => a.value.expiry.compareTo(b.value.expiry));

    // Remove oldest 20% of entries
    final removeCount = (_maxMemoryCacheSize * 0.2).round();
    for (int i = 0; i < removeCount && entries.isNotEmpty; i++) {
      _memoryCache.remove(entries[i].key);
    }
  }
}
