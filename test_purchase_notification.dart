import 'package:supabase_flutter/supabase_flutter.dart';

// 발주 알림 테스트 스크립트
// 실행: dart run test_purchase_notification.dart

void main() async {
  // Supabase 초기화
  await Supabase.initialize(
    url: 'https://tqyfakmpdijktyowsozw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRxeWZha21wZGlqa3R5b3dzb3p3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjU0NjIwNDQsImV4cCI6MjA0MTAzODA0NH0.RJ3z_qHRMlnvl0VHJiQraNmQT-YI0xKN7xXjGvdP9l4',
  );

  final supabase = Supabase.instance.client;

  try {
    print('🚀 발주 알림 테스트 시작...\n');

    // 1. 로그인 (테스트용 계정 - 필요시 변경)
    print('1️⃣ 로그인 중...');
    await supabase.auth.signInWithPassword(
      email: 'scott@thefiveforest.com', // 실제 계정으로 변경
      password: '1234', // 실제 비밀번호로 변경
    );
    print('✅ 로그인 성공\n');

    // 2. 현재 시간으로 고유한 발주번호 생성
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final purchaseOrderNumber = 'TEST-${timestamp.toString().substring(7)}';
    
    print('2️⃣ 테스트 발주 요청 생성 중...');
    print('   발주번호: $purchaseOrderNumber');
    
    // 3. 발주 요청 생성 (새 발주 알림 테스트)
    final purchaseResponse = await supabase.from('purchase_requests').insert({
      'purchase_order_number': purchaseOrderNumber,
      'requester_name': '테스트사용자',
      'requester_email': 'scott@thefiveforest.com',
      'payment_category': '구매 요청',
      'progress_type': '일반',
      'middle_manager_status': 'pending',
      'is_payment_completed': false,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    print('✅ 발주 요청 생성 완료');
    print('   → middle_manager 역할 사용자에게 "🆕 새 발주 승인 요청" 알림이 발송되어야 함\n');

    // 4. 발주 아이템 추가 (금액 계산용)
    print('3️⃣ 발주 아이템 추가 중...');
    await supabase.from('purchase_request_items').insert([
      {
        'purchase_order_number': purchaseOrderNumber,
        'item_name': '테스트 아이템 1',
        'quantity': 10,
        'unit_price_value': 1000,
        'amount_value': 10000,
      },
      {
        'purchase_order_number': purchaseOrderNumber,
        'item_name': '테스트 아이템 2',
        'quantity': 5,
        'unit_price_value': 2000,
        'amount_value': 10000,
      },
    ]);
    print('✅ 아이템 추가 완료 (총 금액: 20,000원)\n');

    // 5초 대기 (알림 발송 시간)
    print('⏳ 5초 대기 중...');
    await Future.delayed(Duration(seconds: 5));

    // 5. 1차 승인 처리 (최종 승인자 알림 테스트)
    print('\n4️⃣ 1차 승인 처리 중...');
    await supabase.from('purchase_requests')
      .update({
        'middle_manager_status': 'approved',
        'middle_manager_approved_at': DateTime.now().toIso8601String(),
      })
      .eq('purchase_order_number', purchaseOrderNumber);
    
    print('✅ 1차 승인 완료');
    print('   → consumable_manager와 app_admin에게 "🔍 최종 발주 승인 요청" 알림이 발송되어야 함\n');

    // 5초 대기
    print('⏳ 5초 대기 중...');
    await Future.delayed(Duration(seconds: 5));

    // 6. 최종 승인 처리 (승인 완료 & Lead Buyer 알림 테스트)
    print('\n5️⃣ 최종 승인 처리 중...');
    await supabase.from('purchase_requests')
      .update({
        'consumable_manager_status': 'approved',
        'consumable_manager_approved_at': DateTime.now().toIso8601String(),
      })
      .eq('purchase_order_number', purchaseOrderNumber);
    
    print('✅ 최종 승인 완료');
    print('   → 신청자에게 "✅ 발주 승인 완료" 알림이 발송되어야 함');
    print('   → lead buyer에게 "🛒 새로운 구매대기 항목" 알림이 발송되어야 함\n');

    // 7. 선진행 테스트
    print('\n6️⃣ 선진행 구매 요청 테스트...');
    final advancePurchaseNumber = 'ADV-TEST-${timestamp.toString().substring(7)}';
    
    await supabase.from('purchase_requests').insert({
      'purchase_order_number': advancePurchaseNumber,
      'requester_name': '테스트사용자2',
      'requester_email': 'test2@example.com',
      'payment_category': '구매 요청',
      'progress_type': '선진행',
      'middle_manager_status': 'pending',
      'is_payment_completed': false,
      'created_at': DateTime.now().toIso8601String(),
    });

    print('✅ 선진행 구매 요청 생성 완료');
    print('   → middle_manager에게 "🆕 [선진행] 새 발주 승인 요청" 알림이 발송되어야 함');
    print('   → lead buyer에게 "🛒 [선진행] 새로운 구매대기 항목" 알림이 발송되어야 함\n');

    print('\n✨ 테스트 완료!');
    print('📱 다음 사용자들의 기기에서 알림을 확인하세요:');
    print('   - middle_manager 권한 사용자');
    print('   - consumable_manager 권한 사용자');
    print('   - app_admin 권한 사용자');
    print('   - lead buyer 권한 사용자');
    print('   - 신청자 본인 (scott@thefiveforest.com)');

  } catch (e) {
    print('❌ 오류 발생: $e');
  } finally {
    // 로그아웃
    await supabase.auth.signOut();
  }
}
