#!/bin/bash

echo "🔧 Applying migration 013: Fix manager leave update permissions..."

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Please install it first:"
    echo "   npm install -g supabase"
    exit 1
fi

# Apply the migration to local development environment
echo "📝 Applying migration to local environment..."
supabase db reset

if [ $? -eq 0 ]; then
    echo "✅ Local migration applied successfully"
else
    echo "❌ Local migration failed"
    exit 1
fi

# Instructions for production
echo ""
echo "🚀 To apply this migration to production:"
echo "   1. Push the migration to your remote Supabase project:"
echo "      supabase db push"
echo ""
echo "   2. Or manually run the SQL in your Supabase dashboard:"
echo "      - Go to Supabase Dashboard → SQL Editor"
echo "      - Copy and paste the contents of:"
echo "        supabase/migrations/013_fix_manager_leave_update.sql"
echo ""
echo "⚠️  Note: This migration will reset all existing leave table RLS policies"
echo "    and create new ones with proper manager permissions."