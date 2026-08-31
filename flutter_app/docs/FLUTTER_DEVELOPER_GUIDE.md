# Developer Guide

Request flow:

UI Screen -> Provider (when shared state is needed) -> Service -> DioClient -> Flask `/api/v1` -> SQLAlchemy models -> JSON.

Do not put raw HTTP calls inside widgets. Add endpoints to `DioClient`, expose a method from `ApiService`/`DataSyncService`, then consume it from the screen/provider.
