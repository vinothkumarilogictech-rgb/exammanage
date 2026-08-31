# Office Management Mobile API

Base URL: `/api/v1`

## Authentication
- `POST /auth/login/`
- `POST /auth/refresh/`
- `GET /auth/me/`

## Dashboard
- `GET /dashboard/?branch_id=<id>`

## Branch Management
- `GET /branches/?q=<text>&status=Active`
- `POST /branches/`
- `GET /branches/<id>/`
- `PUT /branches/<id>/`
- `DELETE /branches/<id>/` (deactivate)

## Exam Management
- `GET /exams/types/`
- `POST /exams/types/`
- `GET /exams/branch-mappings/`
- `POST /exams/branch-mappings/`
- `GET /exams/sessions/`
- `POST /exams/sessions/`
- `GET /exams/candidates/`
- `GET /exams/dashboard/`

## Expense
- `GET /expenses/`
- `POST /expenses/`
- `GET /expenses/categories/`
- `GET /expenses/budgets/`

All protected endpoints require:
`Authorization: Bearer <access-token>`
