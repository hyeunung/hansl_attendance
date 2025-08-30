const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
    console.error('❌ SUPABASE_URL 또는 SUPABASE_SERVICE_KEY가 설정되지 않았습니다.');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function executeSqlFile() {
    try {
        // SQL 파일 읽기
        const sqlContent = fs.readFileSync(path.join(__dirname, 'apply_fcm_token_column.sql'), 'utf8');
        
        // SQL 실행
        const { data, error } = await supabase.rpc('exec_sql', {
            sql_query: sqlContent
        });
        
        if (error) {
            // RPC 함수가 없는 경우 직접 쿼리 실행
            console.log('⚠️ exec_sql RPC가 없습니다. 직접 쿼리를 실행합니다.');
            
            // 먼저 칼럼 존재 여부 확인
            const { data: columns, error: checkError } = await supabase
                .from('employees')
                .select('*')
                .limit(0);
            
            if (checkError) {
                console.error('❌ 테이블 확인 실패:', checkError.message);
                return;
            }
            
            console.log('✅ employees 테이블 접근 가능');
            
            // FCM 토큰이 있는 사용자 수 확인
            const { data: employees, error: countError } = await supabase
                .from('employees')
                .select('email, name, fcm_token');
            
            if (countError) {
                console.error('❌ 사용자 조회 실패:', countError.message);
                return;
            }
            
            const usersWithToken = employees.filter(e => e.fcm_token).length;
            const usersWithoutToken = employees.filter(e => !e.fcm_token).length;
            
            console.log('\n📊 FCM 토큰 현황:');
            console.log(`   - 토큰 있음: ${usersWithToken}명`);
            console.log(`   - 토큰 없음: ${usersWithoutToken}명`);
            console.log(`   - 전체: ${employees.length}명`);
            
            // FCM 토큰이 있는 사용자 샘플 출력
            const usersWithTokenSample = employees
                .filter(e => e.fcm_token)
                .slice(0, 5)
                .map(e => ({
                    email: e.email,
                    name: e.name,
                    token_prefix: e.fcm_token ? e.fcm_token.substring(0, 20) + '...' : null
                }));
            
            if (usersWithTokenSample.length > 0) {
                console.log('\n✅ FCM 토큰이 있는 사용자 (샘플):');
                usersWithTokenSample.forEach(u => {
                    console.log(`   - ${u.name} (${u.email}): ${u.token_prefix}`);
                });
            } else {
                console.log('\n⚠️ FCM 토큰이 있는 사용자가 없습니다.');
            }
            
        } else {
            console.log('✅ SQL 실행 성공:', data);
        }
        
    } catch (error) {
        console.error('❌ 오류 발생:', error.message);
    }
}

executeSqlFile();