from fastapi import APIRouter

from app.api.routes import auth, dashboard, logs, permissions, roles, tenants, users

api_router = APIRouter(prefix="/api")
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(roles.router)
api_router.include_router(tenants.router)
api_router.include_router(permissions.router)
api_router.include_router(logs.router)
api_router.include_router(dashboard.router)
