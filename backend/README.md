# EcoTrack Backend (Step 1: foundation + auth, PostgreSQL)

## Setup
```bash
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env              # then edit DB password + JWT secret
psql -U postgres -f schema.sql    # creates the database
python run.py                     # tables auto-create; runs on :5000
```

## Test in Postman
| Method | URL | Body (JSON) |
|---|---|---|
| GET | /api/health | - |
| POST | /api/auth/register | {"name":"Yannis","email":"a@b.com","password":"secret123"} |
| POST | /api/auth/login | {"email":"a@b.com","password":"secret123"} |
| GET | /api/auth/me | header: Authorization: Bearer <access_token> |
