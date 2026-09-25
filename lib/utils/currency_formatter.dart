import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// 발주 통화(KRW/USD 등)에 맞춰 금액을 표시하는 헬퍼
class CurrencyFormatter {
  CurrencyFormatter._();

  static const _symbols = {
    'KRW': '₩',
    'USD': '\$',
    'EUR': '€',
    'JPY': '¥',
    'CNY': '¥',
  };

  static final _krwFormat = NumberFormat('#,##0');
  static final _decimalFormat = NumberFormat('#,##0.00');

  /// null/빈 값은 KRW로 간주
  static String normalize(String? currency) {
    final code = currency?.trim().toUpperCase() ?? '';
    return code.isEmpty ? 'KRW' : code;
  }

  static bool isKrw(String? currency) => normalize(currency) == 'KRW';

  static String symbol(String? currency) {
    final code = normalize(currency);
    return _symbols[code] ?? '$code ';
  }

  /// DB 값(num/String/null)을 숫자로 변환
  static num toNum(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// 기호 없이 숫자만 포맷 (KRW: 정수, 그 외: 소수점 2자리)
  static String formatNumber(Object? value, String? currency) {
    final v = toNum(value);
    return isKrw(currency) ? _krwFormat.format(v) : _decimalFormat.format(v);
  }

  /// 기호 포함 포맷 (예: ₩17,050 / $17,050.00)
  static String format(Object? value, String? currency) {
    return '${symbol(currency)}${formatNumber(value, currency)}';
  }

  /// 원화는 '원' 접미사, 외화는 기호 접두사 (예: 17,050원 / $17,050.00)
  static String formatWon(Object? value, String? currency) {
    final number = formatNumber(value, currency);
    return isKrw(currency) ? '$number원' : '${symbol(currency)}$number';
  }

  /// 입력란 단위 표시 (원 / USD 등)
  static String unitLabel(String? currency) =>
      isKrw(currency) ? '원' : normalize(currency);

  /// 금액 입력 키보드 (외화는 소수점 허용)
  static TextInputType keyboardType(String? currency) => isKrw(currency)
      ? TextInputType.number
      : const TextInputType.numberWithOptions(decimal: true);

  /// 금액 입력 포맷터 (원화: 정수, 외화: 소수점 2자리까지)
  static List<TextInputFormatter> inputFormatters(String? currency) => [
        isKrw(currency)
            ? FilteringTextInputFormatter.digitsOnly
            : FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ];

  /// 통화 단위에 맞춰 반올림 (원화: 정수, 외화: 소수점 2자리)
  static num round(num value, String? currency) => isKrw(currency)
      ? value.round()
      : (value * 100).round() / 100;

  /// DB row(Map)에서 통화 코드 추출
  static String fromRow(Map<String, dynamic>? row, {String? fallback}) {
    final value = row?['unit_price_currency'] ??
        row?['amount_currency'] ??
        row?['currency'] ??
        fallback;
    return normalize(value?.toString());
  }
}
