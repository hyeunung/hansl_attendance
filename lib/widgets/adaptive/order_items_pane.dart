import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../shared/flat_section.dart';

/// 펼친 폴더블 오른쪽 패널: 발주 한 건의 품목 목록.
/// 폰에서는 카드의 펼침(∨)으로 보던 내용을 그대로 옮겨 보여준다.
class OrderItemsPane extends StatelessWidget {
  const OrderItemsPane({
    super.key,
    required this.orderNumber,
    required this.listenable,
    required this.itemCount,
    required this.itemsBuilder,
  });

  final String orderNumber;

  /// 목록 화면의 상태가 바뀔 때마다 알려주는 신호(입고 처리 후 갱신 등).
  final Listenable listenable;

  /// 현재 품목 수. 발주가 목록에서 사라졌으면 null.
  final int? Function() itemCount;

  /// 품목 목록 위젯(목록 화면의 펼침 내용과 동일).
  final Widget Function(BuildContext context) itemsBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(orderNumber, style: AppTextStyles.appBarTitle(context)),
      ),
      body: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) {
          final count = itemCount();
          if (count == null || count == 0) {
            return const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FlatEmptyState(
                  icon: Icons.check_circle_outline,
                  message: '처리가 끝나 목록에서 사라진 발주입니다',
                ),
              ],
            );
          }
          return ListView(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveUtils.spacing(context, 8),
            ),
            children: [
              FlatCard(
                child: Column(
                  children: [
                    FlatCardHeader(
                      title: '품목',
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.primary,
                      trailing: Text(
                        '$count개',
                        style: AppTextStyles.listSubtitle(context),
                      ),
                    ),
                    itemsBuilder(context),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
