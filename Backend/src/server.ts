/**
 * BucketPilot Backend Server
 * Express server with Plaid, Sync, and AI endpoints
 */

import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

// Load environment variables FIRST before importing anything that uses them
dotenv.config();

// Now import modules that depend on environment variables
import plaidRoutes from './routes/plaid';
import syncRoutes from './routes/sync';
import aiRoutes from './routes/ai';
import { supabase } from './db/supabase';

// Verify Supabase connection on startup
supabase
    .from('users')
    .select('count')
    .limit(1)
    .then(() => {
        console.log('✅ Supabase connection verified');
    })
    .catch((error) => {
        console.error('❌ Supabase connection failed:', error.message);
        console.error('Please check your SUPABASE_URL and SUPABASE_KEY in .env');
    });

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Root route
app.get('/', (req, res) => {
    res.json({
        name: 'BucketPilot Backend API',
        version: '1.0.0',
        status: 'running',
        timestamp: new Date().toISOString(),
        endpoints: {
            health: '/health',
            plaid: '/plaid/*',
            sync: '/sync/*',
            ai: '/ai/*'
        },
        documentation: 'See README.md for API documentation'
    });
});

// Health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Routes
app.use('/plaid', plaidRoutes);
app.use('/sync', syncRoutes);
app.use('/ai', aiRoutes);

// Error handling
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
    console.error('Unhandled error:', err);
    res.status(500).json({
        error: 'Internal server error',
        message: process.env.NODE_ENV === 'development' ? err.message : undefined,
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Not found' });
});

app.listen(PORT, () => {
    console.log(`🚀 BucketPilot backend server running on port ${PORT}`);
    console.log(`📦 Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`🗄️  Supabase: ${process.env.SUPABASE_URL || 'Not configured'}`);
});
