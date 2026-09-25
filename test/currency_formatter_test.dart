import 'package:flutter_test/flutter_test.dart';
import 'package:hansl/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('KRW는 정수 + ₩/원', () {
      expect(CurrencyFormatter.format(17050, 'KRW'), '₩17,050');
      expect(CurrencyFormatter.formatWon(17050, 'KRW'), '17,050원');
      expect(CurrencyFormatter.format(1000, null), '₩1,000');
    });

    test('USD는 소수점 2자리 + \$', () {
      expect(CurrencyFormatter.format(17050, 'USD'), '\$17,050.00');
      expect(CurrencyFormatter.format(0.28, 'USD'), '\$0.28');
      expect(CurrencyFormatter.formatWon('5.67', 'usd'), '\$5.67');
    });

    test('DB row에서 통화 추출', () {
      expect(CurrencyFormatter.fromRow({'unit_price_currency': 'USD'}), 'USD');
      expect(CurrencyFormatter.fromRow({'currency': 'USD'}), 'USD');
      expect(CurrencyFormatter.fromRow({}), 'KRW');
      expect(CurrencyFormatter.fromRow(null), 'KRW');
    });

    test('통화 단위 반올림', () {
      expect(CurrencyFormatter.round(3 * 0.1, 'USD'), 0.3);
      expect(CurrencyFormatter.round(1000.6, 'KRW'), 1001);
    });
  });
}
