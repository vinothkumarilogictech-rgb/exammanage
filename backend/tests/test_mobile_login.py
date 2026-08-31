"""
Regression test for the "login works on the website but not in the Flutter
app" bug.

Root causes found:
  1. backend/MOBILE_API.md told developers to run
     `flutter run --dart-define=API_SERVER_URL=http://YOUR-PC-IP:5000/api/v1`
     but ApiConfig.apiBaseUrl (flutter_app/lib/config/api_config.dart)
     already appends '/api/v1' itself, so every request - including
     /auth/login/ - was sent to '.../api/v1/api/v1/...' and 404'd.
  2. backend/app.py started Flask with the default host (127.0.0.1), which
     refuses connections from a phone or emulator on the same network even
     though a browser on the same PC (the website) connects fine.
"""
import re

from app import app


def test_login_route_is_registered_at_the_documented_path():
    # This is the single source of truth for where the app's login request
    # must land.
    client = app.test_client()
    r = client.post('/api/v1/auth/login/', json={'username': 'admin', 'password': '1234'})
    assert r.status_code == 200
    assert r.get_json()['success'] is True

    # The doubled-up path from the old docs must NOT resolve to anything.
    r_bad = client.post('/api/v1/api/v1/auth/login/', json={'username': 'admin', 'password': '1234'})
    assert r_bad.status_code == 404


def test_mobile_api_docs_do_not_duplicate_api_v1_prefix():
    with open('MOBILE_API.md', encoding='utf-8') as f:
        docs = f.read()
    for match in re.findall(r'API_SERVER_URL=(\S+)', docs):
        assert not match.rstrip('/').endswith('/api/v1'), (
            f"MOBILE_API.md tells developers to set API_SERVER_URL={match!r}, "
            "but ApiConfig.apiBaseUrl already appends '/api/v1' - this doubles "
            "the prefix and breaks every API call from the app, including login."
        )


def test_server_binds_to_all_interfaces_so_the_app_can_reach_it():
    with open('app.py', encoding='utf-8') as f:
        src = f.read()
    run_line = next(line for line in src.splitlines() if 'app.run(' in line)
    assert "host='0.0.0.0'" in run_line or 'host="0.0.0.0"' in run_line, (
        "app.run() must bind to 0.0.0.0, not the 127.0.0.1 default - "
        "otherwise a phone/emulator can never reach the API even though "
        "the website (same-machine browser) still works."
    )
