# Build Guide

```powershell
flutter pub get
flutter analyze
flutter run --dart-define=API_SERVER_URL=http://10.0.2.2:5000
flutter build apk --release --dart-define=API_SERVER_URL=http://YOUR-PC-LAN-IP:5000
```

For a real device, the PC firewall must allow the Flask port and Flask should listen on `0.0.0.0`.
