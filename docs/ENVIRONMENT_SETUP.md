# Environment Setup Guide

This guide explains where to place API keys and configuration for BucketPilot.

## Backend Configuration

### 1. Create `.env` file

In the `Backend/` directory, create a `.env` file from the template:

```bash
cd Backend
cp .env.example .env
```

### 2. Fill in your values

Edit `Backend/.env` with your actual API keys:

```env
# Server
PORT=3000
NODE_ENV=development

# Plaid (get from https://dashboard.plaid.com/)
PLAID_CLIENT_ID=your_client_id_here
PLAID_SECRET=your_secret_here
PLAID_ENVIRONMENT=sandbox

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/bucketpilot

# AI Service
OPENAI_API_KEY=sk-your_key_here
OPENAI_MODEL=gpt-4

# Generate these with openssl:
API_KEY_HASH=your_hash_here
ENCRYPTION_KEY=your_32_byte_key_here
```

### 3. Generate secure keys

```bash
# Generate API key hash
openssl rand -hex 32

# Generate encryption key for Plaid tokens
openssl rand -base64 32
```

### 4. Important: Never commit `.env`

The `.gitignore` file already excludes `.env` files. **Never commit these to version control.**

## iOS App Configuration

### API Keys & Secrets

**IMPORTANT**: iOS app should NEVER contain:
- Plaid client_id or secret (backend only)
- Plaid access tokens (backend only)
- OpenAI API keys (backend only)

### What iOS app needs:

1. **Backend URL** (non-sensitive)
   - Development: `http://localhost:3000`
   - Production: `https://your-backend.com`
   - Can be set via environment variable or build configuration

2. **API Key for Backend Authentication** (sensitive)
   - MUST be stored in iOS Keychain (see `Config.swift`)
   - Retrieved from backend during initial setup
   - Never hardcode in source

### Setup Process:

1. **User obtains API key from backend**
   - First-time setup: Backend generates API key
   - User copies key to iOS app

2. **iOS app stores in Keychain**
   ```swift
   Config.saveAPIKey("user_api_key_here")
   ```

3. **App uses key for all API requests**
   ```swift
   let apiKey = Config.getAPIKey()
   request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
   ```

### Configuration Options:

#### Option 1: Build Configuration (Recommended)

Create a `Config.xcconfig` file:

```xcconfig
// Config.xcconfig
BACKEND_URL = http://localhost:3000
```

Add to Xcode build settings.

#### Option 2: Environment Variables

Set via Xcode scheme:
- Product > Scheme > Edit Scheme
- Run > Arguments > Environment Variables
- Add: `BACKEND_URL` = `http://localhost:3000`

#### Option 3: Hardcode (Development Only)

In `Config.swift`, update default values:
```swift
static var backendURL: String {
    return "http://localhost:3000"
}
```

## Getting API Keys

### Plaid

1. Sign up at https://dashboard.plaid.com/
2. Create a new application
3. Get your `CLIENT_ID` and `SECRET`
4. Start with `sandbox` environment for testing
5. Use `development` for testing with real bank accounts
6. Use `production` for live app

### OpenAI

1. Sign up at https://platform.openai.com/
2. Go to API Keys section
3. Create new secret key
4. Copy key (starts with `sk-`)
5. Add to backend `.env` file

### Anthropic (Alternative)

1. Sign up at https://console.anthropic.com/
2. Create API key
3. Copy key (starts with `sk-ant-`)
4. Add to backend `.env` file

## Security Best Practices

### ✅ DO:

- Store `.env` file locally only
- Use iOS Keychain for API keys
- Use environment variables for non-sensitive config
- Rotate keys periodically
- Use different keys for dev/staging/production
- Encrypt sensitive data at rest (backend)

### ❌ DON'T:

- Commit `.env` files to git
- Hardcode API keys in source code
- Store keys in UserDefaults (iOS)
- Log API keys in console/logs
- Share keys in screenshots or messages
- Use production keys in development

## Environment-Specific Setup

### Development

**Backend:**
```env
NODE_ENV=development
PLAID_ENVIRONMENT=sandbox
DATABASE_URL=postgresql://localhost:5432/bucketpilot_dev
```

**iOS:**
- Backend URL: `http://localhost:3000`
- Use sandbox Plaid accounts

### Staging

**Backend:**
```env
NODE_ENV=staging
PLAID_ENVIRONMENT=development
DATABASE_URL=postgresql://staging-server:5432/bucketpilot_staging
```

**iOS:**
- Backend URL: `https://staging-api.bucketpilot.app`
- Use development Plaid accounts

### Production

**Backend:**
```env
NODE_ENV=production
PLAID_ENVIRONMENT=production
DATABASE_URL=postgresql://prod-server:5432/bucketpilot
```

**iOS:**
- Backend URL: `https://api.bucketpilot.app`
- Use production Plaid accounts

## Troubleshooting

### Backend can't read `.env` file

- Ensure `.env` is in `Backend/` directory
- Check file has correct format (no spaces around `=`)
- Restart server after changes

### iOS can't connect to backend

- Check backend URL in `Config.swift`
- Ensure backend is running
- For localhost on simulator: use `http://localhost:3000`
- For localhost on device: use your computer's IP (e.g., `http://192.168.1.100:3000`)

### API key not working

- Verify key is correct in iOS Keychain
- Check backend authentication middleware
- Ensure key hasn't expired or been rotated

## Quick Start Checklist

- [ ] Copy `Backend/.env.example` to `Backend/.env`
- [ ] Add Plaid credentials to `.env`
- [ ] Add OpenAI API key to `.env`
- [ ] Generate API key hash and encryption key
- [ ] Verify `.env` is in `.gitignore`
- [ ] Configure iOS backend URL in `Config.swift`
- [ ] Set up API key storage in iOS Keychain (via app settings)
