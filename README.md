## SMARTAFYA — Local development

This repo contains three projects:

- `smartafya_backend/smart_afya`: FastAPI backend (SQLite by default for local testing)
- `smartafya_admin/smartafya-admin-dashboard`: Next.js admin dashboard
- `smartafya_app/smartafya_app`: Flutter app (client/doctor)

### One-command start (recommended)

From the repo root:

```powershell
.\run-local.ps1
```

To stop the local servers:

```powershell
.\stop-local.ps1
```

### Backend (FastAPI + SQLite)

From `smartafya_backend/smart_afya`:

```powershell
python -m venv .venv
.\.venv\Scripts\python -m pip install --upgrade pip
.\.venv\Scripts\pip install -r requirements.txt

Copy-Item .env.example .env
.\.venv\Scripts\python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

- API base URL: `http://127.0.0.1:8000`
- Swagger docs: `http://127.0.0.1:8000/docs`
- On first start, the backend creates `smart_afya.db` and seeds the default admin from `.env`.

Default seeded admin (from `.env.example`):

- Email: `admin@smartafya.com`
- Password: `Admin@1234`

### Admin dashboard (Next.js)

From `smartafya_admin/smartafya-admin-dashboard`:

```powershell
Copy-Item .env.local.example .env.local
npm install
npm run dev
```

Open `http://localhost:3000` and sign in with the admin credentials above.

### Flutter app

From `smartafya_app/smartafya_app`:

```powershell
Copy-Item .env.example .env
flutter pub get
flutter run
```

The Flutter app reads `API_BASE_URL` from `.env` (asset). For Android emulator, use:

```env
API_BASE_URL=http://10.0.2.2:8000/api/v1
```

