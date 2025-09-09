import 'dart:async';
import 'package:flutter/foundation.dart';

/// Centralized timer management service for efficient timer operations
/// Prevents memory leaks, reduces battery usage, and optimizes timer creation
class TimerManager {
  static final TimerManager _instance = TimerManager._internal();
  static TimerManager get instance => _instance;
  TimerManager._internal();

  // Active timers registry
  final Map<String, Timer> _activeTimers = {};

  // Timer statistics for monitoring
  int _totalTimersCreated = 0;
  int _totalTimersDestroyed = 0;

  /// Create or reuse a periodic timer
  /// Returns existing timer if one with the same key exists and is active
  Timer createPeriodicTimer({
    required String key,
    required Duration interval,
    required void Function(Timer) callback,
    bool forceRestart = false,
  }) {
    // Cancel existing timer if force restart is requested
    if (forceRestart && _activeTimers.containsKey(key)) {
      cancelTimer(key);
    }

    // Return existing timer if already active
    if (_activeTimers.containsKey(key)) {
      final existingTimer = _activeTimers[key]!;
      if (existingTimer.isActive) {
        if (kDebugMode) print('🔄 Reusing existing timer: $key');
        return existingTimer;
      } else {
        // Remove inactive timer
        _activeTimers.remove(key);
        _totalTimersDestroyed++;
      }
    }

    // Create new periodic timer
    final timer = Timer.periodic(interval, callback);
    _activeTimers[key] = timer;
    _totalTimersCreated++;

    if (kDebugMode)
      if (kDebugMode) {
        print('✅ Created periodic timer: $key (${interval.inMilliseconds}ms)');
      }
    return timer;
  }

  /// Create a one-time timer
  Timer createTimer({
    required String key,
    required Duration delay,
    required void Function() callback,
    bool forceRestart = false,
  }) {
    // Cancel existing timer if force restart is requested
    if (forceRestart && _activeTimers.containsKey(key)) {
      cancelTimer(key);
    }

    // Return existing timer if already active (rare case for one-time timers)
    if (_activeTimers.containsKey(key)) {
      final existingTimer = _activeTimers[key]!;
      if (existingTimer.isActive) {
        if (kDebugMode) print('🔄 Existing one-time timer still active: $key');
        return existingTimer;
      } else {
        _activeTimers.remove(key);
        _totalTimersDestroyed++;
      }
    }

    // Create new timer with auto-cleanup
    final timer = Timer(delay, () {
      callback();
      // Auto-cleanup one-time timers
      _activeTimers.remove(key);
      _totalTimersDestroyed++;
    });

    _activeTimers[key] = timer;
    _totalTimersCreated++;

    if (kDebugMode)
      if (kDebugMode) {
        print('✅ Created one-time timer: $key (${delay.inMilliseconds}ms)');
      }
    return timer;
  }

  /// Cancel a specific timer
  bool cancelTimer(String key) {
    final timer = _activeTimers.remove(key);
    if (timer != null) {
      timer.cancel();
      _totalTimersDestroyed++;
      if (kDebugMode) print('❌ Cancelled timer: $key');
      return true;
    }
    return false;
  }

  /// Cancel multiple timers by prefix
  int cancelTimersByPrefix(String prefix) {
    final keysToCancel = _activeTimers.keys
        .where((key) => key.startsWith(prefix))
        .toList();

    int cancelledCount = 0;
    for (final key in keysToCancel) {
      if (cancelTimer(key)) {
        cancelledCount++;
      }
    }

    if (cancelledCount > 0 && kDebugMode) {
      if (kDebugMode) {
        print('❌ Cancelled $cancelledCount timers with prefix: $prefix');
      }
    }

    return cancelledCount;
  }

  /// Cancel all active timers
  int cancelAllTimers() {
    final count = _activeTimers.length;

    for (final timer in _activeTimers.values) {
      timer.cancel();
    }

    _activeTimers.clear();
    _totalTimersDestroyed += count;

    if (count > 0 && kDebugMode) {
      if (kDebugMode) print('❌ Cancelled all timers: $count timers');
    }

    return count;
  }

  /// Check if a timer is active
  bool isTimerActive(String key) {
    final timer = _activeTimers[key];
    if (timer == null) return false;

    if (!timer.isActive) {
      // Clean up inactive timer
      _activeTimers.remove(key);
      _totalTimersDestroyed++;
      return false;
    }

    return true;
  }

  /// Get all active timer keys
  List<String> getActiveTimerKeys() {
    // Clean up inactive timers first
    final keysToRemove = <String>[];

    for (final entry in _activeTimers.entries) {
      if (!entry.value.isActive) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _activeTimers.remove(key);
      _totalTimersDestroyed++;
    }

    return List.unmodifiable(_activeTimers.keys);
  }

  /// Get timer statistics for monitoring
  TimerStats getStats() {
    // Clean up inactive timers first
    final inactiveKeys = <String>[];

    for (final entry in _activeTimers.entries) {
      if (!entry.value.isActive) {
        inactiveKeys.add(entry.key);
      }
    }

    for (final key in inactiveKeys) {
      _activeTimers.remove(key);
      _totalTimersDestroyed++;
    }

    return TimerStats(
      activeTimers: _activeTimers.length,
      totalCreated: _totalTimersCreated,
      totalDestroyed: _totalTimersDestroyed,
      activeTimerKeys: List.unmodifiable(_activeTimers.keys),
    );
  }

