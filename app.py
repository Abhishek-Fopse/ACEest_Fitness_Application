from datetime import date, datetime
import os
import random
import sqlite3
from flask import Flask, g, redirect, render_template_string, request, url_for, flash, abort

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "change-this-development-key")
DB_PATH = os.environ.get("ACEEST_DB_PATH", os.path.join(os.path.dirname(__file__), "aceest_fitness.db"))

PROGRAM_TEMPLATES = {
    "Fat Loss": ["Full Body HIIT", "Circuit Training", "Cardio + Weights"],
    "Muscle Gain": ["Push/Pull/Legs", "Upper/Lower Split", "Full Body Strength"],
    "Beginner": ["Full Body 3x/week", "Light Strength + Mobility"],
}
WORKOUT_TYPES = ["Strength", "Hypertrophy", "Cardio", "Mobility"]

SCHEMA = """
CREATE TABLE IF NOT EXISTS clients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    age INTEGER,
    height REAL,
    weight REAL,
    program TEXT,
    calories INTEGER,
    target_weight REAL,
    target_adherence INTEGER,
    membership_status TEXT NOT NULL DEFAULT 'Active',
    membership_end TEXT
);
CREATE TABLE IF NOT EXISTS progress (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_name TEXT NOT NULL,
    week TEXT NOT NULL,
    adherence INTEGER NOT NULL CHECK(adherence BETWEEN 0 AND 100)
);
CREATE TABLE IF NOT EXISTS workouts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_name TEXT NOT NULL,
    date TEXT NOT NULL,
    workout_type TEXT NOT NULL,
    duration_min INTEGER NOT NULL CHECK(duration_min > 0),
    notes TEXT DEFAULT ''
);
CREATE TABLE IF NOT EXISTS exercises (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    workout_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    sets INTEGER,
    reps INTEGER,
    weight REAL,
    FOREIGN KEY(workout_id) REFERENCES workouts(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_name TEXT NOT NULL,
    date TEXT NOT NULL,
    weight REAL,
    waist REAL,
    bodyfat REAL
);
"""

def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA foreign_keys = ON")
    return g.db

