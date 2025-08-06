import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/ui_optimization_service.dart';

/// Collection of optimized widgets for better performance
library optimized_widgets;

/// Optimized Card widget with intelligent rebuilding
class OptimizedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double? elevation;
  final ShapeBorder? shape;
  final bool enableRepaintBoundary;
  final String? semanticsLabel;

  const OptimizedCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.color,
    this.elevation,
    this.shape,
    this.enableRepaintBoundary = true,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardWidget = Card(
      margin: margin,
      color: color,
      elevation: elevation,
      shape: shape,
      child: padding != null 
          ? Padding(padding: padding!, child: child)
          : child,
    );

    // Wrap with RepaintBoundary for better performance
    if (enableRepaintBoundary) {
      cardWidget = RepaintBoundary(child: cardWidget);
    }

    // Add semantics if provided
    if (semanticsLabel != null) {
      cardWidget = Semantics(
        label: semanticsLabel,
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}

/// Optimized AppBar with reduced rebuilds
class OptimizedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final double? elevation;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final ShapeBorder? shape;
  final IconThemeData? iconTheme;
  final IconThemeData? actionsIconTheme;
  final TextStyle? titleTextStyle;
  final bool centerTitle;
  final double? titleSpacing;
  final double toolbarOpacity;
  final double bottomOpacity;
  final double? leadingWidth;
  final bool? backwardsCompatibility;
  final Widget? flexibleSpace;

  const OptimizedAppBar({
    super.key,
    required this.title,
    this.actions,
    this.backgroundColor,
    this.elevation,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.shape,
    this.iconTheme,
    this.actionsIconTheme,
    this.titleTextStyle,
    this.centerTitle = true,
    this.titleSpacing,
    this.toolbarOpacity = 1.0,
    this.bottomOpacity = 1.0,
    this.leadingWidth,
    this.backwardsCompatibility,
    this.flexibleSpace,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AppBar(
        title: Text(title, style: titleTextStyle),
        actions: actions,
        backgroundColor: backgroundColor,
        elevation: elevation,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        bottom: bottom,
        shape: shape,
        iconTheme: iconTheme,
        actionsIconTheme: actionsIconTheme,
        centerTitle: centerTitle,
        titleSpacing: titleSpacing,
        toolbarOpacity: toolbarOpacity,
        bottomOpacity: bottomOpacity,
        leadingWidth: leadingWidth,
        flexibleSpace: flexibleSpace,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Optimized button with reduced rebuilds and better performance
class OptimizedButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final bool enabled;
  final Duration? debounceDuration;
  final String componentKey;

  const OptimizedButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.componentKey,
    this.style,
    this.enabled = true,
    this.debounceDuration,
  });

  @override
  State<OptimizedButton> createState() => _OptimizedButtonState();
}

class _OptimizedButtonState extends State<OptimizedButton> with UIOptimizationMixin {
  bool _isPressed = false;

  void _handlePressed() {
    if (!widget.enabled || widget.onPressed == null) return;

    setState(() => _isPressed = true);

    if (widget.debounceDuration != null) {
      // Use debounced operation
      debouncedOperation(
        widget.onPressed!,
        delay: widget.debounceDuration,
      );
    } else {
      widget.onPressed!();
    }

    // Reset pressed state after a short delay
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        optimizedSetState(() => _isPressed = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ElevatedButton(
        onPressed: widget.enabled ? _handlePressed : null,
        style: widget.style?.copyWith(
          overlayColor: _isPressed 
              ? WidgetStateProperty.all(Colors.black.withValues(alpha: 0.1))
              : null,
        ) ?? (widget.style),
        child: widget.child,
      ),
    );
  }
}

/// Optimized text widget with caching
class OptimizedText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  final bool enableCaching;

  const OptimizedText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.enableCaching = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget textWidget = Text(
      data,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );

    // Use RepaintBoundary for text that doesn't change often
    if (enableCaching) {
      textWidget = RepaintBoundary(child: textWidget);
    }

    return textWidget;
  }
}

/// Optimized Icon with reduced rebuilds
class OptimizedIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final TextDirection? textDirection;
  final bool enableCaching;

  const OptimizedIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.textDirection,
    this.enableCaching = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(
      icon,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
      textDirection: textDirection,
    );

    if (enableCaching) {
      iconWidget = RepaintBoundary(child: iconWidget);
    }

    return iconWidget;
  }
}

