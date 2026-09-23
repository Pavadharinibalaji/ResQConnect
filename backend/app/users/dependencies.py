from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.dependencies.database import get_db
from app.users.repository import UserRepository
from app.users.service import UserService

def get_user_service(db: AsyncSession = Depends(get_db)) -> UserService:
    repository = UserRepository(db)
    return UserService(repository)
