import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';

// ─── Data Classes ───

class FlatColumn {
  final String label;
  final int flex;
  final TextAlign align;

  const FlatColumn({
    required this.label,
    this.flex = 1,
    this.align = TextAlign.start,
  });
}

class FlatStatItem {
  final String label;
  final String value;
  final Color? color;

  const FlatStatItem({
    required this.label,
    required this.value,
    this.color,
  });
}

// ─── Section Header ───

/// 회색 배경 섹션 헤더 (상단 여백으로 섹션 구분)
class FlatSectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final IconData? icon;
  final Color? iconColor;

  const FlatSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: ResponsiveUtils.spacing(context, 16),
        right: ResponsiveUtils.spacing(context, 16),
        top: ResponsiveUtils.spacing(context, 8),
        bottom: ResponsiveUtils.spacing(context, 8),
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: iconColor ?? AppColors.textTertiary),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.sectionHeader(context),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: AppTextStyles.statLabel(context),
            ),
        ],
      ),
    );
  }
}

// ─── Card Wrapper ───

/// 섹션을 감싸는 카드 (Enterprise Neutral: 흰 배경 + 1px 테두리, 그림자 없음)
class FlatCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;

  const FlatCard({super.key, required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ??
          EdgeInsets.fromLTRB(
            ResponsiveUtils.spacing(context, 16),
            0,
            ResponsiveUtils.spacing(context, 16),
            ResponsiveUtils.spacing(context, 8),
          ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: child,
    );
  }
}

// ─── Card Header / Info Row ───

/// 카드 내부 제목 줄 (근무기록 섹션 헤더와 동일 규격)
/// 회색 띠 + 13px 세미볼드 + 상하 8px
class FlatCardHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const FlatCardHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 14),
        vertical: ResponsiveUtils.spacing(context, 8),
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: iconColor ?? AppColors.primary),
            SizedBox(width: ResponsiveUtils.spacing(context, 6)),
          ],
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.sectionHeader(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// 카드 내부 정보 행 (라벨 11px 회색 / 값 12px)
class FlatInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final Widget? trailing;

  const FlatInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 14),
        vertical: ResponsiveUtils.spacing(context, 6),
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.textTertiary),
            SizedBox(width: ResponsiveUtils.spacing(context, 6)),
          ],
          SizedBox(
            width: ResponsiveUtils.spacing(context, 76),
            child: Text(label, style: AppTextStyles.listSubtitle(context)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.tableCell(context).copyWith(color: valueColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─── Progress Row ───

/// 진행률 행 (Enterprise Neutral: 얇은 트랙 + 채움 바)
/// 라벨 / 완료·전체·퍼센트 / 4px 진행 바
class FlatProgressRow extends StatelessWidget {
  final String label;
  final num completed;
  final num total;
  final int percentage;
  final Color color;

  /// 기본 '완료 / 전체' 대신 표시할 문자열 (예: '1일 / 18일')
  final String? valueText;

  const FlatProgressRow({
    super.key,
    required this.label,
    required this.completed,
    required this.total,
    required this.percentage,
    required this.color,
    this.valueText,
  });

  /// 소수점이 없으면 정수로 표기 (1.0 → 1, 1.5 → 1.5)
  static String formatCount(num v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? completed / total : 0.0;
    final isDone = total > 0 && completed >= total;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 14),
        vertical: ResponsiveUtils.spacing(context, 8),
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: AppTextStyles.listSubtitle(context)),
              ),
              Text(
                valueText ??
                    '${formatCount(completed)} / ${formatCount(total)}',
                style: AppTextStyles.tableCell(context),
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 6)),
              Text(
                '$percentage%',
                style: AppTextStyles.tableCell(context).copyWith(
                  color: isDone ? AppColors.success : color,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacing(context, 5)),
          // 전체 트랙(회색) 위에 진행분(색상)을 얹어 비율이 보이도록 구성
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? AppColors.success : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Table Column Header ───

/// 테이블 컬럼 헤더 (연한 배경)
class FlatTableColumnHeader extends StatelessWidget {
  final List<FlatColumn> columns;
  final double? trailingWidth;

  const FlatTableColumnHeader({
    super.key,
    required this.columns,
    this.trailingWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 16),
        vertical: ResponsiveUtils.spacing(context, 5),
      ),
      decoration: const BoxDecoration(
        color: AppColors.gray50,
        border: Border(
          bottom: BorderSide(color: AppColors.gray300, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          ...columns.map((col) => Expanded(
                flex: col.flex,
                child: Text(
                  col.label,
                  textAlign: col.align,
                  style: AppTextStyles.tableHeader(context),
                ),
              )),
          if (trailingWidth != null) SizedBox(width: trailingWidth!),
        ],
      ),
    );
  }
}

// ─── Table Row ───

/// 테이블 데이터 행
class FlatTableRow extends StatelessWidget {
  final List<Widget> cells;
  final List<int> flexValues;
  final VoidCallback? onTap;
  final double? trailingWidth;
  final Widget? trailing;

  const FlatTableRow({
    super.key,
    required this.cells,
    required this.flexValues,
    this.onTap,
    this.trailingWidth,
    this.trailing,
  }) : assert(cells.length == flexValues.length, 'cells and flexValues must have the same length');

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 16),
        vertical: ResponsiveUtils.spacing(context, 7),
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < cells.length; i++)
            Expanded(flex: flexValues[i], child: cells[i]),
          if (trailing != null)
            SizedBox(
              width: trailingWidth ?? 60,
              child: Align(alignment: Alignment.centerRight, child: trailing!),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: AppColors.backgroundCard,
        child: InkWell(onTap: onTap, child: content),
      );
    }
    return content;
  }
}

