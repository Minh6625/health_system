from datetime import datetime, timezone


def get_current_time() -> datetime:
    """
    Get current UTC time (timezone-aware).

    Returns:
        datetime object in UTC
    """
    return datetime.now(timezone.utc)
