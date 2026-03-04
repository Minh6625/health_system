import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Optional
import logging

from app.core.config import settings

logger = logging.getLogger(__name__)


class EmailService:
    """Service for sending emails via SMTP."""

    SMTP_SERVER = settings.SMTP_SERVER or "smtp.gmail.com"
    SMTP_PORT = settings.SMTP_PORT or 587
    SENDER_EMAIL = settings.SENDER_EMAIL or "noreply@healthguard.com"
    SENDER_PASSWORD = settings.SENDER_PASSWORD or ""

    @classmethod
    def send_verification_email(cls, to_email: str, verification_token: str) -> bool:
        """
        Send email verification token to user.

        Args:
            to_email: Recipient email address
            verification_token: JWT token for email verification

        Returns:
            True if sent successfully, False otherwise
        """
        try:
            # Use mobile deep link for app
            verification_link = f"{settings.MOBILE_DEEP_LINK_SCHEME}://verify-email?token={verification_token}"

            subject = "Xác thực email - Health Guard"
            body = f"""
Xin chào,

Cảm ơn bạn đã đăng ký tài khoản Health Guard!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
XÁC THỰC TÀI KHOẢN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Vui lòng click vào link dưới đây để xác thực email:

{verification_link}

Link này sẽ tự động mở ứng dụng Health Guard và kích hoạt tài khoản của bạn.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️ Lưu ý:
- Link có hiệu lực trong 24 giờ
- Nếu link không hoạt động, vui lòng mở app và sử dụng mã:
  {verification_token}
- Không chia sẻ link này với bất kỳ ai

---
Health Guard Team
            """

            return cls._send_email(to_email, subject, body)

        except Exception as e:
            logger.error(f"Error sending verification email to {to_email}: {str(e)}")
            return False

    @classmethod
    def send_password_reset_email(
        cls, to_email: str, reset_token: str
    ) -> bool:
        """
        Send password reset token to user.

        Args:
            to_email: Recipient email address
            reset_token: JWT token for password reset

        Returns:
            True if sent successfully, False otherwise
        """
        try:
            # Use mobile deep link for app
            reset_link = f"{settings.MOBILE_DEEP_LINK_SCHEME}://reset-password?token={reset_token}"

            subject = "Đặt lại mật khẩu - Health Guard"
            body = f"""
Xin chào,

Bạn đã yêu cầu đặt lại mật khẩu Health Guard.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ĐẶT LẠI MẬT KHẨU
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Vui lòng click vào link dưới đây để đặt lại mật khẩu:

{reset_link}

Link này sẽ tự động mở ứng dụng Health Guard để bạn cập nhật mật khẩu mới.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️ Lưu ý:
- Link có hiệu lực trong 15 phút
- Nếu link không hoạt động, vui lòng sử dụng mã:
  {reset_token}
- Không chia sẻ link này với bất kỳ ai
- Nếu bạn không yêu cầu đổi mật khẩu, vui lòng bỏ qua email này

---
Health Guard Team
            """

            return cls._send_email(to_email, subject, body)

        except Exception as e:
            logger.error(f"Error sending password reset email to {to_email}: {str(e)}")
            return False

    @classmethod
    def send_password_changed_notification(cls, to_email: str) -> bool:
        """
        Send notification email after password change.

        Args:
            to_email: Recipient email address

        Returns:
            True if sent successfully, False otherwise
        """
        try:
            subject = "Mật khẩu đã được thay đổi - Health Guard"
            body = f"""
Xin chào,

Mật khẩu tài khoản Health Guard của bạn đã được thay đổi thành công.

Nếu bạn không thực hiện thay đổi này, vui lòng liên hệ với chúng tôi ngay lập tức.

---
Health Guard Team
            """

            return cls._send_email(to_email, subject, body)

        except Exception as e:
            logger.error(f"Error sending password changed notification to {to_email}: {str(e)}")
            return False

    @classmethod
    def _send_email(cls, to_email: str, subject: str, body: str) -> bool:
        """
        Internal method to send email via SMTP.

        Args:
            to_email: Recipient email
            subject: Email subject
            body: Email body

        Returns:
            True if sent, False if failed
        """
        try:
            # For development/testing: skip if credentials not configured
            if not cls.SENDER_PASSWORD:
                logger.warning(f"SMTP not configured. Skipping email to {to_email}")
                logger.info(f"Email subject: {subject}")
                return True

            message = MIMEMultipart()
            message["From"] = cls.SENDER_EMAIL
            message["To"] = to_email
            message["Subject"] = subject

            message.attach(MIMEText(body, "plain"))

            with smtplib.SMTP(cls.SMTP_SERVER, cls.SMTP_PORT) as server:
                server.starttls()
                server.login(cls.SENDER_EMAIL, cls.SENDER_PASSWORD)
                server.send_message(message)

            logger.info(f"Email sent successfully to {to_email}")
            return True

        except Exception as e:
            logger.error(f"SMTP error sending to {to_email}: {str(e)}")
            return False
