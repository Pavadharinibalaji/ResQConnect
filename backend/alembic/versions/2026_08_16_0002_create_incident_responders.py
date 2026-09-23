"""create_incident_responders

Revision ID: 2026_08_16_0002
Revises: 2026_08_16_0001
Create Date: 2026-08-16 20:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '2026_08_16_0002'
down_revision: Union[str, None] = '2026_08_16_0001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'incident_responders',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('incident_id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('status', sa.String(length=50), nullable=False, server_default='responding'),
        sa.Column('notes', sa.String(length=512), nullable=True),
        sa.Column('joined_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['incident_id'], ['incidents.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('incident_id', 'user_id', name='uq_incident_responder')
    )
    op.create_index(op.f('ix_incident_responders_id'), 'incident_responders', ['id'], unique=False)
    op.create_index(op.f('ix_incident_responders_incident_id'), 'incident_responders', ['incident_id'], unique=False)
    op.create_index(op.f('ix_incident_responders_user_id'), 'incident_responders', ['user_id'], unique=False)
    op.create_index(op.f('ix_incident_responders_status'), 'incident_responders', ['status'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_incident_responders_status'), table_name='incident_responders')
    op.drop_index(op.f('ix_incident_responders_user_id'), table_name='incident_responders')
    op.drop_index(op.f('ix_incident_responders_incident_id'), table_name='incident_responders')
    op.drop_index(op.f('ix_incident_responders_id'), table_name='incident_responders')
    op.drop_table('incident_responders')
