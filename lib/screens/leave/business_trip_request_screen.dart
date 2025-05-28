import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/leave_provider.dart';
import '../../providers/user_provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../../theme/app_colors.dart';
import '../approval/approval_screen.dart';
import '../../theme/app_shadows.dart';

class BusinessTripRequestScreen extends StatefulWidget {
  const BusinessTripRequestScreen({super.key});

  @override
  State<BusinessTripRequestScreen> createState() => _BusinessTripRequestScreenState();
}

class _BusinessTripRequestScreenState extends State<BusinessTripRequestScreen> {
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  String? _selectedTransport;
  Set<DateTime> _selectedDates = {};
  String? _selectedEmployee;
  List<String> _employeeList = [];
  bool _isLoadingEmployees = false;
  List<String> _selectedCompanions = [];
  final List<String> _transports = [
    '펠리세이드',
    '스타리아',
    'GV80',
    'GV90',
    'KTX(SRT)',
    '버스',
    '자차',
    '비행기',
  ];
  final TextEditingController _searchController = TextEditingController();
  String? _bannerMessage;
  Color _bannerColor = AppColors.primary;

  @override
  void dispose() {
    _placeController.dispose();
    _purposeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoadingEmployees = true);
    final service = SupabaseService();
    final response = await service.fetchEmployees();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    String? myName = userProvider.name;
    setState(() {
      _employeeList = response;
      _isLoadingEmployees = false;
      // 내 이름 자동 선택(없으면 첫번째)
      if (_employeeList.isNotEmpty) {
        if (myName != null && _employeeList.contains(myName)) {
          _selectedEmployee = myName;
        } else {
          _selectedEmployee = _employeeList.first;
        }
      }
    });
    print('직원 목록: $response');
  }

  // 추가 인원 선택: 중앙 Dialog + 검색 + 카드형 멀티셀렉트
  void _showCompanionDialog() async {
    final List<String> candidates = _employeeList
        .where((name) => name != _selectedEmployee)
        .toList();
    List<String> tempSelected = List.from(_selectedCompanions);
    String search = '';
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = candidates
                .where((name) => name.contains(search))
                .toList();
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(20),
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('추가 인원 선택', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 12),
                    if (tempSelected.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Wrap(
                          spacing: 8,
                          children: tempSelected.map((name) => Chip(
                            label: Text(name),
                            onDeleted: () {
                              setModalState(() => tempSelected.remove(name));
                            },
                          )).toList(),
                        ),
                      ),
                    TextField(
                      decoration: InputDecoration(
                        hintText: '이름 검색',
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: const Color(0xFFF4F5F7),
                      ),
                      onChanged: (v) => setModalState(() => search = v),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 220,
                      child: filtered.isEmpty
                          ? const Center(child: Text('직원이 없습니다.'))
                          : ListView(
                              children: filtered.map((name) {
                                final selected = tempSelected.contains(name);
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      if (selected) {
                                        tempSelected.remove(name);
                                      } else {
                                        tempSelected.add(name);
                                      }
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selected ? AppColors.primary.withOpacity(0.12) : Colors.white,
                                      border: Border.all(
                                        color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
                                        width: selected ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: selected ? AppColors.primary : const Color(0xFFE0E0E0),
                                          child: Text(name.characters.first, style: const TextStyle(color: Colors.white)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: selected ? AppColors.primary : Colors.black87,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        if (selected)
                                          Icon(Icons.check_circle, color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          setState(() => _selectedCompanions = tempSelected);
                          Navigator.pop(context);
                        },
                        child: const Text('확인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEmployeeDialog() async {
    final List<String> candidates = _employeeList;
    String search = '';
    String? tempSelected = _selectedEmployee;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = candidates.where((name) => name.contains(search)).toList();
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(20),
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('출장자(신청자) 선택', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: '이름 검색',
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: const Color(0xFFF4F5F7),
                      ),
                      onChanged: (v) => setModalState(() => search = v),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 220,
                      child: filtered.isEmpty
                          ? const Center(child: Text('직원이 없습니다.'))
                          : ListView(
                              children: filtered.map((name) {
                                final selected = tempSelected == name;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedEmployee = name;
                                      _selectedCompanions.remove(name);
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selected ? AppColors.primary.withOpacity(0.12) : Colors.white,
                                      border: Border.all(
                                        color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
                                        width: selected ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: selected ? AppColors.primary : const Color(0xFFE0E0E0),
                                          child: Text(name.characters.first, style: const TextStyle(color: Colors.white)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: selected ? AppColors.primary : Colors.black87,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        if (selected)
                                          Icon(Icons.check_circle, color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDatePickerDialog(List<Map<String, dynamic>> myLeaves) async {
    final now = DateTime.now();
    Set<DateTime> tempSelected = {..._selectedDates};
    // 이미 신청된 날짜
    final Set<DateTime> disabledDates = myLeaves.map((l) {
      final start = DateTime.parse(l['start_date']);
      final end = DateTime.parse(l['end_date']);
      return List.generate(end.difference(start).inDays + 1, (i) => DateTime(start.year, start.month, start.day + i));
    }).expand((x) => x).toSet();
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(20),
                width: 370,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('출장 날짜 선택', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 12),
                    TableCalendar(
                      firstDay: DateTime(now.year, 1, 1),
                      lastDay: DateTime(now.year + 1, 12, 31),
                      focusedDay: tempSelected.isNotEmpty ? tempSelected.first : DateTime.now(),
                      selectedDayPredicate: (day) => tempSelected.any((d) => isSameDay(d, day)),
                      onDaySelected: (selectedDay, _) {
                        if (disabledDates.any((d) => isSameDay(d, selectedDay))) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('이미 신청된 날짜입니다.'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        setModalState(() {
                          if (tempSelected.any((d) => isSameDay(d, selectedDay))) {
                            tempSelected.removeWhere((d) => isSameDay(d, selectedDay));
                          } else {
                            tempSelected.add(selectedDay);
                          }
                        });
                      },
                      calendarStyle: CalendarStyle(
                        isTodayHighlighted: true,
                        selectedDecoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        disabledTextStyle: TextStyle(color: Colors.grey.shade400),
                      ),
                      enabledDayPredicate: (day) => !disabledDates.any((d) => isSameDay(d, day)),
                      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                      calendarFormat: CalendarFormat.month,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: (tempSelected.toList()..sort((a, b) => a.compareTo(b)))
                          .map((d) => Chip(
                                label: Text(DateFormat('yyyy.MM.dd').format(d)),
                                backgroundColor: AppColors.primary.withOpacity(0.12),
                                labelStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                onDeleted: () => setModalState(() => tempSelected.remove(d)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          setState(() => _selectedDates = tempSelected);
                          Navigator.pop(context);
                        },
                        child: const Text('확인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '출장 신청',
          style: TextStyle(
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Color(0xFF222222),
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Consumer<LeaveProvider>(
        builder: (context, leaveProvider, _) {
          final now = DateTime.now();
          final thisMonth = now.month;
          final thisYear = now.year;
          final myBiztrips = leaveProvider.myLeaves.where((l) => l['type'] == 'biztrip').toList();
          final monthBiztrips = myBiztrips.where((l) => DateTime.parse(l['start_date']).month == thisMonth && DateTime.parse(l['start_date']).year == thisYear).length;
          final yearBiztrips = myBiztrips.where((l) => DateTime.parse(l['start_date']).year == thisYear).length;
          return Column(
            children: [
              _buildBanner(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    // 상단 카드
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('이번달 출장', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$monthBiztrips회',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 40, color: Colors.white, height: 1.1),
                              ),
                              const SizedBox(width: 20),
                              Text(
                                '올해 누적 출장  $yearBiztrips회',
                                style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    // 출장자(신청자)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [AppShadows.card],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text('출장자(신청자)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                  const Text('  *', style: TextStyle(color: Colors.red, fontSize: 17)),
                                ],
                              ),
                              GestureDetector(
                                onTap: _showCompanionDialog,
                                child: const Text(
                                  '+ 추가 인원',
                                  style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _employeeList.isNotEmpty && !_isLoadingEmployees ? _showEmployeeDialog : null,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F5F7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              child: _isLoadingEmployees
                                  ? const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          _selectedEmployee ?? '출장자를 선택하세요',
                                          style: TextStyle(
                                            fontSize: 17,
                                            color: _selectedEmployee != null ? AppColors.primary : Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_selectedCompanions.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 8,
                                children: _selectedCompanions.map((m) => Chip(
                                  label: Text(m),
                                  onDeleted: () => setState(() => _selectedCompanions.remove(m)),
                                )).toList(),
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // 날짜
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [AppShadows.card],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('날짜', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                              const Text('  *', style: TextStyle(color: Colors.red, fontSize: 17)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F5F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            child: InkWell(
                              onTap: () {
                                final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
                                _showDatePickerDialog(leaveProvider.myLeaves);
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, color: Colors.grey),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _selectedDates.isNotEmpty
                                          ? ((_selectedDates.toList()..sort((a, b) => a.compareTo(b)))
                                              .map((d) => DateFormat('yyyy.MM.dd').format(d))
                                              .join(', '))
                                          : '출장 날짜를 선택하세요',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: _selectedDates.isNotEmpty ? AppColors.primary : Colors.grey,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_selectedDates.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Wrap(
                                spacing: 8,
                                children: (_selectedDates.toList()..sort((a, b) => a.compareTo(b)))
                                    .map((d) => Chip(
                                      label: Text(DateFormat('yyyy.MM.dd').format(d)),
                                      backgroundColor: AppColors.primary.withOpacity(0.12),
                                      labelStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                      onDeleted: () => setState(() => _selectedDates.remove(d)),
                                    ))
                                    .toList(),
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // 출장지
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [AppShadows.card],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('출장지', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                              const Text('  *', style: TextStyle(color: Colors.red, fontSize: 17)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F5F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: TextField(
                              controller: _placeController,
                              style: const TextStyle(fontSize: 17, color: Color(0xFF222222)),
                              decoration: const InputDecoration(
                                hintText: '출장지를 입력하세요',
                                hintStyle: TextStyle(fontSize: 17, color: Colors.grey),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // 교통
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [AppShadows.card],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('교통', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                              const Text('  *', style: TextStyle(color: Colors.red, fontSize: 17)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F5F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedTransport,
                                hint: const Text('교통수단을 선택하세요'),
                                isExpanded: true,
                                items: _transports
                                    .map((t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedTransport = v),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // 업무
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [AppShadows.card],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('업무', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                              const Text('  *', style: TextStyle(color: Colors.red, fontSize: 17)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F5F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: TextField(
                              controller: _purposeController,
                              maxLines: 4,
                              style: const TextStyle(fontSize: 17, color: Color(0xFF222222)),
                              decoration: const InputDecoration(
                                hintText: '업무를 입력하세요',
                                hintStyle: TextStyle(fontSize: 17, color: Color(0xFF888888)),
                                border: InputBorder.none,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (_purposeController.text.trim().isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(left: 4, top: 8),
                              child: Text(
                                '업무는 필수 입력 항목입니다.',
                                style: TextStyle(color: Colors.red, fontSize: 15),
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 6,
                          backgroundColor: _canSubmit
                              ? AppColors.primary
                              : const Color(0xFFE0E0E0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _canSubmit
                            ? () async {
                                final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
                                final userProvider = Provider.of<UserProvider>(context, listen: false);
                                final userEmail = userProvider.email;
                                if (userEmail == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('로그인 정보가 없습니다.'), backgroundColor: Colors.red),
                                  );
                                  return;
                                }
                                bool hasError = false;
                                for (final d in _selectedDates) {
                                  try {
                                    await leaveProvider.requestLeave(
                                      userEmail: userEmail,
                                      type: 'biztrip',
                                      startDate: d,
                                      endDate: d,
                                      reason:
                                          '출장자: ${_selectedEmployee ?? ''}\n추가인원: ${_selectedCompanions.join(', ')}\n교통: ${_selectedTransport ?? ''}\n출장지: ${_placeController.text.trim()}\n업무: ${_purposeController.text.trim()}',
                                    );
                                  } catch (e) {
                                    hasError = true;
                                  }
                                }
                                if (!hasError) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('신청이 완료되었습니다.'), backgroundColor: AppColors.primary),
                                    );
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ApprovalScreen()));
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('신청 중 오류가 발생했습니다.'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              }
                            : null,
                        child: Text(
                          '신청하기',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _canSubmit ? Colors.white : const Color(0xFFB0B0B0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool get _canSubmit {
    return _selectedEmployee != null &&
        _selectedDates.isNotEmpty &&
        _placeController.text.trim().isNotEmpty &&
        _selectedTransport != null &&
        _purposeController.text.trim().isNotEmpty;
  }

  Widget _buildBanner() {
    if (_bannerMessage == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: _bannerColor,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          _bannerMessage!,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
} 