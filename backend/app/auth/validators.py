# This file can contain additional custom validators for requests if needed, 
# e.g., validating password strengths (not needed here since we use Firebase Phone Auth),
# or validating specific token formats. Currently, pydantic handles schema validation 
# and jwt handles token validation natively.

def is_valid_token_format(token: str) -> bool:
    """Basic structural validation for a JWT."""
    parts = token.split(".")
    return len(parts) == 3
