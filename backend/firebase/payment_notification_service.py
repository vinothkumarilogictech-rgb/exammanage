from datetime import date

from apps.models import (
    db,
    VoucherSaleHistory,
    PaymentNotificationLog,
)
from firebase.notification_sender import send_to_all_active_devices


def send_daily_payment_notifications(slot='morning'):
    print("==========================================")
    print(f"STARTING PAYMENT NOTIFICATIONS - {slot.upper()}")
    print("==========================================")

    today = date.today()

    payments = VoucherSaleHistory.query.filter(
        VoucherSaleHistory.payment_status.in_(["Pending", "Partial"])
    ).all()

    total = 0
    sent = 0
    skipped = 0

    for payment in payments:
        total += 1

        # Calculate remaining balance
        balance = payment.balance_amount

        # No balance = nothing to notify
        if balance <= 0:
            skipped += 1
            continue

        # Check whether THIS slot's notification was already sent today
        existing_log = PaymentNotificationLog.query.filter_by(
            voucher_sale_id=payment.id,
            notification_date=today,
            slot=slot,
        ).first()

        if existing_log:
            print(
                f"SKIPPED ({slot}) - Already notified today: "
                f"{payment.student_name}"
            )
            skipped += 1
            continue

        # Notification title
        if payment.payment_status == "Partial":
            title = "Partial Payment"
        else:
            title = "Pending Payment"

        # Notification body
        student_name = payment.student_name or "Unknown"

        body = (
            f"{student_name} — "
            f"₹{balance:,.2f}"
        )

        print("------------------------------------------")
        print("Payment ID:", payment.id)
        print("Student:", student_name)
        print("Status:", payment.payment_status)
        print("Balance:", balance)
        print("Slot:", slot)
        print("Sending:", title)
        print("Body:", body)

        # Send notification
        success_count = send_to_all_active_devices(
            title=title,
            body=body,
            payment_id=payment.id,
        )

        # Save notification log only if at least one device received it
        if success_count > 0:

            log = PaymentNotificationLog(
                voucher_sale_id=payment.id,
                notification_date=today,
                slot=slot,
                payment_status=payment.payment_status,
            )

            db.session.add(log)
            db.session.commit()

            sent += 1

            print(
                f"SUCCESS - Notification logged "
                f"for payment {payment.id} ({slot})"
            )

        else:
            print(
                f"FAILED - No active device for "
                f"payment {payment.id}"
            )

    print("==========================================")
    print(f"{slot.upper()} PAYMENT NOTIFICATION COMPLETED")
    print("==========================================")
    print("Total Pending/Partial:", total)
    print("Notifications Sent:", sent)
    print("Skipped:", skipped)
    print("==========================================")

    return {
        "total": total,
        "sent": sent,
        "skipped": skipped,
    }