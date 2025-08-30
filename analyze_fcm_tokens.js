const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function analyzeFCMTokens() {
    try {
        console.log('🔍 FCM 토큰 분석 중...\n');
        
        // 모든 직원의 FCM 토큰 조회
        const { data: employees, error } = await supabase
            .from('employees')
            .select('email, name, fcm_token, department, attendance_role')
            .not('fcm_token', 'is', null);
        
        if (error) {
            console.error('❌ 조회 실패:', error.message);
            return;
        }
        
        console.log(`📊 FCM 토큰이 있는 사용자: ${employees.length}명\n`);
        
        // 토큰 형식 분석 (iOS vs Android 구분)
        const iosTokens = [];
        const androidTokens = [];
        const unknownTokens = [];
        
        employees.forEach(emp => {
            const token = emp.fcm_token;
            const tokenLength = token.length;
            
            // FCM 토큰 패턴 분석
            // iOS FCM 토큰: 보통 길이가 더 짧고 특정 패턴
            // Android FCM 토큰: 보통 152자 정도, 콜론(:) 포함
            
            if (token.includes(':')) {
                // Android 토큰 (콜론 포함)
                androidTokens.push({
                    name: emp.name,
                    email: emp.email,
                    tokenPrefix: token.substring(0, 30),
                    tokenLength: tokenLength,
                    department: emp.department
                });
            } else if (tokenLength < 100) {
                // iOS 토큰 (짧은 길이)
                iosTokens.push({
                    name: emp.name,
                    email: emp.email,
                    tokenPrefix: token.substring(0, 30),
                    tokenLength: tokenLength,
                    department: emp.department
                });
            } else {
                // 구분하기 어려운 토큰
                unknownTokens.push({
                    name: emp.name,
                    email: emp.email,
                    tokenPrefix: token.substring(0, 30),
                    tokenLength: tokenLength,
                    department: emp.department
                });
            }
        });
        
        console.log('📱 Android 사용자 (추정):', androidTokens.length, '명');
        if (androidTokens.length > 0) {
            console.log('   샘플:');
            androidTokens.slice(0, 3).forEach(u => {
                console.log(`   - ${u.name} (${u.department}): ${u.tokenPrefix}... [길이: ${u.tokenLength}]`);
            });
        }
        
        console.log('\n🍎 iOS 사용자 (추정):', iosTokens.length, '명');
        if (iosTokens.length > 0) {
            console.log('   샘플:');
            iosTokens.slice(0, 3).forEach(u => {
                console.log(`   - ${u.name} (${u.department}): ${u.tokenPrefix}... [길이: ${u.tokenLength}]`);
            });
        }
        
        console.log('\n❓ 구분 불가:', unknownTokens.length, '명');
        if (unknownTokens.length > 0) {
            console.log('   샘플:');
            unknownTokens.slice(0, 3).forEach(u => {
                console.log(`   - ${u.name} (${u.department}): ${u.tokenPrefix}... [길이: ${u.tokenLength}]`);
            });
        }
        
        // 관리자의 플랫폼 확인
        console.log('\n👑 관리자/매니저 플랫폼 분석:');
        
        const admins = employees.filter(e => 
            e.attendance_role && (
                e.attendance_role.includes('superadmin') || 
                e.attendance_role.includes('admin') ||
                e.attendance_role.some(r => r.includes('_manager'))
            )
        );
        
        admins.forEach(admin => {
            const token = admin.fcm_token;
            let platform = '❓';
            
            if (token.includes(':')) {
                platform = '🤖 Android';
            } else if (token.length < 100) {
                platform = '🍎 iOS';
            }
            
            console.log(`   ${platform} ${admin.name} (${admin.email})`);
            console.log(`      토큰: ${token.substring(0, 40)}...`);
            console.log(`      길이: ${token.length}자`);
        });
        
        // 토큰 패턴 분석
        console.log('\n🔬 토큰 패턴 분석:');
        const tokenPatterns = new Map();
        
        employees.forEach(emp => {
            const token = emp.fcm_token;
            const pattern = token.substring(0, 10);
            
            if (!tokenPatterns.has(pattern)) {
                tokenPatterns.set(pattern, []);
            }
            tokenPatterns.get(pattern).push(emp.name);
        });
        
        console.log(`   서로 다른 패턴 수: ${tokenPatterns.size}개`);
        console.log('   주요 패턴:');
        Array.from(tokenPatterns.entries()).slice(0, 5).forEach(([pattern, users]) => {
            console.log(`   - "${pattern}...": ${users.length}명 (${users.slice(0, 2).join(', ')}${users.length > 2 ? ' 등' : ''})`);
        });
        
    } catch (error) {
        console.error('❌ 오류:', error.message);
    }
}

analyzeFCMTokens();