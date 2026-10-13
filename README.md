# ACEest Fitness & Performance — Application

This folder contains only the files required to run the Flask application locally.

## Requirements
- Python 3.10 or newer
- pip

## Run on Windows

Open a terminal in this folder and run:

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

Then open http://127.0.0.1:5000 in your browser.

## Run on macOS/Linux

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python app.py
```

Then open http://127.0.0.1:5000 in your browser.

## Included features
- Client creation and client summary
- Optional profile and target details
- Training-program generation based on a selected goal
- Workout logging and workout history
- Membership status and renewal-date display
- SQLite database created automatically as `aceest_fitness.db`
- Health endpoint at `/health`

The generated training program is a simple random template selector; it is not an AI model. This is a local demonstration application and does not include authentication or production security controls. Do not expose it publicly with real client information.
