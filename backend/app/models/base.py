from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase):
    """
    SQLAlchemy Declarative Base class from which all database models inherit.
    Ensures model registration metadata registry is shared.
    """
    pass
