import os
import firebase_admin
from firebase_admin import credentials


def initialize_firebase():
    if firebase_admin._apps:
        return

    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    service_account_path = os.path.join(
        base_dir,
        "firebase",
        "serviceAccountKey.json"
    )

    cred = credentials.Certificate(service_account_path)

    firebase_admin.initialize_app(cred)