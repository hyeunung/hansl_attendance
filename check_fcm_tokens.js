const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkFCMTokens() {
    try {
        console.log('🔍 FCM 토큰 확인 중...\n');
        
        // 관리자 역할을 가진 사용자들 조회
        const { data: employees, error } = await supabase
            .from('employees')
            .select('email, name, fcm_token, attendance_role, department')
            .not('attendance_role', 'is', null);
        
        if (error) {
            console.error('❌ 조회 실패:', error.message);
            return;
        }
        
        // 관리자 분류
        const superAdmins = employees.filter(e => 
            e.attendance_role && e.attendance_role.includes('superadmin')
        );
        const admins = employees.filter(e => 
            e.attendance_role && e.attendance_role.includes('admin') && !e.attendance_role.includes('superadmin')
        );
        const managers = employees.filter(e => 
            e.attendance_role && e.attendance_role.some(r => r.includes('_manager'))
        );
        
        console.log('👑 SuperAdmin:');
        superAdmins.forEach(u => {
            const hasToken = u.fcm_token ? '✅' : '❌';
            const tokenInfo = u.fcm_token ? `${u.fcm_token.substring(0, 20)}...` : '토큰 없음';
            console.log(`   ${hasToken} ${u.name} (${u.email}): ${tokenInfo}`);
        });
        
        console.log('\n👔 Admin:');
        admins.forEach(u => {
            const hasToken = u.fcm_token ? '✅' : '❌';
            const tokenInfo = u.fcm_token ? `${u.fcm_token.substring(0, 20)}...` : '토큰 없음';
            console.log(`   ${hasToken} ${u.name} (${u.email}): ${tokenInfo}`);
        });
        
        console.log('\n🏢 Manager:');
        managers.forEach(u => {
            const hasToken = u.fcm_token ? '✅' : '❌';
            const tokenInfo = u.fcm_token ? `${u.fcm_token.substring(0, 20)}...` : '토큰 없음';
            console.log(`   ${hasToken} ${u.name} (${u.email}, ${u.department}): ${tokenInfo}`);
        });
        
        // 테스트 사용자의 FCM 토큰 확인
        const testUser = employees.find(e => e.email === 'test@hansl.com');
        if (testUser) {
            console.log('\n🧪 테스트 사용자:');
            const hasToken = testUser.fcm_token ? '✅' : '❌';
            const tokenInfo = testUser.fcm_token ? `${testUser.fcm_token.substring(0, 20)}...` : '토큰 없음';
            console.log(`   ${hasToken} ${testUser.name} (${testUser.email}): ${tokenInfo}`);
            console.log(`   부서: ${testUser.department}`);
            console.log(`   역할: ${JSON.stringify(testUser.attendance_role)}`);
        }
        
        // 통계
        const withToken = employees.filter(e => e.fcm_token).length;
        const withoutToken = employees.filter(e => !e.fcm_token).length;
        
        console.log('\n📊 통계:');
        console.log(`   전체 관리자/매니저: ${employees.length}명`);
        console.log(`   FCM 토큰 있음: ${withToken}명`);
        console.log(`   FCM 토큰 없음: ${withoutToken}명`);
        
    } catch (error) {
        console.error('❌ 오류:', error.message);
    }
}

checkFCMTokens();