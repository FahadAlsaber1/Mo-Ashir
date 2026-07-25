# MO'ASHIR Python Backend

FastAPI backend for MO'ASHIR using Supabase as the database.

## Setup

1. Fill the root `.env` file:

   ```env
   SUPABASE_URL=https://your-project-ref.supabase.co
   SUPABASE_ANON_KEY=your-publishable-key
   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
   ```

2. Install dependencies:

   ```powershell
   cd C:\Projects\moashir
   python -m pip install -r backend\requirements.txt
   ```

3. Run the backend:

   ```powershell
   python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000 --reload
   ```

4. Open:

   ```text
   http://127.0.0.1:8000/health
   ```

## Database

Run `supabase/schema.sql` in the Supabase SQL Editor before using database endpoints.

Write endpoints need `SUPABASE_SERVICE_ROLE_KEY`. Do not expose that key in Flutter.
