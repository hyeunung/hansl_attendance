import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'timer_manager.dart';

/// Comprehensive caching service for network requests and data optimization
/// Implements in-memory cache with TTL, persistent cache, and request deduplication
class CacheService with TimerManagementMixin {
  static final CacheService _instance = CacheService._internal();
  static CacheService get instance => _instance;
  CacheService._internal();

  // In-memory cache with TTL
  final Map<String, _CacheItem> _memoryCache = {};
  final Map<String, Future<dynamic>> _pendingRequests = {};
  
  // Cache configuration
  static const int _maxMemoryCacheSize = 100;
  static const Duration _defaultTtl = Duration(minutes: 5);
  static const Duration _shortTtl = Duration(minutes: 1);
  static const Duration _longTtl = Duration(hours: 1);
  
  // Persistent cache keys
  static const String _persistentPrefix = 'cache_';
  
  SharedPreferences? _prefs;
  bool _initialized = false;

  /// Initialize the cache service
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      _startCleanupTimer();
      _initialized = true;
      if (kDebugMode) print('✅ CacheService initialized successfully');
    } catch (e) {
      if (kDebugMode) print('❌ CacheService initialization failed: $e');
      rethrow;
    }
  }

  /// Get data from cache with fallback function
  /// Uses memory cache first, then persistent cache, then fallback function
  Future<T?> getOrFetch<T>({
    required String key,
    required Future<T> Function() fallback,
    Duration? ttl,
    bool usePersistentCache = true,
    bool useMemoryCache = true,
    T Function(Map<String, dynamic>)? fromJson,
    Map<String, dynamic> Function(T)? toJson,
  }) async {
    await _ensureInitialized();
    
    final effectiveTtl = ttl ?? _defaultTtl;
    
    // 1. Check memory cache first
    if (useMemoryCache) {
      final memoryData = _getFromMemory<T>(key);
      if (memoryData != null) {
        if (kDebugMode) print('🎯 Cache HIT (memory): $key');
        return memoryData;
      }
    }
    
    // 2. Check persistent cache
    if (usePersistentCache) {
      final persistentData = await _getFromPersistent<T>(key, fromJson);
      if (persistentData != null) {
        // Store in memory for faster next access
        if (useMemoryCache) {
          _storeInMemory(key, persistentData, effectiveTtl);
        }
        if (kDebugMode) print('🎯 Cache HIT (persistent): $key');
        return persistentData;
      }
    }
    
    // 3. Check for pending request (deduplication)
    if (_pendingRequests.containsKey(key)) {
      if (kDebugMode) print('⏳ Request deduplication: $key');
      return await _pendingRequests[key] as T?;
    }
    
    // 4. Execute fallback function
    if (kDebugMode) print('🔄 Cache MISS, fetching: $key');
    final future = _executeFallback<T>(key, fallback);
    _pendingRequests[key] = future;
    
    try {
      final result = await future;
      _pendingRequests.remove(key);
      
      if (result != null) {
        // Store in both caches
        if (useMemoryCache) {
          _storeInMemory(key, result, effectiveTtl);
        }
        if (usePersistentCache && toJson != null) {
          await _storeToPersistent(key, result, toJson, effectiveTtl);
        }
      }
      
      return result;
    } catch (e) {
      _pendingRequests.remove(key);
      rethrow;
    }
  }

  /// Store data in cache manually
  Future<void> put<T>({
    required String key,
    required T data,
    Duration? ttl,
    bool usePersistentCache = true,
    bool useMemoryCache = true,
    Map<String, dynamic> Function(T)? toJson,
  }) async {
    await _ensureInitialized();
    
    final effectiveTtl = ttl ?? _defaultTtl;
    
    if (useMemoryCache) {
      _storeInMemory(key, data, effectiveTtl);
    }
    
    if (usePersistentCache && toJson != null) {
      await _storeToPersistent(key, data, toJson, effectiveTtl);
    }
  }

  /// Invalidate cache entry
  Future<void> invalidate(String key) async {
    await _ensureInitialized();
    
    // Remove from memory cache
    _memoryCache.remove(key);
    
    // Remove from persistent cache
    await _prefs?.remove('$_persistentPrefix$key');
    await _prefs?.remove('${_persistentPrefix}${key}_expires');
    
    if (kDebugMode) print('🗑️ Cache invalidated: $key');
  }

  /// Invalidate cache entries by pattern
  Future<void> invalidatePattern(String pattern) async {
    await _ensureInitialized();
    
    // Remove from memory cache
    final memoryKeys = _memoryCache.keys.where((k) => k.contains(pattern)).toList();
    for (final key in memoryKeys) {
      _memoryCache.remove(key);
    }
    
    // Remove from persistent cache
    final allKeys = _prefs?.getKeys() ?? <String>{};
    final persistentKeys = allKeys.where((k) => 
      k.startsWith(_persistentPrefix) && k.contains(pattern)
    ).toList();
    
    for (final key in persistentKeys) {
      await _prefs?.remove(key);
    }
    
    if (kDebugMode) print('🗑️ Cache pattern invalidated: $pattern (${memoryKeys.length + persistentKeys.length} entries)');
  }

  /// Clear all cache
  Future<void> clearAll() async {
    await _ensureInitialized();
    
    // Clear memory cache
    _memoryCache.clear();
    
    // Clear persistent cache
    final allKeys = _prefs?.getKeys() ?? <String>{};
    final cacheKeys = allKeys.where((k) => k.startsWith(_persistentPrefix)).toList();
    
    for (final key in cacheKeys) {
      await _prefs?.remove(key);
    }
    
    if (kDebugMode) print('🗑️ All cache cleared (${cacheKeys.length} persistent entries)');
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final validMemoryEntries = _memoryCache.values.where((item) => 
      item.expiresAt.isAfter(now)
    ).length;
    
    return {
      'memory_total': _memoryCache.length,
      'memory_valid': validMemoryEntries,
      'memory_expired': _memoryCache.length - validMemoryEntries,
      'pending_requests': _pendingRequests.length,
      'max_memory_size': _maxMemoryCacheSize,
    };
  }

  /// Check if cache entry exists and is valid
  bool isValid(String key) {
    final item = _memoryCache[key];
    if (item == null) return false;
    
    final now = DateTime.now();
    return item.expiresAt.isAfter(now);
  }

  // Private methods

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  T? _getFromMemory<T>(String key) {
    final item = _memoryCache[key];
    if (item == null) return null;
    
    final now = DateTime.now();
    if (item.expiresAt.isBefore(now)) {
      _memoryCache.remove(key);
      return null;
    }
    
    return item.data as T?;
  }

  Future<T?> _getFromPersistent<T>(String key, T Function(Map<String, dynamic>)? fromJson) async {
    if (_prefs == null || fromJson == null) return null;
    
    try {
      final expiresAtStr = _prefs!.getString('${_persistentPrefix}${key}_expires');
      if (expiresAtStr == null) return null;
      
      final expiresAt = DateTime.parse(expiresAtStr);
      final now = DateTime.now();
      
      if (expiresAt.isBefore(now)) {
        await _prefs!.remove('$_persistentPrefix$key');
        await _prefs!.remove('${_persistentPrefix}${key}_expires');
        return null;
      }
      
      final dataStr = _prefs!.getString('$_persistentPrefix$key');
      if (dataStr == null) return null;
      
      final dataMap = json.decode(dataStr) as Map<String, dynamic>;
      return fromJson(dataMap);
    } catch (e) {
      if (kDebugMode) print('⚠️ Error reading persistent cache for $key: $e');
      return null;
    }
  }

  void _storeInMemory<T>(String key, T data, Duration ttl) {
    // Implement LRU eviction if cache is full
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      _evictLeastRecentlyUsed();
    }
    
    final expiresAt = DateTime.now().add(ttl);
    _memoryCache[key] = _CacheItem(data, expiresAt);
  }

  Future<void> _storeToPersistent<T>(
    String key, 
    T data, 
    Map<String, dynamic> Function(T) toJson,
    Duration ttl
  ) async {
    if (_prefs == null) return;
    
    try {
      final dataMap = toJson(data);
      final dataStr = json.encode(dataMap);
      final expiresAt = DateTime.now().add(ttl);
      
      await _prefs!.setString('$_persistentPrefix$key', dataStr);
      await _prefs!.setString('${_persistentPrefix}${key}_expires', expiresAt.toIso8601String());
    } catch (e) {
      if (kDebugMode) print('⚠️ Error storing persistent cache for $key: $e');
    }
  }

  Future<T> _executeFallback<T>(String key, Future<T> Function() fallback) async {
    try {
      final result = await fallback();
      return result;
    } catch (e) {
      if (kDebugMode) print('❌ Fallback function failed for $key: $e');
      rethrow;
    }
  }

  void _evictLeastRecentlyUsed() {
    if (_memoryCache.isEmpty) return;
    
    // Find the oldest entry
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _memoryCache.entries) {
      if (oldestTime == null || entry.value.expiresAt.isBefore(oldestTime)) {
        oldestTime = entry.value.expiresAt;
        oldestKey = entry.key;
      }
    }
    
    if (oldestKey != null) {
      _memoryCache.remove(oldestKey);
      if (kDebugMode) print('🗑️ LRU evicted: $oldestKey');
    }
  }

  void _startCleanupTimer() {
    createScopedPeriodicTimer(
      key: 'cache_cleanup',
      interval: const Duration(minutes: 5),
      callback: (_) => _cleanupExpiredEntries(),
    );
  }

  void _cleanupExpiredEntries() {
    final now = DateTime.now();
    final expiredKeys = _memoryCache.entries
        .where((entry) => entry.value.expiresAt.isBefore(now))
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredKeys) {
      _memoryCache.remove(key);
    }
    
    if (expiredKeys.isNotEmpty && kDebugMode) {
      print('🧹 Cleanup: removed ${expiredKeys.length} expired entries');
    }
  }

  void dispose() {
    disposeScopedTimers();
    _memoryCache.clear();
    _pendingRequests.clear();
  }
}

