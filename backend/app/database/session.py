from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from app.core.config import settings

engine = create_async_engine(
    settings.async_database_uri,
    echo=settings.ENVIRONMENT == "development",
    future=True,
    pool_pre_ping=True,
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)
