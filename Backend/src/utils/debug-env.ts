/**
 * Debug utility to check environment variables
 * Run with: npx tsx src/utils/debug-env.ts
 */

import dotenv from 'dotenv';

dotenv.config();

console.log('Environment Variables Check:');
console.log('============================');
console.log('SUPABASE_URL:', process.env.SUPABASE_URL ? '✅ Set' : '❌ Missing');
console.log('SUPABASE_KEY:', process.env.SUPABASE_KEY ? '✅ Set' : '❌ Missing');
console.log('');
console.log('Values (first 20 chars):');
console.log('SUPABASE_URL:', process.env.SUPABASE_URL?.substring(0, 20) + '...');
console.log('SUPABASE_KEY:', process.env.SUPABASE_KEY?.substring(0, 20) + '...');
console.log('');
console.log('Full .env check:');
console.log('File location should be:', process.cwd() + '/.env');
console.log('Current working directory:', process.cwd());
