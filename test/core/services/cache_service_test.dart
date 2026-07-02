import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/cache_service.dart';

void main() {
  group('CacheService', () {
    late CacheService cache;

    setUp(() {
      cache = CacheService();
      cache.clear();
    });

    group('get / set', () {
      test('should return null for missing key', () {
        expect(cache.get<String>('missing'), isNull);
      });

      test('should return stored value', () {
        cache.set<String>('key1', 'value1');
        expect(cache.get<String>('key1'), 'value1');
      });

      test('should return typed value', () {
        cache.set<int>('count', 42);
        expect(cache.get<int>('count'), 42);
      });

      test('should overwrite existing value', () {
        cache.set<String>('key', 'first');
        cache.set<String>('key', 'second');
        expect(cache.get<String>('key'), 'second');
      });

      test('should store different types independently', () {
        cache.set<String>('str', 'hello');
        cache.set<int>('num', 99);
        expect(cache.get<String>('str'), 'hello');
        expect(cache.get<int>('num'), 99);
      });
    });

    group('expiry', () {
      test('should return null for expired entry', () {
        cache.set<String>('key', 'value', ttl: const Duration(hours: -1));
        expect(cache.get<String>('key'), isNull);
      });

      test('should remove expired entry on get', () {
        cache.set<String>('key', 'value', ttl: const Duration(hours: -1));
        cache.get<String>('key');
      });
    });

    group('remove', () {
      test('should remove specific entry', () {
        cache.set<String>('key', 'value');
        cache.remove('key');
        expect(cache.get<String>('key'), isNull);
      });

      test('should not affect other entries', () {
        cache.set<String>('a', '1');
        cache.set<String>('b', '2');
        cache.remove('a');
        expect(cache.get<String>('b'), '2');
      });
    });

    group('clear', () {
      test('should remove all entries', () {
        cache.set<String>('a', '1');
        cache.set<String>('b', '2');
        cache.set<int>('c', 3);
        cache.clear();
        expect(cache.get<String>('a'), isNull);
        expect(cache.get<String>('b'), isNull);
        expect(cache.get<int>('c'), isNull);
      });
    });

    group('clearExpired', () {
      test('should remove only expired entries', () {
        cache.set<String>('expired', 'gone', ttl: const Duration(hours: -1));
        cache.set<String>('valid', 'still here');
        cache.clearExpired();
        expect(cache.get<String>('expired'), isNull);
        expect(cache.get<String>('valid'), 'still here');
      });
    });
  });
}
