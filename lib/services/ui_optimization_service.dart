import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

/// UI optimization service for efficient rendering and state management
/// Provides intelligent widget rebuilding, performance monitoring, and memory management
class UIOptimizationService {
  static final UIOptimizationService _instance =
      UIOptimizationService._internal();
  static UIOptimizationService get instance => _instance;
  UIOptimizationService._internal();

  // Performance tracking
  int _totalRebuilds = 0;
  int _preventedRebuilds = 0;
  final Map<String, int> _componentRebuilds = {};
  final Map<String, DateTime> _lastRebuildTime = {};

  // Rebuild throttling
  final Map<String, Timer> _rebuildThrottlers = {};
  final Map<String, VoidCallback> _pendingCallbacks = {};

  // Memory management
  final Set<String> _activeComponents = {};
  final Map<String, WeakReference<StatefulWidget>> _componentReferences = {};

  static const Duration _defaultThrottleDuration = Duration(
    milliseconds: 16,
  ); // 60 FPS

  /// Throttled setState that prevents excessive rebuilds
  void throttledSetState({
    required String componentKey,
    required VoidCallback callback,
    Duration? throttleDuration,
    bool forceUpdate = false,
  }) {
    final duration = throttleDuration ?? _defaultThrottleDuration;

    // Track component activity
    _activeComponents.add(componentKey);

    if (forceUpdate || !_rebuildThrottlers.containsKey(componentKey)) {
      _executeCallback(componentKey, callback);

      // Set up throttle timer
      _rebuildThrottlers[componentKey]?.cancel();
      _rebuildThrottlers[componentKey] = Timer(duration, () {
        _rebuildThrottlers.remove(componentKey);

        // Execute any pending callback
        final pendingCallback = _pendingCallbacks.remove(componentKey);
        if (pendingCallback != null) {
          _executeCallback(componentKey, pendingCallback);
        }
      });
    } else {
      // Store the callback for later execution
      _pendingCallbacks[componentKey] = callback;
      _preventedRebuilds++;

      if (kDebugMode) {
        if (kDebugMode) {
          print(
            '⏳ Throttled rebuild for $componentKey (saved $_preventedRebuilds rebuilds)',
          );
        }
      }
    }
  }

  void _executeCallback(String componentKey, VoidCallback callback) {
    _totalRebuilds++;
    _componentRebuilds[componentKey] =
        (_componentRebuilds[componentKey] ?? 0) + 1;
    _lastRebuildTime[componentKey] = DateTime.now();

    // Execute on next frame to avoid build-during-build errors
    SchedulerBinding.instance.addPostFrameCallback((_) {
      try {
        callback();
      } catch (e) {
        if (kDebugMode) {
          if (kDebugMode) {
            print('❌ Error in throttled callback for $componentKey: $e');
          }
        }
      }
    });
  }

  /// Smart Consumer wrapper that optimizes rebuild frequency
  Widget optimizedConsumer<T extends ChangeNotifier>({
    required Widget Function(BuildContext context, T provider, Widget? child)
    builder,
    required String componentKey,
    Widget? child,
    bool Function(T previous, T current)? shouldRebuild,
    Duration? throttleDuration,
  }) {
    return Consumer<T>(
      builder: (context, provider, child) {
        // Register component
        _activeComponents.add(componentKey);

        // Custom shouldRebuild logic
        if (shouldRebuild != null) {
          // This would require a custom implementation of Consumer
          // For now, we'll use standard Consumer with optimization notes
        }

        return _OptimizedBuilder(
          key: ValueKey(componentKey),
          componentKey: componentKey,
          builder: () => builder(context, provider, child),
          throttleDuration: throttleDuration,
        );
      },
      child: child,
    );
  }

  /// Batch multiple setState operations
  void batchSetState({
    required Map<String, VoidCallback> operations,
    Duration? delay,
  }) {
    final batchDelay = delay ?? const Duration(milliseconds: 16);

    Timer(batchDelay, () {
      for (final entry in operations.entries) {
        throttledSetState(
          componentKey: entry.key,
          callback: entry.value,
          forceUpdate: true,
        );
      }
    });
  }

