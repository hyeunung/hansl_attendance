import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client with service role to bypass RLS
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get current user from auth header
    const authHeader = req.headers.get('authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'No authorization header' }),
        { 
          status: 401, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Verify user is authenticated
    const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''))
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { 
          status: 401, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Get all approved and pending leaves for calendar display (biztrip_migrated 제외)
    const { data: leaves, error } = await supabase
      .from('leave')
      .select(`
        *,
        employees!inner(name, department, email)
      `)
      .in('status', ['approved', 'pending'])
      .not('type', 'eq', 'biztrip_migrated')
      .order('created_at', { ascending: false })

    if (error) {
      console.error('Error fetching calendar leaves:', error)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch calendar data' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Format data for calendar
    const calendarLeaves = leaves.map(leave => ({
      id: leave.id,
      user_email: leave.user_email,
      name: leave.employees?.name || leave.name,
      department: leave.employees?.department,
      type: leave.type,
      status: leave.status,
      start_date: leave.start_date,
      end_date: leave.end_date,
      reason: leave.reason,
      desc: leave.desc,
      created_at: leave.created_at
    }))

    // Get business_trips for calendar
    const { data: businessTrips, error: btError } = await supabase
      .from('business_trips')
      .select('*, employees:requester_id(name, department, email)')
      .in('approval_status', ['approved', 'pending', 'completed'])
      .order('created_at', { ascending: false })

    if (btError) {
      console.error('Error fetching business trips for calendar:', btError)
    }

    const btCalendarLeaves = (businessTrips || []).map(bt => {
      const companionNames = (bt.companions || []).map((c: any) => c.name).filter(Boolean)
      const requesterName = bt.employees?.name || '알 수 없음'
      return {
        id: `bt_${bt.id}`,
        user_email: bt.employees?.email || '',
        name: requesterName,
        department: bt.employees?.department || bt.request_department,
        type: 'biztrip',
        status: bt.approval_status === 'completed' ? 'approved' : bt.approval_status,
        start_date: bt.trip_start_date,
        end_date: bt.trip_end_date,
        reason: bt.trip_purpose,
        place: bt.trip_destination,
        '출장자': [requesterName, ...companionNames],
        trip_code: bt.trip_code,
        is_business_trip: true,
        created_at: bt.created_at
      }
    })

    const allCalendarLeaves = [...calendarLeaves, ...btCalendarLeaves]

    return new Response(
      JSON.stringify(allCalendarLeaves),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Error in get_calendar_leaves:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
}) 