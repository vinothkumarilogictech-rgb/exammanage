from functools import wraps
from datetime import datetime, timedelta, timezone
from itsdangerous import URLSafeTimedSerializer, BadSignature, SignatureExpired
from flask import request, g
from werkzeug.security import check_password_hash
from apps.models import User

ACCESS_MAX_AGE = 7 * 24 * 60 * 60
REFRESH_MAX_AGE = 30 * 24 * 60 * 60
DEFAULT_USERNAME = 'admin'
DEFAULT_PASSWORD = '1234'


def _serializer(secret):
    return URLSafeTimedSerializer(secret, salt='office-management-api')


def authenticate(username, password):
    username = (username or '').strip()
    if username == DEFAULT_USERNAME and password == DEFAULT_PASSWORD:
        return {'id': 'admin', 'username': DEFAULT_USERNAME}
    user = User.query.filter_by(username=username).first()
    if user and check_password_hash(user.password_hash, password):
        return {'id': str(user.id), 'username': user.username}
    return None


def issue_tokens(identity, secret):
    serializer = _serializer(secret)
    now = int(datetime.now(timezone.utc).timestamp())
    access = serializer.dumps({'sub': str(identity['id']), 'username': identity['username'], 'type': 'access', 'iat': now})
    refresh = serializer.dumps({'sub': str(identity['id']), 'username': identity['username'], 'type': 'refresh', 'iat': now})
    return {'access': access, 'refresh': refresh}


def verify_token(token, secret, expected_type='access', max_age=ACCESS_MAX_AGE):
    try:
        data = _serializer(secret).loads(token, max_age=max_age)
    except (BadSignature, SignatureExpired):
        return None
    if data.get('type') != expected_type or not data.get('sub'):
        return None
    return data


def api_token_required(fn):
    @wraps(fn)
    def wrapped(*args, **kwargs):
        header = request.headers.get('Authorization', '')
        if not header.startswith('Bearer '):
            return {'success': False, 'message': 'Authentication required.'}, 401
        from flask import current_app
        data = verify_token(header[7:].strip(), current_app.config['SECRET_KEY'], 'access', ACCESS_MAX_AGE)
        if not data:
            return {'success': False, 'message': 'Invalid or expired access token.'}, 401
        g.api_identity = data
        return fn(*args, **kwargs)
    return wrapped
