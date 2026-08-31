import pytest

from app import app


def test_enabled_module_routes_are_available():
    client = app.test_client()
    assert client.get('/').status_code == 200
    assert client.get('/dashboard').status_code == 200
    assert client.get('/branches').status_code == 200
    assert client.get('/exams/').status_code == 200
    assert client.get('/expense-management').status_code == 200


def test_removed_module_routes_are_not_registered():
    client = app.test_client()
    for path in ['/employees', '/inventory-management', '/customer-master', '/quotation', '/invoice', '/bank-master', '/return', '/delivery', '/settings']:
        assert client.get(path).status_code == 404
