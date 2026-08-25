from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_root():
    response = client.get("/")

    assert response.status_code == 200

    data = response.json()

    assert data["service"] == "cloud-reliability-lab"
    assert data["status"] == "running"
    assert data["message"] == "FastAPI reliability lab is online"
    assert "config" in data


def test_health():
    response = client.get("/health")

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "ok"
    assert "hostname" in data
    assert "started_at" in data
    assert "checked_at" in data


def test_version():
    response = client.get("/version")

    assert response.status_code == 200

    data = response.json()

    assert data["service"] == "cloud-reliability-lab"
    assert "version" in data