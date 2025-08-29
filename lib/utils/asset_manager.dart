import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/optimized_image.dart';

/// Asset management utility for optimized loading and caching
class AssetManager {
  static final AssetManager _instance = AssetManager._internal();
  factory AssetManager() => _instance;
  AssetManager._internal();

  // Track loaded assets to avoid duplicates
  final Set<String> _loadedAssets = <String>{};

  // Critical assets that should be preloaded
  static const List<String> _criticalAssets = [
    'assets/images/splash_logo.jpeg',
    'assets/icons/icon_1024.png',
  ];

  // Font assets removed - not used

  /// Initialize asset management (call in main.dart)
  static Future<void> initialize(BuildContext context) async {
    debugPrint('AssetManager: Initializing...');

    // Configure image cache for optimal performance
    ImagePreloader.configureImageCache(
      maxCacheSize: 100,
      maxCacheByteSize: 50 << 20, // 50MB
    );

    // Preload critical assets
    await ImagePreloader.preloadCriticalAssets(context);

    debugPrint('AssetManager: Initialization complete');
  }

  /// Check if an asset exists before loading
  static Future<bool> assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      debugPrint('AssetManager: Asset not found - $assetPath');
      return false;
    }
  }

  /// Load asset with validation and error handling
  static Future<ByteData?> loadAsset(String assetPath) async {
    try {
      if (!await assetExists(assetPath)) {
        return null;
      }

      final data = await rootBundle.load(assetPath);
      _instance._loadedAssets.add(assetPath);
      return data;
    } catch (e) {
      debugPrint('AssetManager: Failed to load asset - $assetPath: $e');
      return null;
    }
  }

  /// Get optimized image widget with lazy loading
  static Widget getOptimizedImage({
    required String assetPath,
    double? width,
    double? height,
    BoxFit? fit = BoxFit.contain,
    String? semanticLabel,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return OptimizedImage.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  /// Clean up resources and clear caches
  static void dispose() {
    debugPrint('AssetManager: Disposing resources...');
    ImagePreloader.clearPreloadCache();
    _instance._loadedAssets.clear();
  }

  /// Get memory usage statistics
  static AssetMemoryInfo getMemoryInfo() {
    return AssetMemoryInfo(
      cacheSize: ImagePreloader.getCacheSize(),
      loadedAssetsCount: _instance._loadedAssets.length,
      criticalAssetsLoaded: _criticalAssets.length,
    );
  }

  /// Remove unused font files (for optimization)
  static List<String> getUnusedFontFiles() {
    // Based on font usage analysis, these weights are not used:
    return [
      'assets/fonts/NotoSans-Thin.otf', // FontWeight.w100 - not used
      'assets/fonts/NotoSans-Light.otf', // FontWeight.w300 - not used
      'assets/fonts/NotoSans-DemiLight.otf', // FontWeight.w350 - not used
    ];
  }

  /// Get recommended optimizations
  static AssetOptimizationReport getOptimizationReport() {
    final unusedFonts = getUnusedFontFiles();
    final totalFontSize = _calculateFontSizes();
    final unusedFontSize = _calculateUnusedFontSizes(unusedFonts);

    return AssetOptimizationReport(
      unusedFonts: unusedFonts,
      totalFontSize: totalFontSize,
      unusedFontSize: unusedFontSize,
      potentialSavings: unusedFontSize,
      recommendations: _getOptimizationRecommendations(),
    );
  }

  static int _calculateFontSizes() {
    // Font sizes in bytes (approximate)
    return 396 * 1024 + // NotoSans-Black.otf
        388 * 1024 + // NotoSans-Bold.otf
        388 * 1024 + // NotoSans-DemiLight.otf
        388 * 1024 + // NotoSans-Light.otf
        384 * 1024 + // NotoSans-Medium.otf
        384 * 1024 + // NotoSans-Regular.otf
        392 * 1024; // NotoSans-Thin.otf
  }

  static int _calculateUnusedFontSizes(List<String> unusedFonts) {
    // Approximate sizes for unused fonts
    return 392 * 1024 + // NotoSans-Thin.otf
        388 * 1024 + // NotoSans-Light.otf
        388 * 1024; // NotoSans-DemiLight.otf
  }

  static List<String> _getOptimizationRecommendations() {
    return [
      'Remove unused font weights (Thin, Light, DemiLight) to save ~1.16MB',
      'Convert JPEG splash logo to WebP for better compression',
      'Enable image caching for frequently used assets',
      'Implement lazy loading for non-critical images',
      'Use vector icons instead of multiple PNG sizes where possible',
      'Compress existing PNG icons without quality loss',
    ];
  }
}

/// Memory information for asset management
class AssetMemoryInfo {
  final int cacheSize;
  final int loadedAssetsCount;
  final int criticalAssetsLoaded;

  AssetMemoryInfo({
    required this.cacheSize,
    required this.loadedAssetsCount,
    required this.criticalAssetsLoaded,
  });

  @override
  String toString() {
    return 'AssetMemoryInfo(cacheSize: $cacheSize, loadedAssets: $loadedAssetsCount, criticalAssets: $criticalAssetsLoaded)';
  }
}

/// Asset optimization report
class AssetOptimizationReport {
  final List<String> unusedFonts;
  final int totalFontSize;
  final int unusedFontSize;
  final int potentialSavings;
  final List<String> recommendations;

  AssetOptimizationReport({
    required this.unusedFonts,
    required this.totalFontSize,
    required this.unusedFontSize,
    required this.potentialSavings,
    required this.recommendations,
  });

  /// Get savings as percentage
  double get savingsPercentage => (potentialSavings / totalFontSize) * 100;

  /// Format file size in human readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  String toString() {
    return '''
Asset Optimization Report:
- Total font size: ${formatFileSize(totalFontSize)}
- Unused font size: ${formatFileSize(unusedFontSize)}
- Potential savings: ${formatFileSize(potentialSavings)} (${savingsPercentage.toStringAsFixed(1)}%)
- Unused fonts: ${unusedFonts.length}
- Recommendations: ${recommendations.length}
''';
  }
}
