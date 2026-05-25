# Newsletter App

A private reply-able newsletter app for keeping up with friends across countries.

## Tech Stack

- Backend: Python + FastAPI
- Database: PostgreSQL
- Mobile UI: JavaScript + React Native + Expo

## Project Structure

```text
backend/      FastAPI API server
mobile/       Expo React Native app
docker-compose.yml  Local PostgreSQL database
```

## Local Development

Start the database:

```bash
docker compose up -d db
```

Run the backend:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload
```

Run the mobile app:

```bash
cd mobile
npm install
npm start
```

