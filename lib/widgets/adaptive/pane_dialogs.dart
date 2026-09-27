import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'detail_pane.dart';

/// `Dialog` 대체. 폰에서는 그대로 `Dialog`로, 펼친 폴더블의 오른쪽 패널에서는
/// 떠 있는 팝업이 아니라 패널 전체를 채우는 화면으로 그린다.
class PaneDialog extends StatelessWidget {
  const PaneDialog({
    super.key,
    required this.child,
    this.insetPadding,
    this.shape,
    this.clipBehavior = Clip.none,
    this.backgroundColor,
    this.surfaceTintColor,
  });

  final Widget child;
  final EdgeInsets? insetPadding;
  final ShapeBorder? shape;
  final Clip clipBehavior;
  final Color? backgroundColor;
  final Color? surfaceTintColor;

  @override
  Widget build(BuildContext context) {
    if (DetailPane.isPage(context)) {
      return SizedBox.expand(
        child: Material(
          color: backgroundColor ?? Colors.white,
          child: SafeArea(child: child),
        ),
      );
    }
    return Dialog(
      insetPadding: insetPadding,
      shape: shape,
      clipBehavior: clipBehavior,
      backgroundColor: backgroundColor,
      surfaceTintColor: surfaceTintColor,
      child: child,
    );
  }
}

/// `AlertDialog` 대체. 폰에서는 그대로 `AlertDialog`로, 오른쪽 패널에서는
/// 제목(상단) · 본문(스크롤) · 버튼(하단 고정) 구조의 화면으로 그린다.
class PaneAlertDialog extends StatelessWidget {
  const PaneAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.titlePadding,
    this.contentPadding,
    this.actionsPadding,
    this.insetPadding,
    this.backgroundColor,
    this.surfaceTintColor,
    this.shape,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final EdgeInsets? insetPadding;
  final Color? backgroundColor;
  final Color? surfaceTintColor;
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) {
    if (!DetailPane.isPage(context)) {
      return AlertDialog(
        title: title,
        content: content,
        actions: actions,
        titlePadding: titlePadding,
        contentPadding: contentPadding,
        actionsPadding: actionsPadding,
        insetPadding: insetPadding,
        backgroundColor: backgroundColor,
        surfaceTintColor: surfaceTintColor,
        shape: shape,
      );
    }

    final theme = Theme.of(context);
    final dialogTheme = DialogTheme.of(context);
    return SizedBox.expand(
      child: Material(
        color: backgroundColor ?? Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: titlePadding ??
                      const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: DefaultTextStyle(
                    style: dialogTheme.titleTextStyle ??
                        theme.textTheme.titleLarge!,
                    child: title!,
                  ),
                ),
              if (title != null)
                const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: SingleChildScrollView(
                  padding: contentPadding ??
                      const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: DefaultTextStyle(
                    style: dialogTheme.contentTextStyle ??
                        theme.textTheme.bodyMedium!,
                    child: content ?? const SizedBox.shrink(),
                  ),
                ),
              ),
              if (actions != null && actions!.isNotEmpty) ...[
                const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: actions!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
