const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkAllTables() {
  try {
    console.log('=== Supabase 연결 테스트 ===\n');
    console.log('URL:', supabaseUrl);
    console.log('Key (first 20 chars):', supabaseKey.substring(0, 20) + '...\n');

    // Try different possible table names
    const tableNames = ['leave', 'leaves', 'leave_requests', 'annual_leave', 'vacation'];
    
    for (const tableName of tableNames) {
      console.log(`\nChecking table: ${tableName}`);
      console.log('─'.repeat(40));
      
      const { data, error, count } = await supabase
        .from(tableName)
        .select('*', { count: 'exact', head: false })
        .limit(5);
      
      if (error) {
        if (error.code === '42P01') {
          console.log(`  ❌ Table '${tableName}' does not exist`);
        } else {
          console.log(`  ⚠️ Error: ${error.message}`);
        }
      } else {
        console.log(`  ✅ Table '${tableName}' exists!`);
        console.log(`  Total records: ${count || data.length}`);
        
        if (data && data.length > 0) {
          console.log(`  Sample columns: ${Object.keys(data[0]).join(', ')}`);
          
          // Check status distribution
          const statuses = {};
          for (const row of data) {
            if (row.status) {
              statuses[row.status] = (statuses[row.status] || 0) + 1;
            }
          }
          
          if (Object.keys(statuses).length > 0) {
            console.log('  Status distribution in sample:');
            Object.entries(statuses).forEach(([status, cnt]) => {
              console.log(`    ${status}: ${cnt}`);
            });
          }
        }
      }
    }

    // Also check employees table
    console.log('\n\nChecking employees table for comparison:');
    console.log('─'.repeat(40));
    
    const { data: employees, error: empError } = await supabase
      .from('employees')
      .select('name, email, used_annual_leave')
      .gt('used_annual_leave', 0)
      .order('used_annual_leave', { ascending: false })
      .limit(5);
    
    if (!empError && employees) {
      console.log(`Found ${employees.length} employees with used_annual_leave > 0:`);
      employees.forEach(emp => {
        console.log(`  ${emp.name}: ${emp.used_annual_leave}일`);
      });
    }

  } catch (error) {
    console.error('Unexpected error:', error);
  }
}

checkAllTables();