/// Internal cache item with TTL
class _CacheItem {
  final dynamic data;
  final DateTime expiresAt;
  
  _CacheItem(this.data, this.expiresAt);
}

/// Cache configuration presets for different data types
class CacheConfig {
  // Employee data - long-lived, changes infrequently
  static const Duration employeeDataTtl = Duration(hours: 2);
  
  // Leave data - medium-lived, can change during approval process
  static const Duration leaveDataTtl = Duration(minutes: 15);
  
  // Attendance data - short-lived for today, longer for history
  static const Duration attendanceTodayTtl = Duration(minutes: 2);
  static const Duration attendanceHistoryTtl = Duration(minutes: 30);
  
  // System data - very long-lived
  static const Duration systemDataTtl = Duration(hours: 24);
}

/// Retry configuration with exponential backoff
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 10),
  });

  static const RetryConfig standard = RetryConfig();
  static const RetryConfig aggressive = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(milliseconds: 200),
    backoffMultiplier: 1.5,
    maxDelay: Duration(seconds: 5),
  );
}

/// Network request utilities with retry and exponential backoff
class NetworkUtils {
  static Future<T> withRetry<T>({
    required Future<T> Function() operation,
    RetryConfig config = RetryConfig.standard,
    bool Function(Object error)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = config.initialDelay;

    while (attempt < config.maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        if (attempt >= config.maxAttempts || 
            (shouldRetry != null && !shouldRetry(e))) {
          rethrow;
        }
        
        if (kDebugMode) print('⚠️ Retry attempt $attempt/${config.maxAttempts} after ${delay.inMilliseconds}ms: $e');
        
        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * config.backoffMultiplier).round()
        );
        if (delay > config.maxDelay) {
          delay = config.maxDelay;
        }
      }
    }
    
    throw Exception('Max retry attempts exceeded');
  }
}