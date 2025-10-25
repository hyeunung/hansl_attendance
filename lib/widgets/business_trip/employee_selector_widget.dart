import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../utils/responsive_utils.dart';

/// 직원 선택 위젯
/// 출장자 선택 및 동행자 추가를 위한 재사용 가능한 컴포넌트
class EmployeeSelectorWidget extends StatelessWidget {
  final String? selectedEmployee;
  final List<String> selectedCompanions;
  final List<String> employeeList;
  final bool isLoading;
  final VoidCallback? onSelectEmployee;
  final VoidCallback? onSelectCompanions;
  final Function(String)? onRemoveCompanion;

  const EmployeeSelectorWidget({
    super.key,
    required this.selectedEmployee,
    required this.selectedCompanions,
    required this.employeeList,
    required this.isLoading,
    this.onSelectEmployee,
    this.onSelectCompanions,
    this.onRemoveCompanion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 10),
          _buildEmployeeSelector(context),
          if (selectedCompanions.isNotEmpty) _buildCompanionChips(context),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              '출장자(신청자)',
              style: ResponsiveUtils.getTextStyle(context, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text('  *', style: ResponsiveUtils.getTextStyle(context, color: Colors.red, fontSize: 17)),
          ],
        ),
        if (onSelectCompanions != null)
          GestureDetector(
            onTap: onSelectCompanions,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_add, color: AppColors.primary, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '추가 인원',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmployeeSelector(BuildContext context) {
    return GestureDetector(
      onTap: employeeList.isNotEmpty && !isLoading ? onSelectEmployee : null,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedEmployee != null
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: isLoading
            ? const SizedBox(
                height: 24,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : Row(
                children: [
                  if (selectedEmployee != null)
                    Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          selectedEmployee!.isNotEmpty
                              ? selectedEmployee!.substring(0, 1)
                              : '?',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      selectedEmployee ?? '출장자를 선택하세요',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 16,
                        color: selectedEmployee != null
                            ? AppColors.primary
                            : Colors.grey,
                        fontWeight: selectedEmployee != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: selectedEmployee != null
                        ? AppColors.primary
                        : Colors.grey,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCompanionChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '동행자 (${selectedCompanions.length}명)',
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedCompanions.map((companion) {
              return Chip(
                label: Text(companion, style: ResponsiveUtils.getTextStyle(context, fontSize: 14)),
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                deleteIcon: const Icon(Icons.close, size: 18),
                deleteIconColor: AppColors.primary,
                onDeleted: onRemoveCompanion != null
                    ? () => onRemoveCompanion!(companion)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// 직원 선택 다이얼로그
class EmployeeSelectionDialog extends StatefulWidget {
  final List<String> employeeList;
  final String? currentSelection;
  final bool isMultiSelect;
  final List<String>? selectedEmployees;
  final String title;

  const EmployeeSelectionDialog({
    super.key,
    required this.employeeList,
    this.currentSelection,
    this.isMultiSelect = false,
    this.selectedEmployees,
    this.title = '직원 선택',
  });

  @override
  State<EmployeeSelectionDialog> createState() =>
      _EmployeeSelectionDialogState();
}

class _EmployeeSelectionDialogState extends State<EmployeeSelectionDialog> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  String? _tempSelection;
  List<String> _tempMultiSelection = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tempSelection = widget.currentSelection;
    _tempMultiSelection = widget.selectedEmployees ?? [];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = widget.employeeList
        .where(
          (name) => name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTitle(),
            const SizedBox(height: 16),
            _buildSearchField(),
            const SizedBox(height: 16),
            Flexible(child: _buildEmployeeList(filteredList)),
            const SizedBox(height: 16),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        Icon(
          widget.isMultiSelect ? Icons.group_add : Icons.person,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          widget.title,
          style: ResponsiveUtils.getTextStyle(context, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        if (widget.isMultiSelect && _tempMultiSelection.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_tempMultiSelection.length}',
              style: ResponsiveUtils.getTextStyle(
                context,
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: '이름 검색',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: const Color(0xFFF4F5F7),
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildEmployeeList(List<String> filteredList) {
    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              '검색 결과가 없습니다',
              style: ResponsiveUtils.getTextStyle(context, color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final name = filteredList[index];
        final isSelected = widget.isMultiSelect
            ? _tempMultiSelection.contains(name)
            : _tempSelection == name;

        return _buildEmployeeItem(name, isSelected);
      },
    );
  }

  Widget _buildEmployeeItem(String name, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (widget.isMultiSelect) {
            if (isSelected) {
              _tempMultiSelection.remove(name);
            } else {
              _tempMultiSelection.add(name);
            }
          } else {
            _tempSelection = name;
            Navigator.pop(context, name);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isSelected
                  ? AppColors.primary
                  : const Color(0xFFE0E0E0),
              child: Text(
                name.isNotEmpty ? name.substring(0, 1) : '?',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                widget.isMultiSelect ? Icons.check_box : Icons.check_circle,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        if (widget.isMultiSelect) ...[
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, _tempMultiSelection),
            child: const Text('확인'),
          ),
        ],
      ],
    );
  }
}
