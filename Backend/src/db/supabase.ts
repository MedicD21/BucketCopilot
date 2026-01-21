/**
 * Supabase Client Configuration
 * Initializes and exports Supabase client for database operations
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

// Ensure environment variables are loaded before checking them
// This works even if dotenv.config() hasn't been called yet
dotenv.config();

// Check configuration
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_KEY) {
    throw new Error('Missing Supabase configuration. Please set SUPABASE_URL and SUPABASE_KEY in your .env file');
}

// Initialize Supabase client with anon key (for public operations)
export const supabase: SupabaseClient = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_KEY
);

// Optional: Service role client for admin operations (server-side only)
// Use this for operations that bypass Row Level Security (RLS)
export const supabaseAdmin: SupabaseClient | null = process.env.SUPABASE_SERVICE_ROLE_KEY
    ? createClient(
          process.env.SUPABASE_URL!,
          process.env.SUPABASE_SERVICE_ROLE_KEY,
          {
              auth: {
                  autoRefreshToken: false,
                  persistSession: false,
              },
          }
      )
    : null;

/**
 * Database table names (matching schema)
 */
export const Tables = {
    EVENTS: 'events',
    BUCKETS: 'buckets',
    TRANSACTIONS: 'transactions',
    TRANSACTION_SPLITS: 'transaction_splits',
    ALLOCATION_EVENTS: 'allocation_events',
    FUNDING_RULES: 'funding_rules',
    PLAID_ITEMS: 'plaid_items',
    USERS: 'users',
} as const;

/**
 * Helper function to handle Supabase errors
 */
export function handleSupabaseError(error: any): never {
    console.error('Supabase error:', error);
    throw new Error(error.message || 'Database operation failed');
}
