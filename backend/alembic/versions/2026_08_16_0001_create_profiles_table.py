"""create_profiles_table

Revision ID: 2026_08_16_0001
Revises: 14c6d7c9ef80
Create Date: 2026-08-16 16:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '2026_08_16_0001'
down_revision: Union[str, None] = '14c6d7c9ef80'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'profiles',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('display_name', sa.String(length=100), nullable=True),
        sa.Column('username', sa.String(length=50), nullable=True),
        sa.Column('bio', sa.String(length=255), nullable=True),
        sa.Column('avatar_url', sa.String(length=1024), nullable=True),
        sa.Column('location', sa.String(length=255), nullable=True),
        sa.Column('emergency_role', sa.String(length=50), nullable=False, server_default='citizen'),
        sa.Column('skills', sa.JSON(), nullable=False, server_default='[]'),
        sa.Column('response_radius_km', sa.Float(), nullable=False, server_default='10.0'),
        sa.Column('emergency_alerts_enabled', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('nearby_alerts_enabled', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('critical_override_enabled', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('availability_enabled', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('high_urgency_sound_enabled', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('profile_completed', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_profiles_id'), 'profiles', ['id'], unique=False)
    op.create_index(op.f('ix_profiles_user_id'), 'profiles', ['user_id'], unique=True)
    op.create_index(op.f('ix_profiles_username'), 'profiles', ['username'], unique=True)


def downgrade() -> None:
    op.drop_index(op.f('ix_profiles_username'), table_name='profiles')
    op.drop_index(op.f('ix_profiles_user_id'), table_name='profiles')
    op.drop_index(op.f('ix_profiles_id'), table_name='profiles')
    op.drop_table('profiles')
