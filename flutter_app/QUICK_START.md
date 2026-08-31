# Quick Start

1. Start the Flask backend from `backend/`.
2. Verify the API:
   `http://127.0.0.1:5000/api/v1/dashboard/`
3. Android emulator:
   `flutter run --dart-define=API_SERVER_URL=http://10.0.2.2:5000`
4. Physical Android device:
   `flutter run --dart-define=API_SERVER_URL=http://YOUR-PC-LAN-IP:5000`
5. Login: `admin / 1234` unless you changed the backend credentials.

The API requires a bearer token after login.
