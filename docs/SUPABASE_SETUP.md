# Supabase Setup Guide

BucketPilot uses Supabase as the PostgreSQL database backend. This guide walks you through setting it up.

## 1. Create Supabase Project

1. Go to https://supabase.com and sign up/login
2. Click "New Project"
3. Fill in:
   - **Project Name**: `bucketpilot` (or your choice)
   - **Database Password**: Generate a strong password
   - **Region**: Choose closest to you
   - **Pricing Plan**: Free tier is fine for development

## 2. Get Your API Keys

1. In your Supabase project dashboard, go to **Settings** → **API**
2. Copy:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon/public key** (starts with `eyJ...`)

## 3. Set Up Database Schema

1. In Supabase dashboard, go to **SQL Editor**
2. Click **New Query**
3. Open `Backend/src/db/schema.sql` from this project
4. Copy and paste the entire SQL into the editor
5. Click **Run** (or press Cmd/Ctrl + Enter)

This will create:
- All required tables (users, buckets, transactions, events, etc.)
- Indexes for performance
- Row Level Security (RLS) policies

## 4. Configure Environment Variables

Add to your `Backend/.env` file:

```env
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_KEY=eyJ... (your anon key)
```

## 5. Verify Connection

Start your backend server:

```bash
cd Backend
npm install
npm run dev
```

You should see:
```
✅ Supabase connection verified
🚀 BucketPilot backend server running on port 3000
🗄️  Supabase: https://xxxxx.supabase.co
```

## Security: Row Level Security (RLS)

The schema includes RLS policies that are currently permissive (allow all). **For production**, you should update these to enforce proper access control.

### Example Production RLS Policy

```sql
-- Drop the permissive policy
DROP POLICY IF EXISTS "Allow all operations" ON buckets;

-- Create user-specific policy
CREATE POLICY "Users can only access their own buckets" ON buckets
  FOR ALL
  USING (auth.uid()::text = user_id::text)
  WITH CHECK (auth.uid()::text = user_id::text);
```

For now, the permissive policies allow development without authentication setup.

## Service Role Key (Optional)

For admin operations (like setting up initial users), you can use the service role key:

1. In Supabase dashboard: **Settings** → **API**
2. Copy **service_role** key (⚠️ Keep this secret!)
3. Add to `.env`:
   ```env
   SUPABASE_SERVICE_ROLE_KEY=eyJ... (service role key)
   ```

**Warning**: Service role key bypasses RLS. Only use on backend, never expose to clients.

## Database Features

### Automatic Timestamps

Most tables have `created_at` and `updated_at` columns that auto-update.

### UUID Primary Keys

All IDs use UUID v4, generated automatically via `uuid-ossp` extension.

### Event Sequencing

The `events` table uses `BIGSERIAL` for automatic sequence numbers, ensuring deterministic ordering.

## Troubleshooting

### Connection Failed

- Verify `SUPABASE_URL` and `SUPABASE_KEY` in `.env`
- Check Supabase project is active (not paused)
- Ensure no typos in the URL

### Schema Errors

- Make sure you ran the entire `schema.sql` file
- Check for existing tables (may need to drop them first)
- Verify PostgreSQL extensions are enabled

### RLS Blocking Queries

- Check RLS policies match your use case
- For development, use permissive policies
- For production, implement proper user authentication

## Next Steps

1. ✅ Database schema created
2. ⏭️ Implement user authentication
3. ⏭️ Update RLS policies for production
4. ⏭️ Add database migrations (if needed)

## Supabase Dashboard

Use the Supabase dashboard to:
- **Table Editor**: View and edit data
- **SQL Editor**: Run custom queries
- **API Docs**: Auto-generated API documentation
- **Logs**: Monitor queries and errors
- **Settings**: Configure database, auth, storage
