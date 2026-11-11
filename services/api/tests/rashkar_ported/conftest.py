import uuid
import pytest
from fastapi.testclient import TestClient
from cropnet.services.api.app.core.config import settings
from cropnet.services.api.app.main import app


class _AuthClientWrapper:
    def __init__(self, inner: TestClient):
        self._inner = inner
        self._headers = {"X-Dev-User-Id": settings.DEV_USER_ID}

    def get(self, url, **kwargs):
        hdrs = {**self._headers, **(kwargs.pop("headers", None) or {})}
        return self._inner.get(url, headers=hdrs, **kwargs)

    def post(self, url, **kwargs):
        hdrs = {**self._headers, **(kwargs.pop("headers", None) or {})}
        return self._inner.post(url, headers=hdrs, **kwargs)

    def put(self, url, **kwargs):
        hdrs = {**self._headers, **(kwargs.pop("headers", None) or {})}
        return self._inner.put(url, headers=hdrs, **kwargs)


@pytest.fixture
def client(test_client):
    settings.ALLOW_DEV_AUTH_BYPASS = True
    return _AuthClientWrapper(test_client)
