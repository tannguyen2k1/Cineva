from fastapi import APIRouter

from app.api.routes import auth, dashboard, films, logs, permissions, roles, users

api_router = APIRouter(prefix="/api")
api_router.include_router(auth.router)
api_router.include_router(films.auth_register_router)
api_router.include_router(films.public_router)
api_router.include_router(films.me_router)
api_router.include_router(films.admin_films_router)
api_router.include_router(users.router)
api_router.include_router(roles.router)
api_router.include_router(permissions.router)
api_router.include_router(logs.router)
api_router.include_router(dashboard.router)
