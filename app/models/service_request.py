from typing import Literal

from pydantic import BaseModel, Field, field_validator


class ServiceRequest(BaseModel):
    service_name: str
    owner: str
    language: str = "python"
    environment: str = "dev"
    needs_ai: bool = True

    aws_account_id: str = "123456789012"
    aws_region: str = "eu-north-1"
    github_owner: str = "hansessay"
    github_repo: str = "platform-engineering-reference-architecture"

    # --------------------------
    # Persistent Storage
    # --------------------------

    persistent_storage: bool = False

    storage_type: Literal["block", "filesystem"] = "block"

    storage_size: str = Field(default="10Gi")

    storage_class: str = Field(default="rook-ceph-block")

    storage_access_mode: Literal[
        "ReadWriteOnce",
        "ReadWriteMany",
    ] = "ReadWriteOnce"

    mount_path: str = "/data"

    storage_snapshots: bool = False

    @field_validator("storage_size")
    @classmethod
    def validate_storage_size(cls, value: str):
        if not value.endswith(("Mi", "Gi", "Ti")):
            raise ValueError("Storage size must end with Mi, Gi or Ti.")
        return value