import 'package:flutter_test/flutter_test.dart';

/// Simple MessageCache implementation for testing
/// This mirrors the Android/iOS implementation
class MessageCache {
  final int maxSize;
  final Duration expirationDuration;

  final Map<int, DateTime> _cache = {};
  final List<int> _insertionOrder = [];

  MessageCache({
    this.maxSize = 1000,
    this.expirationDuration = const Duration(minutes: 5),
  });

  /// Check if a message has been seen before
  bool hasMessage(int messageId) {
    final entry = _cache[messageId];
    if (entry == null) return false;

    // Check if expired
    final now = DateTime.now();
    if (now.difference(entry) > expirationDuration) {
      _removeMessage(messageId);
      return false;
    }

    return true;
  }

  /// Add a message to the cache
  bool addMessage(int messageId) {
    // Check if already exists
    if (hasMessage(messageId)) {
      return false;
    }

    // Check capacity and evict if needed
    if (_cache.length >= maxSize) {
      _evictOldest();
    }

    // Add new entry
    _cache[messageId] = DateTime.now();
    _insertionOrder.add(messageId);
    return true;
  }

  /// Remove a message from cache
  void _removeMessage(int messageId) {
    _cache.remove(messageId);
    _insertionOrder.remove(messageId);
  }

  /// Evict oldest entry (LRU)
  void _evictOldest() {
    if (_insertionOrder.isEmpty) return;
    final oldest = _insertionOrder.removeAt(0);
    _cache.remove(oldest);
  }

  /// Clear all entries
  void clear() {
    _cache.clear();
    _insertionOrder.clear();
  }

  /// Get cache size
  int get size => _cache.length;

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final oldestEntry = _insertionOrder.isNotEmpty ? _cache[_insertionOrder.first] : null;
    final oldestAge = oldestEntry != null ? now.difference(oldestEntry).inMilliseconds : 0;

    return {
      'size': _cache.length,
      'capacity': maxSize,
      'oldestEntryAgeMs': oldestAge,
      'expirationTimeMs': expirationDuration.inMilliseconds,
    };
  }

  /// Clean up expired entries
  void cleanupExpired() {
    final now = DateTime.now();
    final expiredIds = <int>[];

    _cache.forEach((id, timestamp) {
      if (now.difference(timestamp) > expirationDuration) {
        expiredIds.add(id);
      }
    });

    for (final id in expiredIds) {
      _removeMessage(id);
    }
  }
}

