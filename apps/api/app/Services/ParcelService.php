<?php

namespace App\Services;

use App\Models\Parcel;
use App\Models\ParcelEvent;
use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class ParcelService
{
    public function __construct(
        private GeocodingService $geo,
        private NotificationService $notifier,
    ) {
    }

    /** Base 60 for the first kg, +20 per extra kg, +60 for express (PHP) */
    public function calculateFee(float $weightKg, string $serviceType): float
    {
        $fee = 60 + max(0, (int) ceil($weightKg) - 1) * 20;
        if ($serviceType === 'express') {
            $fee += 60;
        }

        return (float) $fee;
    }

    public function book(array $data, ?User $by = null): Parcel
    {
        $data = $this->withCoordinates($data);

        $parcel = DB::transaction(function () use ($data, $by) {
            $parcel = Parcel::create([
                'tracking_number' => $this->newTrackingNumber(),
                'customer_id' => ($by && $by->role === 'customer') ? $by->id : ($data['customer_id'] ?? null),
                ...Arr::only($data, [
                    'sender_name', 'sender_phone', 'sender_email', 'pickup_address',
                    'receiver_name', 'receiver_phone', 'receiver_email', 'delivery_address',
                    'description', 'weight_kg', 'service_type',
                    'pickup_lat', 'pickup_lng', 'drop_lat', 'drop_lng',
                ]),
                'fee' => $this->calculateFee((float) $data['weight_kg'], $data['service_type']),
                'status' => 'booked',
            ]);

            $this->logEvent($parcel, 'booked', 'Parcel booked.', null, null, $by);

            return $parcel;
        });

        $this->notifier->parcelStatus($parcel);

        return $parcel->load(['events', 'rider:id,name,phone']);
    }

    public function assign(Parcel $parcel, User $rider, ?User $by = null): Parcel
    {
           if ($rider->role !== 'rider' || $rider->is_active === false) {
            throw ValidationException::withMessages(['rider_id' => ['Choose an active rider.']]);
        }
        $this->guardNotFinal($parcel);

        $previousProofPaths = $parcel->proofPhotoPaths();
        DB::transaction(function () use ($parcel, $rider, $by) {
            $parcel->update([
                'rider_id' => $rider->id,
                'status' => 'assigned',
                'assigned_at' => now(),
                'route_order' => null,
                'route_distance_km' => null,
                'pod_photo_path' => null,
                'pod_photo_paths' => null,
                'pod_delivered_at' => null,
            ]);
            $this->logEvent($parcel, 'assigned', "Assigned to rider {$rider->name}.", null, null, $by);
        });

        if ($previousProofPaths !== []) {
            Storage::disk(config('filesystems.default'))->delete($previousProofPaths);
        }

        $this->notifier->parcelStatus($parcel, "Rider: {$rider->name}");

        return $parcel->fresh(['events', 'rider:id,name,phone']);
    }

    public function changeStatus(Parcel $parcel, string $status, ?string $note, ?float $lat, ?float $lng, ?User $by): Parcel
    {
        $parcel->refresh();
        $this->guardNotFinal($parcel);

        $proofPaths = $parcel->proofPhotoPaths();
        if ($status === 'delivered' && (
            $proofPaths === []
            || ! $parcel->pod_delivered_at
            || count(array_filter(
                $proofPaths,
                fn ($path) => Storage::disk(config('filesystems.default'))->exists($path),
            )) !== count($proofPaths)
        )) {
            throw ValidationException::withMessages([
                'status' => [
                    'Delivery not completed. Upload at least one supported proof photo (maximum 4 MB each) first.',
                ],
            ]);
        }

        DB::transaction(function () use ($parcel, $status, $note, $lat, $lng, $by) {
            $parcel->status = $status;
            if ($status === 'delivered') {
                $parcel->delivered_at = now();
            }
            if (in_array($status, ['delivered', 'failed', 'cancelled'], true)) {
                $parcel->route_order = null;
                $parcel->route_distance_km = null;
            }
            $parcel->save();

            $this->logEvent($parcel, $status, $note, $lat, $lng, $by);
        });

        $this->notifier->parcelStatus($parcel, $note);

        return $parcel->fresh(['events', 'rider:id,name,phone']);
    }

    private function guardNotFinal(Parcel $parcel): void
    {
        if (in_array($parcel->status, Parcel::FINAL, true)) {
            throw ValidationException::withMessages([
                'status' => ["This parcel is already {$parcel->status} and can no longer be changed."],
            ]);
        }
    }

    private function logEvent(Parcel $parcel, string $status, ?string $note, ?float $lat, ?float $lng, ?User $by): void
    {
        ParcelEvent::create([
            'parcel_id' => $parcel->id,
            'status' => $status,
            'note' => $note,
            'lat' => $lat,
            'lng' => $lng,
            'created_by' => $by?->id,
        ]);
    }

    private function newTrackingNumber(): string
    {
        do {
            $number = 'TRK'.now()->format('ymd').strtoupper(Str::random(6));
        } while (Parcel::where('tracking_number', $number)->exists());

        return $number;
    }

    /** Fill in missing coordinates from the addresses (Nominatim allows 1 request/second) */
    private function withCoordinates(array $data): array
    {
        $lookedUp = false;

        if (empty($data['pickup_lat']) || empty($data['pickup_lng'])) {
            if ($c = $this->geo->geocode($data['pickup_address'])) {
                $data['pickup_lat'] = $c['lat'];
                $data['pickup_lng'] = $c['lng'];
            }
            $lookedUp = true;
        }

        if (empty($data['drop_lat']) || empty($data['drop_lng'])) {
            if ($lookedUp && config('trackit.geocode_enabled')) {
                usleep(1100000);
            }
            if ($c = $this->geo->geocode($data['delivery_address'])) {
                $data['drop_lat'] = $c['lat'];
                $data['drop_lng'] = $c['lng'];
            }
        }

        return $data;
    }
}
