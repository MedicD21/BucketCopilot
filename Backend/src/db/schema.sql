-- BucketPilot Database Schema for Supabase
-- Run this in Supabase SQL Editor to create the tables

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE,
    api_key_hash VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Plaid Items (bank connections)
CREATE TABLE IF NOT EXISTS plaid_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    item_id VARCHAR(255) UNIQUE NOT NULL,
    access_token_encrypted TEXT NOT NULL,
    institution_id VARCHAR(255),
    institution_name VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Buckets (virtual envelopes)
CREATE TABLE IF NOT EXISTS buckets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    icon VARCHAR(50),
    color VARCHAR(7),
    target_type VARCHAR(20),
    target_amount DECIMAL(12,2),
    target_date DATE,
    priority INT DEFAULT 5,
    rollover_mode VARCHAR(20) DEFAULT 'rollover',
    rollover_cap DECIMAL(12,2),
    allow_negative BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Funding Rules
CREATE TABLE IF NOT EXISTS funding_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    enabled BOOLEAN DEFAULT true,
    priority INT NOT NULL,
    trigger_type VARCHAR(50) NOT NULL,
    conditions JSONB,
    actions JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Transactions
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plaid_transaction_id VARCHAR(255),
    account_id VARCHAR(255) NOT NULL,
    merchant_name VARCHAR(255),
    amount DECIMAL(12,2) NOT NULL,
    date DATE NOT NULL,
    category JSONB,
    description TEXT,
    is_pending BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_plaid_transaction UNIQUE (plaid_transaction_id)
);

-- Transaction Splits (transaction -> bucket mappings)
CREATE TABLE IF NOT EXISTS transaction_splits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    bucket_id UUID REFERENCES buckets(id) ON DELETE SET NULL,
    amount DECIMAL(12,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Allocation Events (event sourcing - append-only log)
CREATE TABLE IF NOT EXISTS allocation_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bucket_id UUID REFERENCES buckets(id) ON DELETE SET NULL,
    amount DECIMAL(12,2) NOT NULL,
    source_type VARCHAR(20) NOT NULL,
    source_id VARCHAR(255),
    timestamp TIMESTAMPTZ NOT NULL,
    sequence BIGSERIAL,
    device_id VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Events table (general event log for sync)
CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    sequence BIGSERIAL,
    payload JSONB NOT NULL,
    device_id VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_events_user_timestamp ON events(user_id, timestamp, sequence);
CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON transactions(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_plaid_id ON transactions(plaid_transaction_id);
CREATE INDEX IF NOT EXISTS idx_splits_transaction ON transaction_splits(transaction_id);
CREATE INDEX IF NOT EXISTS idx_splits_bucket ON transaction_splits(bucket_id);
CREATE INDEX IF NOT EXISTS idx_allocations_user_bucket ON allocation_events(user_id, bucket_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_rules_user_enabled ON funding_rules(user_id, enabled, priority);
CREATE INDEX IF NOT EXISTS idx_plaid_items_user ON plaid_items(user_id);

-- Row Level Security (RLS) Policies
-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE buckets ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE allocation_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE funding_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE plaid_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- For now, allow all operations (you can restrict based on user_id later)
-- In production, you'll want to create policies that match user_id from authenticated context
CREATE POLICY "Allow all operations" ON users FOR ALL USING (true);
CREATE POLICY "Allow all operations" ON buckets FOR ALL USING (true);
CREATE POLICY "Allow all operations" ON transactions FOR ALL USING (true);
CREATE POLICY "Allow all operations" ON transaction_splits FOR ALL USING (true);
CREATE POLICY "Allow all operations" ON allocation_events FOR ALL USING (true);
CREATE POLICY "Allow all operations" ON funding_rules FOR ALL USING (true);
CREATE POLICY "Allow all operations" ON plaid_items FOR ALL USING (true);
CREATE POLICY "Allow all operations" ON events FOR ALL USING (true);

-- Note: In production, replace the above policies with proper user-based RLS:
-- Example:
-- CREATE POLICY "Users can only access their own data" ON buckets
--   FOR ALL USING (auth.uid()::text = user_id::text);
