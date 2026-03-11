from datetime import datetime
import re

from pydantic import BaseModel, Field, field_validator


class DeviceCreateRequest(BaseModel):
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


class DeviceListResponse(BaseModel):
    devices: list[DeviceItemResponse]
    total: int = 0
    limit: int = 50
    offset: int = 0
