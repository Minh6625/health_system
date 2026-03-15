def get_base_html(title: str, content: str) -> str:
    """
    Returns the base HTML template with Steam Guard style.
    """
    return f"""
    <!DOCTYPE html>
    <html lang="vi">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>{title}</title>
    </head>
    <body style="margin: 0; padding: 0; background-color: #171a21; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #c6d4df;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px; background-color: #1b2838;">
            <!-- Header -->
            <div style="padding-bottom: 20px; border-bottom: 1px solid #2a3f5a; margin-bottom: 20px;">
                <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: bold; letter-spacing: 1px;">HEALTH GUARD</h1>
            </div>
            
            <!-- Content -->
            <div style="font-size: 15px; line-height: 1.6;">
                {content}
            </div>

            <!-- Footer -->
            <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #2a3f5a; font-size: 12px; color: #8f98a0;">
                <p style="margin: 0;">Email này được gửi tự động từ hệ thống Health Guard. Vui lòng không trả lời email này.</p>
                <p style="margin: 5px 0 0 0;">&copy; 2026 Health Guard Team.</p>
            </div>
        </div>
    </body>
    </html>
    """

def get_verification_email_html(link: str, token: str) -> str:
    content = f"""
        <p style="color: #66c0f4; font-size: 22px; font-weight: bold; margin-top: 0;">Xin chào,</p>
        <p>Cảm ơn bạn đã đăng ký tài khoản Health Guard! Bạn cần xác thực địa chỉ email để hoàn tất quá trình đăng ký.</p>
        
        <div style="background-color: #000000; padding: 30px; text-align: center; margin: 30px 0; border-radius: 4px;">
            <p style="margin: 0 0 10px 0; color: #8f98a0; font-size: 14px; text-transform: uppercase; letter-spacing: 1px;">Mã xác thực của bạn là</p>
            <div style="color: #66c0f4; font-size: 42px; font-weight: bold; letter-spacing: 4px; font-family: monospace;">{token}</div>
        </div>

        <p>Hoặc bạn có thể click trực tiếp vào nút bên dưới để xác thực:</p>
        
        <div style="text-align: center; margin: 30px 0;">
            <a href="{link}" style="display: inline-block; background: linear-gradient(to right, #47bfff 0%, #1a44c2 100%); color: #ffffff; text-decoration: none; padding: 15px 30px; border-radius: 2px; font-weight: bold; font-size: 16px; text-transform: uppercase; letter-spacing: 1px;">XÁC THỰC EMAIL</a>
        </div>

        <p style="color: #8f98a0; font-size: 13px;">
            <strong style="color: #c6d4df;">Lưu ý:</strong><br>
            - Link và mã có hiệu lực trong 24 giờ.<br>
            - Nếu bạn không yêu cầu tạo tài khoản, vui lòng bỏ qua email này. KHÔNG chia sẻ mã xác thực với bất kỳ ai.
        </p>
    """
    return get_base_html("Xác thực email - Health Guard", content)

def get_password_reset_html(link: str, token: str) -> str:
    content = f"""
        <p style="color: #66c0f4; font-size: 22px; font-weight: bold; margin-top: 0;">Xin chào,</p>
        <p>Bạn đã yêu cầu đặt lại mật khẩu cho tài khoản Health Guard của mình.</p>
        
        <div style="background-color: #000000; padding: 30px; text-align: center; margin: 30px 0; border-radius: 4px;">
            <p style="margin: 0 0 10px 0; color: #8f98a0; font-size: 14px; text-transform: uppercase; letter-spacing: 1px;">Mã đặt lại mật khẩu là</p>
            <div style="color: #66c0f4; font-size: 42px; font-weight: bold; letter-spacing: 4px; font-family: monospace;">{token}</div>
        </div>

        <p>Hoặc bạn có thể click trực tiếp vào nút bên dưới để đặt lại mật khẩu:</p>
        
        <div style="text-align: center; margin: 30px 0;">
            <a href="{link}" style="display: inline-block; background: linear-gradient(to right, #47bfff 0%, #1a44c2 100%); color: #ffffff; text-decoration: none; padding: 15px 30px; border-radius: 2px; font-weight: bold; font-size: 16px; text-transform: uppercase; letter-spacing: 1px;">ĐẶT LẠI MẬT KHẨU</a>
        </div>

        <p style="color: #8f98a0; font-size: 13px;">
            <strong style="color: #c6d4df;">Nếu không phải bạn yêu cầu?</strong><br>
            Email này được gửi do ai đó đã thử khôi phục mật khẩu tài khoản Health Guard của bạn. Nếu bạn không muốn đặt lại mật khẩu, bạn có thể bỏ qua email này. Tuyệt đối KHÔNG chia sẻ mã này với bất kỳ ai.<br>
            Mã này có hiệu lực trong 15 phút.
        </p>
    """
    return get_base_html("Đặt lại mật khẩu - Health Guard", content)

def get_password_changed_html() -> str:
    content = f"""
        <p style="color: #66c0f4; font-size: 22px; font-weight: bold; margin-top: 0;">Xin chào,</p>
        <p>Mật khẩu tài khoản Health Guard của bạn đã được thay đổi thành công.</p>
        
        <p style="color: #8f98a0; font-size: 14px; margin-top: 30px;">
            Nếu bạn không thực hiện thay đổi này, tài khoản của bạn có thể đã bị xâm phạm. Vui lòng liên hệ với bộ phận hỗ trợ của chúng tôi ngay lập tức để bảo vệ tài khoản của bạn.
        </p>
        
        <div style="margin-top: 30px; padding-left: 10px; border-left: 3px solid #66c0f4;">
            <p style="margin: 0; color: #c6d4df; font-weight: bold;">Chúc sức khoẻ,</p>
            <p style="margin: 5px 0 0 0; color: #c6d4df;">Đội ngũ Health Guard</p>
        </div>
    """
    return get_base_html("Mật khẩu đã được thay đổi - Health Guard", content)
