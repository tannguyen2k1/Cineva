from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

PermissionAction = Literal["read", "create", "update", "delete"]

ACTION_LABELS: dict[str, str] = {
    "read": "Xem",
    "create": "Tạo",
    "update": "Sửa",
    "delete": "Xóa",
}


@dataclass(frozen=True)
class ModulePermissionDef:
    action: PermissionAction
    description: str


@dataclass(frozen=True)
class SystemModuleDef:
    key: str
    label: str
    permissions: tuple[ModulePermissionDef, ...]


SYSTEM_MODULES: tuple[SystemModuleDef, ...] = (
    SystemModuleDef(
        key="dashboard",
        label="Dashboard",
        permissions=(ModulePermissionDef("read", "Xem trang tổng quan"),),
    ),
    SystemModuleDef(
        key="users",
        label="Người dùng",
        permissions=(
            ModulePermissionDef("read", "Xem danh sách người dùng"),
            ModulePermissionDef("create", "Tạo người dùng"),
            ModulePermissionDef("update", "Sửa / khóa người dùng"),
            ModulePermissionDef("delete", "Xóa người dùng (soft delete)"),
        ),
    ),
    SystemModuleDef(
        key="roles",
        label="Vai trò",
        permissions=(
            ModulePermissionDef("read", "Xem danh sách vai trò"),
            ModulePermissionDef("create", "Tạo vai trò"),
            ModulePermissionDef("update", "Sửa vai trò và phân quyền"),
            ModulePermissionDef("delete", "Xóa vai trò (soft delete)"),
        ),
    ),
    SystemModuleDef(
        key="tenants",
        label="Tenant",
        permissions=(
            ModulePermissionDef("read", "Xem danh sách tenant"),
            ModulePermissionDef("create", "Tạo tenant"),
            ModulePermissionDef("update", "Sửa / khóa tenant"),
            ModulePermissionDef("delete", "Xóa tenant (soft delete)"),
        ),
    ),
    SystemModuleDef(
        key="logs",
        label="Nhật ký",
        permissions=(ModulePermissionDef("read", "Xem nhật ký hệ thống"),),
    ),
)

SYSTEM_PERMISSIONS = [
    {
        "action": p.action,
        "resource": mod.key,
        "description": p.description,
        "module_label": mod.label,
    }
    for mod in SYSTEM_MODULES
    for p in mod.permissions
]

RESOURCE_LABELS = {m.key: m.label for m in SYSTEM_MODULES}


def permission_key(action: str, resource: str) -> str:
    return f"{action}:{resource}"
