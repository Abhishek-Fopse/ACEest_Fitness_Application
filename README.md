# ACEest Fitness & Performance — Application

This repository contains the Flask application for ACEest Fitness & Gym, along with automated tests and configuration files for Docker, Jenkins, and GitHub Actions.

## Requirements

- Python 3.10 or newer
- pip
- Docker (for containerized execution and testing)

## Run on Windows

Open a terminal in the project root folder and run:

```powershell
py -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python app.py
```

If PowerShell blocks activation, use Command Prompt and run:

```bat
.venv\Scripts\activate.bat
```

Then open [http://127.0.0.1:5000](http://127.0.0.1:5000) in your browser.

## Run on macOS/Linux

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python app.py
```

Then open [http://127.0.0.1:5000](http://127.0.0.1:5000) in your browser.

## Included Features

- Client creation and client summary
- Optional profile and target details
- Training-program generation based on a selected goal
- Workout logging and workout history
- Membership status and renewal-date display
- SQLite database created automatically as `aceest_fitness.db`
- Health endpoint at `/health`

The generated training program is a simple random template selector; it is not an AI model. This is a local demonstration application and does not include authentication or production security controls. Do not expose it publicly with real client information.

## Automated Testing

Pytest is used to run automated tests against the application.

From the project root, execute:

```bash
python -m pytest -v
```

The command discovers and executes the test suite, displaying individual test results and a summary of the execution.

## Docker

Build the Docker image from the project root:

```bash
docker build -t aceest-fitness .
```

Run the automated tests inside the container:

```bash
docker run --rm aceest-fitness python -m pytest -v
```

The `--rm` option removes the test container after the command finishes.

To run the application in a container:

```bash
docker run --rm -p 5000:5000 aceest-fitness
```

Then open [http://127.0.0.1:5000](http://127.0.0.1:5000) in your browser.

## Continuous Integration

### GitHub Actions

The GitHub Actions workflow is defined in `.github/workflows/main.yml`. It is triggered by `push` and `pull_request` events and performs the following tasks:

- Validates Python syntax.
- Checks code quality using Ruff.
- Builds the Docker image.
- Executes the Pytest suite inside a Docker container.

### Jenkins

The `Jenkinsfile` defines the Jenkins pipeline used to retrieve the project from GitHub and execute the build and validation stages. The pipeline includes:

- Python syntax validation.
- Ruff linting.
- Automated testing with Pytest.
- Static code analysis using SonarQube.
- Docker image creation.

The Jenkins job is configured to retrieve the pipeline definition from the `main` branch of the GitHub repository using the `Jenkinsfile` located in the repository root.

## Repository

GitHub: https://github.com/Abhishek-Fopse/ACEest_Fitness_Application