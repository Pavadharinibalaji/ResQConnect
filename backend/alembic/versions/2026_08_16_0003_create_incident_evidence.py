"""create_incident_evidence

Revision ID: 2026_08_16_0003
Revises: 2026_08_16_0002
Create Date: 2026-08-16 21:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '2026_08_16_0003'
down_revision: Union[str, None] = '2026_08_16_0002'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'incident_evidence',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('incident_id', sa.Uuid(), nullable=False),
        sa.Column('type', sa.String(length=20), nullable=False, server_default='photo'),
        sa.Column('file_path', sa.String(length=512), nullable=False),
        sa.Column('file_url', sa.String(length=1024), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['incident_id'], ['incidents.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_incident_evidence_id'), 'incident_evidence', ['id'], unique=False)
    op.create_index(op.f('ix_incident_evidence_incident_id'), 'incident_evidence', ['incident_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_incident_evidence_incident_id'), table_name='incident_evidence')
    op.drop_index(op.f('ix_incident_evidence_id'), table_name='incident_evidence')
    op.drop_table('incident_evidence')
