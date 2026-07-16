import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/common/notification_banner_widget.dart';
import '../../widgets/shared/flat_section.dart';

/// 제작현황 알림 항목 정의 — send_fcm_notification(production_teams)의
/// data.type/data.field 값과 1:1 대응하는 키를 사용한다
class _ProductionNotifyItem {
  final String key;
  final String label;
  final String description;

  const _ProductionNotifyItem({
    required this.key,
    required this.label,
    required this.description,
  });
}

const List<_ProductionNotifyItem> _productionItems = [
  _ProductionNotifyItem(
    key: 'production_new_row',
    label: '신규 제작 건 등록',
    description: '새 제작 건(PCB/케이블)이 등록되면 알림',
  ),
  _ProductionNotifyItem(
    key: 'pcb_stock_completed',
    label: 'PCB 입고완료',
    description: 'PCB 입고가 완료되면 알림',
  ),
  _ProductionNotifyItem(
    key: 'artwork_status',
    label: 'ARTWORK 완료',
    description: 'ARTWORK 작업이 완료되면 알림',
  ),
  _ProductionNotifyItem(
    key: 'parts_organization',
    label: '부품정리 완료',
    description: '부품정리가 완료되면 알림',
  ),
  _ProductionNotifyItem(
    key: 'delivery_completed',
    label: '납품 배송완료',
    description: '납품 배송이 완료되면 알림',
  ),
  _ProductionNotifyItem(
    key: 'final_product_stock',
    label: '완제품 입고',
    description: '완제품이 입고되면 알림',
  ),
];

/// 푸시 알림 수신 설정 화면
/// employees.notification_preferences(jsonb)에 카테고리별 수신 여부를 저장한다.
/// 실제 발송 필터링은 send_fcm_notification Edge Function에서 수행된다.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;

  /// 서버에 저장된 전체 설정(jsonb) — 다른 카테고리 값 보존을 위해 통째로 유지
  Map<String, dynamic> _preferences = {};

  String? get _email =>
      Provider.of<UserProvider>(context, listen: false).email ??
      _supabase.auth.currentUser?.email;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final email = _email;
    if (email == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final row = await _supabase
          .from('employees')
          .select('notification_preferences')
          .eq('email', email)
          .single();
      if (mounted) {
        setState(() {
          _preferences = Map<String, dynamic>.from(
            row['notification_preferences'] as Map? ?? {},
          );
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppBanner.show(context, '알림 설정을 불러오지 못했습니다', type: BannerType.error);
      }
    }
  }

  bool _isEnabled(String key) {
    final production = _preferences['production_teams'];
    if (production is Map && production[key] == false) return false;
    return true; // 키가 없으면 기본 수신
  }

  Future<void> _toggle(String key, bool enabled) async {
    final email = _email;
    if (email == null) return;

    final previous = Map<String, dynamic>.from(_preferences);
    final production = Map<String, dynamic>.from(
      _preferences['production_teams'] as Map? ?? {},
    );
    if (enabled) {
      production.remove(key); // 수신 거부만 저장, 켜면 키 제거
    } else {
      production[key] = false;
    }
    final updated = Map<String, dynamic>.from(_preferences);
    if (production.isEmpty) {
      updated.remove('production_teams');
    } else {
      updated['production_teams'] = production;
    }

    setState(() => _preferences = updated);

    try {
      await _supabase
          .from('employees')
          .update({'notification_preferences': updated}).eq('email', email);
    } catch (_) {
      if (mounted) {
        setState(() => _preferences = previous);
        AppBanner.show(context, '설정 저장에 실패했습니다', type: BannerType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: Text(
          '푸시 알림',
          style: ResponsiveUtils.getTextStyle(
            context,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              children: [
                FlatSectionHeader(
                  title: '제작현황',
                  icon: Icons.factory_outlined,
                  iconColor: AppColors.primary,
                ),
                for (final item in _productionItems) _buildToggleRow(item),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.spacing(context, 16),
                    vertical: ResponsiveUtils.spacing(context, 12),
                  ),
                  child: Text(
                    '끄면 해당 항목의 푸시 알림과 알림함 기록을 받지 않습니다.',
                    style: AppTextStyles.listSubtitle(context),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildToggleRow(_ProductionNotifyItem item) {
    final enabled = _isEnabled(item.key);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 16),
        vertical: ResponsiveUtils.spacing(context, 10),
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: AppTextStyles.listTitle(context)),
                SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                Text(
                  item.description,
                  style: AppTextStyles.listSubtitle(context),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: enabled,
            activeTrackColor: AppColors.primary,
            onChanged: (value) => _toggle(item.key, value),
          ),
        ],
      ),
    );
  }
}
