<?php

namespace Tests\Feature;

use App\Mail\GmailApiTransport;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Symfony\Component\Mailer\Exception\TransportException;
use Symfony\Component\Mime\Email;
use Tests\TestCase;

class GmailApiTransportTest extends TestCase
{
    public function test_it_sends_mail_through_the_gmail_https_api(): void
    {
        Http::fake([
            'https://oauth2.googleapis.com/token' => Http::response([
                'access_token' => 'test-access-token',
                'expires_in' => 3600,
            ]),
            'https://gmail.googleapis.com/gmail/v1/users/me/messages/send' => Http::response([
                'id' => 'gmail-message-id',
            ]),
        ]);

        $message = (new Email)
            ->from('trackit@gmail.com')
            ->to('customer@example.com')
            ->subject('Verify your email')
            ->text('Open the verification link.');

        (new GmailApiTransport([
            'client_id' => 'test-client-id',
            'client_secret' => 'test-client-secret',
            'refresh_token' => 'test-refresh-token',
        ]))->send($message);

        Http::assertSent(function (Request $request) {
            return $request->url() === 'https://oauth2.googleapis.com/token'
                && $request['grant_type'] === 'refresh_token'
                && $request['client_id'] === 'test-client-id';
        });
        Http::assertSent(function (Request $request) {
            if ($request->url() !== 'https://gmail.googleapis.com/gmail/v1/users/me/messages/send') {
                return false;
            }

            $decoded = base64_decode(strtr($request['raw'], '-_', '+/'));

            return $request->hasHeader('Authorization', 'Bearer test-access-token')
                && str_contains($decoded, 'To: customer@example.com')
                && str_contains($decoded, 'Subject: Verify your email')
                && str_contains($decoded, 'Open the verification link.');
        });
    }

    public function test_it_fails_clearly_when_google_rejects_oauth_credentials(): void
    {
        Http::fake([
            'https://oauth2.googleapis.com/token' => Http::response([
                'error' => 'invalid_grant',
            ], 400),
        ]);

        $this->expectException(TransportException::class);
        $this->expectExceptionMessage('Google OAuth could not issue an access token (HTTP 400).');

        (new GmailApiTransport([
            'client_id' => 'test-client-id',
            'client_secret' => 'test-client-secret',
            'refresh_token' => 'expired-refresh-token',
        ]))->send(
            (new Email)
                ->from('trackit@gmail.com')
                ->to('customer@example.com')
                ->subject('Verify your email')
                ->text('Open the verification link.')
        );
    }
}
