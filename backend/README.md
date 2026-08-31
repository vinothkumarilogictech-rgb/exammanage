# Office Management Backend

Flask application with server-rendered web UI and a mobile REST API.

## API architecture

`api/`
- `routes.py` — Flask REST endpoints
- `views.py` — compatibility entry point
- `serializers.py` — JSON serializers
- `auth.py` — token authentication
- `permissions.py` — API permission helpers
- `filters.py` — query/filter helpers
- `pagination.py` — pagination helpers
- `exceptions.py` — API error helpers
- `urls.py` — endpoint documentation/compatibility layer

The API is registered at `/api/v1`.
