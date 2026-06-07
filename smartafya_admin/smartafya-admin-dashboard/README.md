# Smart Afya Admin Dashboard

Web admin console for **Smart Afya Solutions**—a mental health consultation platform. Operators use it to review booking requests, assign specialists, track sessions, and read client feedback. The dashboard talks to the Smart Afya **FastAPI** backend over REST.

## Features

| Area | Description |
|------|-------------|
| **Dashboard** | Summary stats and recent consultations that still need scheduling |
| **Consultations** | Full consultation list with search, status filters, and a workflow sheet to assign specialists, schedule sessions, and manage transfers |
| **Clients** | Browse registered clients from the API |
| **Specialists** | View doctors and other specialists (type, availability, verification status) |
| **Reports** | Session-oriented reporting and links into consultation detail |
| **Feedback** | Client ratings and comments after sessions |

Protected routes require a valid admin JWT stored in the browser after sign-in.

## Tech stack

- [Next.js](https://nextjs.org/) 16 (App Router)
- [React](https://react.dev/) 19
- [TypeScript](https://www.typescriptlang.org/)
- [Tailwind CSS](https://tailwindcss.com/) 4
- [shadcn/ui](https://ui.shadcn.com/) (Radix UI primitives)
- [Axios](https://axios-http.com/) and `fetch` for API calls

## Prerequisites

1. **Node.js** 18+ (20+ recommended)
2. **Smart Afya API** running locally or deployed (default: `http://localhost:8000`)
3. **Admin credentials** configured on the backend (login uses `/api/v1/admin/login`, with a fallback to `/api/v1/auth/login`)

## Getting started

### 1. Install dependencies

```bash
npm install
```

Or with pnpm:

```bash
pnpm install
```

### 2. Configure environment

Create a `.env.local` file in the project root:

```env
# Backend API base URL (no trailing slash)
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000

# Optional: request timeout in milliseconds (default: 15000)
NEXT_PUBLIC_API_TIMEOUT_MS=15000
```

Tip: you can copy the provided example file:

```bash
cp .env.local.example .env.local
```

### 3. Run the development server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). You will be redirected to `/login` until you sign in with admin credentials.

### 4. Production build

```bash
npm run build
npm start
```

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start Next.js in development mode |
| `npm run build` | Create an optimized production build |
| `npm start` | Serve the production build |
| `npm run lint` | Run ESLint |

## Authentication

- Sign-in posts email and password to the API and stores the `access_token` in `localStorage` under `smartafya_admin_access_token`.
- The admin layout checks for a token on load; missing tokens redirect to `/login`.
- Sign out clears the token and returns to the login page.

Ensure the backend accepts your admin user and that CORS allows requests from your dashboard origin when not using the same host.

## Project structure

```
app/
  (admin)/          # Protected admin pages (sidebar layout)
    page.tsx        # Dashboard
    consultations/
    clients/
    specialists/
    reports/
    feedback/
  login/            # Admin sign-in
components/         # UI and feature components (tables, workflow sheet, sidebar)
lib/                # API client, auth storage, shared types/utils
services/           # Domain API wrappers (consultations, clients, scheduling, etc.)
hooks/              # Shared React hooks
public/             # Static assets (logo, icons)
```

API types and low-level HTTP helpers live in `lib/api.ts`. Higher-level calls are grouped under `services/`.

## API integration

All data comes from the backend configured via `NEXT_PUBLIC_API_BASE_URL`. Typical endpoints include:

- `POST /api/v1/admin/login` — authentication
- `GET /api/v1/users/`, `/api/v1/users/doctors` — users and specialists
- `GET /api/v1/bookings/`, `/api/v1/sessions/` — bookings and sessions
- `POST /api/v1/sessions/{id}/assign` — assign a specialist and schedule
- `GET /api/v1/feedback/` — post-session feedback

If the API is unreachable or times out, pages show an error hint pointing at the configured base URL.

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| **Network / timeout errors** | API is running at `NEXT_PUBLIC_API_BASE_URL`; firewall and CORS |
| **401 on login** | Admin user exists; backend `.env` credentials match; API restarted after env changes |
| **Empty lists** | Token is valid; logged-in user has admin permissions on the API |
| **Stale data** | Refresh the page or use in-page actions that re-fetch (e.g. consultations workflow) |

## License

Private project. All rights reserved unless otherwise specified by the repository owner.