/// Optimized Container with intelligent rebuilding
class OptimizedContainer extends StatelessWidget {
  final Widget? child;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Decoration? decoration;
  final Decoration? foregroundDecoration;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? margin;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;
  final Clip clipBehavior;
  final bool enableRepaintBoundary;

  const OptimizedContainer({
    super.key,
    this.child,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.foregroundDecoration,
    this.width,
    this.height,
    this.constraints,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.clipBehavior = Clip.none,
    this.enableRepaintBoundary = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget containerWidget = Container(
      alignment: alignment,
      padding: padding,
      color: color,
      decoration: decoration,
      foregroundDecoration: foregroundDecoration,
      width: width,
      height: height,
      constraints: constraints,
      margin: margin,
      transform: transform,
      transformAlignment: transformAlignment,
      clipBehavior: clipBehavior,
      child: child,
    );

    if (enableRepaintBoundary) {
      containerWidget = RepaintBoundary(child: containerWidget);
    }

    return containerWidget;
  }
}

/// Optimized loading indicator
class OptimizedLoadingIndicator extends StatelessWidget {
  final Color? color;
  final double? strokeWidth;
  final String? message;
  final bool showMessage;

  const OptimizedLoadingIndicator({
    super.key,
    this.color,
    this.strokeWidth,
    this.message,
    this.showMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: color,
              strokeWidth: strokeWidth ?? 4.0,
            ),
            if (showMessage && message != null) ...[
              const SizedBox(height: 16),
              OptimizedText(
                message!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Optimized divider with reduced rebuilds
class OptimizedDivider extends StatelessWidget {
  final double? height;
  final double? thickness;
  final double? indent;
  final double? endIndent;
  final Color? color;

  const OptimizedDivider({
    super.key,
    this.height,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Divider(
        height: height,
        thickness: thickness,
        indent: indent,
        endIndent: endIndent,
        color: color,
      ),
    );
  }
}

/// Mixin for widgets that need performance optimization
mixin OptimizedWidgetMixin on Widget {
  /// Whether this widget should use RepaintBoundary
  bool get shouldUseRepaintBoundary => true;

  /// Whether this widget content changes frequently
  bool get isFrequentlyChanging => false;

  /// Custom rebuild condition
  bool shouldRebuild(covariant Widget oldWidget) => true;

  /// Wrap widget with performance optimizations
  Widget buildOptimized(BuildContext context, Widget child) {
    if (shouldUseRepaintBoundary && !isFrequentlyChanging) {
      child = RepaintBoundary(child: child);
    }

    return child;
  }
}

/// Helper class for creating optimized widgets
class OptimizedWidgetBuilder {
  /// Create an optimized ListView
  static Widget buildOptimizedListView({
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
    ScrollController? controller,
    ScrollPhysics? physics,
    EdgeInsets? padding,
    bool shrinkWrap = false,
    double? cacheExtent,
  }) {
    return OptimizedListView(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          key: ValueKey('list_item_$index'),
          child: itemBuilder(context, index),
        );
      },
      controller: controller,
      physics: physics,
      padding: padding,
      shrinkWrap: shrinkWrap,
    );
  }

  /// Create an optimized Column
  static Widget buildOptimizedColumn({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.max,
    bool enableRepaintBoundary = false,
  }) {
    Widget column = Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children,
    );

    if (enableRepaintBoundary) {
      column = RepaintBoundary(child: column);
    }

    return column;
  }

  /// Create an optimized Row
  static Widget buildOptimizedRow({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.max,
    bool enableRepaintBoundary = false,
  }) {
    Widget row = Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children,
    );

    if (enableRepaintBoundary) {
      row = RepaintBoundary(child: row);
    }

    return row;
  }
}

/// Performance constants for UI optimization
class UIPerformanceConstants {
  // Throttling durations
  static const Duration fastThrottle = Duration(milliseconds: 16); // 60 FPS
  static const Duration mediumThrottle = Duration(milliseconds: 100);
  static const Duration slowThrottle = Duration(milliseconds: 500);

  // Debounce durations
  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration buttonDebounce = Duration(milliseconds: 500);
  static const Duration formDebounce = Duration(milliseconds: 150);

  // Cache settings
  static const int maxCachedWidgets = 50;
  static const Duration widgetCacheTtl = Duration(minutes: 5);

  // List view settings
  static const double defaultCacheExtent = 200.0;
  static const int defaultMaxListItems = 100;
}