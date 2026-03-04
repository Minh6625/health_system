from datetime import datetime, timedelta
from collections import defaultdict
from typing import Dict, List

from app.utils.datetime_helper import get_current_time


class RateLimiter:
    """In-memory rate limiter for login attempts."""
    
    def __init__(self, max_attempts: int = 5, window_minutes: int = 15):
        self.max_attempts = max_attempts
        self.window_minutes = window_minutes
        self._attempts: Dict[str, List[datetime]] = defaultdict(list)
    
    def is_rate_limited(self, identifier: str) -> bool:
        """
        Check if identifier (IP address) is rate limited.
        
        Args:
            identifier: IP address or user identifier
        
        Returns:
            True if rate limited, False otherwise
        """
        now = get_current_time()
        cutoff = now - timedelta(minutes=self.window_minutes)
        
        # Clean old attempts
        self._attempts[identifier] = [
            attempt for attempt in self._attempts[identifier]
            if attempt > cutoff
        ]
        
        # Check if exceeded limit
        return len(self._attempts[identifier]) >= self.max_attempts
    
    def record_attempt(self, identifier: str):
        """Record a login attempt."""
        self._attempts[identifier].append(get_current_time())
    
    def get_remaining_attempts(self, identifier: str) -> int:
        """Get remaining attempts before rate limit."""
        now = get_current_time()
        cutoff = now - timedelta(minutes=self.window_minutes)
        
        # Clean old attempts
        self._attempts[identifier] = [
            attempt for attempt in self._attempts[identifier]
            if attempt > cutoff
        ]
        
        current_attempts = len(self._attempts[identifier])
        return max(0, self.max_attempts - current_attempts)
    
    def reset(self, identifier: str):
        """Reset rate limit for identifier (e.g., after successful login)."""
        if identifier in self._attempts:
            del self._attempts[identifier]


# Global rate limiter instances
login_rate_limiter = RateLimiter(max_attempts=5, window_minutes=15)
forgot_password_rate_limiter = RateLimiter(max_attempts=3, window_minutes=15)
change_password_rate_limiter = RateLimiter(max_attempts=5, window_minutes=15)
resend_verification_rate_limiter = RateLimiter(max_attempts=3, window_minutes=15)
