const fetch = require('node-fetch');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

async function callEdgeFunction() {
  try {
    const response = await fetch(`${supabaseUrl}/functions/v1/update-kang-leave`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${supabaseAnonKey}`,
        'Content-Type': 'application/json'
      }
    });

    const result = await response.json();
    console.log('Edge function result:', result);
  } catch (error) {
    console.error('Error calling edge function:', error);
  }
}

callEdgeFunction();