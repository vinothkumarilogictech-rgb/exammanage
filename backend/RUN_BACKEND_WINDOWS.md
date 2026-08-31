# Backend - Windows quick start

Open PowerShell in this `backend` folder.

## 1. Create a virtual environment (first time only)

```powershell
py -3.12 -m venv venv
.\venv\Scripts\Activate.ps1
```

If PowerShell blocks activation, run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\venv\Scripts\Activate.ps1
```

## 2. Install dependencies

```powershell
python -m pip install --upgrade pip
pip install -r requirements.txt
```

## 3. Start the API

```powershell
python app.py
```

The Flutter Web client should then use `http://127.0.0.1:5000` (or the same browser hostname).

## 4. Flutter Web

In another PowerShell window, open the `flutter_app` folder:

```powershell
flutter clean
flutter pub get
flutter run -d chrome
```
