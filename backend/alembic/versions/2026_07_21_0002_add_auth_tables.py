"""add_auth_tables

Revision ID: 0002
Revises: 0001
Create Date: 2026-07-21 23:15:00.000000

"""
from typing import Sequence, Union
import uuid
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0002'
down_revision: Union[str, None] = '0001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create 'roles' table
    op.create_table(
        'roles',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('name', sa.String(length=50), nullable=False),
        sa.Column('description', sa.String(length=255), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_roles_id'), 'roles', ['id'], unique=False)
    op.create_index(op.f('ix_roles_name'), 'roles', ['name'], unique=True)

    # 2. Create 'users' table
    op.create_table(
        'users',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('firebase_uid', sa.String(length=255), nullable=False),
        sa.Column('phone_number', sa.String(length=50), nullable=False),
        sa.Column('full_name', sa.String(length=255), nullable=True),
        sa.Column('email', sa.String(length=255), nullable=True),
        sa.Column('profile_photo', sa.String(length=1024), nullable=True),
        sa.Column('role', sa.String(length=50), nullable=False, server_default='citizen'),
        sa.Column('is_verified', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('last_login', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_id'), 'users', ['id'], unique=False)
    op.create_index(op.f('ix_users_firebase_uid'), 'users', ['firebase_uid'], unique=True)
    op.create_index(op.f('ix_users_phone_number'), 'users', ['phone_number'], unique=True)
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)

    # 3. Create many-to-many association 'user_roles' table
    op.create_table(
        'user_roles',
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('role_id', sa.UUID(), nullable=False),
        sa.ForeignKeyConstraint(['role_id'], ['roles.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('user_id', 'role_id')
    )
    op.create_index(op.f('ix_user_roles_role_id'), 'user_roles', ['role_id'], unique=False)
    op.create_index(op.f('ix_user_roles_user_id'), 'user_roles', ['user_id'], unique=False)

    # 4. Create 'devices' table
    op.create_table(
        'devices',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('device_token', sa.String(length=512), nullable=False),
        sa.Column('device_type', sa.String(length=50), nullable=False),
        sa.Column('os_version', sa.String(length=50), nullable=True),
        sa.Column('ip_address', sa.String(length=50), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_devices_id'), 'devices', ['id'], unique=False)
    op.create_index(op.f('ix_devices_user_id'), 'devices', ['user_id'], unique=False)

    # 5. Create 'refresh_tokens' table
    op.create_table(
        'refresh_tokens',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('token_hash', sa.String(length=255), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('is_revoked', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_refresh_tokens_id'), 'refresh_tokens', ['id'], unique=False)
    op.create_index(op.f('ix_refresh_tokens_user_id'), 'refresh_tokens', ['user_id'], unique=False)
    op.create_index(op.f('ix_refresh_tokens_token_hash'), 'refresh_tokens', ['token_hash'], unique=True)

    # 6. Create 'audit_logs' table
    op.create_table(
        'audit_logs',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=True),
        sa.Column('action', sa.String(length=100), nullable=False),
        sa.Column('ip_address', sa.String(length=50), nullable=True),
        sa.Column('user_agent', sa.String(length=512), nullable=True),
        sa.Column('details', sa.JSON(), nullable=True),
        sa.Column('timestamp', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_audit_logs_id'), 'audit_logs', ['id'], unique=False)
    op.create_index(op.f('ix_audit_logs_user_id'), 'audit_logs', ['user_id'], unique=False)
    op.create_index(op.f('ix_audit_logs_action'), 'audit_logs', ['action'], unique=False)

    # 7. Seed standard Roles (Task 1 & 3)
    # citizen, volunteer, ngo, police, fire, ambulance, admin
    roles_table = sa.table(
        'roles',
        sa.column('id', sa.UUID),
        sa.column('name', sa.String),
        sa.column('description', sa.String)
    )
    op.bulk_insert(
        roles_table,
        [
            {'id': uuid.uuid4(), 'name': 'citizen', 'description': 'Citizen reporting incidents'},
            {'id': uuid.uuid4(), 'name': 'volunteer', 'description': 'Volunteer response coordinate'},
            {'id': uuid.uuid4(), 'name': 'ngo', 'description': 'NGO Organization response coordinate'},
            {'id': uuid.uuid4(), 'name': 'police', 'description': 'Law enforcement responder'},
            {'id': uuid.uuid4(), 'name': 'fire', 'description': 'Fire department responder'},
            {'id': uuid.uuid4(), 'name': 'ambulance', 'description': 'Medical ambulance responder'},
            {'id': uuid.uuid4(), 'name': 'admin', 'description': 'Global system administrator'},
        ]
    )


def downgrade() -> None:
    op.drop_table('audit_logs')
    op.drop_table('refresh_tokens')
    op.drop_table('devices')
    op.drop_table('user_roles')
    op.drop_table('users')
    op.drop_table('roles')