  /// Debounced operation execution
  void debouncedOperation({
    required String operationKey,
    required VoidCallback operation,
    Duration delay = const Duration(milliseconds: 300),
  }) {
    _rebuildThrottlers[operationKey]?.cancel();
    _rebuildThrottlers[operationKey] = Timer(delay, () {
      operation();
      _rebuildThrottlers.remove(operationKey);
    });
  }

  /// Register component for memory tracking
  void registerComponent(String componentKey, StatefulWidget component) {
    _componentReferences[componentKey] = WeakReference(component);
    _activeComponents.add(componentKey);
  }

  /// Unregister component and cleanup resources
  void unregisterComponent(String componentKey) {
    _activeComponents.remove(componentKey);
    _componentReferences.remove(componentKey);
    _rebuildThrottlers[componentKey]?.cancel();
    _rebuildThrottlers.remove(componentKey);
    _pendingCallbacks.remove(componentKey);
    _componentRebuilds.remove(componentKey);
    _lastRebuildTime.remove(componentKey);
  }

  /// Get component performance statistics
  Map<String, dynamic> getComponentStats(String componentKey) {
    final rebuilds = _componentRebuilds[componentKey] ?? 0;
    final lastRebuild = _lastRebuildTime[componentKey];
    final isActive = _activeComponents.contains(componentKey);
    final hasThrottler = _rebuildThrottlers.containsKey(componentKey);

    return {
      'component_key': componentKey,
      'rebuilds': rebuilds,
      'last_rebuild': lastRebuild?.toIso8601String(),
      'is_active': isActive,
      'has_throttler': hasThrottler,
      'rebuild_frequency': rebuilds > 0 && lastRebuild != null
          ? rebuilds /
                DateTime.now()
                    .difference(lastRebuild)
                    .inMinutes
                    .clamp(1, double.infinity)
          : 0.0,
    };
  }

  /// Get overall UI performance statistics
  Map<String, dynamic> getUIPerformanceStats() {
    final activeComponentCount = _activeComponents.length;
    final totalComponents = _componentReferences.length;
    final averageRebuilds = _componentRebuilds.isNotEmpty
        ? _componentRebuilds.values.reduce((a, b) => a + b) /
              _componentRebuilds.length
        : 0.0;

    final rebuildSavings = _totalRebuilds > 0
        ? _preventedRebuilds / (_totalRebuilds + _preventedRebuilds)
        : 0.0;

    return {
      'total_rebuilds': _totalRebuilds,
      'prevented_rebuilds': _preventedRebuilds,
      'rebuild_savings_percentage': rebuildSavings * 100,
      'active_components': activeComponentCount,
      'total_components': totalComponents,
      'average_rebuilds_per_component': averageRebuilds,
      'components_with_throttlers': _rebuildThrottlers.length,
      'pending_operations': _pendingCallbacks.length,
      'most_active_components': _getMostActiveComponents(),
    };
  }

  List<Map<String, dynamic>> _getMostActiveComponents() {
    final sortedComponents = _componentRebuilds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedComponents
        .take(5)
        .map(
          (entry) => {
            'component_key': entry.key,
            'rebuilds': entry.value,
            'last_rebuild': _lastRebuildTime[entry.key]?.toIso8601String(),
          },
        )
        .toList();
  }

  /// Cleanup expired components and free memory
  void cleanup() {
    final now = DateTime.now();
    final expiredComponents = <String>[];

    // Find components that haven't been rebuilt in the last 5 minutes
    for (final entry in _lastRebuildTime.entries) {
      if (now.difference(entry.value).inMinutes > 5) {
        expiredComponents.add(entry.key);
      }
    }

    // Clean up expired components
    for (final key in expiredComponents) {
      if (!_activeComponents.contains(key)) {
        unregisterComponent(key);
      }
    }

    // Clean up weak references
    _componentReferences.removeWhere((key, ref) => ref.target == null);

    if (kDebugMode && expiredComponents.isNotEmpty) {
      if (kDebugMode) {
        print(
          '🧹 Cleaned up ${expiredComponents.length} expired UI components',
        );
      }
    }
  }

  /// Clear all performance statistics
  void clearStats() {
    _totalRebuilds = 0;
    _preventedRebuilds = 0;
    _componentRebuilds.clear();
    _lastRebuildTime.clear();
  }

