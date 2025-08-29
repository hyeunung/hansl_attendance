import 'package:flutter_test/flutter_test.dart';
import 'package:hansl/utils/validators/leave_validators.dart';
import 'package:hansl/models/leave_request.dart';

void main() {
  group('LeaveValidators', () {
    group('validateEmail', () {
      test('null 이메일 검증 실패', () {
        final result = LeaveValidators.validateEmail(null);
        expect(result, '이메일을 입력해주세요');
      });

      test('빈 이메일 검증 실패', () {
        final result = LeaveValidators.validateEmail('');
        expect(result, '이메일을 입력해주세요');
      });

      test('잘못된 형식의 이메일 검증 실패', () {
        final invalidEmails = [
          'notanemail',
          'missing@domain',
          '@nodomain.com',
          'spaces in@email.com',
          'double@@domain.com',
        ];

        for (final email in invalidEmails) {
          final result = LeaveValidators.validateEmail(email);
          expect(result, '올바른 이메일 형식이 아닙니다',
              reason: '$email should be invalid');
        }
      });

      test('올바른 이메일 검증 성공', () {
        final validEmails = [
          'user@example.com',
          'test.user@company.co.kr',
          'name+tag@domain.org',
          'user123@test-domain.com',
        ];

        for (final email in validEmails) {
          final result = LeaveValidators.validateEmail(email);
          expect(result, isNull, reason: '$email should be valid');
        }
      });
    });

    group('validateMemo', () {
      test('필수 메모가 비어있을 때 검증 실패', () {
        final result = LeaveValidators.validateMemo(null);
        expect(result, '메모를 입력해주세요');

        final result2 = LeaveValidators.validateMemo('   ');
        expect(result2, '메모를 입력해주세요');
      });

      test('선택적 메모가 비어있을 때 검증 성공', () {
        final result = LeaveValidators.validateMemo(null, isRequired: false);
        expect(result, isNull);
      });

      test('500자 초과 메모 검증 실패', () {
        final longMemo = 'a' * 501;
        final result = LeaveValidators.validateMemo(longMemo);
        expect(result, '메모는 500자 이내로 입력해주세요');
      });

      test('SQL Injection 패턴 검증 실패', () {
        final sqlInjectionTests = [
          "'; DROP TABLE users; --",
          "1' OR '1'='1",
          'SELECT * FROM users',
          'DELETE FROM table',
        ];

        for (final memo in sqlInjectionTests) {
          final result = LeaveValidators.validateMemo(memo);
          expect(result, '사용할 수 없는 문자가 포함되어 있습니다',
              reason: 'Should detect SQL injection in: $memo');
        }
      });

      test('HTML 태그 검증 실패', () {
        final htmlTests = [
          '<script>alert("XSS")</script>',
          '<div>content</div>',
          '&lt;encoded&gt;',
        ];

        for (final memo in htmlTests) {
          final result = LeaveValidators.validateMemo(memo);
          expect(result, 'HTML 태그는 사용할 수 없습니다',
              reason: 'Should detect HTML in: $memo');
        }
      });

      test('정상적인 메모 검증 성공', () {
        final validMemos = [
          '연차 사용합니다.',
          '가족 행사 참석차 연차 신청드립니다.',
          '병원 방문 예정입니다. (오전 반차)',
        ];

        for (final memo in validMemos) {
          final result = LeaveValidators.validateMemo(memo);
          expect(result, isNull, reason: '$memo should be valid');
        }
      });
    });

    group('validateDates', () {
      test('날짜가 선택되지 않았을 때 검증 실패', () {
        final emptyDates = <LeaveType, Set<DateTime>>{
          LeaveType.annual: {},
          LeaveType.halfAm: {},
          LeaveType.halfPm: {},
        };

        final result = LeaveValidators.validateDates(emptyDates);
        expect(result, '최소 1일 이상 선택해주세요');
      });

      test('과거 날짜 선택시 검증 실패', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final dates = <LeaveType, Set<DateTime>>{
          LeaveType.annual: {yesterday},
        };

        final result = LeaveValidators.validateDates(dates);
        expect(result, '과거 날짜는 선택할 수 없습니다');
      });

      test('30일 초과 연속 신청시 검증 실패', () {
        final today = DateTime.now();
        final dates = <LeaveType, Set<DateTime>>{
          LeaveType.annual: {
            today,
            today.add(const Duration(days: 31)),
          },
        };

        final result = LeaveValidators.validateDates(dates);
        expect(result, '한 번에 최대 30일까지만 신청 가능합니다');
      });

      test('정상적인 날짜 선택시 검증 성공', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final dates = <LeaveType, Set<DateTime>>{
          LeaveType.annual: {tomorrow},
          LeaveType.halfAm: {tomorrow.add(const Duration(days: 2))},
        };

        final result = LeaveValidators.validateDates(dates);
        expect(result, isNull);
      });
    });

    group('validatePlace', () {
      test('빈 출장지 검증 실패', () {
        final result = LeaveValidators.validatePlace(null);
        expect(result, '출장지를 입력해주세요');

        final result2 = LeaveValidators.validatePlace('   ');
        expect(result2, '출장지를 입력해주세요');
      });

      test('100자 초과 출장지 검증 실패', () {
        final longPlace = 'a' * 101;
        final result = LeaveValidators.validatePlace(longPlace);
        expect(result, '출장지는 100자 이내로 입력해주세요');
      });

      test('SQL Injection 패턴 검증 실패', () {
        final result = LeaveValidators.validatePlace("서울'; DROP TABLE--");
        expect(result, '사용할 수 없는 문자가 포함되어 있습니다');
      });

      test('정상적인 출장지 검증 성공', () {
        final validPlaces = [
          '서울시 강남구',
          '부산광역시 해운대구 센텀시티',
          '제주도',
          'Samsung Electronics, Suwon',
        ];

        for (final place in validPlaces) {
          final result = LeaveValidators.validatePlace(place);
          expect(result, isNull, reason: '$place should be valid');
        }
      });
    });

    group('validatePurpose', () {
      test('빈 업무 내용 검증 실패', () {
        final result = LeaveValidators.validatePurpose(null);
        expect(result, '업무 내용을 입력해주세요');
      });

      test('10자 미만 업무 내용 검증 실패', () {
        final result = LeaveValidators.validatePurpose('짧은 내용');
        expect(result, '업무 내용을 10자 이상 입력해주세요');
      });

      test('1000자 초과 업무 내용 검증 실패', () {
        final longPurpose = 'a' * 1001;
        final result = LeaveValidators.validatePurpose(longPurpose);
        expect(result, '업무 내용은 1000자 이내로 입력해주세요');
      });

      test('정상적인 업무 내용 검증 성공', () {
        final validPurposes = [
          '신제품 개발 회의 참석 및 기술 검토 진행',
          '고객사 미팅 및 계약 협의를 위한 방문입니다.',
          '본사 교육 프로그램 참가 예정',
        ];

        for (final purpose in validPurposes) {
          final result = LeaveValidators.validatePurpose(purpose);
          expect(result, isNull, reason: '$purpose should be valid');
        }
      });
    });

    group('sanitizeInput', () {
      test('HTML 태그 제거', () {
        final input = '<script>alert("test")</script>Normal text';
        final result = LeaveValidators.sanitizeInput(input);
        expect(result, 'Normal text');
      });

      test('앞뒤 공백 제거', () {
        final input = '   text with spaces   ';
        final result = LeaveValidators.sanitizeInput(input);
        expect(result, 'text with spaces');
      });

      test('연속된 공백을 하나로 변환', () {
        final input = 'text    with     multiple    spaces';
        final result = LeaveValidators.sanitizeInput(input);
        expect(result, 'text with multiple spaces');
      });

      test('복합 정제 테스트', () {
        final input = '  <b>Bold</b>  text   with    spaces  ';
        final result = LeaveValidators.sanitizeInput(input);
        expect(result, 'text with spaces');
      });
    });

    group('validateRemainingDays', () {
      test('잔여 일수 부족시 검증 실패', () {
        final result = LeaveValidators.validateRemainingDays(5.0, 7.0);
        expect(result, '신청 가능한 연차가 부족합니다 (잔여: 5.0일)');
      });

      test('잔여 일수 충분시 검증 성공', () {
        final result = LeaveValidators.validateRemainingDays(10.0, 5.0);
        expect(result, isNull);
      });

      test('잔여 일수와 요청 일수가 같을 때 검증 성공', () {
        final result = LeaveValidators.validateRemainingDays(5.0, 5.0);
        expect(result, isNull);
      });

      test('반차 계산 검증', () {
        final result = LeaveValidators.validateRemainingDays(0.5, 1.0);
        expect(result, '신청 가능한 연차가 부족합니다 (잔여: 0.5일)');

        final result2 = LeaveValidators.validateRemainingDays(1.5, 1.5);
        expect(result2, isNull);
      });
    });
  });
}