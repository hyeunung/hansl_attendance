const axios = require('axios');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

async function testNotification() {
    try {
        console.log('🔔 알림 전송 테스트 시작...\n');
        
        // Edge Function URL
        const functionUrl = `${supabaseUrl}/functions/v1/send_fcm_notification`;
        
        // 테스트 알림 데이터
        const testData = {
            type: 'admin',  // 관리자들에게 알림
            title: '🧪 테스트 알림',
            body: '알림 시스템이 정상적으로 작동하는지 테스트 중입니다.',
            data: {
                type: 'test',
                timestamp: new Date().toISOString(),
                message: '테스트 알림입니다.'
            },
            requester_department: '연구소',
            requester_email: 'test@hansl.com'
        };
        
        console.log('📮 요청 데이터:');
        console.log(JSON.stringify(testData, null, 2));
        console.log('\n📡 Edge Function 호출 중...');
        
        const response = await axios.post(functionUrl, testData, {
            headers: {
                'Authorization': `Bearer ${supabaseServiceKey}`,
                'Content-Type': 'application/json'
            }
        });
        
        console.log('\n✅ 응답 받음:');
        console.log('   상태 코드:', response.status);
        console.log('   응답 데이터:', JSON.stringify(response.data, null, 2));
        
        if (response.data.success) {
            console.log('\n🎉 알림 전송 성공!');
            console.log(`   - 전체: ${response.data.total}명`);
            console.log(`   - 성공: ${response.data.success_count}명`);
            console.log(`   - 실패: ${response.data.failure_count}명`);
        } else {
            console.log('\n❌ 알림 전송 실패:', response.data.message);
        }
        
    } catch (error) {
        console.error('\n❌ 오류 발생:');
        if (error.response) {
            console.error('   상태 코드:', error.response.status);
            console.error('   오류 메시지:', error.response.data);
        } else {
            console.error('   오류:', error.message);
        }
    }
}

// 특정 사용자에게 알림 전송 테스트
async function testUserNotification(userEmail) {
    try {
        console.log(`\n🔔 특정 사용자(${userEmail})에게 알림 전송 테스트...\n`);
        
        const functionUrl = `${supabaseUrl}/functions/v1/send_fcm_notification`;
        
        const testData = {
            type: 'user',
            title: '✅ 휴가 승인 완료',
            body: '신청하신 휴가가 승인되었습니다.',
            data: {
                type: 'leave_result',
                status: 'approved',
                timestamp: new Date().toISOString()
            },
            user_email: userEmail
        };
        
        console.log('📮 요청 데이터:');
        console.log(JSON.stringify(testData, null, 2));
        
        const response = await axios.post(functionUrl, testData, {
            headers: {
                'Authorization': `Bearer ${supabaseServiceKey}`,
                'Content-Type': 'application/json'
            }
        });
        
        console.log('\n✅ 응답:', JSON.stringify(response.data, null, 2));
        
    } catch (error) {
        console.error('\n❌ 오류:', error.response?.data || error.message);
    }
}

// 실행
async function main() {
    // 1. 관리자들에게 테스트 알림
    await testNotification();
    
    // 2. 특정 사용자에게 테스트 (FCM 토큰이 있는 사용자 이메일로 변경)
    // await testUserNotification('hyun-woong.jeong@hansl.com');
}

main();