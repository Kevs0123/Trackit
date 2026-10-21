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

Requirements: PHP 8.3+, Composer, and Flutter with web support enabled. If `apps/api/.env` already exists, keep it and skip copying the example or generating a new app key. Migrations create the schema; the seeder does not add demo data. Create a local admin only when you are ready to sign in.

```powershell
cd apps/api
composer install
Copy-Item .env.example .env
php artisan key:generate
php artisan migrate --seed
php artisan trackit:create-admin
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

The database seeder does not create demo users or parcels. To create the first local admin, run `php artisan trackit:create-admin` from `apps/api`; it prompts for a name, email, and private password. Public sign-up creates customer accounts, not admins.

### Production admin setup

Production seeding does not create demo users or parcels. It disables any legacy demo accounts and revokes their API tokens. Your existing named production admin is not removed. Do not run destructive database resets against production. If you need to create an admin on a new production database, run these commands from the Railway service shell:

```sh
php artisan db:seed --force
php artisan trackit:create-admin
```

The admin command prompts for a name, email, and a hidden password (minimum 12 characters). Use a unique password and do not paste it into chat or commit it to the repository. Sign in with that account, then add rider accounts from the admin **Riders** tab.

To intentionally clear and recreate only a local development database, run `php artisan migrate:fresh --seed` from `apps/api`. This deletes all data in the database configured by that local `.env`; never use it against production. The result is an empty app with no users. Create a new admin separately with `php artisan trackit:create-admin`.

### Production email setup

The API uses Laravel SMTP for production email. For Mailtrap, use **Email Sending**
(not the Email Testing sandbox) and add the SMTP values shown in your Mailtrap
account to the Railway service variables. Typical Mailtrap Email Sending values are:

```text
MAIL_MAILER=smtp
# Leave MAIL_SCHEME unset for STARTTLS
MAIL_HOST=live.smtp.mailtrap.io
MAIL_PORT=587
MAIL_USERNAME=api
MAIL_PASSWORD=<Mailtrap SMTP/API token>
MAIL_FROM_ADDRESS=<sender address on your verified domain>
MAIL_FROM_NAME=TrackIt
```

Mailtrap must verify a domain you own before it can deliver production email.
Do not use the Firebase `web.app` URL or Railway `up.railway.app` URL as the
email-sending domain. Keep credentials in Railway variables, not in source control.

### Registration and password recovery

Customer registration validates the email address format and uniqueness, then signs the customer in immediately. The app does not verify that the address belongs to the customer or can receive messages. The sign-in screen also has a forgot-password flow; reset links return to the Flutter web app and expire after Laravel's configured reset-token lifetime.

Password-reset and parcel-status emails still use the production mailer configured above. Configure those SMTP values in Railway service variables and keep credentials out of source control.
