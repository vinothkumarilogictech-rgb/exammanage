"""
Quick check: list all registered FCM device tokens.
Run from backend/ folder:
    python check_devices.py
"""

from apps import create_app
from apps.models import db, DeviceToken

app = create_app()

with app.app_context():
    devices = DeviceToken.query.all()
    print(f"Total devices: {len(devices)}")
    print("-" * 60)
    for d in devices:
        print(f"id={d.id}  user_type={d.user_type}  user_id={d.user_id}  "
              f"is_active={d.is_active}  token={d.token[:25]}...")