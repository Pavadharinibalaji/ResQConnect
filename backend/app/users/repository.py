from uuid import UUID
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.users.models import User
from app.users.schemas import UserCreate, UserUpdate
from datetime import datetime

class UserRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, user_id: UUID) -> Optional[User]:
        result = await self.db.execute(
            select(User).where(User.id == user_id, User.is_deleted == False)
        )
        return result.scalar_one_or_none()

    async def get_by_firebase_uid(self, firebase_uid: str) -> Optional[User]:
        result = await self.db.execute(
            select(User).where(User.firebase_uid == firebase_uid, User.is_deleted == False)
        )
        return result.scalar_one_or_none()

    async def create(self, user_in: UserCreate) -> User:
        user = User(**user_in.model_dump())
        self.db.add(user)
        await self.db.flush()
        return user

    async def update(self, user: User, user_update: UserUpdate) -> User:
        update_data = user_update.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(user, field, value)
        await self.db.flush()
        return user

    async def update_last_login(self, user: User) -> User:
        user.last_login = datetime.utcnow()
        await self.db.flush()
        return user
