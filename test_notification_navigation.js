const axios = require('axios');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

async function testLeaveRequestNotification() {
    try {
        console.log('📅 연차 신청 알림 테스트 시작...\n');
        
        const functionUrl = `${supabaseUrl}/functions/v1/send_fcm_notification`;
        
        const testData = {
            type: 'admin',
            title: '🏖️ 새로운 연차 신청',
            body: '테스트 직원님이 연차를 신청했습니다. (8/28)',
            data: {
                type: 'leave_request',  // 연차 신청 타입
                requester_email: 'test@hansl.com',
                requester_name: '테스트 직원',
                timestamp: new Date().toISOString()
            },
            requester_department: 'CAD',
            requester_email: 'test@hansl.com'
        };
        
        console.log('📮 연차 신청 알림 전송...');
        
        const response = await axios.post(functionUrl, testData, {
            headers: {
                'Authorization': `Bearer ${supabaseServiceKey}`,
                'Content-Type': 'application/json'
            }
        });
        
        console.log('✅ 응답:', response.data);
        console.log('\n💡 알림을 탭하면 관리자는 승인 탭으로, 일반 사용자는 홈으로 이동합니다.');
        
    } catch (error) {
        console.error('❌ 오류:', error.response?.data || error.message);
    }
}

async function testLeaveResultNotification() {
    try {
        console.log('\n✅ 연차 승인 결과 알림 테스트...\n');
        
        const functionUrl = `${supabaseUrl}/functions/v1/send_fcm_notification`;
        
        // 특정 사용자에게 승인 결과 알림
        const testData = {
            type: 'user',
            title: '✅ 연차 신청이 승인되었습니다',
            body: '8/28 연차가 승인되었습니다.',
            data: {
                type: 'leave_result',  // 연차 결과 타입
                status: 'approved',
                timestamp: new Date().toISOString()
            },
            user_email: 'hyun-woong.jeong@hansl.com'  // 실제 사용자 이메일로 변경 필요
        };
        
        console.log('📮 승인 결과 알림 전송...');
        
        const response = await axios.post(functionUrl, testData, {
            headers: {
                'Authorization': `Bearer ${supabaseServiceKey}`,
                'Content-Type': 'application/json'
            }
        });
        
        console.log('✅ 응답:', response.data);
        console.log('\n💡 알림을 탭하면 연차 현황 탭으로 이동합니다.');
        
    } catch (error) {
        console.error('❌ 오류:', error.response?.data || error.message);
    }
}

async function testBusinessTripNotification() {
    try {
        console.log('\n🚗 출장 신청 알림 테스트...\n');
        
        const functionUrl = `${supabaseUrl}/functions/v1/send_fcm_notification`;
        
        const testData = {
            type: 'admin',
            title: '🚗 새로운 출장 신청',
            body: '테스트 직원님이 출장을 신청했습니다. (8/29~8/30)',
            data: {
                type: 'business_trip',  // 출장 신청 타입
                requester_email: 'test@hansl.com',
                requester_name: '테스트 직원',
                timestamp: new Date().toISOString()
            },
            requester_department: 'CAD',
            requester_email: 'test@hansl.com'
        };
        
        console.log('📮 출장 신청 알림 전송...');
        
        const response = await axios.post(functionUrl, testData, {
            headers: {
                'Authorization': `Bearer ${supabaseServiceKey}`,
                'Content-Type': 'application/json'
            }
        });
        
        console.log('✅ 응답:', response.data);
        console.log('\n💡 알림을 탭하면 관리자는 승인 탭으로 이동합니다.');
        
    } catch (error) {
        console.error('❌ 오류:', error.response?.data || error.message);
    }
}

// 실행
async function main() {
    console.log('🔔 알림 네비게이션 테스트 시작\n');
    console.log('앱이 다음 상태일 때 모두 알림이 옵니다:');
    console.log('  - 📱 포그라운드 (앱 실행 중)');
    console.log('  - 🔄 백그라운드 (앱이 백그라운드에 있을 때)');
    console.log('  - 🚫 종료됨 (앱이 완전히 종료된 상태)\n');
    console.log('=' .repeat(50));
    
    // 1. 연차 신청 알림 (관리자들에게)
    await testLeaveRequestNotification();
    
    // 2초 대기
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // 2. 출장 신청 알림 (관리자들에게)
    await testBusinessTripNotification();
    
    // 2초 대기
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // 3. 연차 승인 결과 알림 (특정 사용자에게)
    // await testLeaveResultNotification();
}

main();