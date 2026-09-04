"""Seed Admin role, permissions, and admin user."""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select

from app.core.config import get_settings
from app.core.security import hash_password
from app.db.session import AsyncSessionLocal
from app.models import Role, User, UserRole
from app.services.permissions_sync import ensure_system_permissions


async def main() -> None:
    settings = get_settings()
    print("Seeding database...")

    async with AsyncSessionLocal() as db:
        role_result = await db.execute(
            select(Role).where(Role.name == "Admin", Role.deleted_at.is_(None))
        )
        role = role_result.scalar_one_or_none()
        if not role:
            role = Role(
                name="Admin",
                description="Quản trị viên hệ thống",
            )
            db.add(role)
            await db.flush()

        user_result = await db.execute(
            select(User).where(
                User.username == settings.default_admin_username,
                User.deleted_at.is_(None),
            )
        )
        user = user_result.scalar_one_or_none()
        hashed = hash_password(settings.default_admin_password)
        if not user:
            user = User(
                username=settings.default_admin_username,
                password=hashed,
                full_name="Super Admin",
                is_active=True,
            )
            db.add(user)
            await db.flush()
        else:
            user.password = hashed

        link = await db.execute(
            select(UserRole).where(UserRole.user_id == user.id, UserRole.role_id == role.id)
        )
        if not link.scalar_one_or_none():
            db.add(UserRole(user_id=user.id, role_id=role.id))

        await db.commit()
        await ensure_system_permissions(db)

        member_result = await db.execute(
            select(Role).where(Role.name == "Member", Role.deleted_at.is_(None))
        )
        if not member_result.scalar_one_or_none():
            db.add(Role(name="Member", description="Thành viên xem phim"))
            await db.commit()

    print("Seeding completed!")
    print("--- CINEVA DEFAULT ACCOUNT ---")
    print(f"Username: {settings.default_admin_username}")
    print(f"Password: {settings.default_admin_password}")


if __name__ == "__main__":
    asyncio.run(main())
