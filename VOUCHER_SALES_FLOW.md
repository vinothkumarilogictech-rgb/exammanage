# Voucher Management – Separate Sales Flow

Voucher Management is intentionally separate from Exam Management.

## Business flow

1. **Bulk Purchase** adds voucher stock.
2. Every purchased voucher has its own unique **Voucher ID**.
3. **Sell Voucher** selects only an available Voucher ID.
4. The operator enters a separate **Voucher Student** record (name, mobile, email, address and ID number).
5. Sale/payment details are saved in `voucher_sale_history`.
6. The voucher changes from `Available` to `Sold`.
7. Sold voucher details and sale history can be opened from the Flutter app.
8. Exam Management's `Candidate` table is not used by the new sales flow.

## New database tables

- `voucher_student` – voucher-only student/customer master.
- `voucher_sale_history` – sale ledger with a snapshot of student and payment details.

The existing `Candidate` relationship on the legacy `Voucher` model is retained only for backward compatibility with old data. New sales use the voucher-only tables.

## API

- `GET /api/v1/vouchers/` – voucher stock/list
- `GET /api/v1/vouchers/dashboard/` – dashboard statistics
- `GET /api/v1/vouchers/students/` – voucher-only students
- `GET /api/v1/vouchers/history/` – complete sales history
- `GET /api/v1/vouchers/<id>/details/` – purchase + student + sale history
- `POST /api/v1/vouchers/purchase/` – add stock
- `POST /api/v1/vouchers/sell/` – sell an available voucher
- `POST /api/v1/vouchers/<id>/use/` – mark a sold voucher as used