  /// Create a debounced timer that delays execution
  /// Automatically cancels previous timer if called again within the delay
  void debounce({
    required String key,
    required Duration delay,
    required void Function() callback,
  }) {
    // Cancel existing debounce timer
    cancelTimer(key);

    // Create new debounce timer
    createTimer(key: key, delay: delay, callback: callback);
  }

  /// Create a throttled timer that limits execution frequency
  /// Executes immediately if no timer is active, otherwise ignores the call
  bool throttle({
    required String key,
    required Duration cooldown,
    required void Function() callback,
  }) {
    if (isTimerActive(key)) {
      if (kDebugMode) print('⏸️ Throttled execution: $key (cooldown active)');
      return false;
    }

    // Execute immediately
    callback();

    // Start cooldown timer
    createTimer(
      key: key,
      delay: cooldown,
      callback: () {
        // Timer auto-cleans up itself
        if (kDebugMode) print('⏰ Throttle cooldown ended: $key');
      },
    );

    return true;
  }

  /// Pause all timers (useful for app backgrounding)
  List<String> pauseAllTimers() {
    final pausedKeys = getActiveTimerKeys();
    cancelAllTimers();

    if (pausedKeys.isNotEmpty && kDebugMode) {
      if (kDebugMode) print('⏸️ Paused ${pausedKeys.length} timers');
    }

    return pausedKeys;
  }

  /// Clean up inactive timers periodically
  void startMaintenanceTimer() {
    createPeriodicTimer(
      key: '__maintenance__',
      interval: const Duration(minutes: 5),
      callback: (_) => _performMaintenance(),
    );
  }

  /// Stop maintenance timer
  void stopMaintenanceTimer() {
    cancelTimer('__maintenance__');
  }

  void _performMaintenance() {
    final stats = getStats(); // This also cleans up inactive timers

    if (kDebugMode) {
      if (kDebugMode) {
        print(
          '🧹 Timer maintenance: ${stats.activeTimers} active, '
          '${stats.totalCreated - stats.totalDestroyed} net created',
        );
      }
    }
  }

  /// Dispose all resources
  void dispose() {
    cancelAllTimers();
    if (kDebugMode) debugPrint('🗑️ TimerManager disposed');
  }
}

/// Timer statistics data class
class TimerStats {
  final int activeTimers;
  final int totalCreated;
  final int totalDestroyed;
  final List<String> activeTimerKeys;

  const TimerStats({
    required this.activeTimers,
    required this.totalCreated,
    required this.totalDestroyed,
    required this.activeTimerKeys,
  });

  int get netTimers => totalCreated - totalDestroyed;

  @override
  String toString() {
    return 'TimerStats(active: $activeTimers, created: $totalCreated, '
        'destroyed: $totalDestroyed, net: $netTimers)';
  }

  Map<String, dynamic> toJson() {
    return {
      'active_timers': activeTimers,
      'total_created': totalCreated,
      'total_destroyed': totalDestroyed,
      'net_timers': netTimers,
      'active_timer_keys': activeTimerKeys,
    };
  }
}

/// Mixin for easy TimerManager integration in providers and widgets
mixin TimerManagementMixin {
  final TimerManager _timerManager = TimerManager.instance;

  /// Create a scoped timer key with object hash
  String _scopedKey(String key) => '${runtimeType.toString()}_${hashCode}_$key';

  /// Create a periodic timer scoped to this object
  Timer createScopedPeriodicTimer({
    required String key,
    required Duration interval,
    required void Function(Timer) callback,
    bool forceRestart = false,
  }) {
    return _timerManager.createPeriodicTimer(
      key: _scopedKey(key),
      interval: interval,
      callback: callback,
      forceRestart: forceRestart,
    );
  }

  /// Create a one-time timer scoped to this object
  Timer createScopedTimer({
    required String key,
    required Duration delay,
    required void Function() callback,
    bool forceRestart = false,
  }) {
    return _timerManager.createTimer(
      key: _scopedKey(key),
      delay: delay,
      callback: callback,
      forceRestart: forceRestart,
    );
  }

  /// Debounce with object scope
  void scopedDebounce({
    required String key,
    required Duration delay,
    required void Function() callback,
  }) {
    _timerManager.debounce(
      key: _scopedKey(key),
      delay: delay,
      callback: callback,
    );
  }

  /// Throttle with object scope
  bool scopedThrottle({
    required String key,
    required Duration cooldown,
    required void Function() callback,
  }) {
    return _timerManager.throttle(
      key: _scopedKey(key),
      cooldown: cooldown,
      callback: callback,
    );
  }

  /// Cancel a scoped timer
  bool cancelScopedTimer(String key) {
    return _timerManager.cancelTimer(_scopedKey(key));
  }

  /// Cancel all timers for this object
  int cancelAllScopedTimers() {
    return _timerManager.cancelTimersByPrefix(
      '${runtimeType.toString()}_$hashCode',
    );
  }

  /// Dispose scoped timers (call from dispose method)
  void disposeScopedTimers() {
    final cancelledCount = cancelAllScopedTimers();
    if (kDebugMode && cancelledCount > 0) {
      if (kDebugMode) {
        print(
          '🗑️ Disposed $cancelledCount scoped timers for ${runtimeType.toString()}',
        );
      }
    }
  }
}
