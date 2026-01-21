# BucketPilot Backend

Backend API server for BucketPilot iOS app. Handles Plaid integration, event sync, and AI copilot.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create `.env` file from template:
```bash
# Copy the template file
cp env.example.txt .env
```

3. Edit `.env` file and add your credentials:
   - **Supabase**: Get URL and anon key from https://supabase.com/dashboard/project/YOUR_PROJECT/settings/api
   - **Plaid**: Get credentials from https://dashboard.plaid.com/
   - **OpenAI**: Get API key from https://platform.openai.com/
   - Generate secure keys (see `env.example.txt` for details)

4. Set up Supabase database:
   - Create a new Supabase project at https://supabase.com
   - Run the SQL schema from `src/db/schema.sql` in Supabase SQL Editor
   - Copy your project URL and anon key to `.env`

4. Run development server:
```bash
npm run dev
```

**Important**: Never commit `.env` file to version control. See `../docs/ENVIRONMENT_SETUP.md` for detailed setup instructions.

## API Endpoints

### Plaid Integration
- `POST /plaid/create_link_token` - Create Plaid Link token
- `POST /plaid/exchange_public_token` - Exchange public token for access token
- `GET /plaid/accounts` - Fetch connected accounts
- `GET /plaid/transactions` - Fetch transactions (with cursor)

### Event Sync
- `POST /sync/pushEvents` - Push local events to server
- `GET /sync/pullEvents` - Pull events since last cursor

### AI Copilot
- `POST /ai/command` - Process user command, return structured actions

## Architecture

- **Express.js** - Web framework
- **Plaid API** - Bank account integration
- **PostgreSQL/SQLite** - Event log storage
- **OpenAI/Anthropic** - AI service (TODO)

## Security

- API key authentication (TODO: implement)
- Encrypted Plaid access tokens at rest
- No secrets in responses
- HTTPS only in production

## Development Status

This is a skeleton implementation. TODOs:
- [ ] Database schema and Prisma setup
- [ ] Authentication middleware
- [ ] Token encryption/decryption
- [ ] AI service integration
- [ ] Event log persistence
- [ ] Error handling improvements
- [ ] Rate limiting
- [ ] Logging
