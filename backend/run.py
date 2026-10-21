import os
from app import create_app

# gunicorn imports this module and uses `app` (see Procfile); app.run() below
# is only for local development with: python run.py
app = create_app()

if __name__ == "__main__":
    app.run(
        debug=os.getenv("FLASK_DEBUG", "0") == "1",
        port=int(os.getenv("PORT", "5000")),
    )