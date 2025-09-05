import 'package:flutter/material.dart';

/// Optimized image loading widget with caching, error handling, and progressive loading
class OptimizedImage extends StatefulWidget {
  final String? assetPath;
  final String? networkUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final String? semanticLabel;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final bool enableMemoryCache;
  final FilterQuality filterQuality;

  const OptimizedImage.asset(
    this.assetPath, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.semanticLabel,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.enableMemoryCache = true,
    this.filterQuality = FilterQuality.medium,
  }) : networkUrl = null;

  const OptimizedImage.network(
    this.networkUrl, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.semanticLabel,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.enableMemoryCache = true,
    this.filterQuality = FilterQuality.medium,
  }) : assetPath = null;

  @override
  State<OptimizedImage> createState() => _OptimizedImageState();
}

class _OptimizedImageState extends State<OptimizedImage> {
  bool _hasError = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set initial loading state for network images
    if (widget.networkUrl != null) {
      _isLoading = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Asset image handling
    if (widget.assetPath != null) {
      return _buildAssetImage();
    }

    // Network image handling
    if (widget.networkUrl != null) {
      return _buildNetworkImage();
    }

    // Fallback if no image source provided
    return _buildErrorWidget();
  }

  Widget _buildAssetImage() {
    return AnimatedSwitcher(
      duration: widget.fadeInDuration,
      child: _hasError
          ? _buildErrorWidget()
          : Image.asset(
              widget.assetPath!,
              key: ValueKey(widget.assetPath),
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              semanticLabel: widget.semanticLabel,
              filterQuality: widget.filterQuality,
              errorBuilder: (context, error, stackTrace) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _hasError = true;
                    });
                  }
                });
                return _buildErrorWidget();
              },
            ),
    );
  }

  Widget _buildNetworkImage() {
    return AnimatedSwitcher(
      duration: widget.fadeInDuration,
      child: _hasError
          ? _buildErrorWidget()
          : Image.network(
              widget.networkUrl!,
              key: ValueKey(widget.networkUrl),
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              semanticLabel: widget.semanticLabel,
              filterQuality: widget.filterQuality,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  });
                  return child;
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_isLoading) {
                    setState(() {
                      _isLoading = true;
                    });
                  }
                });
                return _buildPlaceholder();
              },
              errorBuilder: (context, error, stackTrace) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _hasError = true;
                      _isLoading = false;
                    });
                  }
                });
                return _buildErrorWidget();
              },
            ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: (widget.width != null && widget.width! < 100) ? 24 : 48,
            color: Colors.grey[400],
          ),
          if (widget.width == null || widget.width! > 100) ...[
            const SizedBox(height: 8),
            Text(
              '이미지를 불러올 수 없습니다',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'NotoSans'),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Cached asset image widget for frequently used images
class CachedAssetImage extends StatelessWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final String? semanticLabel;

  const CachedAssetImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedImage.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      enableMemoryCache: true,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Preloader for critical images
class ImagePreloader {
  static final Set<String> _preloadedAssets = <String>{};

  /// Preload critical assets (splash, icons, etc.)
  static Future<void> preloadCriticalAssets(BuildContext context) async {
    final criticalAssets = ['assets/images/splash_logo.jpeg', 'assets/icons/icon_1024.png'];

    for (final asset in criticalAssets) {
      if (!_preloadedAssets.contains(asset)) {
        try {
          await precacheImage(AssetImage(asset), context);
          _preloadedAssets.add(asset);
        } catch (e) {
          debugPrint('Failed to preload asset: $asset - $e');
        }
      }
    }
  }

  /// Clear preloaded cache when memory pressure is detected
  static void clearPreloadCache() {
    _preloadedAssets.clear();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Get memory usage of image cache
  static int getCacheSize() {
    return PaintingBinding.instance.imageCache.currentSize;
  }

  /// Configure image cache limits
  static void configureImageCache({
    int maxCacheSize = 100,
    int maxCacheByteSize = 50 << 20, // 50MB
  }) {
    PaintingBinding.instance.imageCache.maximumSize = maxCacheSize;
    PaintingBinding.instance.imageCache.maximumSizeBytes = maxCacheByteSize;
  }
}
