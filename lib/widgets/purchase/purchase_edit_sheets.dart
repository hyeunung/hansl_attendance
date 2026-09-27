import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/purchase_request.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/currency_formatter.dart';
import '../common/notification_banner_widget.dart';
import '../adaptive/detail_pane.dart';

/// 구매/입고 수정 바텀시트 (Enterprise Neutral)
///
/// - [showPurchaseItemEditSheet]: 구매 완료 목록의 단일 품목 수정
/// - [showOrderEditSheet]: 입고대기 발주 전체(공통 정보 + 품목) 수정
///
/// 드래그로 닫히면 PopScope를 거치지 않으므로 enableDrag를 끄고,
/// 변경사항이 있을 때 닫기(바깥 탭/뒤로가기/X)는 확인 후 닫는다.

Future<void> showPurchaseItemEditSheet({
  required BuildContext context,
  required PurchaseRequest item,
  required Future<void> Function({
    required String itemName,
    required String specification,
    required int quantity,
    required double unitPrice,
  }) onSave,
}) {
  // 펼친 폴더블: 오른쪽 패널 안에서 열린다 (폰은 기존과 동일)
  DetailPane.clear(context);
  return showModalBottomSheet<void>(
    context: DetailPane.hostContext(context),
    isScrollControlled: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _PurchaseItemEditSheet(item: item, onSave: onSave),
  );
}

Future<void> showOrderEditSheet({
  required BuildContext context,
  required String orderNumber,
  required List<Map<String, dynamic>> items,
  required VoidCallback onSaved,
}) {
  // 펼친 폴더블: 오른쪽 패널 안에서 열린다 (폰은 기존과 동일)
  DetailPane.clear(context);
  return showModalBottomSheet<void>(
    context: DetailPane.hostContext(context),
    isScrollControlled: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _OrderEditSheet(
      orderNumber: orderNumber,
      items: items,
      onSaved: onSaved,
    ),
  );
}

// ───────────────────────────── 공통 구성요소 ─────────────────────────────

/// 시트 프레임: 헤더(제목/부제/닫기) + 스크롤 본문 + 하단 고정 버튼(취소·저장 반반)
class _EditSheetFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final bool hasChanges;
  final bool saving;
  final VoidCallback onSave;

  const _EditSheetFrame({
    required this.title,
    this.subtitle,
    required this.body,
    required this.hasChanges,
    required this.saving,
    required this.onSave,
  });

  Future<bool> _confirmDiscard(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('수정 내용을 버릴까요?', style: AppTextStyles.sectionTitle(ctx)),
        content: Text('저장하지 않은 변경사항이 사라집니다.', style: AppTextStyles.cardBody(ctx)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('계속 수정'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('버리기'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _requestClose(BuildContext context) async {
    if (saving) return;
    if (!hasChanges || await _confirmDiscard(context)) {
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return PopScope(
      canPop: !hasChanges && !saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose(context);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppTextStyles.sectionTitle(context).copyWith(fontSize: 15)),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: AppTextStyles.cardBody(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _requestClose(context),
                      icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                      tooltip: '닫기',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.borderLight),

              // 본문
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: body,
                ),
              ),

              // 하단 버튼 (반반)
              Container(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + (media.viewInsets.bottom > 0 ? 0 : media.padding.bottom)),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.borderLight)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving ? null : () => _requestClose(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        // 저장 중에는 파란 배경 유지(스피너가 보이도록) + 중복 탭 무시
                        onPressed: !hasChanges ? null : (saving ? () {} : onSave),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          // 변경사항 없으면 취소 버튼과 동일한 흰색 외곽선 스타일
                          disabledBackgroundColor: Colors.white,
                          disabledForegroundColor: AppColors.textDisabled,
                          side: hasChanges ? null : const BorderSide(color: AppColors.border),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('저장'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 라벨(위) + 입력창
class _SheetField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? suffix;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool required;

  const _SheetField({
    required this.label,
    required this.controller,
    this.hint,
    this.suffix,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.required = false,
  });

  OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (required)
                const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
            ],
          ),
          style: AppTextStyles.inputLabel(context),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          style: AppTextStyles.listTitle(context).copyWith(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            hintText: hint,
            hintStyle: AppTextStyles.tableCell(context, color: AppColors.textDisabled),
            suffixText: suffix,
            suffixStyle: AppTextStyles.cardBody(context),
            errorText: errorText,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: _border(AppColors.border),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.primary, 1.5),
            errorBorder: _border(AppColors.error),
            focusedErrorBorder: _border(AppColors.error, 1.5),
          ),
        ),
      ],
    );
  }
}

