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

The script starts Laravel in the background, opens the Flutter web app in Chrome at `http://localhost:8080`, and stops the API when you exit Flutter. The fixed web port keeps local password-reset links valid. It installs Composer or Flutter dependencies only if they are missing. The client uses `http://127.0.0.1:8000/api` by default.

For production, set `FRONTEND_URL` to the deployed Flutter web app URL so reset emails link back to the deployed client.

## Proof of delivery storage

Riders must submit between one and ten JPG, PNG, WebP, GIF, BMP, or AVIF proof photos (up to 4 MB each) before a parcel can be marked delivered. Proof photos are stored on Laravel's configured `FILESYSTEM_DISK` and are served only to courier staff and the owning customer through authenticated API requests. Recipient names are not collected or shown, and public tracking never exposes proof photos.

Run `php artisan migrate` from `apps/api` after updating the application to add the proof-of-delivery columns. The default local disk is suitable for development. Some production hosts use temporary local storage that can be erased during restarts or redeploys; configure a persistent private S3-compatible disk or Cloudinary-backed storage in production and set `FILESYSTEM_DISK` accordingly. Keep proof images private; do not use a public disk.
