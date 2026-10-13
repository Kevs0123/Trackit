<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Auth\Notifications\VerifyEmail;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Tests\TestCase;

class AuthRecoveryTest extends TestCase
{
    use RefreshDatabase;

    public function test_customer_registration_requires_email_verification_before_login(): void
    {
        Notification::fake();

        $response = $this->postJson('/api/auth/register', [
            'name' => 'New Customer',
            'email' => 'new-customer@example.com',
            'password' => 'a-secure-password',
        ]);

        $response->assertCreated()
            ->assertJsonMissingPath('token')
            ->assertJsonPath('message', 'Account created. Check your email for a verification link before signing in.');

        $user = User::where('email', 'new-customer@example.com')->firstOrFail();
        $this->assertNull($user->email_verified_at);
        Notification::assertSentTo($user, VerifyEmail::class);

        $this->postJson('/api/auth/login', [
            'email' => 'new-customer@example.com',
            'password' => 'a-secure-password',
        ])->assertForbidden()
            ->assertJsonPath('message', 'Verify your email before signing in. You can request another verification email.');
    }

    public function test_registration_sends_verification_through_the_gmail_api_mailer(): void
    {
        config([
            'mail.default' => 'gmail_api',
            'mail.mailers.gmail_api' => [
                'transport' => 'gmail_api',
                'client_id' => 'test-client-id',
                'client_secret' => 'test-client-secret',
                'refresh_token' => 'test-refresh-token',
            ],
            'mail.from.address' => 'trackit@gmail.com',
            'mail.from.name' => 'TrackIt',
        ]);
        Http::fake([
            'https://oauth2.googleapis.com/token' => Http::response([
                'access_token' => 'test-access-token',
                'expires_in' => 3600,
            ]),
            'https://gmail.googleapis.com/gmail/v1/users/me/messages/send' => Http::response([
                'id' => 'gmail-message-id',
            ]),
        ]);

        $this->postJson('/api/auth/register', [
            'name' => 'New Customer',
            'email' => 'new-customer@example.com',
            'password' => 'a-secure-password',
        ])->assertCreated();

        Http::assertSent(fn ($request) => $request->url() ===
            'https://gmail.googleapis.com/gmail/v1/users/me/messages/send');
    }

    public function test_registration_returns_service_unavailable_when_gmail_api_cannot_be_reached(): void
    {
        config([
            'mail.default' => 'gmail_api',
            'mail.mailers.gmail_api' => [
                'transport' => 'gmail_api',
                'client_id' => 'test-client-id',
                'client_secret' => 'test-client-secret',
                'refresh_token' => 'test-refresh-token',
            ],
        ]);
        Http::fake([
            'https://oauth2.googleapis.com/token' => Http::failedConnection('network unavailable'),
        ]);

        $this->postJson('/api/auth/register', [
            'name' => 'New Customer',
            'email' => 'new-customer@example.com',
            'password' => 'a-secure-password',
        ])->assertServiceUnavailable()
            ->assertJsonPath('message', 'We could not send the verification email. Please try again later.');

        $this->assertDatabaseMissing('users', ['email' => 'new-customer@example.com']);
    }

    public function test_signed_verification_link_verifies_the_address_and_allows_login(): void
    {
        Notification::fake();
        $this->postJson('/api/auth/register', [
            'name' => 'New Customer',
            'email' => 'new-customer@example.com',
            'password' => 'a-secure-password',
        ])->assertCreated();

        $user = User::where('email', 'new-customer@example.com')->firstOrFail();
        $notification = Notification::sent($user, VerifyEmail::class)->first();
        $verificationUrl = $notification->toMail($user)->actionUrl;
        $url = parse_url($verificationUrl);

        $this->get($url['path'].'?'.$url['query'])
            ->assertRedirect(rtrim(config('trackit.frontend_url'), '/').'/#/verify-email?status=success');

        $this->assertNotNull($user->fresh()->email_verified_at);
        $this->postJson('/api/auth/login', [
            'email' => 'new-customer@example.com',
            'password' => 'a-secure-password',
        ])->assertOk()->assertJsonStructure(['token', 'user']);
    }

    public function test_verification_can_be_resent_without_disclosing_account_existence(): void
    {
        Notification::fake();
        User::create([
            'name' => 'Unverified Customer',
            'email' => 'unverified@example.com',
            'password' => 'a-secure-password',
            'role' => 'customer',
        ]);

        $response = $this->postJson('/api/auth/email/verification-notification', [
            'email' => 'unverified@example.com',
        ]);

        $response->assertOk()->assertJsonPath(
            'message',
            'If an unverified customer account exists for that address, a verification link has been sent.',
        );
        Notification::assertSentTo(
            User::where('email', 'unverified@example.com')->firstOrFail(),
            VerifyEmail::class,
        );

        $this->postJson('/api/auth/email/verification-notification', [
            'email' => 'nobody@example.com',
        ])->assertExactJson($response->json());
    }

    public function test_password_reset_request_is_generic_and_sends_a_reset_notification(): void
    {
        Notification::fake();
        $user = User::create([
            'name' => 'Reset Customer',
            'email' => 'reset@example.com',
            'password' => 'a-secure-password',
            'role' => 'customer',
        ]);

        $response = $this->postJson('/api/auth/forgot-password', [
            'email' => 'reset@example.com',
        ]);

        $response->assertOk()->assertJsonPath(
            'message',
            'If an account exists for that address, a password reset link has been sent.',
        );
        Notification::assertSentTo($user, ResetPassword::class);
        $notification = Notification::sent($user, ResetPassword::class)->first();
        $this->assertStringContainsString(
            '/#/reset-password?token=',
            $notification->toMail($user)->actionUrl,
        );

        $this->postJson('/api/auth/forgot-password', [
            'email' => 'nobody@example.com',
        ])->assertExactJson($response->json());
    }

    public function test_password_reset_changes_password_and_revokes_existing_tokens(): void
    {
        $user = User::create([
            'name' => 'Reset Admin',
            'email' => 'reset-admin@example.com',
            'password' => 'old-secure-password',
            'role' => 'admin',
        ]);
        $user->createToken('existing-session');
        $token = Password::createToken($user);

        $this->postJson('/api/auth/reset-password', [
            'token' => $token,
            'email' => $user->email,
            'password' => 'new-secure-password',
            'password_confirmation' => 'new-secure-password',
        ])->assertOk();

        $this->assertTrue(Hash::check('new-secure-password', $user->fresh()->password));
        $this->assertDatabaseCount('personal_access_tokens', 0);
        $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => 'new-secure-password',
        ])->assertOk();
    }
}
