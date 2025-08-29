import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';

/// 교통수단 선택 위젯
/// 출장 시 이용할 교통수단을 선택하는 재사용 가능한 컴포넌트
class TransportSelectorWidget extends StatelessWidget {
  final String? selectedTransport;
  final List<String> transportOptions;
  final Function(String?)? onChanged;
  final bool isRequired;

  const TransportSelectorWidget({
    Key? key,
    required this.selectedTransport,
    required this.transportOptions,
    this.onChanged,
    this.isRequired = true,
  }) : super(key: key);

  // 교통수단별 아이콘 매핑
  IconData _getTransportIcon(String transport) {
    switch (transport) {
      case '펠리세이드':
      case '스타리아':
      case 'GV80':
      case 'GV90':
      case '자차':
        return Icons.directions_car;
      case 'KTX(SRT)':
        return Icons.train;
      case '버스':
        return Icons.directions_bus;
      case '비행기':
        return Icons.flight;
      default:
        return Icons.commute;
    }
  }

  // 교통수단별 색상
  Color _getTransportColor(String transport) {
    switch (transport) {
      case '펠리세이드':
      case '스타리아':
      case 'GV80':
      case 'GV90':
        return const Color(0xFF2E7D32); // 회사차 - 초록
      case '자차':
        return const Color(0xFF1976D2); // 자차 - 파랑
      case 'KTX(SRT)':
        return const Color(0xFFE65100); // 기차 - 주황
      case '버스':
        return const Color(0xFF7B1FA2); // 버스 - 보라
      case '비행기':
        return const Color(0xFF0277BD); // 비행기 - 하늘색
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppShadows.card],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          _buildDropdown(),
          if (selectedTransport != null) _buildSelectedInfo(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          '교통',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        if (isRequired)
          const Text('  *', style: TextStyle(color: Colors.red, fontSize: 17)),
      ],
    );
  }

  Widget _buildDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedTransport != null
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedTransport,
          hint: Row(
            children: [
              Icon(Icons.commute, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              const Text('교통수단을 선택하세요', style: TextStyle(fontSize: 15)),
            ],
          ),
          isExpanded: true,
          icon: Icon(
            Icons.arrow_drop_down,
            color: selectedTransport != null ? AppColors.primary : Colors.grey,
          ),
          items: transportOptions.map((transport) {
            return DropdownMenuItem<String>(
              value: transport,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _getTransportColor(
                        transport,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTransportIcon(transport),
                      color: _getTransportColor(transport),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    transport,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isCompanyCar(transport))
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '회사차',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSelectedInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getTransportColor(selectedTransport!).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _getTransportColor(
              selectedTransport!,
            ).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getTransportColor(
                  selectedTransport!,
                ).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                _getTransportIcon(selectedTransport!),
                color: _getTransportColor(selectedTransport!),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedTransport!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getTransportColor(selectedTransport!),
                    ),
                  ),
                  if (_getTransportDescription(selectedTransport!) != null)
                    Text(
                      _getTransportDescription(selectedTransport!)!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isCompanyCar(String transport) {
    return ['펠리세이드', '스타리아', 'GV80', 'GV90'].contains(transport);
  }

  String? _getTransportDescription(String transport) {
    switch (transport) {
      case '펠리세이드':
        return '7인승 SUV (회사 차량)';
      case '스타리아':
        return '9인승 밴 (회사 차량)';
      case 'GV80':
        return '5인승 SUV (회사 차량)';
      case 'GV90':
        return '5인승 대형 SUV (회사 차량)';
      case '자차':
        return '개인 차량 이용';
      case 'KTX(SRT)':
        return '고속철도';
      case '버스':
        return '시외/고속버스';
      case '비행기':
        return '국내선/국제선';
      default:
        return null;
    }
  }
}

/// 교통수단 선택 다이얼로그 (옵션)
class TransportSelectionDialog extends StatelessWidget {
  final String? currentSelection;
  final List<String> transportOptions;

  const TransportSelectionDialog({
    Key? key,
    this.currentSelection,
    required this.transportOptions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.commute, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  '교통수단 선택',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...transportOptions.map((transport) {
              final isSelected = currentSelection == transport;
              final icon = _getTransportIcon(transport);
              final color = _getTransportColor(transport);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  onTap: () => Navigator.pop(context, transport),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transport,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? color : Colors.black87,
                                ),
                              ),
                              if (_getTransportDescription(transport) != null)
                                Text(
                                  _getTransportDescription(transport)!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isSelected) Icon(Icons.check_circle, color: color),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTransportIcon(String transport) {
    switch (transport) {
      case '펠리세이드':
      case '스타리아':
      case 'GV80':
      case 'GV90':
      case '자차':
        return Icons.directions_car;
      case 'KTX(SRT)':
        return Icons.train;
      case '버스':
        return Icons.directions_bus;
      case '비행기':
        return Icons.flight;
      default:
        return Icons.commute;
    }
  }

  Color _getTransportColor(String transport) {
    switch (transport) {
      case '펠리세이드':
      case '스타리아':
      case 'GV80':
      case 'GV90':
        return const Color(0xFF2E7D32);
      case '자차':
        return const Color(0xFF1976D2);
      case 'KTX(SRT)':
        return const Color(0xFFE65100);
      case '버스':
        return const Color(0xFF7B1FA2);
      case '비행기':
        return const Color(0xFF0277BD);
      default:
        return Colors.grey;
    }
  }

  String? _getTransportDescription(String transport) {
    switch (transport) {
      case '펠리세이드':
        return '7인승 SUV (회사 차량)';
      case '스타리아':
        return '9인승 밴 (회사 차량)';
      case 'GV80':
        return '5인승 SUV (회사 차량)';
      case 'GV90':
        return '5인승 대형 SUV (회사 차량)';
      case '자차':
        return '개인 차량 이용';
      case 'KTX(SRT)':
        return '고속철도';
      case '버스':
        return '시외/고속버스';
      case '비행기':
        return '국내선/국제선';
      default:
        return null;
    }
  }
}
