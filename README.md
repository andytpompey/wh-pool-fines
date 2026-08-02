# 🎱 RooBin Fines

A mobile-first web and iOS app for team matches, fines, subs and £10-per-playing-cycle access. Built with React, Vite and Supabase, with a native SwiftUI client.

## Product backlog

- [Master product backlog](docs/ROOBIN_MASTER_BACKLOG.md)
- [Cross-product story register](docs/BACKLOG_REGISTER.md)
- [Commercial model backlog](docs/COMMERCIAL_MODEL_BACKLOG.md)
- [Commercial production configuration](docs/COMMERCIAL_PRODUCTION_CONFIGURATION.md)
- [Commercial deferred actions](docs/COMMERCIAL_DEFERRED_ACTIONS.md)
- [League Management backlog](docs/LEAGUE_MANAGEMENT_BACKLOG.md)
- [iOS delivery backlog](docs/ios/IOS_BACKLOG.md)

## Product backlog

- [Master product backlog](docs/ROOBIN_MASTER_BACKLOG.md)
- [Cross-product story register](docs/BACKLOG_REGISTER.md)
- [Commercial model backlog](docs/COMMERCIAL_MODEL_BACKLOG.md)
- [League Management backlog](docs/LEAGUE_MANAGEMENT_BACKLOG.md)
- [iOS delivery backlog](docs/ios/IOS_BACKLOG.md)

---

## Stack

| Layer    | Tech                          |
|----------|-------------------------------|
| Frontend | React 18 + Vite               |
| Styling  | Tailwind CSS                  |
| Database | Supabase (hosted Postgres)    |
| Hosting  | Vercel (recommended)          |

---

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/wh-pool-fines.git
cd wh-pool-fines
npm install
```

### 2. Create a Supabase project

1. Go to [supabase.com](https://supabase.com) and sign up (free)
2. Click **New Project** — give it a name, pick a region close to you
3. Wait ~2 minutes for it to provision

### 3. Apply the database migrations

Install Docker Desktop, then verify the migration chain locally:

```bash
npx supabase start
npx supabase migration up --local
npx supabase test db
npx supabase db lint --local --schema public --level error
```

Do not use `supabase db reset` against this working environment: it deletes
local records. Use a separately created disposable database when a destructive
fresh-schema replay is specifically required.

To provision a remote development or staging project:

```bash
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase db push --linked --dry-run
npx supabase db push --linked
```

Verify the project reference carefully before the final command. Never test new
migrations against production first.

`supabase/migrations/` is the executable source of truth. `supabase/schema.sql`
is retained only as historical reference and must not be pasted into the SQL
Editor or used to provision a database.

### 4. Get your API keys

In your Supabase project go to **Settings → API** and copy:
- **Project URL** (looks like `https://xxxx.supabase.co`)
- **anon / public key** (the long JWT string)

### 5. Set up your environment

```bash
cp .env.example .env
```

Edit `.env` and fill in your keys:

```env
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
VITE_TWILIO_WHATSAPP_OTP_SEND_URL=https://your-api.example.com/auth/whatsapp/send
VITE_TWILIO_WHATSAPP_OTP_VERIFY_URL=https://your-api.example.com/auth/whatsapp/verify
```

### 6. Run locally

```bash
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) — you're live.

---

## Deploying to Vercel

1. Push your repo to GitHub
2. Go to [vercel.com](https://vercel.com) → **New Project** → import your repo
3. In **Environment Variables**, add:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
4. Click **Deploy**

Every push to `main` auto-deploys. Your app will have a URL like `https://wh-pool-fines.vercel.app`.

> **Note:** Never commit your `.env` file. It's already in `.gitignore`.

---


## Authentication (OTP)

The app now uses one-time passcode authentication with player records stored in `players`.

- **Email OTP:** uses Supabase native `signInWithOtp` + `verifyOtp` with `type: 'email'` (6-digit code entry in app).
- In Supabase **Auth → Email Templates**, install both repository templates:
  **Magic Link** uses `supabase/templates/magic_link.html` for returning users,
  while **Confirm signup** uses `supabase/templates/confirmation.html` for a
  new invited address. The confirmation link is intentional: the web request
  preserves the `/invite` redirect and the server separately verifies the
  authenticated email, invite token, status, and expiry before joining a team.
- **WhatsApp OTP:** uses Twilio via your own webhook/API endpoints.
- Players can store `email`, `mobile` (one or both), and choose a `preferred_auth_method`.

### Twilio WhatsApp integration

Supabase does not send WhatsApp OTP directly. Configure API endpoints that call Twilio Verify (or your preferred flow):

- `VITE_TWILIO_WHATSAPP_OTP_SEND_URL` (POST `{ mobile }`)
- `VITE_TWILIO_WHATSAPP_OTP_VERIFY_URL` (POST `{ mobile, token }`)

These endpoints should handle Twilio secrets server-side and return JSON `{ ok: true }` or `{ error: '...' }`.

## Importing existing data

If you have a JSON backup from the previous version of the app:

1. Open the app → **Setup → Data**
2. Paste the JSON into the Import box
3. Click **Import JSON**

This will overwrite all current data with the backup.

---

## Database schema

```
players        id, name, email, mobile, preferred_auth_method, auth_user_id
fine_types     id, name, cost
seasons        id, name, type (League|Cup)
matches        id, date, season_id, opponent, submitted
match_players  match_id, player_id  (who played)
fines          id, match_id, player_id, fine_type_id, player_name, fine_name, cost, paid
subs           id, match_id, player_id, player_name, amount, paid
app_users      id(auth.users), email, mobile, preferred_auth_method, player_id, role
```

`player_name` and `fine_name` are stored directly on fines/subs so historical records survive if a player is renamed or deleted.

---

## Admin PIN

The default admin PIN is `1234`. To change it, edit `ADMIN_PIN` at the top of `src/App.jsx` before deploying.

---

## Project structure

```
wh-pool-fines/
├── src/
│   ├── App.jsx                  # Root app, shared UI primitives
│   ├── main.jsx
│   ├── index.css
│   ├── lib/
│   │   ├── supabase.js          # Supabase client
│   │   ├── db.js                # Domain database operations
│   │   ├── auth.js              # Supabase auth helpers
│   │   └── userProfile.js       # app_users profile operations
│   └── components/
│       ├── Dashboard.jsx
│       ├── MatchesTab.jsx
│       ├── FinesTab.jsx
│       ├── SetupTab.jsx
│       └── AuthGate.jsx
├── supabase/
│   ├── migrations/              # Executable database source of truth
│   ├── config.toml              # Local Supabase configuration
│   └── schema.sql               # Historical reference; do not execute
├── .env.example                 # Copy to .env and fill in keys
├── .gitignore
├── index.html
├── vite.config.js
├── tailwind.config.js
└── package.json
```
