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

## User flows

TrackIt has a public tracking flow and three signed-in roles: customer, rider, and admin (courier staff). After signing in, the app opens the home screen for the account's role. Sessions are remembered on the device until the user signs out.

### Visitor

1. Open the landing page.
2. Enter a tracking number and choose **Track parcel**; no account is required.
3. View the parcel status, tracking history, and available map locations. The page refreshes periodically while the delivery is active.
4. After a parcel is delivered, submit a star rating and optional feedback.
5. A visitor can sign in or create a customer account from the landing page.

### Customer

1. Create an account with name, email, and password (phone is optional), or sign in.
2. From **My parcels**, choose **Book parcel** and enter sender/pickup details, receiver/delivery details, weight, and standard or express service.
3. Review the estimated fee and submit the booking. The app shows the generated tracking number.
4. Open a parcel to follow its status and history, or enter any tracking number in the search field.
5. Cancel a parcel only while its status is still **booked**.
6. Open **Notifications** to review parcel updates and mark all notifications as read.
7. Sign out from the top bar when finished.

### Rider

Riders sign in with an account created by courier staff; public sign-up creates customer accounts only.

1. Sign in to view assigned active deliveries and recent delivery history. New assignments appear automatically.
2. Optionally choose **Optimize route** to order active stops and open directions in a maps app.
3. For each delivery, use the status action to progress through **assigned → picked up → in transit → out for delivery → delivered**.
4. If delivery cannot be completed, choose **Failed** and enter a reason. Use **Call** to contact the receiver.
5. Optionally enable **Share my live location** and grant location permission. The location is shared while enabled so customers can see the rider on parcel tracking; location access requires HTTPS or localhost in the browser.
6. Sign out from the top bar when finished.

### Admin / courier staff

1. Sign in with an admin account.
2. Use **Dashboard** to monitor parcel totals, statuses, bookings, deliveries, and active riders; it refreshes automatically.
3. In **Parcels**, search by tracking number or sender/receiver name and filter by status. Create bookings for customers, assign or reassign parcels to active riders, open tracking, or cancel parcels.
4. In **Riders**, add rider accounts, activate or deactivate riders, and optimize a rider's route.
5. In **Reports**, choose a date range to review delivery, rider, rating, and fee metrics, or export a CSV.
6. Sign out from the top bar when finished.

For local development only, the database seeder creates demo accounts (`admin@trackit.test`, `rider1@trackit.test`, `rider2@trackit.test`, and `customer@trackit.test`) with the password `password`. Do not use these demo credentials in a deployed environment.

### Production admin setup

Production seeding does not create demo users or parcels. It disables any existing seeded demo accounts and revokes their API tokens. After deploying the API, run these commands from the Railway service shell:

```sh
php artisan db:seed --force
php artisan trackit:create-admin
```

The admin command prompts for a name, email, and a hidden password (minimum 12 characters). Use a unique password and do not paste it into chat or commit it to the repository. Sign in with that account, then add rider accounts from the admin **Riders** tab.

### Email verification and password recovery

Customer registration sends a signed verification link and does not create a login session until the address is verified. Sign-in includes a resend-verification action for unverified customers. The sign-in screen also has a forgot-password flow; reset links return to the Flutter web app and expire after Laravel's configured reset-token lifetime.

In production, the API defaults to Gmail's HTTPS API rather than silently logging email if `MAIL_MAILER` is missing. Registration is rolled back if the verification email cannot be submitted.

Configure these values as Railway service variables (never commit mail credentials). Railway's lower-cost plans block outbound SMTP, so use Gmail's HTTPS API rather than SMTP:

```text
APP_URL=https://<your-railway-api-domain>
FRONTEND_URL=https://trackit-c77df.web.app
MAIL_MAILER=gmail_api
MAIL_FROM_ADDRESS=<your Gmail address>
MAIL_FROM_NAME=TrackIt
GMAIL_OAUTH_CLIENT_ID=<Google OAuth client ID>
GMAIL_OAUTH_CLIENT_SECRET=<Google OAuth client secret>
GMAIL_OAUTH_REFRESH_TOKEN=<Google OAuth refresh token>
```

Enable the Gmail API in a Google Cloud project, configure its OAuth consent screen, and generate an OAuth refresh token authorized for `https://www.googleapis.com/auth/gmail.send` from the Gmail account in `MAIL_FROM_ADDRESS`. Store the OAuth values only in Railway and redeploy after setting them. Google may require OAuth app verification for broader use; OAuth apps left in Testing can have refresh tokens expire after seven days. Gmail sending limits apply. The HTTPS API is used for registration verification, verification resend, and password-reset emails.
