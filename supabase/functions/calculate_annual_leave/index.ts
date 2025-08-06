import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { userEmail, targetYear } = await req.json();

    if (!userEmail) {
      return new Response(
        JSON.stringify({ success: false, error: 'userEmail is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get employee data
    const { data: employee, error: employeeError } = await supabase
      .from('employees')
      .select('*')
      .eq('email', userEmail)
      .single();

    if (employeeError || !employee) {
      return new Response(
        JSON.stringify({ success: false, error: 'Employee not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Calculate annual leave based on join date and current year
    const joinDate = new Date(employee.join_date);
    const currentYear = targetYear || new Date().getFullYear();
    const serviceYears = currentYear - joinDate.getFullYear();

    let annualLeave = 15; // Default

    // Calculate based on service years
    if (serviceYears >= 10) {
      annualLeave = 25;
    } else if (serviceYears >= 5) {
      annualLeave = 20;
    } else if (serviceYears >= 3) {
      annualLeave = 18;
    } else if (serviceYears >= 1) {
      annualLeave = 15;
    } else {
      // First year calculation based on join date
      const monthsWorked = 12 - joinDate.getMonth();
      annualLeave = Math.floor((15 * monthsWorked) / 12);
    }

    // Update employee record
    const { error: updateError } = await supabase
      .from('employees')
      .update({
        annual_leave_granted_current_year: annualLeave,
        remaining_annual_leave: annualLeave
      })
      .eq('email', userEmail);

    if (updateError) {
      return new Response(
        JSON.stringify({ success: false, error: updateError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          userEmail,
          serviceYears,
          calculatedLeave: annualLeave,
          message: `${userEmail}의 ${currentYear}년 연차가 ${annualLeave}일로 설정되었습니다.`
        }
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});