@app.teardown_appcontext
def close_db(_error=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()

def init_db():
    os.makedirs(os.path.dirname(os.path.abspath(DB_PATH)), exist_ok=True)
    db = sqlite3.connect(DB_PATH)
    db.executescript(SCHEMA)
    db.commit()
    db.close()

def get_client_or_404(client_id):
    client = get_db().execute("SELECT * FROM clients WHERE id = ?", (client_id,)).fetchone()
    if client is None:
        abort(404)
    return client

BASE_HTML = """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{ title }} · ACEest Fitness</title>
  <style>
    :root { color-scheme: dark; --bg:#151719; --panel:#202326; --gold:#d8b24c; --muted:#aeb4bb; --line:#383d42; }
    * { box-sizing:border-box; }
    body { margin:0; font:15px/1.5 system-ui,-apple-system,Segoe UI,sans-serif; background:var(--bg); color:#f5f5f5; }
    header { background:#202326; border-bottom:2px solid var(--gold); padding:18px max(20px,calc((100% - 1120px)/2)); display:flex; justify-content:space-between; align-items:center; gap:16px; flex-wrap:wrap; }
    header a { color:var(--gold); text-decoration:none; font-weight:700; }
    main { max-width:1120px; margin:28px auto; padding:0 18px 36px; }
    h1,h2,h3 { line-height:1.2; } h1 { font-size:1.8rem; margin-top:0; } h2 { font-size:1.2rem; }
    .sub { color:var(--muted); } .grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(240px,1fr)); gap:16px; }
    .panel,.stat { background:var(--panel); border:1px solid var(--line); border-radius:12px; padding:18px; }
    .stat strong { display:block; font-size:1.8rem; color:var(--gold); }
    label { display:block; margin:10px 0 5px; color:#e0e3e6; font-size:.92rem; }
    input,select,textarea { width:100%; padding:10px 11px; border-radius:7px; border:1px solid #4b5158; background:#151719; color:#fff; font:inherit; }
    textarea { min-height:76px; resize:vertical; }
    button,.button { display:inline-block; border:0; border-radius:7px; padding:10px 14px; margin-top:12px; background:var(--gold); color:#171717; font-weight:700; text-decoration:none; cursor:pointer; }
    .button.secondary,button.secondary { background:#353b41; color:#fff; border:1px solid #50565d; }
    .actions { display:flex; flex-wrap:wrap; gap:8px; align-items:center; }
    table { width:100%; border-collapse:collapse; margin-top:10px; }
    th,td { padding:10px 8px; text-align:left; border-bottom:1px solid var(--line); vertical-align:top; }
    th { color:var(--gold); font-weight:700; }
    .flash { padding:11px 14px; margin-bottom:12px; border-radius:8px; background:#303a30; border:1px solid #506c4e; }
    .danger { color:#ff9d9d; } .pill { display:inline-block; border-radius:20px; padding:3px 9px; background:#344c3a; color:#b8efc5; font-size:.85rem; }
    .section { margin-top:22px; } .empty { color:var(--muted); padding:18px 0; }
    .inline { display:inline; } .small { font-size:.9rem; }
    @media(max-width:600px) { header { padding:16px; } th,td { padding:8px 5px; font-size:.9rem; } }
  </style>
</head>
<body>
<header>
  <a href="{{ url_for('index') }}">ACEest Fitness &amp; Performance</a>
  <nav class="actions">
    <a href="{{ url_for('index') }}">Dashboard</a>
    <a href="{{ url_for('new_client') }}">Add client</a>
  </nav>
</header>
<main>
  {% with messages = get_flashed_messages() %}
    {% for message in messages %}<div class="flash">{{ message }}</div>{% endfor %}
  {% endwith %}
  {{ content|safe }}
</main>
</body>
</html>
"""

DASHBOARD = """
<h1>Fitness dashboard</h1>
<p class="sub">Manage clients, assign training programs, track workouts and review membership status.</p>
<div class="grid">
  <div class="stat"><span class="sub">Total clients</span><strong>{{ clients|length }}</strong></div>
  <div class="stat"><span class="sub">Workouts logged</span><strong>{{ workout_count }}</strong></div>
  <div class="stat"><span class="sub">Active memberships</span><strong>{{ active_count }}</strong></div>
</div>
<div class="section panel">
  <div class="actions" style="justify-content:space-between">
    <h2>Clients</h2><a class="button" href="{{ url_for('new_client') }}">+ Add client</a>
  </div>
  {% if clients %}
  <table><thead><tr><th>Client</th><th>Program</th><th>Membership</th><th>Workouts</th><th></th></tr></thead><tbody>
  {% for c in clients %}
    <tr>
      <td><strong>{{ c.name }}</strong><div class="sub small">{% if c.age %}Age {{ c.age }}{% endif %}{% if c.weight %} · {{ c.weight }} kg{% endif %}</div></td>
      <td>{{ c.program or 'Not assigned' }}</td>
      <td><span class="pill">{{ c.membership_status }}</span><div class="sub small">{{ c.membership_end or 'No end date set' }}</div></td>
      <td>{{ c.workout_count }}</td>
      <td><a class="button secondary" href="{{ url_for('client_detail', client_id=c.id) }}">Open</a></td>
    </tr>
  {% endfor %}
  </tbody></table>
  {% else %}<p class="empty">No clients yet. Add your first client to get started.</p>{% endif %}
</div>
"""

NEW_CLIENT = """
<h1>Add a client</h1><p class="sub">Enter the details you have. Optional measurements can be filled in later.</p>
<div class="panel">
<form method="post">
  <label for="name">Client name *</label><input id="name" name="name" required maxlength="100">
  <div class="grid">
    <div><label for="age">Age</label><input id="age" name="age" type="number" min="1" max="120"></div>
    <div><label for="height">Height (cm)</label><input id="height" name="height" type="number" min="1" max="300" step="0.1"></div>
    <div><label for="weight">Current weight (kg)</label><input id="weight" name="weight" type="number" min="1" max="500" step="0.1"></div>
  </div>
  <div class="grid">
    <div><label for="calories">Daily calorie target</label><input id="calories" name="calories" type="number" min="0" max="20000"></div>
    <div><label for="target_weight">Target weight (kg)</label><input id="target_weight" name="target_weight" type="number" min="1" max="500" step="0.1"></div>
    <div><label for="target_adherence">Target adherence (%)</label><input id="target_adherence" name="target_adherence" type="number" min="0" max="100"></div>
  </div>
  <div class="grid">
    <div><label for="membership_status">Membership</label><select id="membership_status" name="membership_status"><option>Active</option><option>Expired</option><option>Paused</option></select></div>
    <div><label for="membership_end">Membership end date</label><input id="membership_end" name="membership_end" type="date"></div>
  </div>
  <button type="submit">Save client</button> <a class="button secondary" href="{{ url_for('index') }}">Cancel</a>
</form>
</div>
"""

CLIENT_DETAIL = """
<div class="actions" style="justify-content:space-between">
  <div><h1>{{ client.name }}</h1><p class="sub">Client profile and training history</p></div>
  <a class="button secondary" href="{{ url_for('index') }}">← Dashboard</a>
</div>
<div class="grid">
  <div class="panel"><h2>Client summary</h2>
    <p><span class="sub">Age:</span> {{ client.age or '—' }}</p>
    <p><span class="sub">Height:</span> {{ (client.height|string + ' cm') if client.height else '—' }}</p>
    <p><span class="sub">Current weight:</span> {{ (client.weight|string + ' kg') if client.weight else '—' }}</p>
    <p><span class="sub">Target weight:</span> {{ (client.target_weight|string + ' kg') if client.target_weight else '—' }}</p>
    <p><span class="sub">Daily calories:</span> {{ client.calories or '—' }}</p>
    <p><span class="sub">Membership:</span> <span class="pill">{{ client.membership_status }}</span></p>
    <p><span class="sub">Renewal date:</span> {{ client.membership_end or 'Not set' }}</p>
  </div>
  <div class="panel"><h2>Training program</h2>
    <p>{{ client.program or 'No program assigned yet.' }}</p>
    <form method="post" action="{{ url_for('generate_program', client_id=client.id) }}">
      <label for="program_type">Goal</label>
      <select id="program_type" name="program_type">
        {% for p in program_types %}<option>{{ p }}</option>{% endfor %}
      </select>
      <button type="submit">Generate program</button>
    </form>
    <form method="post" action="{{ url_for('membership_check', client_id=client.id) }}">
      <button class="secondary" type="submit">Check membership</button>
    </form>
  </div>
</div>
<div class="section panel">
  <h2>Log a workout</h2>
  <form method="post" action="{{ url_for('add_workout', client_id=client.id) }}">
    <div class="grid">
      <div><label for="workout_date">Date</label><input id="workout_date" name="workout_date" type="date" value="{{ today }}" required></div>
      <div><label for="workout_type">Workout type</label><select id="workout_type" name="workout_type">{% for t in workout_types %}<option>{{ t }}</option>{% endfor %}</select></div>
      <div><label for="duration_min">Duration (minutes)</label><input id="duration_min" name="duration_min" type="number" min="1" max="1440" value="60" required></div>
    </div>
    <label for="notes">Notes</label><textarea id="notes" name="notes" maxlength="1000" placeholder="Optional workout notes"></textarea>
    <button type="submit">Save workout</button>
  </form>
</div>
<div class="section panel">
  <h2>Workout history</h2>
  {% if workouts %}
  <table><thead><tr><th>Date</th><th>Type</th><th>Duration</th><th>Notes</th></tr></thead><tbody>
  {% for w in workouts %}<tr><td>{{ w.date }}</td><td>{{ w.workout_type }}</td><td>{{ w.duration_min }} min</td><td>{{ w.notes or '—' }}</td></tr>{% endfor %}
  </tbody></table>
  {% else %}<p class="empty">No workouts logged for this client yet.</p>{% endif %}
</div>
"""

@app.route("/")
def index():
    db = get_db()
    clients = db.execute("""
        SELECT c.*, COUNT(w.id) AS workout_count
        FROM clients c LEFT JOIN workouts w ON w.client_name = c.name
        GROUP BY c.id ORDER BY c.name COLLATE NOCASE
    """).fetchall()
    workout_count = db.execute("SELECT COUNT(*) FROM workouts").fetchone()[0]
    active_count = db.execute("SELECT COUNT(*) FROM clients WHERE membership_status='Active'").fetchone()[0]
    content = render_template_string(DASHBOARD, clients=clients, workout_count=workout_count, active_count=active_count)
    return render_template_string(BASE_HTML, title="Dashboard", content=content)

@app.route("/clients/new", methods=["GET", "POST"])
def new_client():
    if request.method == "POST":
        name = request.form.get("name", "").strip()
        if not name:
            flash("Client name is required.")
            return redirect(url_for("new_client"))
        def optional_number(field, cast):
            value = request.form.get(field, "").strip()
            return cast(value) if value else None
        try:
            age = optional_number("age", int)
            height = optional_number("height", float)
            weight = optional_number("weight", float)
            calories = optional_number("calories", int)
            target_weight = optional_number("target_weight", float)
            target_adherence = optional_number("target_adherence", int)
            status = request.form.get("membership_status", "Active")
            if status not in {"Active", "Expired", "Paused"}:
                raise ValueError
            end_date = request.form.get("membership_end", "").strip() or None
            if end_date:
                datetime.strptime(end_date, "%Y-%m-%d")
            db = get_db()
            db.execute("""INSERT INTO clients
                (name, age, height, weight, calories, target_weight, target_adherence, membership_status, membership_end)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (name, age, height, weight, calories, target_weight, target_adherence, status, end_date))
            db.commit()
            flash(f"Client '{name}' saved.")
            return redirect(url_for("index"))
        except sqlite3.IntegrityError:
            flash("A client with that name already exists.")
        except (ValueError, TypeError):
            flash("Please check the numeric values and date fields.")
    content = render_template_string(NEW_CLIENT)
    return render_template_string(BASE_HTML, title="Add client", content=content)

@app.route("/clients/<int:client_id>")
def client_detail(client_id):
    client = get_client_or_404(client_id)
    workouts = get_db().execute(
        "SELECT * FROM workouts WHERE client_name=? ORDER BY date DESC, id DESC", (client["name"],)
    ).fetchall()
    content = render_template_string(
        CLIENT_DETAIL, client=client, workouts=workouts, today=date.today().isoformat(),
        workout_types=WORKOUT_TYPES, program_types=list(PROGRAM_TEMPLATES.keys())
    )
    return render_template_string(BASE_HTML, title=client["name"], content=content)

@app.route("/clients/<int:client_id>/program", methods=["POST"])
def generate_program(client_id):
    client = get_client_or_404(client_id)
    goal = request.form.get("program_type", "Beginner")
    if goal not in PROGRAM_TEMPLATES:
        flash("Please select a valid program goal.")
    else:
        program = random.choice(PROGRAM_TEMPLATES[goal])
        db = get_db()
        db.execute("UPDATE clients SET program=? WHERE id=?", (program, client_id))
        db.commit()
        flash(f"Generated {goal} program: {program}")
    return redirect(url_for("client_detail", client_id=client_id))

@app.route("/clients/<int:client_id>/workouts", methods=["POST"])
def add_workout(client_id):
    client = get_client_or_404(client_id)
    workout_date = request.form.get("workout_date", "")
    workout_type = request.form.get("workout_type", "")
    notes = request.form.get("notes", "").strip()
    try:
        datetime.strptime(workout_date, "%Y-%m-%d")
        duration = int(request.form.get("duration_min", ""))
        if duration < 1 or duration > 1440:
            raise ValueError
        if workout_type not in WORKOUT_TYPES or len(notes) > 1000:
            raise ValueError
    except (ValueError, TypeError):
        flash("Please enter a valid date, workout type and duration.")
        return redirect(url_for("client_detail", client_id=client_id))
    db = get_db()
    db.execute("""INSERT INTO workouts (client_name, date, workout_type, duration_min, notes)
                  VALUES (?, ?, ?, ?, ?)""",
               (client["name"], workout_date, workout_type, duration, notes))
    db.commit()
    flash("Workout saved.")
    return redirect(url_for("client_detail", client_id=client_id))

@app.route("/clients/<int:client_id>/membership", methods=["POST"])
def membership_check(client_id):
    client = get_client_or_404(client_id)
    end = client["membership_end"] or "No renewal date set"
    flash(f"Membership status: {client['membership_status']}. Renewal date: {end}.")
    return redirect(url_for("client_detail", client_id=client_id))

@app.route("/health")
def health():
    return {"status": "ok"}, 200

@app.errorhandler(404)
def not_found(_error):
    content = "<h1>Not found</h1><p class='sub'>The page or client could not be found.</p><a class='button' href='/'>Back to dashboard</a>"
    return render_template_string(BASE_HTML, title="Not found", content=content), 404

with app.app_context():
    init_db()

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "5000")), debug=False)
