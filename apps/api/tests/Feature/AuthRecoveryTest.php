<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Tests\TestCase;

class AuthRecoveryTest extends TestCase
{
    use RefreshDatabase;

    public function test_customer_registration_accepts_valid_email_and_returns_login_credentials(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'name' => 'New Customer',
            'email' => 'new-customer@example.com',
            'password' => 'a-secure-password',
        ]);

        $response->assertCreated()
            ->assertJsonStructure(['token', 'user' => ['id', 'name', 'email', 'role']])
            ->assertJsonPath('user.email', 'new-customer@example.com');

        $user = User::where('email', 'new-customer@example.com')->firstOrFail();
        $this->assertDatabaseHas('personal_access_tokens', [
            'tokenable_id' => $user->id,
            'name' => 'trackit',
        ]);
    }

    public function test_registration_and_login_normalize_email_case_and_whitespace(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'name' => 'Normalized Customer',
            'email' => '  New-Customer@Example.COM ',
            'password' => 'a-secure-password',
        ]);

        $response->assertCreated()
            ->assertJsonPath('user.email', 'new-customer@example.com');

        $this->postJson('/api/auth/login', [
            'email' => '  NEW-CUSTOMER@EXAMPLE.COM ',
            'password' => 'a-secure-password',
        ])->assertOk()->assertJsonPath('user.email', 'new-customer@example.com');

        $this->postJson('/api/auth/register', [
            'name' => 'Duplicate Customer',
            'email' => 'NEW-CUSTOMER@EXAMPLE.COM',
            'password' => 'another-secure-password',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['email']);
    }

    public function test_registration_rejects_invalid_email_addresses(): void
    {
        $this->postJson('/api/auth/register', [
            'name' => 'New Customer',
            'email' => 'not-an-email',
            'password' => 'a-secure-password',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['email']);
    }

    public function test_customer_can_sign_in_without_verifying_email(): void
    {
        User::create([
            'name' => 'Unverified Customer',
            'email' => 'unverified@example.com',
            'password' => 'a-secure-password',
            'role' => 'customer',
        ]);

        $this->postJson('/api/auth/login', [
            'email' => 'unverified@example.com',
            'password' => 'a-secure-password',
        ])->assertOk()->assertJsonStructure(['token', 'user']);
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
            'email' => ' RESET@EXAMPLE.COM ',
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
        $this->assertStringStartsWith(
            'http://localhost:8080/#/reset-password?token=',
            $notification->toMail($user)->actionUrl,
        );

        $this->postJson('/api/auth/forgot-password', [
            'email' => 'nobody@example.com',
        ])->assertExactJson($response->json());
    }

    public function test_local_password_reset_returns_a_working_link_without_sending_email(): void
    {
        Notification::fake();
        $this->app['env'] = 'local';
        config(['trackit.frontend_url' => 'http://localhost:8080']);
        $user = User::create([
            'name' => 'Local Reset Customer',
            'email' => 'local-reset@example.com',
            'password' => 'old-secure-password',
            'role' => 'customer',
        ]);

        $response = $this->postJson('/api/auth/forgot-password', [
            'email' => ' LOCAL-RESET@EXAMPLE.COM ',
        ])->assertOk()
            ->assertJsonPath(
                'message',
                'Email delivery is disabled in local development. Open the reset page below.',
            );

        $resetUrl = $response->json('reset_url');
        $this->assertStringStartsWith(
            'http://localhost:8080/#/reset-password?',
            $resetUrl,
        );
        $fragment = parse_url($resetUrl, PHP_URL_FRAGMENT);
        parse_str(parse_url($fragment, PHP_URL_QUERY), $query);
        $this->assertSame($user->email, $query['email']);

        Notification::assertNothingSent();
        $this->postJson('/api/auth/reset-password', [
            'token' => $query['token'],
            'email' => $query['email'],
            'password' => 'new-secure-password',
            'password_confirmation' => 'new-secure-password',
        ])->assertOk();
        $this->assertTrue(Hash::check('new-secure-password', $user->fresh()->password));
    }

    public function test_password_reset_reports_mail_transport_failure_without_exposing_details(): void
    {
        $this->app['env'] = 'testing';
        User::create([
            'name' => 'Reset Customer',
            'email' => 'smtp-failure@example.com',
            'password' => 'a-secure-password',
            'role' => 'customer',
        ]);
        Notification::shouldReceive('send')
            ->once()
            ->andThrow(new \RuntimeException('SMTP credentials must not be exposed'));
        \Illuminate\Support\Facades\Log::shouldReceive('error')
            ->once()
            ->with('Password reset email delivery failed.', [
                'exception' => \RuntimeException::class,
            ]);

        $this->withHeader('Origin', 'http://localhost:61942')
            ->postJson('/api/auth/forgot-password', [
                'email' => 'smtp-failure@example.com',
            ])->assertServiceUnavailable()
            ->assertHeader('Access-Control-Allow-Origin', '*')
            ->assertJsonPath(
                'message',
                'The password reset email could not be sent because the email service is unavailable. Please try again later or contact support.',
            )
            ->assertJsonMissing(['message' => 'SMTP credentials must not be exposed']);
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
            'email' => ' RESET-ADMIN@EXAMPLE.COM ',
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
