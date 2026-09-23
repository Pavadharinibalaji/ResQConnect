"""
Role categories and the single source of truth for role-based trust.

- `users.role` is the primary/display role; `profiles.emergency_role` mirrors it for the profile.
- `user_roles` holds the roles a user is trusted with. Privileged roles enter it only
  through the admin role endpoints (app/api/v1/admin.py).
- A role name is only ever compared exactly (after trim/lower-case); unknown names such as
  "administrator" or "firefighter" never map onto a known role.

This is authorisation, not identity verification: an admin grant records that an admin
vouched for the user; ResQConnect does not verify real-world credentials.
"""
from typing import Iterable, Set

SELF_SELECTABLE_ROLES = frozenset({"citizen", "volunteer"})
ORGANIZATIONAL_ROLES = frozenset({"ngo", "police", "fire", "ambulance"})
ADMIN_ROLE = "admin"

# Roles only an admin may grant or revoke.
ADMIN_GRANTABLE_ROLES = ORGANIZATIONAL_ROLES | {ADMIN_ROLE}
# Roles a profile may display (admin is an authority, not an emergency role).
PROFILE_ROLES = SELF_SELECTABLE_ROLES | ORGANIZATIONAL_ROLES
KNOWN_ROLES = PROFILE_ROLES | {ADMIN_ROLE}


def normalize_role_name(value: str) -> str:
    return (value or "").strip().lower()


def granted_role_names(user) -> Set[str]:
    """Roles recorded in user_roles (requires `user.roles` to be loaded)."""
    return {role.name for role in user.roles}


def is_admin(user) -> bool:
    """The only admin check: primary role or an admin grant in user_roles."""
    return user.role == ADMIN_ROLE or ADMIN_ROLE in granted_role_names(user)


def can_self_assign(user, role_name: str) -> bool:
    """Self-service may pick a self-selectable role or a privileged role already granted."""
    return role_name in SELF_SELECTABLE_ROLES or role_name in granted_role_names(user)


def describe(roles: Iterable[str]) -> str:
    return ", ".join(sorted(roles))


def resolve_self_service_role(user, requested: str) -> str:
    """
    Validates a role chosen through self-service (profile setup / profile update).
    Returns the normalised role, or raises 403 for a privileged role the user was never
    granted and 400 for anything that is not a profile role.
    """
    from fastapi import HTTPException, status

    role = normalize_role_name(requested)
    if role in ADMIN_GRANTABLE_ROLES and not can_self_assign(user, role):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This role can only be granted by an administrator.",
        )
    if role not in PROFILE_ROLES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid role selected. Self-service roles: {describe(SELF_SELECTABLE_ROLES)}.",
        )
    return role
