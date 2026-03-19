import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';

/// 알림 배너 위젯
/// 성공, 에러, 정보 메시지를 표시하는 재사용 가능한 컴포넌트
class NotificationBannerWidget extends StatelessWidget {
  final String? message;
  final BannerType type;
  final Duration displayDuration;
  final VoidCallback? onDismiss;

  const NotificationBannerWidget({
    super.key,
    this.message,
    this.type = BannerType.info,
    this.displayDuration = const Duration(seconds: 2),
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      color: _getBannerColor(),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Center(
        child: Text(
          message!,
          textAlign: TextAlign.center,
          style: AppTextStyles.sectionSubtitle(context).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getBannerColor() {
    switch (type) {
      case BannerType.success:
      case BannerType.info:
        return AppColors.primary;
      case BannerType.error:
        return AppColors.error;
      case BannerType.warning:
        return AppColors.warning;
    }
  }
}

enum BannerType { success, error, warning, info }

/// 글로벌 배너 — 어디서든 호출 가능
/// AppBanner.show(context, '메시지', type: BannerType.success);
class AppBanner {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context,
    String message, {
    BannerType type = BannerType.info,
    Duration duration = const Duration(seconds: 1),
  }) {
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);
    final topPadding = MediaQuery.of(context).padding.top +
        kToolbarHeight; // 앱바 아래 위치

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AnimatedBannerOverlay(
        message: message,
        type: type,
        topOffset: topPadding,
        duration: duration,
        onDismiss: () {
          entry.remove();
          if (_currentEntry == entry) _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _AnimatedBannerOverlay extends StatefulWidget {
  final String message;
  final BannerType type;
  final double topOffset;
  final Duration duration;
  final VoidCallback onDismiss;

  const _AnimatedBannerOverlay({
    required this.message,
    required this.type,
    required this.topOffset,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_AnimatedBannerOverlay> createState() => _AnimatedBannerOverlayState();
}

class _AnimatedBannerOverlayState extends State<_AnimatedBannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _bgColor() {
    switch (widget.type) {
      case BannerType.success:
      case BannerType.info:
        return AppColors.primary;
      case BannerType.error:
        return AppColors.error;
      case BannerType.warning:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topOffset,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            color: _bgColor(),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Center(
              child: Text(
                widget.message,
                style: AppTextStyles.sectionSubtitle(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 배너 컨트롤러 믹스인
/// StatefulWidget에서 배너를 쉽게 관리할 수 있도록 하는 믹스인
mixin BannerControllerMixin<T extends StatefulWidget> on State<T> {
  String? _bannerMessage;
  BannerType _bannerType = BannerType.info;

  String? get bannerMessage => _bannerMessage;
  BannerType get bannerType => _bannerType;

  void showBanner(
    String message, {
    BannerType type = BannerType.info,
    Duration? duration,
  }) {
    setState(() {
      _bannerMessage = message;
      _bannerType = type;
    });

    final effectiveDuration = duration ?? const Duration(seconds: 1);
    Future.delayed(effectiveDuration, () {
      if (mounted) {
        hideBanner();
      }
    });
  }

  void hideBanner() {
    setState(() {
      _bannerMessage = null;
    });
  }

  Widget buildBanner() {
    return NotificationBannerWidget(
      message: _bannerMessage,
      type: _bannerType,
      onDismiss: hideBanner,
    );
  }
}
