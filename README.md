# FlowStock WMS

Production-ready Warehouse Management System and Order Workflow platform built with Flutter, Riverpod, Supabase, PostgreSQL, realtime subscriptions, RBAC, and EGP as the default system currency.

## What Changed

- All demo users and mock data were removed
- The app now runs against real Supabase data only
- Currency formatting now uses `EGP`
- Order writes, inventory adjustments, and status changes are handled through secured SQL RPC functions
- Employee creation and management are handled through a Supabase Edge Function
- RBAC is enforced in both UI and backend policies

## Core Architecture

```text
lib/
  core/
  data/
  domain/
  presentation/
  modules/
docs/
supabase/
  migrations/
  functions/
```

## Required Setup

1. Apply the schema in `supabase/migrations/0001_initial_schema.sql`
2. Deploy the edge function in `supabase/functions/admin-manage-employee`
3. Run the app with real Supabase credentials:

```bash
flutter pub get
flutter run -d chrome ^
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

If credentials are missing, the app intentionally shows a setup-required screen and does not fall back to fake data.

## Security Model

- Supabase Auth is the only authentication source
- Only Admin can create, update, deactivate, or delete employee accounts
- Permissions are stored in:
  - `permissions`
  - `role_permissions`
  - `user_permissions`
- RLS is enabled on operational tables
- Mutations go through secured SQL functions or the admin employee edge function
- Activity is logged in `activity_logs`

## Business Rules

- Workflow: `ENTERED -> CHECKED -> APPROVED -> SHIPPED -> COMPLETED -> RETURNED`
- No skipping states in normal workflow
- Admin can override order status through a dedicated secured path
- Inventory decreases on `SHIPPED`
- Inventory increases on `RETURNED`
- All prices, totals, and profit values are displayed in `EGP`

## Key References

- ERD: `docs/erd.md`
- SQL schema and policies: `supabase/migrations/0001_initial_schema.sql`
- Employee management edge function: `supabase/functions/admin-manage-employee/index.ts`
