# Mobile/API Setup

The Office Management web application remains Flask + SQLAlchemy. The new mobile layer is an API on top of the same models; it does not create a second database.

## Start backend

```powershell
pip install -r requirements.txt
python app.py
```

The mobile API is available below `/api/v1/`.

## Start Flutter

Inside `flutter_app`:

```powershell
flutter create . --platforms=android,ios
flutter pub get
flutter run --dart-define=API_SERVER_URL=http://YOUR-PC-IP:5000
```

For Android Emulator, use `http://10.0.2.2:5000` when the Flask server runs on the development PC.

> **Note:** `API_SERVER_URL` must be the server root only (no `/api/v1`
> suffix). `ApiConfig.apiBaseUrl` already appends `/api/v1` itself, so
> passing `.../5000/api/v1` here causes every request (including login) to
> be sent to `.../api/v1/api/v1/...`, which 404s.
>
> Also make sure the Flask server is started with `host='0.0.0.0'` (see
> `app.py`) - a phone or emulator can't reach a server bound to
> `127.0.0.1`, even though a browser on the same PC (the website) can.

## Architecture

```text
Flutter App
   │
   │ Dio + Bearer token
   ▼
Flask /api/v1
   │
   ├── Auth
   ├── Dashboard
   ├── Branch Management
   ├── Exam Management
   └── Expense
   │
   ▼
Existing SQLAlchemy Models
   │
   ▼
flask_erp.db
```

The four web modules and the mobile app therefore use the same branch, exam and expense records.
