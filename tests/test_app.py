import sqlite3

import pytest

import app as app_module


@pytest.fixture
def client(tmp_path, monkeypatch):
    """Create a Flask test client with an isolated temporary database."""
    db_path = tmp_path / "test_aceest_fitness.db"
    monkeypatch.setattr(app_module, "DB_PATH", str(db_path))
    app_module.init_db()

    app_module.app.config.update(TESTING=True)

    with app_module.app.test_client() as test_client:
        yield test_client


def create_client(test_client, name="Test Client", **extra_fields):
    """Submit the form used by the application to create a client."""
    form_data = {"name": name, **extra_fields}
    return test_client.post(
        "/clients/new",
        data=form_data,
        follow_redirects=True,
    )


def get_client_id(name):
    """Find a client ID in the current test database."""
    with sqlite3.connect(app_module.DB_PATH) as connection:
        row = connection.execute(
            "SELECT id FROM clients WHERE name = ?", (name,)
        ).fetchone()

    assert row is not None
    return row[0]


def test_dashboard_loads(client):
    response = client.get("/")

    assert response.status_code == 200
    assert b"Fitness dashboard" in response.data
    assert b"Total clients" in response.data
    assert b"No clients yet" in response.data


def test_health_endpoint(client):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_add_client(client):
    response = create_client(
        client,
        name="Aarav Test",
        age="25",
        weight="72",
    )

    assert response.status_code == 200
    assert b"Aarav Test" in response.data
    assert b"Client &#39;Aarav Test&#39; saved." in response.data


def test_duplicate_client_is_rejected(client):
    create_client(client, name="Duplicate Test")
    response = create_client(client, name="Duplicate Test")

    assert response.status_code == 200
    assert b"A client with that name already exists." in response.data


def test_empty_client_name_is_rejected(client):
    response = client.post(
        "/clients/new",
        data={"name": "   "},
        follow_redirects=True,
    )

    assert response.status_code == 200
    assert b"Client name is required." in response.data


def test_client_detail_page_loads(client):
    create_client(client, name="Detail Test")
    client_id = get_client_id("Detail Test")

    response = client.get(f"/clients/{client_id}")

    assert response.status_code == 200
    assert b"Detail Test" in response.data
    assert b"Training program" in response.data
    assert b"Log a workout" in response.data


def test_training_program_can_be_generated(client):
    create_client(client, name="Program Test")
    client_id = get_client_id("Program Test")

    response = client.post(
        f"/clients/{client_id}/program",
        data={"program_type": "Beginner"},
        follow_redirects=True,
    )

    assert response.status_code == 200
    assert b"Generated Beginner program:" in response.data

    with sqlite3.connect(app_module.DB_PATH) as connection:
        program = connection.execute(
            "SELECT program FROM clients WHERE id = ?", (client_id,)
        ).fetchone()[0]

    assert program in app_module.PROGRAM_TEMPLATES["Beginner"]


def test_invalid_training_program_is_rejected(client):
    create_client(client, name="Invalid Program Test")
    client_id = get_client_id("Invalid Program Test")

    response = client.post(
        f"/clients/{client_id}/program",
        data={"program_type": "Invalid Goal"},
        follow_redirects=True,
    )

    assert response.status_code == 200
    assert b"Please select a valid program goal." in response.data


def test_workout_can_be_logged(client):
    create_client(client, name="Workout Test")
    client_id = get_client_id("Workout Test")

    response = client.post(
        f"/clients/{client_id}/workouts",
        data={
            "workout_date": "2026-10-13",
            "workout_type": "Strength",
            "duration_min": "45",
            "notes": "Test workout",
        },
        follow_redirects=True,
    )

    assert response.status_code == 200
    assert b"Workout saved." in response.data
    assert b"Test workout" in response.data
    assert b"45 min" in response.data

    dashboard = client.get("/")
    assert b"Workouts logged" in dashboard.data
    assert b">1</strong>" in dashboard.data


def test_invalid_workout_duration_is_rejected(client):
    create_client(client, name="Invalid Workout Test")
    client_id = get_client_id("Invalid Workout Test")

    response = client.post(
        f"/clients/{client_id}/workouts",
        data={
            "workout_date": "2026-10-13",
            "workout_type": "Strength",
            "duration_min": "0",
            "notes": "",
        },
        follow_redirects=True,
    )

    assert response.status_code == 200
    assert (
            b"Please enter a valid date, workout type and duration."
            in response.data
    )

    with sqlite3.connect(app_module.DB_PATH) as connection:
        workout_count = connection.execute(
            "SELECT COUNT(*) FROM workouts"
        ).fetchone()[0]

    assert workout_count == 0


def test_unknown_client_returns_404(client):
    response = client.get("/clients/99999")

    assert response.status_code == 404
    assert b"Not found" in response.data