  /// Dispose all resources
  void dispose() {
    for (final timer in _rebuildThrottlers.values) {
      timer.cancel();
    }
    _rebuildThrottlers.clear();
    _pendingCallbacks.clear();
    _activeComponents.clear();
    _componentReferences.clear();
    clearStats();
  }
}

/// Optimized builder widget that manages rebuild throttling
class _OptimizedBuilder extends StatefulWidget {
  final String componentKey;
  final Widget Function() builder;
  final Duration? throttleDuration;

  const _OptimizedBuilder({
    super.key,
    required this.componentKey,
    required this.builder,
    this.throttleDuration,
  });

  @override
  State<_OptimizedBuilder> createState() => _OptimizedBuilderState();
}

class _OptimizedBuilderState extends State<_OptimizedBuilder> {
  Widget? _cachedWidget;
  DateTime? _lastBuildTime;

  @override
  void initState() {
    super.initState();
    UIOptimizationService.instance.registerComponent(
      widget.componentKey,
      widget,
    );
  }

  @override
  void dispose() {
    UIOptimizationService.instance.unregisterComponent(widget.componentKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final throttleDuration =
        widget.throttleDuration ?? const Duration(milliseconds: 16);

    // Use cached widget if within throttle period
    if (_cachedWidget != null && _lastBuildTime != null) {
      if (now.difference(_lastBuildTime!).compareTo(throttleDuration) < 0) {
        return _cachedWidget!;
      }
    }

    // Build new widget
    _cachedWidget = widget.builder();
    _lastBuildTime = now;

    return _cachedWidget!;
  }
}

/// Mixin for easy UI optimization integration
mixin UIOptimizationMixin<T extends StatefulWidget> on State<T> {
  late final String _componentKey;

  @override
  void initState() {
    super.initState();
    _componentKey = '${T.toString()}_$hashCode';
    UIOptimizationService.instance.registerComponent(_componentKey, widget);
  }

  @override
  void dispose() {
    UIOptimizationService.instance.unregisterComponent(_componentKey);
    super.dispose();
  }

  /// Optimized setState with throttling
  void optimizedSetState(VoidCallback fn, {Duration? throttleDuration}) {
    UIOptimizationService.instance.throttledSetState(
      componentKey: _componentKey,
      callback: () => setState(fn),
      throttleDuration: throttleDuration,
    );
  }

  /// Debounced operation
  void debouncedOperation(VoidCallback operation, {Duration? delay}) {
    UIOptimizationService.instance.debouncedOperation(
      operationKey: '${_componentKey}_operation',
      operation: operation,
      delay: delay ?? const Duration(milliseconds: 300),
    );
  }

  /// Get this component's performance stats
  Map<String, dynamic> getComponentStats() {
    return UIOptimizationService.instance.getComponentStats(_componentKey);
  }
}

/// Optimized Consumer wrapper for selective rebuilds
class OptimizedConsumer<T extends ChangeNotifier> extends StatelessWidget {
  final Widget Function(BuildContext context, T provider, Widget? child)
  builder;
  final String componentKey;
  final Widget? child;
  final bool Function(T provider)? shouldRebuild;
  final Duration? throttleDuration;

  const OptimizedConsumer({
    super.key,
    required this.builder,
    required this.componentKey,
    this.child,
    this.shouldRebuild,
    this.throttleDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<T>(
      builder: (context, provider, child) {
        // Check if we should rebuild
        if (shouldRebuild != null && !shouldRebuild!(provider)) {
          // Return a placeholder or cached widget
          return const SizedBox.shrink();
        }

        return _OptimizedBuilder(
          key: ValueKey(componentKey),
          componentKey: componentKey,
          builder: () => builder(context, provider, child),
          throttleDuration: throttleDuration,
        );
      },
      child: child,
    );
  }
}

/// Optimized ListView for better performance with large datasets
class OptimizedListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ScrollController? controller;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;

  const OptimizedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Use RepaintBoundary to isolate list items
        return RepaintBoundary(child: itemBuilder(context, index));
      },
      // Performance optimizations
      cacheExtent: 200.0, // Cache items 200 pixels off-screen
      addAutomaticKeepAlives: false, // Don't keep alive items by default
      addRepaintBoundaries: false, // We're adding them manually
    );
  }
}

/// Optimized AnimatedBuilder for smooth animations
class OptimizedAnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const OptimizedAnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: builder,
        child: child,
      ),
    );
  }
}
