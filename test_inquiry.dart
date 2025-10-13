import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

// 테스트용 문의 등록 스크립트
void main() async {
  print('🔍 문의 등록 기능 테스트 시작...\n');
  
  // Supabase 초기화
  await Supabase.initialize(
    url: 'https://qvhbigvdfyvhoegkhvef.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE5MTQ2NTksImV4cCI6MjAzNzQ5MDY1OX0.xDxLKLYzJDPY-REjls3pKGUgrLkHbHkaueUXdGFZLow',
  );

  final supabase = Supabase.instance.client;
  
  try {
    // 1. 로그인 테스트
    print('1️⃣ 테스트 계정으로 로그인 중...');
    final authResponse = await supabase.auth.signInWithPassword(
      email: 'test@hansl.com',
      password: 'hansl!test!5890',
    );
    
    if (authResponse.user != null) {
      print('✅ 로그인 성공: ${authResponse.user!.email}\n');
    } else {
      print('❌ 로그인 실패\n');
      exit(1);
    }
    
    // 2. 사용자 정보 확인
    print('2️⃣ 사용자 정보 확인 중...');
    final employee = await supabase
        .from('employees')
        .select('name, email, purchase_role')
        .eq('email', authResponse.user!.email!)
        .single();
    
    print('✅ 사용자: ${employee['name']} (${employee['email']})\n');
    
    // 3. 문의 등록 테스트
    print('3️⃣ 문의 등록 테스트...');
    final testData = {
      'user_id': authResponse.user!.id,
      'user_email': employee['email'],
      'user_name': employee['name'],
      'inquiry_type': 'other',  // 테스트용
      'subject': '[테스트] ${DateTime.now()} 문의',
      'message': '문의 등록 기능 테스트입니다. 이 메시지가 보이면 성공!',
      'status': 'open',
    };
    
    print('   전송할 데이터:');
    testData.forEach((key, value) {
      print('   - $key: $value');
    });
    print('');
    
    final insertResponse = await supabase
        .from('support_inquiries')  // 올바른 테이블명 사용
        .insert(testData)
        .select()
        .single();
    
    print('✅ 문의 등록 성공!');
    print('   - ID: ${insertResponse['id']}');
    print('   - 생성일시: ${insertResponse['created_at']}\n');
    
    // 4. 등록된 문의 확인
    print('4️⃣ 등록된 문의 목록 확인...');
    final inquiries = await supabase
        .from('support_inquiries')
        .select('*')
        .eq('user_id', authResponse.user!.id)
        .order('created_at', ascending: false)
        .limit(3);
    
    print('✅ 최근 문의 ${inquiries.length}건 조회:');
    for (var inquiry in inquiries) {
      print('   - [${inquiry['status']}] ${inquiry['subject']}');
    }
    print('');
    
    // 5. 테스트 문의 삭제 (정리)
    print('5️⃣ 테스트 데이터 정리...');
    await supabase
        .from('support_inquiries')
        .delete()
        .eq('id', insertResponse['id']);
    
    print('✅ 테스트 문의 삭제 완료\n');
    
    print('🎉 모든 테스트 성공!');
    print('   문의 등록 기능이 정상적으로 작동합니다.');
    
  } catch (e) {
    print('\n❌ 테스트 실패!');
    print('에러: $e');
    exit(1);
  }
  
  exit(0);
}