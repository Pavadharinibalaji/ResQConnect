"""initial_postgis

Revision ID: 0001
Revises: 
Create Date: 2026-07-21 22:45:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0001'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Task 11: Enable PostGIS extension
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis;")


def downgrade() -> None:
    # Disable PostGIS extension
    op.execute("DROP EXTENSION IF EXISTS postgis;")
