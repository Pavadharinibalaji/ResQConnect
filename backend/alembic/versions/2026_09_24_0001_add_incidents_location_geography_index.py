"""add_incidents_location_geography_index

GiST expression index on incidents.location cast to geography, so that
GET /incidents/nearby can filter with ST_DWithin(location::geography, ..., metres)
using an index. The existing geometry index (idx_incidents_location) cannot serve
a geography expression and is kept as is.

Revision ID: 2026_09_24_0001
Revises: 2026_08_16_0003
Create Date: 2026-09-24 12:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '2026_09_24_0001'
down_revision: Union[str, None] = '2026_08_16_0003'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_index(
        'idx_incidents_location_geography',
        'incidents',
        [sa.text('(location::geography)')],
        unique=False,
        postgresql_using='gist',
    )


def downgrade() -> None:
    op.drop_index('idx_incidents_location_geography', table_name='incidents')
