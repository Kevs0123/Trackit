# TrackIt monorepo

TrackIt is a parcel tracking and delivery management system for small couriers. This workspace contains the Laravel API and a Flutter web client.

## Structure

```text
apps/
  api/       Laravel API and database migrations
  mobile/    Flutter client (web)
```

Each app keeps its own dependency manager and configuration. Run commands from that app's directory.

## First-time setup

Requirements: PHP 8.3+, Composer, and Flutter with web support enabled. If `apps/api/.env` already exists, keep it and skip copying the example or generating a new app key. Run migrations and seed data only when initializing a fresh database.

```powershell
cd apps/api
composer install
Copy-Item .env.example .env
php artisan key:generate
php artisan migrate --seed
```

## Run the whole app

From the repository root, start the API and web client together:

```powershell
cd C:\Projects
.\run-web.ps1
```

The script starts Laravel in the background, opens the Flutter web app in Chrome, and stops the API when you exit Flutter. It installs Composer or Flutter dependencies only if they are missing. The client uses `http://127.0.0.1:8000/api` by default.
