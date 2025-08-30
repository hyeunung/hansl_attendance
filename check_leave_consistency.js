const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkLeaveConsistency() {
  try {
    // First, let's check what columns exist in the leave table
    const { data: sampleLeave, error: sampleError } = await supabase
      .from('leave')
      .select('*')
      .limit(1);
    
    if (sampleError) {
      console.error('Error checking leave table structure:', sampleError);
    } else if (sampleLeave && sampleLeave.length > 0) {
      console.log('Leave table columns:', Object.keys(sampleLeave[0]));
    }

    // 1. Get all employees with their used_annual_leave
    const { data: employees, error: empError } = await supabase
      .from('employees')
      .select('id, name, email, used_annual_leave')
      .order('name');

    if (empError) {
      console.error('Error fetching employees:', empError);
      return;
    }

    // 2. Get all leave requests (check all statuses and types first)
    const { data: allLeaveRequests, error: allLeaveError } = await supabase
      .from('leave')
      .select('*');

    if (allLeaveError) {
      console.error('Error fetching all leave requests:', allLeaveError);
      return;
    }

    console.log('\n=== Leave 테이블 현황 ===');
    console.log('전체 leave 레코드 수:', allLeaveRequests.length);
    
    // Group by status
    const statusCounts = {};
    const typeCounts = {};
    
    allLeaveRequests.forEach(request => {
      statusCounts[request.status] = (statusCounts[request.status] || 0) + 1;
      typeCounts[request.type] = (typeCounts[request.type] || 0) + 1;
    });
    
    console.log('\n상태별 건수:');
    Object.entries(statusCounts).forEach(([status, count]) => {
      console.log(`  ${status}: ${count}건`);
    });
    
    console.log('\n타입별 건수:');
    Object.entries(typeCounts).forEach(([type, count]) => {
      console.log(`  ${type}: ${count}건`);
    });

    // Filter for approved annual leave
    const leaveRequests = allLeaveRequests.filter(request => 
      request.status === 'approved' && 
      (request.type === '연차' || request.type === 'annual')
    );
    
    console.log('\n승인된 연차 신청:', leaveRequests.length, '건\n');

    // 3. Calculate actual used leave per employee (matching by email)
    const actualUsedLeave = {};
    leaveRequests.forEach(request => {
      // Check which field contains the days value
      const daysField = request.days !== undefined ? 'days' : 
                       request.total_days !== undefined ? 'total_days' : 
                       null;
      
      if (!daysField) {
        console.warn('No days field found for leave request:', request);
        return;
      }
      
      if (!actualUsedLeave[request.user_email]) {
        actualUsedLeave[request.user_email] = 0;
      }
      actualUsedLeave[request.user_email] += parseFloat(request[daysField]);
    });

    // 4. Compare and report mismatches
    console.log('=== 연차 사용 일치성 검사 결과 ===\n');
    
    let mismatches = [];
    
    employees.forEach(emp => {
      const dbUsedLeave = emp.used_annual_leave || 0;
      const calculatedLeave = actualUsedLeave[emp.email] || 0;
      
      if (Math.abs(dbUsedLeave - calculatedLeave) > 0.01) { // Allow small floating point differences
        mismatches.push({
          name: emp.name,
          email: emp.email,
          id: emp.id,
          dbUsedLeave,
          calculatedLeave,
          difference: dbUsedLeave - calculatedLeave
        });
      }
    });

    if (mismatches.length === 0) {
      console.log('✅ 모든 직원의 사용연차가 정확히 일치합니다!\n');
    } else {
      console.log(`⚠️ ${mismatches.length}명의 직원에서 불일치 발견:\n`);
      console.log('이름\t\t\tDB 사용연차\t실제 승인연차\t차이');
      console.log('─'.repeat(60));
      
      mismatches.forEach(m => {
        console.log(`${m.name.padEnd(15)}\t${m.dbUsedLeave}\t\t${m.calculatedLeave}\t\t${m.difference > 0 ? '+' : ''}${m.difference}`);
      });
      
      console.log('\n📝 수정 제안:');
      mismatches.forEach(m => {
        console.log(`UPDATE employees SET used_annual_leave = ${m.calculatedLeave} WHERE id = '${m.id}'; -- ${m.name}`);
      });
    }

    // 5. Show summary
    console.log('\n=== 전체 요약 ===');
    console.log(`총 직원 수: ${employees.length}명`);
    console.log(`승인된 연차 신청 건수: ${leaveRequests.length}건`);
    console.log(`불일치 직원 수: ${mismatches.length}명`);
    
  } catch (error) {
    console.error('Unexpected error:', error);
  }
}

checkLeaveConsistency();