/// 섹션 제목
class _SheetSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const _SheetSectionLabel(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppTextStyles.sectionTitle(context))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 수량 × 단가 = 금액 요약 줄
class _AmountLine extends StatelessWidget {
  final num amount;
  final String currency;

  const _AmountLine({required this.amount, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Text('금액', style: AppTextStyles.cardBody(context)),
          const Spacer(),
          Text(
            CurrencyFormatter.formatWon(amount, currency),
            style: AppTextStyles.listTitle(context).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

String _priceText(Object? value, String currency) {
  final v = CurrencyFormatter.toNum(value);
  if (CurrencyFormatter.isKrw(currency)) return v.round().toString();
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

// ───────────────────────────── 구매: 단일 품목 수정 ─────────────────────────────

class _PurchaseItemEditSheet extends StatefulWidget {
  final PurchaseRequest item;
  final Future<void> Function({
    required String itemName,
    required String specification,
    required int quantity,
    required double unitPrice,
  }) onSave;

  const _PurchaseItemEditSheet({required this.item, required this.onSave});

  @override
  State<_PurchaseItemEditSheet> createState() => _PurchaseItemEditSheetState();
}

class _PurchaseItemEditSheetState extends State<_PurchaseItemEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _spec;
  late final TextEditingController _qty;
  late final TextEditingController _price;
  late final List<String> _original;

  String? _nameError;
  String? _qtyError;
  String? _priceError;
  bool _saving = false;

  String get _currency => widget.item.currency;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item.itemName);
    _spec = TextEditingController(text: widget.item.specification);
    _qty = TextEditingController(text: widget.item.quantity.toString());
    _price = TextEditingController(text: _priceText(widget.item.unitPriceValue, _currency));
    _original = [_name.text, _spec.text, _qty.text, _price.text];
    for (final c in [_name, _spec, _qty, _price]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _spec.dispose();
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final now = [_name.text, _spec.text, _qty.text, _price.text];
    for (var i = 0; i < now.length; i++) {
      if (now[i] != _original[i]) return true;
    }
    return false;
  }

  num get _amount =>
      CurrencyFormatter.round((int.tryParse(_qty.text) ?? 0) * (double.tryParse(_price.text) ?? 0), _currency);

  Future<void> _save() async {
    final name = _name.text.trim();
    final qty = int.tryParse(_qty.text.trim());
    final price = double.tryParse(_price.text.trim());

    setState(() {
      _nameError = name.isEmpty ? '품목명을 입력하세요' : null;
      _qtyError = qty == null || qty <= 0 ? '1 이상 입력' : null;
      _priceError = price == null || price < 0 ? '단가를 입력하세요' : null;
    });
    if (_nameError != null || _qtyError != null || _priceError != null) return;

    setState(() => _saving = true);
    await widget.onSave(
      itemName: name,
      specification: _spec.text.trim(),
      quantity: qty!,
      unitPrice: price!,
    );
    if (mounted) {
      setState(() => _saving = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final subtitle = [
      if ((item.purchaseOrderNumber ?? '').isNotEmpty) item.purchaseOrderNumber!,
      if (item.vendorName.isNotEmpty) item.vendorName,
    ].join(' · ');

    return _EditSheetFrame(
      title: '품목 수정',
      subtitle: subtitle,
      hasChanges: _hasChanges,
      saving: _saving,
      onSave: _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetField(
            label: '품목명',
            controller: _name,
            hint: '품목명',
            errorText: _nameError,
            required: true,
          ),
          const SizedBox(height: 14),
          _SheetField(label: '규격', controller: _spec, hint: '규격'),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SheetField(
                  label: '수량',
                  controller: _qty,
                  suffix: '개',
                  errorText: _qtyError,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  required: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SheetField(
                  label: '단가',
                  controller: _price,
                  suffix: CurrencyFormatter.unitLabel(_currency),
                  errorText: _priceError,
                  keyboardType: CurrencyFormatter.keyboardType(_currency),
                  inputFormatters: CurrencyFormatter.inputFormatters(_currency),
                  required: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AmountLine(amount: _amount, currency: _currency),
        ],
      ),
    );
  }
}

// ───────────────────────────── 입고: 발주 전체 수정 ─────────────────────────────

class _ItemEditState {
  final Map<String, dynamic> row;
  final TextEditingController name;
  final TextEditingController spec;
  final TextEditingController qty;
  final TextEditingController price;
  final TextEditingController remark;
  final List<String> original;
  bool expanded = false;
  String? nameError;
  String? qtyError;
  String? priceError;

  _ItemEditState._(this.row, this.name, this.spec, this.qty, this.price, this.remark)
      : original = [name.text, spec.text, qty.text, price.text, remark.text];

  factory _ItemEditState(Map<String, dynamic> row) {
    final currency = CurrencyFormatter.fromRow(row);
    return _ItemEditState._(
      row,
      TextEditingController(text: row['item_name']?.toString() ?? ''),
      TextEditingController(text: row['specification']?.toString() ?? ''),
      TextEditingController(text: CurrencyFormatter.toNum(row['quantity']).round().toString()),
      TextEditingController(text: _priceText(row['unit_price_value'], currency)),
      TextEditingController(text: row['remark']?.toString() ?? ''),
    );
  }

  List<TextEditingController> get controllers => [name, spec, qty, price, remark];

  String get currency => CurrencyFormatter.fromRow(row);

  bool get changed {
    final now = controllers.map((c) => c.text).toList();
    for (var i = 0; i < now.length; i++) {
      if (now[i] != original[i]) return true;
    }
    return false;
  }

  num get amount =>
      CurrencyFormatter.round((int.tryParse(qty.text) ?? 0) * (double.tryParse(price.text) ?? 0), currency);

  bool validate() {
    final q = int.tryParse(qty.text.trim());
    final p = double.tryParse(price.text.trim());
    nameError = name.text.trim().isEmpty ? '품목명을 입력하세요' : null;
    qtyError = q == null || q <= 0 ? '1 이상 입력' : null;
    priceError = p == null || p < 0 ? '단가를 입력하세요' : null;
    return nameError == null && qtyError == null && priceError == null;
  }

  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
  }
}

class _OrderEditSheet extends StatefulWidget {
  final String orderNumber;
  final List<Map<String, dynamic>> items;
  final VoidCallback onSaved;

  const _OrderEditSheet({
    required this.orderNumber,
    required this.items,
    required this.onSaved,
  });

  @override
  State<_OrderEditSheet> createState() => _OrderEditSheetState();
}

class _OrderEditSheetState extends State<_OrderEditSheet> {
  static const _categories = ['발주', '구매 요청', '현장 결제'];
  static final _dateFormat = DateFormat('yyyy.MM.dd');

  SupabaseClient get _supabase => Supabase.instance.client;

  // 업체: vendors 테이블에서 검색·선택 (vendor_id 기준 저장 — 이름 직접 입력은 DB 트리거가 되돌림)
  final TextEditingController _vendorCtrl = TextEditingController();
  late final String _originalVendor;
  List<Map<String, dynamic>> _vendors = [];
  bool _vendorsLoading = true;
  int? _selectedVendorId;
  String? _selectedVendorName;
  late final String _originalCategory;
  late final DateTime? _originalExpected;
  late final DateTime? _originalRevised;
  late final List<_ItemEditState> _items;

  String _category = '';
  DateTime? _expected;
  DateTime? _revised;
  String? _vendorError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final first = widget.items.isNotEmpty ? widget.items.first : <String, dynamic>{};

    _originalVendor = first['vendor_name']?.toString() ?? '';
    _vendorCtrl.text = _originalVendor;
    _category = first['payment_category']?.toString() ?? '';
    _originalCategory = _category;
    _expected = DateTime.tryParse(first['delivery_request_date']?.toString() ?? '');
    _originalExpected = _expected;
    _revised = DateTime.tryParse(first['revised_delivery_request_date']?.toString() ?? '');
    _originalRevised = _revised;

    _items = widget.items.map(_ItemEditState.new).toList();
    if (_items.length == 1) _items.first.expanded = true;

    _loadVendors();
    for (final item in _items) {
      for (final c in item.controllers) {
        c.addListener(_rebuild);
      }
    }
  }

  void _rebuild() => setState(() {});

  Future<void> _loadVendors() async {
    try {
      final data = await _supabase
          .from('vendors')
          .select('id, vendor_name, vendor_alias')
          .order('vendor_name');
      if (!mounted) return;
      setState(() {
        _vendors = List<Map<String, dynamic>>.from(data);
        _vendorsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _vendorsLoading = false);
    }
  }

  /// 업체명 + 별칭(vendor_alias)으로 부분 일치 검색
  List<DropdownMenuEntry<int>> _filterVendors(List<DropdownMenuEntry<int>> entries, String filter) {
    final q = filter.trim().toLowerCase();
    if (q.isEmpty || q == _currentVendorName.toLowerCase()) return entries;
    final aliasById = {
      for (final v in _vendors) v['id'] as int: (v['vendor_alias'] ?? '').toString().toLowerCase(),
    };
    return entries
        .where((e) => e.label.toLowerCase().contains(q) || (aliasById[e.value] ?? '').contains(q))
        .toList();
  }

  String get _currentVendorName => _selectedVendorName ?? _originalVendor;

  bool get _vendorChanged => _selectedVendorId != null && _selectedVendorName != _originalVendor;

  @override
  void dispose() {
    _vendorCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  bool get _hasChanges =>
      _vendorChanged ||
      _category != _originalCategory ||
      _expected != _originalExpected ||
      _revised != _originalRevised ||
      _items.any((i) => i.changed);

  String get _totalCurrency => _items.isEmpty ? 'KRW' : _items.first.currency;

  num get _total => _items.fold<num>(0, (sum, i) => sum + i.amount);

  Future<void> _pickDate({required bool revised}) async {
    final current = revised ? (_revised ?? _expected) : _expected;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDate: current ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (revised) {
        _revised = picked;
      } else {
        _expected = picked;
      }
    });
  }

  Future<void> _save() async {
    // 입력창 글자가 선택된 업체와 다르면(검색만 하고 고르지 않음) 저장 불가
    var valid = _vendorCtrl.text.trim() == _currentVendorName;
    _vendorError = valid ? null : '목록에서 업체를 선택하세요';
    for (final item in _items) {
      if (!item.validate()) {
        item.expanded = true;
        valid = false;
      }
    }
    setState(() {});
    if (!valid) {
      AppBanner.show(context, '입력값을 확인해 주세요', type: BannerType.warning);
      return;
    }

    setState(() => _saving = true);
    try {
      for (final item in _items) {
        final quantity = int.parse(item.qty.text.trim());
        final unitPrice = double.parse(item.price.text.trim());
        await _supabase.from('purchase_request_items').update({
          'item_name': item.name.text.trim(),
          'specification': item.spec.text.trim(),
          'quantity': quantity,
          'unit_price_value': unitPrice,
          'amount_value': quantity * unitPrice,
          'remark': item.remark.text.trim(),
        }).eq('id', item.row['id']);
      }

      await _supabase.from('purchase_requests').update({
        'delivery_request_date': _expected == null ? null : DateFormat('yyyy-MM-dd').format(_expected!),
        'revised_delivery_request_date': _revised == null ? null : DateFormat('yyyy-MM-dd').format(_revised!),
        // 카테고리는 purchase_requests에만 존재 (items에는 칼럼 없음)
        'payment_category': _category,
        // 업체 변경 시 vendor_id만 바꾸면 트리거가 vendor_name을 요청·품목에 전파.
        // 기존 담당자(contact_id)는 이전 업체 소속이므로 해제
        if (_vendorChanged) 'vendor_id': _selectedVendorId,
        if (_vendorChanged) 'contact_id': null,
      }).eq('purchase_order_number', widget.orderNumber);

      if (!mounted) return;
      Navigator.of(context).pop();
      AppBanner.show(context, '수정이 완료되었습니다', type: BannerType.success);
      widget.onSaved();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppBanner.show(context, '저장하지 못했습니다. 다시 시도해 주세요.', type: BannerType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditSheetFrame(
      title: '발주 수정',
      subtitle: [widget.orderNumber, if (_originalVendor.isNotEmpty) _originalVendor].join(' · '),
      hasChanges: _hasChanges,
      saving: _saving,
      onSave: _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetSectionLabel('기본 정보'),
          // 카테고리와 업체는 한 행에 배치
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('카테고리', style: AppTextStyles.inputLabel(context)),
                    const SizedBox(height: 6),
                    _buildCategoryDropdown(),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      const TextSpan(
                        text: '업체',
                        children: [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                      style: AppTextStyles.inputLabel(context),
                    ),
                    const SizedBox(height: 6),
                    _buildVendorDropdown(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDateRows(),
          const SizedBox(height: 24),
          _SheetSectionLabel(
            '품목 ${_items.length}개',
            trailing: Text(
              '합계 ${CurrencyFormatter.formatWon(_total, _totalCurrency)}',
              style: AppTextStyles.cardBody(context).copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildItemList(),
        ],
      ),
    );
  }

  Widget _buildVendorDropdown() {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: width),
        );

    return DropdownMenu<int>(
      controller: _vendorCtrl,
      expandedInsets: EdgeInsets.zero,
      menuHeight: 280,
      enabled: !_vendorsLoading,
      enableFilter: true,
      requestFocusOnTap: true,
      filterCallback: _filterVendors,
      hintText: _vendorsLoading ? '업체 목록 불러오는 중' : '업체명 검색',
      errorText: _vendorError,
      leadingIcon: const Icon(Icons.search, size: 16, color: AppColors.textTertiary),
      trailingIcon: const Icon(Icons.arrow_drop_down,
          size: 18, color: AppColors.textTertiary),
      selectedTrailingIcon: const Icon(Icons.arrow_drop_up,
          size: 18, color: AppColors.textTertiary),
      textStyle: AppTextStyles.tableCell(context),
      inputDecorationTheme: InputDecorationThemeData(
        isDense: true,
        filled: false,
        // 앱 공통 입력 컨트롤 높이(40)로 고정
        constraints: const BoxConstraints(minHeight: 40, maxHeight: 40),
        // 기본 아이콘 터치영역(48)이 필드 높이를 키워서 앞/뒤 아이콘 모두 제한
        prefixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        hintStyle: AppTextStyles.tableCell(context, color: AppColors.textDisabled),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        disabledBorder: border(AppColors.borderLight),
        focusedBorder: border(AppColors.primary, 1.5),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 1.5),
      ),
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(4),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.borderLight),
          ),
        ),
      ),
      dropdownMenuEntries: [
        for (final v in _vendors)
          DropdownMenuEntry<int>(
            value: v['id'] as int,
            label: (v['vendor_name'] ?? '').toString(),
            labelWidget: _vendorLabel(v),
            style: MenuItemButton.styleFrom(
              minimumSize: const Size.fromHeight(38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
      ],
      onSelected: (id) {
        if (id == null) return;
        final v = _vendors.firstWhere((e) => e['id'] == id);
        setState(() {
          _selectedVendorId = id;
          _selectedVendorName = (v['vendor_name'] ?? '').toString();
          _vendorError = null;
        });
      },
    );
  }

  Widget _vendorLabel(Map<String, dynamic> v) {
    final alias = (v['vendor_alias'] ?? '').toString().trim();
    return Text.rich(
      TextSpan(
        text: (v['vendor_name'] ?? '').toString(),
        children: [
          if (alias.isNotEmpty)
            TextSpan(
              text: '  $alias',
              style: AppTextStyles.listSubtitle(context),
            ),
        ],
      ),
      style: AppTextStyles.tableCell(context),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _categories.contains(_category) ? _category : null,
          hint: Text(
            '카테고리 선택',
            style: AppTextStyles.tableCell(context, color: AppColors.textDisabled),
          ),
          icon: const Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: AppColors.textTertiary,
          ),
          isExpanded: true,
          isDense: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(8),
          elevation: 4,
          menuMaxHeight: 320,
          style: AppTextStyles.tableCell(context),
          items: _categories
              .map(
                (value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: AppTextStyles.tableCell(context)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _category = value);
          },
        ),
      ),
    );
  }