void main() {
  group('MessageCache', () {
    test('creates cache with default settings', () {
      final cache = MessageCache();
      expect(cache.size, 0);
      expect(cache.maxSize, 1000);
      expect(cache.expirationDuration.inMinutes, 5);
    });

    test('creates cache with custom settings', () {
      final cache = MessageCache(
        maxSize: 100,
        expirationDuration: const Duration(minutes: 10),
      );
      expect(cache.maxSize, 100);
      expect(cache.expirationDuration.inMinutes, 10);
    });

    test('addMessage adds new message to cache', () {
      final cache = MessageCache();
      final added = cache.addMessage(123);

      expect(added, true);
      expect(cache.size, 1);
      expect(cache.hasMessage(123), true);
    });

    test('addMessage returns false for duplicate message', () {
      final cache = MessageCache();
      cache.addMessage(123);

      final addedAgain = cache.addMessage(123);
      expect(addedAgain, false);
      expect(cache.size, 1);
    });

    test('hasMessage returns false for non-existent message', () {
      final cache = MessageCache();
      expect(cache.hasMessage(999), false);
    });

    test('hasMessage returns true for existing message', () {
      final cache = MessageCache();
      cache.addMessage(123);
      expect(cache.hasMessage(123), true);
    });

    test('cache evicts oldest entry when capacity reached', () {
      final cache = MessageCache(maxSize: 3);

      cache.addMessage(1);
      cache.addMessage(2);
      cache.addMessage(3);
      expect(cache.size, 3);

      // Add 4th message, should evict oldest (1)
      cache.addMessage(4);
      expect(cache.size, 3);
      expect(cache.hasMessage(1), false);
      expect(cache.hasMessage(2), true);
      expect(cache.hasMessage(3), true);
      expect(cache.hasMessage(4), true);
    });

    test('cache evicts multiple old entries when capacity reached', () {
      final cache = MessageCache(maxSize: 5);

      for (int i = 1; i <= 5; i++) {
        cache.addMessage(i);
      }
      expect(cache.size, 5);

      // Add 3 more messages
      cache.addMessage(6);
      cache.addMessage(7);
      cache.addMessage(8);

      expect(cache.size, 5);
      expect(cache.hasMessage(1), false);
      expect(cache.hasMessage(2), false);
      expect(cache.hasMessage(3), false);
      expect(cache.hasMessage(4), true);
      expect(cache.hasMessage(5), true);
      expect(cache.hasMessage(6), true);
      expect(cache.hasMessage(7), true);
      expect(cache.hasMessage(8), true);
    });

    test('clear removes all entries', () {
      final cache = MessageCache();
      cache.addMessage(1);
      cache.addMessage(2);
      cache.addMessage(3);
      expect(cache.size, 3);

      cache.clear();
      expect(cache.size, 0);
      expect(cache.hasMessage(1), false);
      expect(cache.hasMessage(2), false);
      expect(cache.hasMessage(3), false);
    });

    test('getStats returns correct statistics', () {
      final cache = MessageCache(maxSize: 100);
      cache.addMessage(1);
      cache.addMessage(2);

      final stats = cache.getStats();
      expect(stats['size'], 2);
      expect(stats['capacity'], 100);
      expect(stats['oldestEntryAgeMs'], greaterThanOrEqualTo(0));
      expect(stats['expirationTimeMs'], 5 * 60 * 1000);
    });

    test('handles many messages without error', () {
      final cache = MessageCache(maxSize: 1000);

      for (int i = 0; i < 2000; i++) {
        cache.addMessage(i);
      }

      // Should have evicted first 1000 messages
      expect(cache.size, 1000);
      expect(cache.hasMessage(0), false);
      expect(cache.hasMessage(999), false);
      expect(cache.hasMessage(1000), true);
      expect(cache.hasMessage(1999), true);
    });

    test('expired messages are removed on hasMessage check', () async {
      final cache = MessageCache(
        expirationDuration: const Duration(milliseconds: 100),
      );

      cache.addMessage(123);
      expect(cache.hasMessage(123), true);

      // Wait for expiration
      await Future.delayed(const Duration(milliseconds: 150));

      expect(cache.hasMessage(123), false);
      expect(cache.size, 0);
    });

    test('cleanupExpired removes expired entries', () async {
      final cache = MessageCache(
        expirationDuration: const Duration(milliseconds: 100),
      );

      cache.addMessage(1);
      cache.addMessage(2);
      await Future.delayed(const Duration(milliseconds: 60));
      cache.addMessage(3);

      expect(cache.size, 3);

      // Wait for first two to expire (60ms + 60ms = 120ms > 100ms expiration)
      await Future.delayed(const Duration(milliseconds: 60));

      cache.cleanupExpired();
      // Message 3 might also expire depending on timing, so just check that some were removed
      expect(cache.size, lessThanOrEqualTo(1));
      expect(cache.hasMessage(1), false);
      expect(cache.hasMessage(2), false);
    });

    test('cache handles duplicate adds correctly', () {
      final cache = MessageCache();

      expect(cache.addMessage(123), true);
      expect(cache.addMessage(123), false);
      expect(cache.addMessage(123), false);
      expect(cache.size, 1);
    });

    test('cache maintains insertion order for LRU', () {
      final cache = MessageCache(maxSize: 3);

      cache.addMessage(1);
      cache.addMessage(2);
      cache.addMessage(3);

      // Add 4, should evict 1
      cache.addMessage(4);
      expect(cache.hasMessage(1), false);
      expect(cache.hasMessage(2), true);

      // Add 5, should evict 2
      cache.addMessage(5);
      expect(cache.hasMessage(2), false);
      expect(cache.hasMessage(3), true);
    });
  });
}

