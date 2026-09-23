from fastapi import APIRouter
from app.api.v1.endpoints import router as endpoints_router
from app.api.v1.auth import router as auth_router
from app.users.api import router as users_router
from app.api.v1.incidents import router as incidents_router
from app.api.v1.profile import router as profile_router
from app.api.v1.admin import router as admin_router

api_router = APIRouter()

api_router.include_router(endpoints_router)
api_router.include_router(auth_router)
api_router.include_router(users_router)
api_router.include_router(incidents_router)
api_router.include_router(profile_router)
api_router.include_router(admin_router)
