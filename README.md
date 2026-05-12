# Smart Afya Solution — Backend API

> A production-ready mental health consultation platform built with **FastAPI**.
> Connects seamlessly with the Flutter mobile frontend.

---

## Table of Contents

1. [What This Backend Does](#what-this-backend-does)
2. [Tech Stack](#tech-stack)
3. [Project Structure](#project-structure)
4. [Setup Guide](#setup-guide)
5. [Environment Variables](#environment-variables)
6. [Running the Server](#running-the-server)
7. [API Reference](#api-reference)
8. [Authentication Guide](#authentication-guide)
9. [Flutter Integration](#flutter-integration)
10. [GitHub Workflow](#github-workflow)
11. [Future Improvements](#future-improvements)

---

## What This Backend Does

**Smart Afya Solution** is a mental health consultation platform that connects:

- **Clients (patients)** — book consultations, choose specialists, provide feedback
- **Doctors** — psychologists, psychiatrists, therapists, clerics, and influencer specialists
- **Admins** — manage bookings, assign doctors, oversee payments

### Core features:
- Patient consent enforcement before any booking
- Doctor assignment by admin or patient preference
- Session management (audio / video / physical)
- Specialist transfer system with full audit log
- Doctor unavailability notifications with reschedule/transfer options
- Negotiated payment system for physical sessions
- Dual feedback system (doctor performance + app UX)
- JWT-based authentication with role-based access control

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | FastAPI |
| Language | Python 3.11+ |
| Database (dev) | SQLite |
| Database (prod) | PostgreSQL |
| ORM | SQLAlchemy 2.0 |
| Auth | JWT (python-jose) |
| Password hashing | bcrypt (passlib) |
| Validation | Pydantic v2 |
| Server | Uvicorn |

---

## Project Structure

```
smart/
├── app/
│   ├── main.py                    # App entry point
│   ├── core/
│   │   ├── config.py              # Settings from .env
│   │   ├── security.py            # JWT + password hashing
│   │   ├── dependencies.py        # Auth guards & role checks
│   │   └── logging.py             # Logging setup
│   ├── db/
│   │   ├── base.py                # SQLAlchemy base
│   │   ├── session.py             # DB session factory
│   │   └── init_db.py             # Table creation + admin seed
│   ├── models/                    # Database tables
│   ├── schemas/                   # Request & response shapes
│   ├── repositories/              # Database access layer
│   ├── services/                  # Business logic
│   └── api/v1/endpoints/          # API route handlers
├── requirements.txt
├── .env.example
└── README.md
```

---

## Setup Guide

Follow these steps exactly — no prior backend experience needed.

### Step 1 — Clone the repository

```bash
git clone https://github.com/olam-devs/smart_afya.git
cd smart_afya
```

### Step 2 — Create a virtual environment

```bash
# Windows
python -m venv venv
venv\Scripts\activate

# macOS / Linux
python3 -m venv venv
source venv/bin/activate
```

You should see `(venv)` at the start of your terminal line.

### Step 3 — Install dependencies

```bash
pip install -r requirements.txt
```

This installs FastAPI, SQLAlchemy, JWT libraries, and everything else.

### Step 4 — Create your `.env` file

```bash
cp .env.example .env
```

Then open `.env` and update the values (see [Environment Variables](#environment-variables)).

### Step 5 — Run the server

```bash
uvicorn app.main:app --reload
```

The server starts at: `http://127.0.0.1:8000`

On first run the database is created automatically and an admin user is seeded.

---

## Environment Variables

Open `.env` and configure:

```env
# App
APP_NAME="Smart Afya Solution"
APP_ENV=development
DEBUG=true

# IMPORTANT: Change this to a long random string in production
SECRET_KEY=change-me-to-a-long-random-secret-key

ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60

# Database
# Development — SQLite (no setup needed)
DATABASE_URL=sqlite:///./smart_afya.db

# Production — PostgreSQL (uncomment and fill in)
# DATABASE_URL=postgresql://username:password@localhost:5432/smart_afya

# Admin account (created automatically on first run)
ADMIN_EMAIL=admin@smartafya.com
ADMIN_PASSWORD=Admin@1234
ADMIN_FULL_NAME=System Admin
```

> **Never commit your `.env` file to GitHub.** It is already in `.gitignore`.

---

## Running the Server

```bash
# Development (auto-reloads on file changes)
uvicorn app.main:app --reload

# Production
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

### After starting, open in your browser:

| URL | Description |
|-----|-------------|
| `http://localhost:8000` | Health check |
| `http://localhost:8000/docs` | Interactive Swagger UI |
| `http://localhost:8000/redoc` | ReDoc documentation |

---

## API Reference

### Base URL

```
http://localhost:8000/api/v1
```

---

### Auth

#### Register

```
POST /api/v1/auth/register
```

**Request:**
```json
{
  "full_name": "Jane Doe",
  "email": "jane@example.com",
  "phone": "+255700000000",
  "password": "Secret@123",
  "role": "client"
}
```

> `role` can be `"client"` or `"doctor"`.
> For doctors, add `"specialist_type"`: `"psychologist"` | `"psychiatrist"` | `"therapist"` | `"cleric"` | `"influencer"`

**Response `201`:**
```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "full_name": "Jane Doe",
  "email": "jane@example.com",
  "phone": "+255700000000",
  "role": "client",
  "specialist_type": null,
  "is_active": true,
  "is_available": true,
  "created_at": "2024-07-01T08:00:00Z"
}
```

---

#### Login

```
POST /api/v1/auth/login
```

**Request:**
```json
{
  "email": "jane@example.com",
  "password": "Secret@123"
}
```

**Response `200`:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

> Save this `access_token` — you need it for every protected request.

---

#### Create Booking

```
POST /api/v1/bookings/
```

> Requires authentication. Client only.

**Request:**
```json
{
  "mental_health_description": "I have been experiencing anxiety and panic attacks for 3 months.",
  "consent_given": true,
  "session_type": "video",
  "duration_minutes": 60,
  "preferred_dates": [
    "2024-07-10T10:00:00Z",
    "2024-07-11T14:00:00Z",
    "2024-07-12T09:00:00Z"
  ],
  "preferred_specialist_id": null
}
```

> `consent_given` **must be `true`** — the API rejects the request if false.
> `preferred_dates` **must have at least 3 dates**.
> `session_type`: `"audio"` | `"video"` | `"physical"`

**Response `201`:**
```json
{
  "id": "a1b2c3d4-...",
  "client_id": "3fa85f64-...",
  "preferred_specialist_id": null,
  "mental_health_description": "I have been experiencing...",
  "consent_given": true,
  "consent_timestamp": "2024-07-01T08:05:00Z",
  "session_type": "video",
  "duration_minutes": 60,
  "preferred_dates": "[\"2024-07-10T10:00:00Z\", ...]",
  "status": "pending",
  "created_at": "2024-07-01T08:05:00Z"
}
```

---

### Full Endpoint List

| Method | Endpoint | Who can use |
|--------|----------|-------------|
| POST | `/auth/register` | Public |
| POST | `/auth/login` | Public |
| GET | `/users/me` | Any logged-in user |
| PATCH | `/users/me` | Any logged-in user |
| PATCH | `/users/me/availability` | Doctor only |
| GET | `/users/doctors` | Any logged-in user |
| GET | `/users/` | Admin only |
| GET | `/users/{id}` | Admin only |
| PATCH | `/users/{id}/deactivate` | Admin only |
| POST | `/bookings/` | Client / Doctor |
| GET | `/bookings/my` | Client / Doctor |
| GET | `/bookings/` | Admin only |
| GET | `/bookings/{id}` | Owner or Admin |
| GET | `/sessions/` | Role-filtered |
| GET | `/sessions/{id}` | Owner or Admin |
| POST | `/sessions/{id}/assign` | Admin only |
| PATCH | `/sessions/{id}` | Doctor / Admin |
| POST | `/sessions/{id}/unavailable` | Doctor only |
| POST | `/transfers/sessions/{id}` | Doctor only |
| GET | `/transfers/sessions/{id}/history` | Any |
| GET | `/transfers/` | Admin only |
| POST | `/payments/` | Admin only |
| PATCH | `/payments/{id}` | Admin only |
| GET | `/payments/session/{id}` | Any |
| GET | `/payments/{id}` | Any |
| GET | `/payments/` | Admin only |
| POST | `/feedback/` | Client only |
| GET | `/feedback/my` | Client only |
| GET | `/feedback/` | Admin only (read-only) |
| GET | `/feedback/{id}` | Any |

---

## Authentication Guide

### Step 1 — Get your token

Call the login endpoint and save the `access_token` from the response.

### Step 2 — Add the token to every request

Add this header to all protected API calls:

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Token expiry

Tokens expire after **60 minutes** by default (set `ACCESS_TOKEN_EXPIRE_MINUTES` in `.env`).
Your Flutter app should re-login automatically when it receives a `401` response.

---

## Flutter Integration

### Install Dio

```yaml
# pubspec.yaml
dependencies:
  dio: ^5.4.0
  flutter_secure_storage: ^9.0.0
```

### API Client

```dart
// lib/services/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  // Android emulator → 10.0.2.2
  // iOS simulator    → localhost
  // Physical device  → your computer's local IP e.g. 192.168.x.x
  static const _base = 'http://10.0.2.2:8000/api/v1';

  final _storage = const FlutterSecureStorage();
  late final Dio dio;

  ApiClient() {
    dio = Dio(BaseOptions(baseUrl: _base));

    // Automatically attach saved token to every request
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          // Handle 401 — token expired
          if (error.response?.statusCode == 401) {
            // Navigate to login screen
          }
          handler.next(error);
        },
      ),
    );
  }
}
```

### Login

```dart
// lib/services/auth_service.dart
import 'api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final _client = ApiClient();
  final _storage = const FlutterSecureStorage();

  Future<void> login(String email, String password) async {
    final response = await _client.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    final token = response.data['access_token'];
    await _storage.write(key: 'access_token', value: token);
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String role = 'client',
  }) async {
    await _client.dio.post('/auth/register', data: {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'password': password,
      'role': role,
    });
  }
}
```

### Create a Booking

```dart
// lib/services/booking_service.dart
import 'api_client.dart';

class BookingService {
  final _client = ApiClient();

  Future<Map<String, dynamic>> createBooking({
    required String description,
    required String sessionType,   // 'audio' | 'video' | 'physical'
    required List<String> preferredDates,
    String? specialistId,
  }) async {
    final response = await _client.dio.post('/bookings/', data: {
      'mental_health_description': description,
      'consent_given': true,        // User must accept T&C before calling this
      'session_type': sessionType,
      'duration_minutes': 60,
      'preferred_dates': preferredDates,
      'preferred_specialist_id': specialistId,
    });
    return response.data;
  }

  Future<List<dynamic>> getMyBookings() async {
    final response = await _client.dio.get('/bookings/my');
    return response.data;
  }
}
```

### Error Handling

```dart
try {
  await authService.login(email, password);
} on DioException catch (e) {
  final message = e.response?.data['detail'] ?? 'Something went wrong';
  // Show message to user
  showSnackBar(message);
}
```

---

## GitHub Workflow

### Branch Structure

```
main          ← stable production code only
backend-dev   ← all backend (FastAPI) work
frontend-dev  ← all Flutter work
```

### Setting Up (First Time)

```bash
# Clone the repo
git clone https://github.com/olam-devs/smart_afya.git
cd smart_afya

# Backend developer — work on backend-dev
git checkout backend-dev

# Frontend developer — work on frontend-dev
git checkout frontend-dev
```

### Daily Workflow

```bash
# Always pull latest before starting work
git pull origin backend-dev   # or frontend-dev

# Make your changes, then commit
git add .
git commit -m "feat: add session transfer endpoint"

# Push to your branch
git push origin backend-dev
```

### Merging to main (Pull Request Flow)

1. Go to [github.com/olam-devs/smart_afya](https://github.com/olam-devs/smart_afya)
2. Click **"Compare & pull request"**
3. Set base branch to `main`, compare to `backend-dev`
4. Write a clear title and description
5. Request a review from your teammate
6. After approval — **Merge**

### Commit Message Convention

```
feat: add new feature
fix: fix a bug
refactor: improve code without changing behavior
docs: update README or comments
chore: config, dependencies, tooling
```

**Examples:**
```
feat: implement patient consent validation on booking
fix: return 404 when doctor not found in transfer
docs: update Flutter integration guide
```

---

## Future Improvements

### 1. Selcom Payment Gateway (Tanzania)

Replace the current mock payment with real Selcom push payments:

```python
# In app/services/payment_service.py
import httpx

async def initiate_selcom_payment(amount: float, phone: str, reference: str):
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://apigw.selcommobile.com/v1/checkout/initiate",
            headers={"Authorization": f"Bearer {SELCOM_API_KEY}"},
            json={"amount": amount, "msisdn": phone, "transid": reference},
        )
    return response.json()
```

### 2. Video Calls (Zoom / Google Meet)

Replace the mock meeting link with a real generated Zoom link:

```python
# In app/services/session_service.py
import httpx

async def create_zoom_meeting(topic: str, start_time: str) -> str:
    async with httpx.AsyncClient() as client:
        res = await client.post(
            "https://api.zoom.us/v2/users/me/meetings",
            headers={"Authorization": f"Bearer {ZOOM_JWT_TOKEN}"},
            json={"topic": topic, "type": 2, "start_time": start_time, "duration": 60},
        )
    return res.json()["join_url"]
```

### 3. Push Notifications

Use Firebase Cloud Messaging (FCM) to notify patients when:
- A doctor is assigned to their session
- Their doctor marks unavailable
- A transfer occurs

### 4. Deployment

| Platform | Command |
|----------|---------|
| **Railway** | Connect GitHub repo → set env vars → deploy |
| **Render** | New Web Service → `uvicorn app.main:app --host 0.0.0.0 --port $PORT` |
| **Docker** | `docker build -t smart-afya . && docker run -p 8000:8000 smart-afya` |
| **VPS** | Use `gunicorn` + `nginx` as reverse proxy |

### 5. Database Migrations (Alembic)

When you need to change the database schema safely in production:

```bash
alembic init alembic
alembic revision --autogenerate -m "add new column"
alembic upgrade head
```

---

## Quick Reference

| | |
|--|--|
| **Swagger UI** | `http://localhost:8000/docs` |
| **Health check** | `GET http://localhost:8000/` |
| **Default admin email** | `admin@smartafya.com` |
| **Default admin password** | `Admin@1234` (change in `.env`) |
| **Token header** | `Authorization: Bearer <token>` |
| **Token expiry** | 60 minutes (configurable) |

---

> Built with FastAPI · Maintained by the olam-devs team
