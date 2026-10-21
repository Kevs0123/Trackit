<?php

namespace App\Providers;

use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        ResetPassword::createUrlUsing(fn (User $user, string $token) => sprintf(
            '%s/#/reset-password?token=%s&email=%s',
            rtrim(config('trackit.frontend_url'), '/'),
            urlencode($token),
            urlencode($user->getEmailForPasswordReset()),
        ));
    }
}
