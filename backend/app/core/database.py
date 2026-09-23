from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from app.core.config import settings

# Create async engine with robust connection pooling
engine = create_async_engine(
    settings.async_database_uri,
    echo=False,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
)

# Async session factory
SessionLocal = async_sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
    class_=AsyncSession,
)

# Database Session Dependency for FastAPI endpoint injection
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with SessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
