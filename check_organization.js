const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://qvhbigvdfyvhoegkhvef.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgxNDM2MCwiZXhwIjoyMDYzMzkwMzYwfQ.CTunNqWEcvsAo42kcKVSpSkHK66M1OIjlhdvIoCxn78'
);

async function fullReport() {
  const { data: employees } = await supabase
    .from('employees')
    .select('*')
    .order('department');
    
  console.log('============================================');
  console.log('📊 전체 조직 구조 및 승인 권한 보고서');
  console.log('============================================\n');
  
  // 부서별 그룹화
  const departments = {};
  employees?.forEach(emp => {
    const dept = emp.department || '부서없음';
    if (!departments[dept]) departments[dept] = [];
    departments[dept].push(emp);
  });
  
  // 각 부서별 보고
  Object.keys(departments).sort().forEach(dept => {
    console.log('\n【 ' + dept + ' 】');
    console.log('────────────────────────────────');
    
    const members = departments[dept];
    
    // 매니저 찾기
    const managers = members.filter(m => m.attendance_role && m.attendance_role.length > 0);
    const normalMembers = members.filter(m => !m.attendance_role || m.attendance_role.length === 0);
    
    if (managers.length > 0) {
      console.log('👔 매니저:');
      managers.forEach(mgr => {
        console.log('  ▶ ' + mgr.name + ' (' + mgr.email + ')');
        console.log('    권한: ' + JSON.stringify(mgr.attendance_role));
      });
    }
    
    console.log('\n👥 일반 직원:');
    if (normalMembers.length > 0) {
      normalMembers.forEach(mem => {
        console.log('  • ' + mem.name + ' (' + mem.email + ')');
      });
    } else {
      console.log('  (없음)');
    }
    
    console.log('\n🔸 승인 구조:');
    normalMembers.forEach(mem => {
      console.log('  ' + mem.name + '의 연차/출장 승인자:');
      
      // CAD 부서
      if (dept === 'CAD') {
        const cadManager = employees?.find(e => e.attendance_role?.includes('CAD_manager'));
        if (cadManager) {
          console.log('    → ' + cadManager.name + ' (CAD_manager)');
        }
      }
      // 개발1팀, 개발2팀
      else if (dept === '개발1팀' || dept === '개발2팀') {
        const devManager = employees?.find(e => e.attendance_role?.includes('개발팀_manager'));
        if (devManager) {
          console.log('    → ' + devManager.name + ' (개발팀_manager)');
        }
      }
      // 개발3팀
      else if (dept === '개발3팀') {
        const dev3Manager = employees?.find(e => e.attendance_role?.includes('개발3팀_manager'));
        if (dev3Manager) {
          console.log('    → ' + dev3Manager.name + ' (개발3팀_manager)');
        }
      }
      // 경영지원팀
      else if (dept === '경영지원팀') {
        const supportManager = employees?.find(e => e.attendance_role?.includes('경영지원팀_manager'));
        if (supportManager) {
          console.log('    → ' + supportManager.name + ' (경영지원팀_manager)');
        }
      }
      // 연구소
      else if (dept === '연구소') {
        const labManager = employees?.find(e => e.attendance_role?.includes('연구소_manager'));
        if (labManager) {
          console.log('    → ' + labManager.name + ' (연구소_manager)');
        }
      }
      
      // admin과 superadmin도 승인 가능
      const admin = employees?.find(e => e.attendance_role?.includes('admin'));
      const superadmin = employees?.find(e => e.attendance_role?.includes('superadmin'));
      
      if (admin) console.log('    → ' + admin.name + ' (admin)');
      if (superadmin) console.log('    → ' + superadmin.name + ' (superadmin)');
    });
  });
  
  console.log('\n\n============================================');
  console.log('📌 요약');
  console.log('============================================');
  
  const managers = employees?.filter(e => e.attendance_role && e.attendance_role.length > 0);
  console.log('\n🔸 전체 매니저 목록:');
  managers?.forEach(mgr => {
    console.log('  • ' + mgr.name + ' (' + mgr.email + ')');
    console.log('    - 역할: ' + JSON.stringify(mgr.attendance_role));
    console.log('    - 부서: ' + mgr.department);
    
    // 승인 가능한 부서들
    const roles = mgr.attendance_role || [];
    if (roles.includes('superadmin')) {
      console.log('    - 승인 가능: 모든 직원');
    } else if (roles.includes('admin')) {
      console.log('    - 승인 가능: superadmin 제외 모든 직원');
    } else if (roles.includes('CAD_manager')) {
      console.log('    - 승인 가능: CAD 부서 직원');
    } else if (roles.includes('개발팀_manager')) {
      console.log('    - 승인 가능: 개발1팀, 개발2팀 직원');
    } else if (roles.includes('개발3팀_manager')) {
      console.log('    - 승인 가능: 개발3팀 직원');
    } else if (roles.includes('경영지원팀_manager')) {
      console.log('    - 승인 가능: 경영지원팀 직원');
    } else if (roles.includes('연구소_manager')) {
      console.log('    - 승인 가능: 연구소 직원');
    }
    console.log('');
  });
}

fullReport();