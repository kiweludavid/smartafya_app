# Smart Afya Solution - Flutter Frontend

> Flutter frontend for Smart Afya Solution, a mental health consultation platform for clients and doctors.
> The app connects to the Smart Afya backend API and provides role-based workflows for booking, scheduling, consultation management, messaging, payments, and feedback.

---

## Table of Contents

1. [What This Frontend Does](#what-this-frontend-does)
2. [Tech Stack](#tech-stack)
3. [Supported Platforms](#supported-platforms)
4. [Project Structure](#project-structure)
5. [Setup Guide](#setup-guide)
6. [Environment Configuration](#environment-configuration)
7. [Running the App](#running-the-app)
8. [Frontend Features](#frontend-features)
9. [API Integration](#api-integration)
10. [Development Commands](#development-commands)
11. [Troubleshooting](#troubleshooting)
12. [Future Improvements](#future-improvements)

---

## What This Frontend Does

**Smart Afya Solution** is a Flutter app for managing mental health consultations across the client and doctor experience:

- **Clients** create accounts, book consultations, view appointments, join online sessions, submit payment proof, message care teams, and send feedback.
- **Doctors** manage availability, review assigned sessions, join consultations, submit reports, transfer patients, and handle session status updates.

The frontend is the user-facing layer for the FastAPI backend. It does not store business data locally beyond secure authentication tokens and UI state.

---

## Tech Stack

| Area | Technology |
|------|------------|
| Framework | Flutter |
| Language | Dart |
| State management | Provider |
| HTTP client | Dio |
| Auth storage | flutter_secure_storage |
| Environment config | flutter_dotenv |
| Notifications | flutter_local_notifications, timezone, flutter_timezone |
| Calendar UI | table_calendar |
| Fonts | google_fonts |
| Links and meeting launch | url_launcher |
| File selection | file_picker |
| Lints | flutter_lints |

---

## Supported Platforms

The repository contains Flutter platform folders for:

- Android
- iOS
- Web
- Windows
- macOS
- Linux

The main development target is the mobile app experience. Desktop and web support depend on backend accessibility, browser/device permissions, and plugin platform support.

---

## Project Structure

```text
SMART_AFYA/
|-- lib/
|   |-- main.dart                         # App entry point, routes, theme, providers
|   |-- logic/
|   |   `-- upcoming_session_resolver.dart # Session selection helpers
|   |-- screens/                          # Login, signup, role dashboards, workflows
|   |   |-- login_screen.dart
|   |   |-- signup_screen.dart
|   |   |-- home_screen_ui.dart
|   |   |-- client_booking_flow_screen.dart
|   |   |-- doctor_home_dashboard.dart
|   |   `-- ...
|   |-- services/
|   |   |-- api_client.dart               # Dio client, base URL, JWT interceptor
|   |   |-- api_service.dart              # Backend API methods and DTOs
|   |   |-- auth_service.dart             # Login, register, logout
|   |   `-- notification_service.dart      # Local notification setup
|   |-- state/
|   |   `-- client_home_controller.dart    # Client home state
|   `-- utils/                            # Formatting, errors, distance helpers
|-- assets/
|   `-- images/
|       `-- smart_afya_logo.png
|-- android/                              # Android platform project
|-- ios/                                  # iOS platform project
|-- web/                                  # Web platform project
|-- windows/                              # Windows platform project
|-- macos/                                # macOS platform project
|-- linux/                                # Linux platform project
|-- test/
|   `-- widget_test.dart
|-- pubspec.yaml                          # Flutter dependencies and assets
|-- analysis_options.yaml                 # Analyzer and lint configuration
`-- README.md
```

---

## Setup Guide

### Step 1 - Install Flutter

Install Flutter and make sure it is available in your terminal:

```bash
flutter --version
flutter doctor
```

Resolve any required platform setup reported by `flutter doctor`, especially Android Studio, Xcode, or desktop tooling depending on your target platform.

### Step 2 - Clone the repository

```bash
git clone https://github.com/olam-devs/smart_afya.git
cd smart_afya
```

### Step 3 - Install dependencies

```bash
flutter pub get
```

### Step 4 - Create the frontend `.env` file

Create a `.env` file in the project root:

```env
API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Use the URL where the backend API is reachable from the device or emulator running the app.

### Step 5 - Start the backend API

Run the Smart Afya backend separately before logging in or loading app data. The Flutter app expects the API to expose endpoints under `/api/v1`.

---

## Environment Configuration

The app loads environment variables from `.env` in `lib/main.dart` using `flutter_dotenv`.

Required frontend variable:

```env
API_BASE_URL=http://127.0.0.1:8000/api/v1
```

If `API_BASE_URL` is not provided, `ApiClient` uses these development defaults:

| Platform | Default API URL |
|----------|-----------------|
| Android emulator | `http://10.0.2.2:8000/api/v1` |
| iOS simulator | `http://127.0.0.1:8000/api/v1` |
| Web | `http://127.0.0.1:8000/api/v1` |
| Desktop | `http://127.0.0.1:8000/api/v1` |

For a physical Android or iOS device, use the backend machine's LAN address:

```env
API_BASE_URL=http://192.168.1.10:8000/api/v1
```

If Android receives `localhost` or `127.0.0.1` in `API_BASE_URL`, the app automatically maps it to `10.0.2.2` for emulator development.

---

## Running the App

Run on the default connected device:

```bash
flutter run
```

List available devices:

```bash
flutter devices
```

Run on a specific device:

```bash
flutter run -d <device-id>
```

Run on Chrome:

```bash
flutter run -d chrome
```

Build Android APK:

```bash
flutter build apk
```

Build web release:

```bash
flutter build web
```

---

## Frontend Features

### Authentication

- Login with email and password.
- Register as a client or doctor.
- Store JWT access tokens in secure storage.
- Attach `Authorization: Bearer <token>` automatically to API calls.
- Clear the token and return to login when the backend responds with `401 Unauthorized`.

### Client Experience

- Home dashboard with current care status and upcoming sessions.
- Mental health intake and consultation booking flow.
- Specialist selection and session preference collection.
- Audio, video, and physical session support.
- Appointment details with payment status, instructions, cancel, reschedule, and join actions.
- Chat list and session conversation screens.
- Medical records screen.
- Session feedback submission.

### Doctor Experience

- Doctor home dashboard focused on today's consultations and next session.
- Availability toggle and schedule management.
- Session detail view with meeting links, physical check-in/check-out, status updates, and reports.
- Consultation report submission.
- Patient transfer flow and transfer history.
- Messaging entry points for assigned conversations.

### Notifications and Scheduling

- Local notification service initialization at app startup.
- Timezone support for scheduled reminders.
- Calendar-based schedule UI through `table_calendar`.

---

## API Integration

The frontend communicates with the backend through `lib/services/api_client.dart` and `lib/services/api_service.dart`.

Important API areas used by the app:

- Auth: `/auth/login`, `/auth/register`
- Current user: `/users/me`, `/users/me/availability`
- Doctors: `/users/doctors`
- Bookings: `/bookings/`, `/bookings/my`, `/bookings/{id}`
- Sessions: `/sessions/`, `/sessions/{id}`
- Payments, feedback, reports, transfer, and chat endpoints through the shared API service layer

`ApiClient` configures:

- Base URL selection from `.env`
- Dio timeouts
- JSON request headers
- JWT request interceptor
- Unauthorized-response handling

`ApiService` owns the production API calls and DTO parsing used by screens. Prefer adding new backend calls there instead of calling Dio directly inside UI widgets.

---

## Development Commands

Install or refresh dependencies:

```bash
flutter pub get
```

Analyze Dart code:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Format Dart files:

```bash
dart format lib test
```

Check outdated dependencies:

```bash
flutter pub outdated
```

Upgrade dependencies carefully:

```bash
flutter pub upgrade
```

---

## Troubleshooting

### App cannot connect to backend

Check that the backend is running and that `API_BASE_URL` is reachable from the target device.

- Android emulator should use `10.0.2.2`, not `localhost`.
- iOS simulator, web, and desktop can usually use `127.0.0.1`.
- Physical devices need the computer's LAN IP address.

### Login succeeds on backend but app returns to login

Confirm the backend returns an `access_token` field from `/auth/login`. The app stores that token and uses it for authenticated requests.

### `.env` loading fails

Make sure `.env` exists in the project root. It is declared as an asset in `pubspec.yaml`, so run `flutter pub get` after creating or changing it.

### Meeting links do not open

Confirm the meeting link is a valid URL and that the target platform has a browser or app capable of opening it.

### Notifications do not appear

Check platform notification permissions, especially on Android and iOS. Local notification behavior can differ by OS version.

---

## Future Improvements

- Add dedicated integration tests for login, booking, scheduling, and feedback flows.
- Add golden tests for the main dashboards.
- Improve offline and retry behavior for weak network conditions.
- Expand environment examples for staging and production deployments.
- Add CI commands for analyze, format check, and tests.
- Rename the Flutter package from the starter name `flutter_application_1` to a production app package name.
