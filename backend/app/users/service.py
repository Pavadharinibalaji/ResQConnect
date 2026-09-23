from uuid import UUID
from app.users.repository import UserRepository
from app.users.schemas import UserCreate, UserUpdate
from app.users.models import User
from app.users.exceptions import UserNotFoundException

class UserService:
    def __init__(self, repository: UserRepository):
        self.repository = repository

    async def get_user(self, user_id: UUID) -> User:
        user = await self.repository.get_by_id(user_id)
        if not user:
            raise UserNotFoundException()
        return user

    async def get_by_firebase_uid(self, firebase_uid: str) -> User | None:
        return await self.repository.get_by_firebase_uid(firebase_uid)

    async def find_or_create(self, firebase_uid: str, phone_number: str) -> User:
        user = await self.repository.get_by_firebase_uid(firebase_uid)
        if user:
            return await self.repository.update_last_login(user)
        
        # Create new user
        user_in = UserCreate(firebase_uid=firebase_uid, phone_number=phone_number)
        return await self.repository.create(user_in)

    async def update_profile(self, user_id: UUID, user_update: UserUpdate) -> User:
        user = await self.get_user(user_id)
        return await self.repository.update(user, user_update)
