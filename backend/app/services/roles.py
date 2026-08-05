from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Role
from app.repositories import permission as permission_repo
from app.repositories import role as role_repo
from app.schemas import RoleCreate, RolePermissionsUpdate, RoleUpdate
from app.services.system_log import write_system_log


async def list_roles(
    db: AsyncSession,
    tenant_id: str,
    *,
    page: int = 1,
    page_size: int = 10,
    search: str | None = None,
) -> dict:
    roles, total = await role_repo.list_roles_page(
        db, tenant_id=tenant_id, page=page, page_size=page_size, search=search
    )
    data = [
        {
            "id": role.id,
            "name": role.name,
            "description": role.description,
            "userCount": role_repo.active_user_count(role),
            "createdAt": role.created_at,
        }
        for role in roles
    ]
    return {
        "success": True,
        "data": data,
        "total": total,
        "page": page,
        "pageSize": page_size,
    }


async def create_role(
    db: AsyncSession, tenant_id: str, actor_id: str | None, body: RoleCreate
) -> dict:
    name = (body.name or "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="Tên vai trò là bắt buộc")

    if await role_repo.find_by_name(db, tenant_id=tenant_id, name=name):
        raise HTTPException(status_code=409, detail="Tên vai trò đã tồn tại")

    role = await role_repo.add_role(
        db, Role(tenant_id=tenant_id, name=name, description=body.description)
    )
    await db.commit()
    await db.refresh(role)
    await write_system_log(
        db,
        tenant_id=tenant_id,
        user_id=actor_id,
        action="CREATE_ROLE",
        resource="Role",
        details={"id": role.id, "name": role.name},
    )
    return {
        "success": True,
        "data": {
            "id": role.id,
            "name": role.name,
            "description": role.description,
            "createdAt": role.created_at,
            "userCount": 0,
        },
    }


async def update_role(
    db: AsyncSession, tenant_id: str, actor_id: str | None, role_id: str, body: RoleUpdate
) -> dict:
    role = await role_repo.get_by_id(
        db, role_id=role_id, tenant_id=tenant_id, with_users=True
    )
    if not role:
        raise HTTPException(status_code=404, detail="Không tìm thấy vai trò")

    if body.name is not None:
        name = body.name.strip()
        if not name:
            raise HTTPException(status_code=400, detail="Tên vai trò không được trống")
        if await role_repo.find_by_name(
            db, tenant_id=tenant_id, name=name, exclude_id=role_id
        ):
            raise HTTPException(status_code=409, detail="Tên vai trò đã tồn tại")
        role.name = name
    if body.description is not None:
        role.description = body.description

    await db.commit()
    await db.refresh(role)
    await write_system_log(
        db,
        tenant_id=tenant_id,
        user_id=actor_id,
        action="UPDATE_ROLE",
        resource="Role",
        details={"id": role.id, "name": role.name},
    )
    return {
        "success": True,
        "data": {
            "id": role.id,
            "name": role.name,
            "description": role.description,
            "createdAt": role.created_at,
            "userCount": role_repo.active_user_count(role),
        },
    }


async def delete_role(
    db: AsyncSession, tenant_id: str, actor_id: str | None, role_id: str
) -> dict:
    role = await role_repo.get_by_id(
        db, role_id=role_id, tenant_id=tenant_id, with_users=True
    )
    if not role:
        raise HTTPException(status_code=404, detail="Không tìm thấy vai trò")

    if role_repo.active_user_count(role) > 0:
        raise HTTPException(
            status_code=400,
            detail="Không thể xóa vai trò đang được gán cho người dùng",
        )

    await role_repo.soft_delete(db, role)
    await db.commit()
    await write_system_log(
        db,
        tenant_id=tenant_id,
        user_id=actor_id,
        action="DELETE_ROLE",
        resource="Role",
        details={"id": role.id, "name": role.name},
    )
    return {"success": True, "message": "Đã xóa vai trò"}


async def get_role_permissions(db: AsyncSession, tenant_id: str, role_id: str) -> dict:
    role = await role_repo.get_by_id(db, role_id=role_id, tenant_id=tenant_id)
    if not role:
        raise HTTPException(status_code=404, detail="Không tìm thấy vai trò")

    perms = await role_repo.list_role_permissions(db, role_id)
    return {
        "success": True,
        "data": {
            "roleId": role.id,
            "roleName": role.name,
            "permissionIds": [p.permission_id for p in perms],
        },
    }


async def update_role_permissions(
    db: AsyncSession,
    tenant_id: str,
    actor_id: str | None,
    role_id: str,
    body: RolePermissionsUpdate,
) -> dict:
    role = await role_repo.get_by_id(db, role_id=role_id, tenant_id=tenant_id)
    if not role:
        raise HTTPException(status_code=404, detail="Không tìm thấy vai trò")

    permission_ids = body.permissionIds or []
    if permission_ids:
        found = await permission_repo.get_ids_in_tenant(
            db, tenant_id=tenant_id, permission_ids=permission_ids
        )
        if len(found) != len(permission_ids):
            raise HTTPException(status_code=400, detail="Một hoặc nhiều quyền không hợp lệ")

    await role_repo.replace_role_permissions(
        db, role_id=role_id, tenant_id=tenant_id, permission_ids=permission_ids
    )
    await db.commit()
    await write_system_log(
        db,
        tenant_id=tenant_id,
        user_id=actor_id,
        action="UPDATE_ROLE_PERMISSIONS",
        resource="Role",
        details={"id": role.id, "name": role.name, "permissionCount": len(permission_ids)},
    )
    return {
        "success": True,
        "data": {"roleId": role_id, "permissionIds": permission_ids},
    }
