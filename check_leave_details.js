const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkLeaveDetails() {
  try {
    // Get all leave records
    const { data: allLeave, error } = await supabase
      .from('leave')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching leave:', error);
      return;
    }

    console.log('=== Leave 테이블 상세 분석 ===\n');
    console.log(`전체 레코드 수: ${allLeave.length}건\n`);

    if (allLeave.length > 0) {
      // Group by status
      const byStatus = {};
      allLeave.forEach(leave => {
        if (!byStatus[leave.status]) {
          byStatus[leave.status] = [];
        }
        byStatus[leave.status].push(leave);
      });

      console.log('=== 상태별 분류 ===');
      Object.entries(byStatus).forEach(([status, leaves]) => {
        console.log(`\n${status}: ${leaves.length}건`);
        console.log('─'.repeat(50));
        
        leaves.slice(0, 5).forEach(leave => {
          console.log(`  - ${leave.name} (${leave.user_email})`);
          console.log(`    타입: ${leave.type}, 기간: ${leave.start_date} ~ ${leave.end_date}`);
          console.log(`    일수: ${leave.days || leave.total_days || 'N/A'}일`);
          console.log(`    중간승인: ${leave.middle_manager_approval ? '✓' : '✗'}, 최종승인: ${leave.final_approval ? '✓' : '✗'}`);
          console.log(`    생성일: ${leave.created_at}`);
        });
        
        if (leaves.length > 5) {
          console.log(`  ... 외 ${leaves.length - 5}건`);
        }
      });

      // Group by type
      const byType = {};
      allLeave.forEach(leave => {
        if (!byType[leave.type]) {
          byType[leave.type] = 0;
        }
        byType[leave.type]++;
      });

      console.log('\n=== 타입별 분류 ===');
      Object.entries(byType).forEach(([type, count]) => {
        console.log(`${type}: ${count}건`);
      });

      // Check for annual leave specifically
      const annualLeaves = allLeave.filter(l => 
        l.type === '연차' || l.type === 'annual' || l.type === '연차휴가'
      );
      
      console.log('\n=== 연차 관련 레코드 ===');
      console.log(`연차 타입 레코드: ${annualLeaves.length}건`);
      
      if (annualLeaves.length > 0) {
        const annualByStatus = {};
        annualLeaves.forEach(leave => {
          annualByStatus[leave.status] = (annualByStatus[leave.status] || 0) + 1;
        });
        
        console.log('연차 상태별:');
        Object.entries(annualByStatus).forEach(([status, count]) => {
          console.log(`  ${status}: ${count}건`);
        });
      }

      // Show recent records
      console.log('\n=== 최근 5개 레코드 ===');
      allLeave.slice(0, 5).forEach((leave, idx) => {
        console.log(`\n${idx + 1}. ${leave.name} - ${leave.type} (${leave.status})`);
        console.log(`   기간: ${leave.start_date} ~ ${leave.end_date}`);
        console.log(`   승인 상태: 중간(${leave.middle_manager_approval}), 최종(${leave.final_approval})`);
      });

    } else {
      console.log('⚠️  Leave 테이블에 데이터가 없습니다!');
    }

  } catch (error) {
    console.error('Unexpected error:', error);
  }
}

checkLeaveDetails();