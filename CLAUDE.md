# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HANSL is a Flutter mobile application for attendance management and leave tracking for Korean company HANSL. The app integrates with Supabase for backend services, Firebase for push notifications, and Slack for team communication.

## Common Development Commands

### Flutter App Development
```bash
flutter pub get                    # Install dependencies
flutter run                       # Run on connected device/emulator
flutter build apk --release       # Build release APK
flutter test                      # Run tests
flutter analyze                   # Run static analysis
```

### Supabase Local Development
```bash
cd supabase
supabase start                     # Start local Supabase instance (port 54321)
supabase db reset                  # Reset database with migrations and seed data
supabase functions serve          # Serve edge functions locally
supabase gen types dart > lib/types/supabase.dart  # Generate types
```

## Architecture Overview

### Core Architecture Pattern
- **MVC + Provider Pattern**: Uses Provider for state management
- **Services Layer**: Handles external API integrations
- **Multi-platform**: Supports Android, iOS, Web, Windows, macOS

### Key Integrations
- **Supabase**: Backend database, auth, edge functions
- **Firebase**: Push notifications via FCM
- **Slack**: Team notifications and alerts
- **Location Services**: GPS-based attendance tracking

### Project Structure
```
lib/
├── main.dart                 # App entry point with provider setup
├── theme/                    # Design system (colors, fonts, shadows)
├── screens/                  # UI screens organized by feature
│   ├── splash/              # App launch screen
│   ├── auth/                # Login/authentication
│   ├── attendance/          # Clock in/out functionality  
│   ├── leave/               # Annual leave, business trips
│   ├── approval/            # Manager approval workflows
│   ├── calendar/            # Team/personal calendar
│   └── settings/            # User preferences
├── providers/               # State management (Provider pattern)
├── services/                # External API integrations
├── models/                  # Data models/classes
├── widgets/                 # Reusable UI components
├── utils/                   # Utility functions
└── constants/               # App-wide constants

supabase/
├── functions/               # Edge functions (TypeScript/Deno)
└── migrations/              # Database schema changes
```

### Data Architecture

#### Annual Leave System
- **calculate_annual_leave**: Calculates granted annual leave for employees
- **update_used_annual_leave**: Updates used leave and calculates remaining leave
- **anniversary_check**: Grants 15 days leave after 12 months service
- **annual_year_update**: Resets annual leave for new year

#### Core Data Models
- **employees**: User management with roles and Slack integration
- **attendance**: GPS-tracked time entries
- **leave_requests**: Multi-step approval workflow
- **monthly_attendance**: Aggregated attendance data

## Important Development Rules

### Problem-Solving Process (Critical)
**❌ Never immediately fix code when problems are reported**

**✅ Required Process:**
1. **Problem Analysis**: Understand current state and issues
2. **Root Cause Reporting**: Explain why problems occurred  
3. **Solution Proposal**: Present possible solutions
4. **User Confirmation**: Get approval before implementing
5. **Code Implementation**: Apply changes after approval

**🚀 Exception**: Skip analysis only when user explicitly says "바로 수정해줘", "즉시 적용해줘", "알아서 해줘"

### Database Migrations
- **Never modify existing migration files** - they may already be applied
- **Always create new migrations** for schema changes
- **Location**: `supabase/migrations/`  
- **Naming**: `00X_description.sql`

### Slack Integration
- **Use existing edge functions** for Slack messaging
- **Async required**: Use `PERFORM net.http_post()`, not `SELECT http_post()`
- **Role-based targeting**: Users via `employees.purchase_role` field

### Environment Configuration
- **Environment variables**: Uses `.env` file (not committed)
- **Required vars**: `SUPABASE_URL`, `SUPABASE_ANON_KEY` 
- **Korean timezone**: All time-related functionality uses Korea time
- **Multi-platform**: Same codebase runs on Android, iOS, Web, macOS, Windows

### Testing and Quality
- **Static Analysis**: `flutter analyze` with `flutter_lints` package
- **Widget Tests**: Located in `test/` directory using `flutter_test`
- **Manual Testing**: Test on multiple platforms before release

## Key Service Integrations

### Supabase Edge Functions
All backend business logic runs in Supabase edge functions (Deno/TypeScript):
- Authentication and authorization
- Annual leave calculations
- Attendance validation
- Slack notifications
- FCM push notifications

### Firebase Setup
- **FCM**: Push notifications for leave approvals, attendance reminders
- **Multi-platform**: Configured for iOS (`GoogleService-Info.plist`) and Android (`google-services.json`)

### Location Services
- **GPS Tracking**: Uses `geolocator` package for attendance verification
- **Validation**: Server-side location validation via edge functions

## Security Considerations
- **RLS Policies**: All database tables use Row Level Security
- **JWT Authentication**: Supabase JWT tokens for API access
- **Role-based Access**: Different permissions for employees, managers, admins
- **Environment Secrets**: API keys stored in environment variables, not code

## Performance Notes
- **Provider Pattern**: Efficient state management with selective rebuilds
- **Image Assets**: Optimized icons and splash screens for all platforms
- **Bundle Size**: Uses tree shaking and code splitting
- **Offline Capability**: Caches essential data locally