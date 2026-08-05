from pydantic import BaseModel


class PermissionItemOut(BaseModel):
    id: str
    action: str
    actionLabel: str
    key: str
    description: str | None = None


class PermissionGroupOut(BaseModel):
    resource: str
    label: str
    permissions: list[PermissionItemOut]
