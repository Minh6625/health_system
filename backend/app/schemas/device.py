from datetime import datetime
import re

from pydantic import BaseModel, ConfigDict, Field, field_validator


# [HS-015] Every Request schema in this module rejects unknown fields so
# typos surface as 422 instead of being silently dropped.


class DeviceCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    device_name: str = Field(min_length=1, max_length=100)
    device_type: str = Field(default="smartwatch")
    model: str | None = Field(default=None, max_length=100)
    firmware_version: str | None = Field(default=None, max_length=20)
    mac_address: str | None = Field(default=None, max_length=17)
    serial_number: str | None = Field(default=None, max_length=100)
    mqtt_client_id: str | None = Field(default=None, max_length=100)

    @field_validator("device_type")
    @classmethod
    def validate_device_type(cls, value: str) -> str:
        allowed = {"smartwatch", "fitness_band", "medical_device"}
        if value not in allowed:
            raise ValueError("Loai thiet bi khong hop le")
        return value

    @field_validator("mac_address")
    @classmethod
    def validate_mac_address(cls, value: str | None) -> str | None:
        if value is None:
            return None
        mac = value.strip().upper()
        if not mac:
            return None
        pattern = re.compile(r"^[0-9A-F]{2}(:[0-9A-F]{2}){5}$")
        if not pattern.match(mac):
            raise ValueError("MAC address khong dung dinh dang AA:BB:CC:DD:EE:FF")
        return mac


class DeviceUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    device_name: str | None = Field(default=None, min_length=1, max_length=100)
    firmware_version: str | None = Field(default=None, max_length=20)
    is_active: bool | None = None


class DeviceActionResponse(BaseModel):
    success: bool
    message: str


class DeviceItemResponse(BaseModel):
    id: int
    uuid: str
    device_name: str | None = None
    device_type: str
    model: str | None = None
    firmware_version: str | None = None
    mac_address: str | None = None
    serial_number: str | None = None
    is_active: bool
    is_online: bool
    battery_level: int | None = None
    signal_strength: int | None = None
    last_seen_at: datetime | None = None
    last_sync_at: datetime | None = None
    mqtt_client_id: str | None = None
    registered_at: datetime | None = None
    # Stored notification + calibration preferences as a JSON dict. The mobile
    # client uses this to seed the configure screen toggles so they reflect
    # the saved values instead of always defaulting to "true".
    calibration_data: dict | None = None


class DeviceListResponse(BaseModel):
    devices: list[DeviceItemResponse]
    total: int = 0
    limit: int = 50
    offset: int = 0


class DeviceScanPairRequest(BaseModel):
    """BLE scan & pair request - for DEVICE_Connect screen"""
    model_config = ConfigDict(extra="forbid")

    mac_address: str = Field(min_length=17, max_length=17)  # AA:BB:CC:DD:EE:FF
    device_name: str = Field(min_length=1, max_length=100)
    device_type: str = Field(default="smartwatch")
    model: str | None = Field(default=None, max_length=100)
    
    @field_validator("mac_address")
    @classmethod
    def validate_mac_address(cls, value: str) -> str:
        mac = value.strip().upper()
        pattern = re.compile(r"^[0-9A-F]{2}(:[0-9A-F]{2}){5}$")
        if not pattern.match(mac):
            raise ValueError("MAC address khong dung dinh dang AA:BB:CC:DD:EE:FF")
        return mac
    
    @field_validator("device_type")
    @classmethod
    def validate_device_type(cls, value: str) -> str:
        allowed = {"smartwatch", "fitness_band", "medical_device"}
        if value not in allowed:
            raise ValueError("Loai thiet bi khong hop le")
        return value


class DeviceScanPairResponse(BaseModel):
    """Response after successful pairing"""
    success: bool
    message: str
    device: DeviceItemResponse | None = None


class DeviceSettingsRequest(BaseModel):
    """Cập nhật cấu hình thiết bị - for DEVICE_Configure screen.

    [HS-003 ADR-012] Calibration offsets dropped — no consumer in mobile BE,
    IoT sim, or HealthGuard backend. Schema retains notification toggles +
    wear_side preference only.
    """
    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "example": {
                "notify_high_hr": True,
                "notify_low_spo2": True,
                "notify_high_bp": True,
                "wear_side": "left",
            }
        },
    )

    notify_high_hr: bool | None = None
    notify_low_spo2: bool | None = None
    notify_high_bp: bool | None = None
    wear_side: str | None = Field(default=None, pattern="^(left|right)$")  # left/right wrist


class DeviceSettingsResponse(BaseModel):
    """Response after updating settings"""
    success: bool
    message: str
    calibration_data: dict | None = None  # Updated calibration_data from DB