  Widget _buildDateRows() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _dateRow('입고예정일', _expected, () => _pickDate(revised: false)),
          const Divider(height: 1, thickness: 1, color: AppColors.borderLight),
          _dateRow('변경요청일', _revised, () => _pickDate(revised: true)),
        ],
      ),
    );
  }

  Widget _dateRow(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.inputLabel(context)),
            const Spacer(),
            Text(
              value == null ? '선택 안 함' : _dateFormat.format(value),
              style: AppTextStyles.listTitle(context).copyWith(
                color: value == null ? AppColors.textDisabled : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildItemList() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.borderLight),
            _buildItemRow(_items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow(_ItemEditState item) {
    final hasError = item.nameError != null || item.qtyError != null || item.priceError != null;
    final name = item.name.text.trim();
    final spec = item.spec.text.trim();
    final qty = int.tryParse(item.qty.text) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => item.expanded = !item.expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name.isEmpty ? '품목명 없음' : name,
                              style: AppTextStyles.listTitle(context).copyWith(
                                color: hasError ? AppColors.error : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.changed) ...[
                            const SizedBox(width: 6),
                            _changedBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [if (spec.isNotEmpty) spec, '$qty개'].join(' · '),
                        style: AppTextStyles.listSubtitle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  CurrencyFormatter.formatWon(item.amount, item.currency),
                  style: AppTextStyles.listTitle(context).copyWith(fontWeight: FontWeight.w500),
                ),
                Icon(
                  item.expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (item.expanded)
          Container(
            color: AppColors.gray50,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SheetField(
                  label: '품목명',
                  controller: item.name,
                  hint: '품목명',
                  errorText: item.nameError,
                  required: true,
                ),
                const SizedBox(height: 12),
                _SheetField(label: '규격', controller: item.spec, hint: '규격'),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SheetField(
                        label: '수량',
                        controller: item.qty,
                        suffix: '개',
                        errorText: item.qtyError,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SheetField(
                        label: '단가',
                        controller: item.price,
                        suffix: CurrencyFormatter.unitLabel(item.currency),
                        errorText: item.priceError,
                        keyboardType: CurrencyFormatter.keyboardType(item.currency),
                        inputFormatters: CurrencyFormatter.inputFormatters(item.currency),
                        required: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SheetField(label: '비고', controller: item.remark, hint: '비고', maxLines: 2),
                const SizedBox(height: 12),
                _AmountLine(amount: item.amount, currency: item.currency),
              ],
            ),
          ),
      ],
    );
  }

  Widget _changedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '수정됨',
        style: AppTextStyles.chipSmall(context, color: AppColors.warning),
      ),
    );
  }
}
