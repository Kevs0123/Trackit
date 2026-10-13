<?php

namespace App\Mail;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Symfony\Component\Mailer\Exception\TransportException;
use Symfony\Component\Mailer\SentMessage;
use Symfony\Component\Mailer\Transport\AbstractTransport;

class GmailApiTransport extends AbstractTransport
{
    private ?string $accessToken = null;

    private int $accessTokenExpiresAt = 0;

    public function __construct(
        private readonly array $config,
    ) {
        parent::__construct();
    }

    protected function doSend(SentMessage $message): void
    {
        $raw = rtrim(strtr(base64_encode($message->toString()), '+/', '-_'), '=');

        try {
            $response = Http::acceptJson()
                ->connectTimeout(5)
                ->timeout(10)
                ->withToken($this->accessToken())
                ->post('https://gmail.googleapis.com/gmail/v1/users/me/messages/send', [
                    'raw' => $raw,
                ]);
        } catch (ConnectionException $exception) {
            throw new TransportException('Could not connect to the Gmail API.', 0, $exception);
        }

        if (! $response->successful()) {
            throw new TransportException(
                'Gmail API rejected the message with HTTP '.$response->status().'.'
            );
        }
    }

    private function accessToken(): string
    {
        if ($this->accessToken !== null && time() < $this->accessTokenExpiresAt - 30) {
            return $this->accessToken;
        }

        foreach (['client_id', 'client_secret', 'refresh_token'] as $key) {
            if (empty($this->config[$key])) {
                throw new TransportException('Gmail API is missing required OAuth configuration.');
            }
        }

        try {
            $response = Http::asForm()
                ->acceptJson()
                ->connectTimeout(5)
                ->timeout(10)
                ->post('https://oauth2.googleapis.com/token', [
                    'client_id' => $this->config['client_id'],
                    'client_secret' => $this->config['client_secret'],
                    'refresh_token' => $this->config['refresh_token'],
                    'grant_type' => 'refresh_token',
                ]);
        } catch (ConnectionException $exception) {
            throw new TransportException('Could not connect to Google OAuth.', 0, $exception);
        }

        $token = $response->json('access_token');
        if (! $response->successful() || ! is_string($token) || $token === '') {
            throw new TransportException(
                'Google OAuth could not issue an access token (HTTP '.$response->status().').'
            );
        }

        $this->accessToken = $token;
        $this->accessTokenExpiresAt = time() + (int) $response->json('expires_in', 3600);

        return $this->accessToken;
    }

    public function __toString(): string
    {
        return 'gmail+https://gmail.googleapis.com';
    }
}
