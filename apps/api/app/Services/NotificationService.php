<?php

namespace App\Services;

use App\Models\Parcel;
use App\Models\ParcelNotification;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

/**
 * Sends an in-app notification (customers) and an email (customer, sender, receiver)
 * every time a parcel changes status. Emails go to storage/logs/laravel.log
 * while MAIL_MAILER=log, so no mail server is needed for a demo.
 */
class NotificationService
{
    public function parcelStatus(Parcel $parcel, ?string $note = null): void
    {
        $parcel->loadMissing('customer');

        $label = Parcel::STATUSES[$parcel->status] ?? $parcel->status;
        $message = "TrackIt update: parcel {$parcel->tracking_number} is now \"{$label}\".";
        if ($note) {
            $message .= " Note: {$note}";
        }

        $url = rtrim(config('trackit.frontend_url'), '/').'/#/track/'.$parcel->tracking_number;
        $body = $message."\n\nTrack your parcel: ".$url;

        if ($parcel->customer_id) {
            $this->record($parcel, 'app', (string) $parcel->customer_id, $message, 'sent', $parcel->customer_id);
        }

        $emails = collect([$parcel->customer?->email, $parcel->sender_email, $parcel->receiver_email])
            ->filter()
            ->map(fn ($e) => strtolower($e))
            ->unique();

        foreach ($emails as $email) {
            try {
                Mail::raw($body, function ($mail) use ($email, $parcel, $label) {
                    $mail->to($email)->subject("TrackIt: {$parcel->tracking_number} - {$label}");
                });
                $this->record($parcel, 'email', $email, $message, 'sent');
            } catch (\Throwable $e) {
                Log::warning('TrackIt email failed: '.$e->getMessage());
                $this->record($parcel, 'email', $email, $message, 'failed');
            }
        }
    }

    private function record(Parcel $parcel, string $channel, string $recipient, string $message, string $status, ?int $userId = null): void
    {
        ParcelNotification::create([
            'parcel_id' => $parcel->id,
            'user_id' => $userId,
            'channel' => $channel,
            'recipient' => $recipient,
            'message' => $message,
            'status' => $status,
        ]);
    }
}
