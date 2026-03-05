import bcrypt
import re
from typing import Tuple


def hash_password(password: str) -> str:
    """Hash password using bcrypt."""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode(), salt).decode()


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password against hash."""
    return bcrypt.checkpw(plain_password.encode(), hashed_password.encode())


def validate_password_strength(password: str) -> Tuple[bool, str]:
    """
    Validate password meets strength requirements:
    - Min 8 characters
    - At least 1 uppercase letter
    - At least 1 lowercase letter
    - At least 1 digit
    - At least 1 special character
    
    Args:
        password: Password to validate
    
    Returns:
        (is_valid, message) tuple
    """
    if len(password) < 8:
        return False, "Mật khẩu phải có ít nhất 8 ký tự"
    
    if not re.search(r"[A-Z]", password):
        return False, "Mật khẩu phải chứa ít nhất 1 ký tự in hoa"
    
    if not re.search(r"[a-z]", password):
        return False, "Mật khẩu phải chứa ít nhất 1 ký tự in thường"
    
    if not re.search(r"\d", password):
        return False, "Mật khẩu phải chứa ít nhất 1 chữ số"
    
    if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", password):
        return False, "Mật khẩu phải chứa ít nhất 1 ký tự đặc biệt"
    
    return True, "Mật khẩu mạnh"
