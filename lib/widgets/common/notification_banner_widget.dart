import 'package:flutter/material.dart';
import '../../utils/responsive_utils.dart';

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
      alignment: Alignment.center,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _getBannerColor(),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: _getBannerColor().withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Row(
        children: [
          _getIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: ResponsiveUtils.getTextStyle(
                context,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Color _getBannerColor() {
    switch (type) {
      case BannerType.success:
        return const Color(0xFF4CAF50);
      case BannerType.error:
        return const Color(0xFFF44336);
      case BannerType.warning:
        return const Color(0xFFFF9800);
      case BannerType.info:
        return const Color(0xFF2196F3);
    }
  }

  Widget _getIcon() {
    IconData iconData;
    switch (type) {
      case BannerType.success:
        iconData = Icons.check_circle_outline;
        break;
      case BannerType.error:
        iconData = Icons.error_outline;
        break;
      case BannerType.warning:
        iconData = Icons.warning_amber_outlined;
        break;
      case BannerType.info:
        iconData = Icons.info_outline;
        break;
    }

    return Icon(iconData, color: Colors.white, size: 24);
  }
}

enum BannerType { success, error, warning, info }

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

    if (duration != null) {
      Future.delayed(duration, () {
        if (mounted) {
          hideBanner();
        }
      });
    }
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