// ─── Toggle Section ───

/// 토글 가능한 섹션 (접기/펼치기)
class FlatToggleSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? color;
  final bool isExpanded;
  final VoidCallback onTap;
  final List<Widget> children;

  const FlatToggleSection({
    super.key,
    required this.title,
    this.icon,
    this.color,
    required this.isExpanded,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: AppColors.backgroundSecondary,
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.spacing(context, 16),
                vertical: ResponsiveUtils.spacing(context, 8),
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: color ?? AppColors.textTertiary),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.sectionHeader(context).copyWith(
                        color: color ?? AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded) ...children,
      ],
    );
  }
}

// ─── Status Chip ───

/// 상태 칩 (작은 라운드 배지)
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final double? fontSize;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 8),
        vertical: ResponsiveUtils.spacing(context, 3),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        // 배지는 높이가 17pt 정도라 radius 8이면 알약처럼 보여 6을 쓴다
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: fontSize != null
            ? AppTextStyles.chipSmall(context, color: color).copyWith(
                fontSize: fontSize,
                height: 1.0,
              )
            : AppTextStyles.chipSmall(context, color: color).copyWith(
                height: 1.0,
              ),
      ),
    );
  }
}

// ─── Stat Grid ───

/// N칸 요약 그리드 (세로 구분선)
class FlatStatGrid extends StatelessWidget {
  final List<FlatStatItem> items;

  const FlatStatGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: ResponsiveUtils.spacing(context, 8),
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  width: 1,
                  thickness: 0.5,
                  color: AppColors.borderLight,
                ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      items[i].value,
                      style: AppTextStyles.compactValue(
                        context,
                        color: items[i].color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].label,
                      style: AppTextStyles.compactLabel(context),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ───

/// 빈 상태 메시지
class FlatEmptyState extends StatelessWidget {
  final String message;
  final IconData? icon;

  const FlatEmptyState({
    super.key,
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: ResponsiveUtils.spacing(context, 16),
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: ResponsiveUtils.spacing(context, 24),
              color: AppColors.gray400,
            ),
            SizedBox(height: ResponsiveUtils.spacing(context, 6)),
          ],
          Text(
            message,
            style: AppTextStyles.emptyState(context),
          ),
        ],
      ),
    );
  }
}

// ─── Flat List Tile ───

/// iOS 설정 스타일 리스트 항목
class FlatListTile extends StatelessWidget {
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Widget? leading;

  const FlatListTile({
    super.key,
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 16),
        vertical: ResponsiveUtils.spacing(context, 9),
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(width: ResponsiveUtils.spacing(context, 12)),
          ],
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.listTitle(context).copyWith(
                color: titleColor,
              ),
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: AppTextStyles.listSubtitle(context),
            ),
          if (value != null && trailing != null)
            SizedBox(width: ResponsiveUtils.spacing(context, 8)),
          if (trailing != null) trailing!,
          if (onTap != null && trailing == null)
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textTertiary,
            ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: AppColors.backgroundCard,
        child: InkWell(onTap: onTap, child: content),
      );
    }
    return content;
  }
}
