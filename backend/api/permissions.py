from .auth import api_token_required

# Compatibility name matching the WorkLog API architecture.
IsAuthenticatedAPI = api_token_required
