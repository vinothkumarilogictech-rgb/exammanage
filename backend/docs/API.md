# Office Management Mobile API

The API follows the same mobile-first separation used in the WorkLog project: authentication, dashboard, feature endpoints, serializers, permissions, filters, pagination and exception helpers are isolated under `api/`.

Base URL:

`http://<server-ip>:5000/api/v1`

## Authentication

### Login
`POST /auth/login/`

```json
{"username":"admin","password":"1234"}
```

Response contains `data.tokens.access` and `data.tokens.refresh`.

Send the access token on protected calls:

`Authorization: Bearer <access-token>`

### Refresh
`POST /auth/refresh/`

Send the refresh token as the Bearer token. A new access token is returned.

### Current user
`GET /auth/me/`

## Dashboard

`GET /dashboard/?branch_id=1`

Returns branch counts, scheduled/completed exams, pending results and expense totals.

## Branch Management

- `GET /branches/` — list/search branches
- `POST /branches/` — create branch
- `GET /branches/<id>/` — branch details
- `PUT /branches/<id>/` — update branch
- `DELETE /branches/<id>/` — deactivate branch

## Exam Management

- `GET /exams/types/`
- `POST /exams/types/`
- `GET /exams/branch-mappings/`
- `POST /exams/branch-mappings/`
- `GET /exams/sessions/`
- `POST /exams/sessions/`
- `GET /exams/candidates/`
- `GET /exams/attempts/`
- `GET /exams/dashboard/`

The API reads the same SQLAlchemy models used by the existing web Exam Management module, so mobile and web clients share the same data.

## Expense

- `GET /expenses/`
- `POST /expenses/`
- `GET /expenses/categories/`
- `POST /expenses/categories/`
- `GET /expenses/budgets/`
- `GET /expenses/summary/`

## Flutter architecture

```text
flutter_app/
├── lib/
│   ├── main.dart
│   ├── app_theme.dart
│   ├── models.dart
│   ├── providers/
│   │   └── auth_provider.dart
│   ├── services/
│   │   └── dio_client.dart
│   └── screens/
│       ├── login_screen.dart
│       ├── dashboard_screen.dart
│       ├── branches_screen.dart
│       ├── exams_screen.dart
│       └── expenses_screen.dart
└── pubspec.yaml
```

This intentionally follows the WorkLog pattern of using a central Dio client, Provider authentication state, models for API responses, and feature screens separated from networking code.
