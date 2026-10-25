import uuid
from unittest.mock import MagicMock
from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError
from app.database import get_db
from app.main import app


def test_health_check_returns_200_and_healthy_status(client: TestClient):
    """
    Requirement 11:
    The API exposes a health check endpoint for load balancer integration.
    GET /health must return HTTP 200 OK.
    Response Body must be exactly: {"status": "healthy"}.
    """
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


def test_create_item_persists_and_returns_201(client: TestClient):
    """
    Requirement 12:
    The API accepts data ingestion and persists it to the database.
    Request: POST /items with JSON {"name": "test_name", "description": "test_desc"}.
    Response: HTTP 201 Created.
    Response Body must be a JSON object containing id, name, description, and created_at.
    """
    payload = {
        "name": "Integration Test Item",
        "description": "Created during automated unit testing."
    }
    response = client.post("/items", json=payload)
    assert response.status_code == 201
    
    data = response.json()
    assert "id" in data
    # Verify UUID format
    item_id = uuid.UUID(data["id"])
    assert str(item_id) == data["id"]
    assert data["name"] == payload["name"]
    assert data["description"] == payload["description"]
    assert "created_at" in data


def test_create_item_validation_error(client: TestClient):
    """Verifies that invalid requests without required fields are rejected."""
    # Missing required 'name' field
    response = client.post("/items", json={"description": "Missing name"})
    assert response.status_code == 422


def test_list_items_returns_200_and_array(client: TestClient):
    """
    Requirement 13:
    The API retrieves data from the persistent database.
    Request: GET /items.
    Response: HTTP 200 OK.
    Response Body must be a JSON Array containing serialized item objects matching the schema.
    """
    # Create two items first
    item1 = {"name": "Item Alpha", "description": "First test item"}
    item2 = {"name": "Item Beta", "description": "Second test item"}
    
    res1 = client.post("/items", json=item1)
    res2 = client.post("/items", json=item2)
    assert res1.status_code == 201
    assert res2.status_code == 201

    response = client.get("/items")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 2
    
    names = [it["name"] for it in data]
    assert "Item Alpha" in names
    assert "Item Beta" in names
    for it in data:
        assert "id" in it
        assert "name" in it
        assert "description" in it
        assert "created_at" in it


def test_database_failure_on_post_handled_gracefully():
    """
    Requirement 14:
    The API handles database connection failures gracefully.
    If the database is unreachable during a request to POST /items,
    the application must not crash the container. It must catch the exception
    and return an HTTP 500 Internal Server Error with a JSON error message.
    """
    # Create a mock session that raises OperationalError when commit is called
    mock_session = MagicMock()
    mock_session.commit.side_effect = OperationalError("connection refused", {}, Exception("DB down"))

    def override_get_db_failure():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db_failure
    try:
        with TestClient(app, raise_server_exceptions=False) as test_client:
            response = test_client.post("/items", json={"name": "Fault Test", "description": "Simulated failure"})
            assert response.status_code == 500
            data = response.json()
            assert "error" in data
            assert "message" in data
    finally:
        app.dependency_overrides.clear()


def test_database_failure_on_get_handled_gracefully():
    """
    Requirement 14:
    If the database is unreachable during a request to GET /items,
    the application must not crash the container. It must catch the exception
    and return an HTTP 500 Internal Server Error with a JSON error message.
    """
    mock_session = MagicMock()
    mock_session.query.side_effect = OperationalError("connection lost", {}, Exception("DB down"))

    def override_get_db_failure():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db_failure
    try:
        with TestClient(app, raise_server_exceptions=False) as test_client:
            response = test_client.get("/items")
            assert response.status_code == 500
            data = response.json()
            assert "error" in data
            assert "message" in data
    finally:
        app.dependency_overrides.clear()
