from firebase_admin import messaging
from apps.models import db, DeviceToken


def send_payment_notification(
    device_token,
    title,
    body,
    payment_id=None
):
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                "type": "payment",
                "payment_id": str(payment_id or ""),
            },
            token=device_token,
        )

        response = messaging.send(message)

        print("======================================")
        print("FCM NOTIFICATION SENT")
        print("Token:", device_token[:20], "...")
        print("Response:", response)
        print("======================================")

        return True

    except Exception as e:
        print("======================================")
        print("FCM NOTIFICATION FAILED")
        print("Error:", e)
        print("======================================")

        return False


def send_to_all_active_devices(title, body, payment_id=None):
    # Only Admin-logged-in devices should receive payment reminder pushes,
    # not Employee logins.
    devices = DeviceToken.query.filter_by(
        is_active=True,
        user_type='Admin'
    ).all()

    success_count = 0

    for device in devices:

        success = send_payment_notification(
            device_token=device.token,
            title=title,
            body=body,
            payment_id=payment_id,
        )

        if success:
            success_count += 1

    print(
        f"Notification sent to "
        f"{success_count}/{len(devices)} devices"
    )

    return success_count