from __future__ import annotations

from sqlalchemy import text
from sqlalchemy.exc import ProgrammingError
from sqlalchemy.orm import Session

from app.models.user_model import User


class AdminDeviceService:
    _DEVICE_DETAIL_SQL = """
        SELECT
            d.id,
            d.uuid,
            d.user_id,
            d.device_name,
            d.device_type,
            d.model,
            d.firmware_version,
            d.mac_address,
            d.serial_number,
            d.is_active,
            d.battery_level,
            d.signal_strength,
            d.last_seen_at,
            d.last_sync_at,
            d.mqtt_client_id,
            d.calibration_data,
            d.registered_at,
            d.updated_at,
            d.deleted_at,
            u.email AS user_email,
            u.full_name AS user_full_name
        FROM devices d
        LEFT JOIN users u ON u.id = d.user_id
        WHERE d.id = :device_id
          AND d.deleted_at IS NULL
    """

    @staticmethod
    def _is_missing_devices_table(error: Exception) -> bool:
        return 'relation "devices" does not exist' in str(error)

    @staticmethod
    def _normalize_optional_string(value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None

    @staticmethod
    def _ensure_user_exists(user_id: int, db: Session) -> None:
        row = db.execute(
            text(
                """
                SELECT id
                FROM users
                WHERE id = :user_id
                  AND deleted_at IS NULL
                LIMIT 1
                """
            ),
            {"user_id": user_id},
        ).mappings().first()

        if row is None:
            raise ValueError("User khong ton tai")

    @staticmethod
    def _check_duplicate_identity(
        *,
        serial_number: str | None,
        mac_address: str | None,
        mqtt_client_id: str | None,
        db: Session,
    ) -> None:
        if not serial_number and not mac_address and not mqtt_client_id:
            return

        row = db.execute(
            text(
                """
                SELECT id
                FROM devices
                WHERE deleted_at IS NULL
                  AND (
                    (:serial_number IS NOT NULL AND serial_number = :serial_number)
                    OR (:mac_address IS NOT NULL AND mac_address = :mac_address)
                    OR (:mqtt_client_id IS NOT NULL AND mqtt_client_id = :mqtt_client_id)
                  )
                LIMIT 1
                """
            ),
            {
                "serial_number": serial_number,
                "mac_address": mac_address,
                "mqtt_client_id": mqtt_client_id,
            },
        ).mappings().first()

        if row is not None:
            raise ValueError("Thiet bi da ton tai (trung serial/mac/mqtt)")

    @staticmethod
    def _fetch_device(device_id: int, db: Session) -> dict | None:
        row = db.execute(
            text(AdminDeviceService._DEVICE_DETAIL_SQL),
            {"device_id": device_id},
        ).mappings().first()
        return dict(row) if row is not None else None

    @staticmethod
    def find_user_by_email(email: str, db: Session) -> User | None:
        normalized_email = email.strip().lower()
        row = db.execute(
            text(
                """
                SELECT id
                FROM users
                WHERE lower(email) = :email
                  AND deleted_at IS NULL
                LIMIT 1
                """
            ),
            {"email": normalized_email},
        ).mappings().first()

        if row is None:
            return None

        return db.get(User, int(row["id"]))

    @staticmethod
    def list_all_devices(
        db: Session,
        skip: int = 0,
        limit: int = 200,
        user_id: int | None = None,
    ) -> list[dict]:
        rows = db.execute(
            text(
                """
                SELECT
                    d.id,
                    d.uuid,
                    d.user_id,
                    d.device_name,
                    d.device_type,
                    d.model,
                    d.firmware_version,
                    d.mac_address,
                    d.serial_number,
                    d.is_active,
                    d.battery_level,
                    d.signal_strength,
                    d.last_seen_at,
                    d.last_sync_at,
                    d.mqtt_client_id,
                    d.calibration_data,
                    d.registered_at,
                    d.updated_at,
                    d.deleted_at,
                    u.email AS user_email,
                    u.full_name AS user_full_name
                FROM devices d
                LEFT JOIN users u ON u.id = d.user_id
                WHERE d.deleted_at IS NULL
                  AND (:user_id IS NULL OR d.user_id = :user_id)
                ORDER BY d.is_active DESC, d.registered_at DESC
                LIMIT :limit OFFSET :skip
                """
            ),
            {
                "user_id": user_id,
                "limit": limit,
                "skip": skip,
            },
        ).mappings().all()

        return [dict(row) for row in rows]

    @staticmethod
    def create_device(
        db: Session,
        *,
        device_name: str,
        device_type: str = "smartwatch",
        serial_number: str | None = None,
        mqtt_client_id: str | None = None,
        model: str | None = None,
        user_id: int | None = None,
        firmware_version: str | None = None,
        mac_address: str | None = None,
    ) -> dict:
        normalized_device_name = device_name.strip()
        normalized_serial_number = AdminDeviceService._normalize_optional_string(serial_number)
        normalized_mqtt_client_id = AdminDeviceService._normalize_optional_string(mqtt_client_id)
        normalized_model = AdminDeviceService._normalize_optional_string(model)
        normalized_firmware_version = AdminDeviceService._normalize_optional_string(firmware_version)
        normalized_mac_address = AdminDeviceService._normalize_optional_string(mac_address)
        if normalized_mac_address is not None:
            normalized_mac_address = normalized_mac_address.upper()

        if not normalized_device_name:
            raise ValueError("device_name khong duoc de trong")

        if user_id is not None:
            AdminDeviceService._ensure_user_exists(user_id, db)

        try:
            AdminDeviceService._check_duplicate_identity(
                serial_number=normalized_serial_number,
                mac_address=normalized_mac_address,
                mqtt_client_id=normalized_mqtt_client_id,
                db=db,
            )

            row = db.execute(
                text(
                    """
                    INSERT INTO devices (
                        user_id,
                        device_name,
                        device_type,
                        model,
                        firmware_version,
                        mac_address,
                        serial_number,
                        mqtt_client_id,
                        is_active,
                        registered_at,
                        updated_at
                    )
                    VALUES (
                        :user_id,
                        :device_name,
                        :device_type,
                        :model,
                        :firmware_version,
                        :mac_address,
                        :serial_number,
                        :mqtt_client_id,
                        FALSE,
                        NOW(),
                        NOW()
                    )
                    RETURNING id
                    """
                ),
                {
                    "user_id": user_id,
                    "device_name": normalized_device_name,
                    "device_type": device_type,
                    "model": normalized_model,
                    "firmware_version": normalized_firmware_version,
                    "mac_address": normalized_mac_address,
                    "serial_number": normalized_serial_number,
                    "mqtt_client_id": normalized_mqtt_client_id,
                },
            ).mappings().first()
        except ProgrammingError as error:
            db.rollback()
            if AdminDeviceService._is_missing_devices_table(error):
                raise ValueError("Bang devices chua duoc tao trong database") from error
            raise

        if row is None:
            db.rollback()
            raise ValueError("Khong the tao device")

        db.commit()
        created = AdminDeviceService._fetch_device(int(row["id"]), db)
        if created is None:
            raise ValueError("Khong the tai lai device sau khi tao")
        return created

    @staticmethod
    def assign_device(device_id: int, user_id: int, db: Session) -> dict | None:
        AdminDeviceService._ensure_user_exists(user_id, db)

        row = db.execute(
            text(
                """
                UPDATE devices
                SET
                    user_id = :user_id,
                    updated_at = NOW()
                WHERE id = :device_id
                  AND deleted_at IS NULL
                RETURNING id
                """
            ),
            {
                "device_id": device_id,
                "user_id": user_id,
            },
        ).mappings().first()

        if row is None:
            db.rollback()
            return None

        db.commit()
        return AdminDeviceService._fetch_device(device_id, db)

    @staticmethod
    def activate_device(device_id: int, db: Session) -> dict | None:
        target = db.execute(
            text(
                """
                SELECT user_id
                FROM devices
                WHERE id = :device_id
                  AND deleted_at IS NULL
                LIMIT 1
                """
            ),
            {"device_id": device_id},
        ).mappings().first()

        if target is None:
            db.rollback()
            return None

        user_id = target.get("user_id")
        if user_id is None:
            db.rollback()
            raise ValueError("Assign user truoc")

        db.execute(
            text(
                """
                UPDATE devices
                SET
                    is_active = FALSE,
                    updated_at = NOW()
                WHERE user_id = :user_id
                  AND id != :device_id
                  AND deleted_at IS NULL
                """
            ),
            {
                "user_id": user_id,
                "device_id": device_id,
            },
        )

        row = db.execute(
            text(
                """
                UPDATE devices
                SET
                    is_active = TRUE,
                    updated_at = NOW()
                WHERE id = :device_id
                  AND deleted_at IS NULL
                RETURNING id
                """
            ),
            {"device_id": device_id},
        ).mappings().first()

        if row is None:
            db.rollback()
            return None

        db.commit()
        return AdminDeviceService._fetch_device(device_id, db)

    @staticmethod
    def deactivate_device(device_id: int, db: Session) -> dict | None:
        row = db.execute(
            text(
                """
                UPDATE devices
                SET
                    is_active = FALSE,
                    updated_at = NOW()
                WHERE id = :device_id
                  AND deleted_at IS NULL
                RETURNING id
                """
            ),
            {"device_id": device_id},
        ).mappings().first()

        if row is None:
            db.rollback()
            return None

        db.commit()
        return AdminDeviceService._fetch_device(device_id, db)

    @staticmethod
    def delete_device(device_id: int, db: Session) -> bool:
        row = db.execute(
            text(
                """
                UPDATE devices
                SET
                    deleted_at = NOW(),
                    is_active = FALSE,
                    updated_at = NOW()
                WHERE id = :device_id
                  AND deleted_at IS NULL
                RETURNING id
                """
            ),
            {"device_id": device_id},
        ).mappings().first()

        if row is None:
            db.rollback()
            return False

        db.commit()
        return True

    @staticmethod
    def update_device(
        device_id: int,
        db: Session,
        *,
        device_name: str | None = None,
        firmware_version: str | None = None,
        battery_level: int | None = None,
        signal_strength: int | None = None,
    ) -> dict | None:
        normalized_device_name = AdminDeviceService._normalize_optional_string(device_name)
        normalized_firmware_version = AdminDeviceService._normalize_optional_string(firmware_version)

        row = db.execute(
            text(
                """
                UPDATE devices
                SET
                    device_name = COALESCE(:device_name, device_name),
                    firmware_version = COALESCE(:firmware_version, firmware_version),
                    battery_level = COALESCE(:battery_level, battery_level),
                    signal_strength = COALESCE(:signal_strength, signal_strength),
                    updated_at = NOW()
                WHERE id = :device_id
                  AND deleted_at IS NULL
                RETURNING id
                """
            ),
            {
                "device_id": device_id,
                "device_name": normalized_device_name,
                "firmware_version": normalized_firmware_version,
                "battery_level": battery_level,
                "signal_strength": signal_strength,
            },
        ).mappings().first()

        if row is None:
            db.rollback()
            return None

        db.commit()
        return AdminDeviceService._fetch_device(device_id, db)

    @staticmethod
    def update_heartbeat(
        device_id: int,
        db: Session,
        *,
        battery_level: int | None = None,
        signal_strength: int | None = None,
    ) -> None:
        row = db.execute(
            text(
                """
                UPDATE devices
                SET
                    last_seen_at = NOW(),
                    battery_level = COALESCE(:battery_level, battery_level),
                    signal_strength = COALESCE(:signal_strength, signal_strength),
                    updated_at = NOW()
                WHERE id = :device_id
                  AND deleted_at IS NULL
                RETURNING id
                """
            ),
            {
                "device_id": device_id,
                "battery_level": battery_level,
                "signal_strength": signal_strength,
            },
        ).mappings().first()

        if row is None:
            db.rollback()
            return

        db.commit()
