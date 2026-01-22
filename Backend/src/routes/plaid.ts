/**
 * Plaid Integration Routes
 * Handles bank account connection and transaction sync (read-only)
 */

import express from 'express';
import { Configuration, PlaidApi, PlaidEnvironments } from 'plaid';
import { supabase, Tables } from '../db/supabase';

const router = express.Router();

// Initialize Plaid client
const configuration = new Configuration({
    basePath: PlaidEnvironments[process.env.PLAID_ENVIRONMENT || 'sandbox'],
    baseOptions: {
        headers: {
            'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID!,
            'PLAID-SECRET': process.env.PLAID_SECRET!,
        },
    },
});

const plaidClient = new PlaidApi(configuration);

async function getStoredAccessToken(userId: string): Promise<string | null> {
    const { data, error } = await supabase
        .from(Tables.PLAID_ITEMS)
        .select('access_token_encrypted')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
    
    if (error) {
        console.error('Error fetching Plaid access token:', error.message);
        return null;
    }
    
    return data?.access_token_encrypted ?? null;
}

/**
 * POST /plaid/create_link_token
 * Creates a Link token for Plaid Link flow
 */
router.post('/create_link_token', async (req, res) => {
    try {
        // TODO: Extract userId from auth middleware
        const userId = process.env.DEV_USER_ID;
        if (!userId) {
            return res.status(500).json({ error: 'DEV_USER_ID is not set' });
        }
        
        const request = {
            user: {
                client_user_id: userId,
            },
            client_name: 'BucketPilot',
            products: ['transactions'] as const,
            country_codes: ['US'] as const,
            language: 'en' as const,
        };
        
        const response = await plaidClient.linkTokenCreate(request);
        
        res.json({
            link_token: response.data.link_token,
        });
    } catch (error) {
        console.error('Error creating link token:', error);
        res.status(500).json({
            error: 'Failed to create link token',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});

/**
 * POST /plaid/exchange_public_token
 * Exchanges public token for access token (server-side only)
 */
router.post('/exchange_public_token', async (req, res) => {
    try {
        const { public_token } = req.body;
        const userId = process.env.DEV_USER_ID; // TODO: From auth
        if (!userId) {
            return res.status(500).json({ error: 'DEV_USER_ID is not set' });
        }
        
        if (!public_token) {
            return res.status(400).json({ error: 'public_token is required' });
        }
        
        const response = await plaidClient.itemPublicTokenExchange({
            public_token,
        });
        
        const { access_token, item_id } = response.data;
        
        const { error: upsertError } = await supabase
            .from(Tables.PLAID_ITEMS)
            .upsert(
                {
                    user_id: userId,
                    item_id,
                    access_token_encrypted: access_token,
                },
                { onConflict: 'item_id' }
            );
        
        if (upsertError) {
            throw upsertError;
        }
        
        res.json({
            success: true,
            item_id,
            // Never return access_token to client
        });
    } catch (error) {
        console.error('Error exchanging token:', error);
        res.status(500).json({
            error: 'Failed to exchange public token',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});

/**
 * GET /plaid/accounts
 * Fetches connected bank accounts
 */
router.get('/accounts', async (req, res) => {
    try {
        const userId = process.env.DEV_USER_ID; // TODO: From auth
        if (!userId) {
            return res.status(500).json({ error: 'DEV_USER_ID is not set' });
        }
        
        const storedToken = await getStoredAccessToken(userId);
        const access_token = storedToken || process.env.PLAID_ACCESS_TOKEN || '';
        
        if (!access_token) {
            return res.status(404).json({ error: 'No connected account' });
        }
        
        const response = await plaidClient.accountsGet({
            access_token,
        });
        
        res.json({
            accounts: response.data.accounts,
        });
    } catch (error) {
        console.error('Error fetching accounts:', error);
        res.status(500).json({
            error: 'Failed to fetch accounts',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});

/**
 * GET /plaid/transactions
 * Fetches transactions with cursor-based pagination
 */
router.get('/transactions', async (req, res) => {
    try {
        const { cursor, start_date, end_date } = req.query;
        const userId = process.env.DEV_USER_ID; // TODO: From auth
        if (!userId) {
            return res.status(500).json({ error: 'DEV_USER_ID is not set' });
        }
        
        const storedToken = await getStoredAccessToken(userId);
        const access_token = storedToken || process.env.PLAID_ACCESS_TOKEN || '';
        
        if (!access_token) {
            return res.status(404).json({ error: 'No connected account' });
        }
        
        // Default to last 30 days
        const endDate = end_date 
            ? new Date(end_date as string)
            : new Date();
        
        const startDate = start_date
            ? new Date(start_date as string)
            : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
        
        const response = await plaidClient.transactionsGet({
            access_token,
            start_date: startDate.toISOString().split('T')[0],
            end_date: endDate.toISOString().split('T')[0],
            cursor: cursor as string | undefined,
            count: 500,
        });
        
        res.json({
            transactions: response.data.transactions,
            total_transactions: response.data.total_transactions,
            next_cursor: response.data.next_cursor,
        });
    } catch (error) {
        console.error('Error fetching transactions:', error);
        res.status(500).json({
            error: 'Failed to fetch transactions',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});

export default router;
