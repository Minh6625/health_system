from datetime import timedelta
from jose import JWTError, jwt

from app.core.config import settings
from app.utils.datetime_helper import get_current_time


def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    """
    Create JWT access token.
    
    Args:
        data: Payload data (user_id, email, role, etc.)
        expires_delta: Token expiry duration (default: 30 days)
    
    Returns:
        Encoded JWT token string
    """
    to_encode = data.copy()
    
    if expires_delta:
        expire = get_current_time() + expires_delta
    else:
        # Default: 30 days (43200 minutes)
        expire = get_current_time() + timedelta(days=30)
    
    to_encode.update({
        "exp": expire,
        "iat": get_current_time(),
        "iss": "healthguard-mobile"
    })
    
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def create_refresh_token(data: dict) -> str:
    """
    Create JWT refresh token with 90 days expiry.
    
    Args:
        data: Minimal payload (user_id only)
    
    Returns:
        Encoded JWT refresh token string
    """
    to_encode = data.copy()
    expire = get_current_time() + timedelta(days=90)
    
    to_encode.update({
        "exp": expire,
        "iat": get_current_time(),
        "iss": "healthguard-mobile",
        "type": "refresh"
    })
    
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def decode_token(token: str) -> dict | None:
    """
    Decode and verify JWT token.
    
    Args:
        token: JWT token string
    
    Returns:
        Decoded payload dict or None if invalid
    """
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except JWTError:
        return None
