# Exam Voucher Management

Added as an integrated module for bulk exam voucher purchasing, inventory, student assignment, usage tracking, Expense integration, dashboard statistics and API/mobile access.

## Business flow
1. Purchase a bulk batch (for example 500 vouchers at ₹12,000 each).
2. The purchase automatically creates an **Exam Voucher Purchase** Expense of quantity × purchase cost.
3. Each voucher is stored individually with a unique code and status `Available`.
4. Assign a voucher to a Candidate/Student with a selling price (for example ₹18,000).
5. The voucher becomes `Assigned`; when the exam is completed it can be marked `Used`.
6. Profit is calculated only on assigned/used vouchers: selling price − purchase cost.

## Web module
- `/vouchers/` — voucher dashboard
- `/vouchers/purchase` — bulk purchase
- `/vouchers/purchases` — purchase history
- `/vouchers/stock?status=Available` — stock
- `/vouchers/issued` — students who received vouchers
- `/vouchers/students` — student-wise summary
- `/vouchers/students/<id>` — student voucher history
- `/vouchers/assign` — assign to a student
- `/vouchers/<id>` — voucher detail / lifecycle

The main Dashboard also includes clickable Available Vouchers, Issued Vouchers, Voucher Sales and Voucher Profit cards.

## API
- `GET /api/v1/vouchers/`
- `GET /api/v1/vouchers/dashboard/`
- `POST /api/v1/vouchers/purchase/`
- `POST /api/v1/vouchers/<id>/assign/`
- `POST /api/v1/vouchers/<id>/use/`

All API endpoints use the project's existing bearer-token authentication.

## Database
New SQLAlchemy tables are created automatically by the existing `db.create_all()` startup path:
- `voucher_batch`
- `voucher`

Existing `Candidate`, `ExamType`, `Branch`, and `Expense` records are reused; no duplicate student/exam/branch master data is created.

## Existing database
The project continues to use the existing local `flask_erp.db`. New tables are additive, so existing data is preserved.

## Run backend
From `backend`:

```powershell
pip install -r requirements.txt
python app.py
```

Open `http://127.0.0.1:5000`.

## Flutter
The Flutter app now has a **Vouchers** navigation section and uses the new voucher API endpoints. Configure the API server exactly as the existing app documentation describes.
