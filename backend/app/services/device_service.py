from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta

from sqlalchemy import text
from sqlalchemy.exc import ProgrammingError
from sqlalchemy.orm import Session

from app.schemas.device import (
    DeviceActionResponse,
    DeviceCreateRequest,
    DeviceItemResponse,
    DeviceListResponse,
    DeviceUpdateRequest,
)


class DeviceService:
    """Read device data for the authenticated mobile user."""

    @staticmethod
    def _map_device_row(row: dict, online_threshold: datetime | None = None) -> DeviceItemResponse:
        last_seen_at = row.get("last_seen_at")
        is_online = bool(
            row.get("is_active")
            and last_seen_at is not None
            and online_threshold is not None
            and last_seen_at >= online_threshold
        )

        # ``calibration_data`` is stored as a JSONB column. SQLAlchemy returns
        # it as a dict already, but admin paths sometimes hand us the raw JSON
        # string, so accept both shapes defensively.
        raw_calibration = row.get("calibration_data")
        if isinstance(raw_calibration, str):
            try:
                raw_calibration = json.loads(raw_calibration)
            except (TypeError, ValueError):
                raw_calibration = None
        if not isinstance(raw_calibration, dict):
            raw_calibration = None

        return DeviceItemResponse(
            id=int(row["id"]),
            uuid=str(row["uuid"]),
            device_name=row.get("device_name"),
            device_type=row.get("device_type") or "unknown",
            model=row.get("model"),
            firmware_version=row.get("firmware_version"),
            mac_address=row.get("mac_address"),
            serial_number=row.get("serial_number"),
            is_active=bool(row.get("is_active")),
            is_online=is_online,
            battery_level=row.get("battery_level"),
            signal_strength=row.get("signal_strength"),
            last_seen_at=last_seen_at,
            last_sync_at=row.get("last_sync_at"),
            mqtt_client_id=row.get("mqtt_client_id"),
            registered_at=row.get("registered_at"),
            calibration_data=raw_calibration,
        )

    @staticmethod
    def _is_missing_devices_table(error: Exception) -> bool:
        return 'relation "devices" does not exist' in str(error)

    @staticmethod
    def _check_duplicate_identity(
        user_id: int,
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
                WHERE user_id = :user_id
                  AND deleted_at IS NULL
                  AND (
                    (:serial_number IS NOT NULL AND serial_number = :serial_number)
                    OR (:mac_address IS NOT NULL AND mac_address = :mac_address)
                    OR (:mqtt_client_id IS NOT NULL AND mqtt_client_id = :mqtt_client_id)
                  )
                LIMIT 1
                """
            ),
            {
                "user_id": user_id,
                "serial_number": serial_number,
                "mac_address": mac_address,
                "mqtt_client_id": mqtt_client_id,
            },
        ).mappings().first()

        if row is not None:
            raise ValueError("Thiet bi da ton tai (trung serial/mac/mqtt)")

    @staticmethod
    def create_device(
        user_id: int,
        payload: DeviceCreateRequest,
        db: Session,
    ) -> DeviceItemResponse:
        serial_number = payload.serial_number.strip() if payload.serial_number else None
        mac_address = payload.mac_address.strip().upper() if payload.mac_address else None
        mqtt_client_id = payload.mqtt_client_id.strip() if payload.mqtt_client_id else None

        try:
            DeviceService._check_duplicate_identity(
                user_id=user_id,
                serial_number=serial_number,
                mac_address=mac_address,
                mqtt_client_id=mqtt_client_id,
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
                        TRUE,
                        NOW(),
                        NOW()
                    )
                    RETURNING
                        id,
                        uuid,
                        device_name,
                        device_type,
                        model,
                        firmware_version,
                        mac_address,
                        serial_number,
                        is_active,
                        battery_level,
                        signal_strength,
                        last_seen_at,
                        last_sync_at,
                        mqtt_client_id,
                        registered_at,
                        calibration_data
                    """
                ),
                {
                    "user_id": user_id,
                    "device_name": payload.device_name.strip(),
                    "device_type": payload.device_type,
                    "model": payload.model.strip() if payload.model else None,
                    "firmware_version": payload.firmware_version.strip()
                    if payload.firmware_version
                    else None,
                    "mac_address": mac_address,
                    "serial_number": serial_number,
                    "mqtt_client_id": mqtt_client_id,
                },
            ).mappings().first()
        except ProgrammingError as error:
            db.rollback()
            if DeviceService._is_missing_devices_table(error):
                raise ValueError("Hệ thống chưa sẵn sàng, vui lòng thử lại sau") from error
            raise

        db.commit()

        return DeviceService._map_device_row(row)

    @staticmethod
    def update_device(
        user_id: int,
        device_id: int,
        payload: DeviceUpdateRequest,
        db: Session,
    ) -> DeviceItemResponse | None:
        row = db.execute(
            text(
                """
                UPDATE devices
                SET
                    device_name = COALESCE(:device_name, device_name),
                    firmware_version = COALESCE(:firmware_version, firmware_version),
                    is_active = COALESCE(:is_active, is_active),
                    updated_at = NOW()
                WHERE id = :device_id
                  AND user_id = :user_id
                  AND deleted_at IS NULL
                RETURNING
                    id,
                    uuid,
                    device_name,
                    device_type,
                    model,
                    firmware_version,
                    mac_address,
                    serial_number,
                    is_active,
                    battery_level,
                    signal_strength,
                    last_seen_at,
                    last_sync_at,
                    mqtt_client_id,
                    registered_at,
                    calibration_data
                """
            ),
            {
                "device_id": device_id,
                "user_id": user_id,
                "device_name": payload.device_name.strip() if payload.device_name else None,
                "firmware_version": payload.firmware_version.strip()
                if payload.firmware_version
                else None,
                "is_active": payload.is_active,
            },
        ).mappings().first()

        if row is None:
            db.rollback()
            return None

        db.commit()
        online_threshold = datetime.now(UTC) - timedelta(minutes=5)
        return DeviceService._map_device_row(row, online_threshold=online_threshold)

    @staticmethod
    def delete_device(user_id: int, device_id: int, db: Session) -> DeviceActionResponse:
        row = db.execute(
            text(
                """
                UPDATE devices
                SET
                    deleted_at = NOW(),
                    is_active = FALSE,
                    updated_at = NOW()
                WHERE id = :device_id
                  AND user_id = :user_id
                  AND deleted_at IS NULL
                RETURNING id
                """
            ),
            {"device_id": device_id, "user_id": user_id},
        ).mappings().first()

        if row is None:
            db.rollback()
            return DeviceActionResponse(success=False, message="Khong tim thay thiet bi")

        db.commit()
        return DeviceActionResponse(success=True, message="Da xoa mem thiet bi")

    @staticmethod
    def get_user_devices(
        user_id: int,
        db: Session,
        device_type: str | None = None,
        active: bool | None = None,
        status: str = "all",
        limit: int = 50,
        offset: int = 0,
    ) -> DeviceListResponse:
        try:
            rows = db.execute(
                text(
                    """
                    SELECT
                        id,
                        uuid,
                        device_name,
                        device_type,
                        model,
                        firmware_version,
                        mac_address,
                        serial_number,
                        is_active,
                        battery_level,
                        signal_strength,
                        last_seen_at,
                        last_sync_at,
                        mqtt_client_id,
                        registered_at,
                        calibration_data
                    FROM devices
                    WHERE user_id = :user_id
                      AND deleted_at IS NULL
                      AND (:device_type IS NULL OR device_type = :device_type)
                      AND (:active IS NULL OR is_active = :active)
                    ORDER BY is_active DESC,
                             last_seen_at DESC NULLS LAST,
                             registered_at DESC
                    """
                ),
                {
                    "user_id": user_id,
                    "device_type": device_type,
                    "active": active,
                },
            ).mappings().all()
        except ProgrammingError as error:
            if DeviceService._is_missing_devices_table(error):
                db.rollback()
                return DeviceListResponse(devices=[], total=0, limit=limit, offset=offset)
            raise

        now = datetime.now(UTC)
        online_threshold = now - timedelta(minutes=5)
        devices = [
            DeviceService._map_device_row(row, online_threshold=online_threshold)
            for row in rows
        ]

        if status == "online":
            devices = [device for device in devices if device.is_online]
        elif status == "offline":
            devices = [device for device in devices if not device.is_online]

        total = len(devices)
        paged_devices = devices[offset : offset + limit]

        return DeviceListResponse(
            devices=paged_devices,
            total=total,
            limit=limit,
            offset=offset,
        )

    @staticmethod
    def get_device_by_id(
        user_id: int,
        device_id: int,
        db: Session,
    ) -> DeviceItemResponse | None:
        """
        Get a single device by ID for the current user.
        Returns None if device not found or doesn't belong to user.
        """
        try:
            row = db.execute(
                text(
                    """
                    SELECT
                        id,
                        uuid,
                        device_name,
                        device_type,
                        model,
                        firmware_version,
                        mac_address,
                        serial_number,
                        is_active,
                        battery_level,
                        signal_strength,
                        last_seen_at,
                        last_sync_at,
                        mqtt_client_id,
                        registered_at,
                        calibration_data
                    FROM devices
                    WHERE id = :device_id
                      AND user_id = :user_id
                      AND deleted_at IS NULL
                    """
                ),
                {
                    "device_id": device_id,
                    "user_id": user_id,
                },
            ).mappings().first()
        except ProgrammingError as error:
            if DeviceService._is_missing_devices_table(error):
                return None
            raise

        if not row:
            return None

        now = datetime.now(UTC)
        online_threshold = now - timedelta(minutes=5)
        return DeviceService._map_device_row(row, online_threshold=online_threshold)

    @staticmethod
    def pair_new_device(
        user_id: int,
        mac_address: str,
        device_name: str,
        device_type: str,
        model: str | None,
        db: Session,
    ) -> DeviceItemResponse:
        """
        Pair new device via BLE scan - for DEVICE_Connect screen.
        Creates device record after successful pairing.
        """
        # Check duplicate MAC address
        DeviceService._check_duplicate_identity(
            user_id=user_id,
            serial_number=None,
            mac_address=mac_address,
            mqtt_client_id=None,
            db=db,
        )

        # Insert new device
        row = db.execute(
            text(
                """
                INSERT INTO devices (
                    user_id,
                    device_name,
                    device_type,
                    model,
                    mac_address,
                    is_active,
                    battery_level,
                    registered_at,
                    updated_at
                )
                VALUES (
                    :user_id,
                    :device_name,
                    :device_type,
                    :model,
                    :mac_address,
                    TRUE,
                    100,
                    NOW(),
                    NOW()
                )
                RETURNING
                    id,
                    uuid,
                    device_name,
                    device_type,
                    model,
                    firmware_version,
                    mac_address,
                    serial_number,
                    is_active,
                    battery_level,
                    signal_strength,
                    last_seen_at,
                    last_sync_at,
                    mqtt_client_id,
                    registered_at,
                    calibration_data
                """
            ),
            {
                "user_id": user_id,
                "device_name": device_name.strip(),
                "device_type": device_type,
                "model": model.strip() if model else None,
                "mac_address": mac_address.upper(),
            },
        ).mappings().first()

        if row is None:
            db.rollback()
            raise ValueError("Failed to create device")

        db.commit()
        online_threshold = datetime.now(UTC) - timedelta(minutes=5)
        return DeviceService._map_device_row(row, online_threshold=online_threshold)

    @staticmethod
    def update_device_settings(
        user_id: int,
        device_id: int,
        settings,  # DeviceSettingsRequest
        db: Session,
    ) -> dict | None:
        """
        Update device configuration & calibration - for DEVICE_Configure screen.
        Stores sensor calibration parameters and notification preferences.
        """
        # Verify device ownership
        device = db.execute(
            text("SELECT id, calibration_data FROM devices WHERE id = :id AND user_id = :user_id"),
            {"id": device_id, "user_id": user_id},
        ).mappings().first()

        if device is None:
            raise PermissionError("Không có quyền truy cập thiết bị này")

        # Build calibration data JSON
        calibration_data = {
            "heart_rate_offset": settings.heart_rate_offset or 0,
            "spo2_calibration": settings.spo2_calibration or 1.0,
            "temperature_offset": settings.temperature_offset or 0.0,
            "notify_high_hr": settings.notify_high_hr if settings.notify_high_hr is not None else True,
            "notify_low_spo2": settings.notify_low_spo2 if settings.notify_low_spo2 is not None else True,
            "notify_high_bp": settings.notify_high_bp if settings.notify_high_bp is not None else True,
            "wear_side": settings.wear_side or "left",
            "updated_at": datetime.now(UTC).isoformat(),
        }

        # Update calibration_data in DB
        db.execute(
            text(
                """
                UPDATE devices
                SET calibration_data = :calibration_data,
                    updated_at = NOW()
                WHERE id = :device_id
                """
            ),
            {
                "device_id": device_id,
                "calibration_data": json.dumps(calibration_data),  # Store as proper JSON
            },
        )

        db.commit()
        return calibration_data
