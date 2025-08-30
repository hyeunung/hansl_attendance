const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

async function testInsert() {
  try {
    // 먼저 테이블 구조 확인
    const { data: sample, error: sampleError } = await supabase
      .from('leave_requests')
      .select('*')
      .limit(1);
    
    if (sample && sample.length > 0) {
      console.log('테이블 구조 샘플:', Object.keys(sample[0]));
    }
    
    // 테스트 삽입
    const testData = {
      user_email: 'kkt@hansl.com',
      type: 'official',
      start_date: '2025-01-31',
      end_date: '2025-01-31',
      days: 1,
      reason: '장인어른 상',
      status: 'approved'
    };
    
    console.log('\n삽입할 데이터:', testData);
    
    const { data, error } = await supabase
      .from('leave_requests')
      .insert(testData)
      .select();
    
    if (error) {
      console.log('오류 발생:', error);
      console.log('오류 상세:', JSON.stringify(error, null, 2));
    } else {
      console.log('성공:', data);
    }
    
  } catch (error) {
    console.error('예외 발생:', error);
  }
}

testInsert();
