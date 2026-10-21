<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Parcel;
use Illuminate\Http\Request;

/** Public endpoints: anyone with a tracking number can follow a parcel. */
class TrackingController extends Controller
{
    public function show(string $trackingNumber)
    {
        $parcel = $this->find($trackingNumber);
        if (! $parcel) {
            return response()->json(['message' => 'Tracking number not found. Please check and try again.'], 404);
        }

        $showRider = $parcel->rider && in_array($parcel->status, ['picked_up', 'in_transit', 'out_for_delivery'], true);

        return response()->json([
            'tracking_number' => $parcel->tracking_number,
            'status' => $parcel->status,
            'status_label' => $parcel->status_label,
            'sender_name' => $this->mask($parcel->sender_name),
            'receiver_name' => $this->mask($parcel->receiver_name),
            'pickup_address' => $parcel->pickup_address,
            'delivery_address' => $parcel->delivery_address,
            'description' => $parcel->description,
            'weight_kg' => $parcel->weight_kg,
            'service_type' => $parcel->service_type,
            'fee' => $parcel->fee,
            'pickup_lat' => $parcel->pickup_lat,
            'pickup_lng' => $parcel->pickup_lng,
            'drop_lat' => $parcel->drop_lat,
            'drop_lng' => $parcel->drop_lng,
            'created_at' => $parcel->created_at,
            'delivered_at' => $parcel->delivered_at,
            'pod_delivered_at' => $parcel->pod_delivered_at,
            'has_proof' => $parcel->has_proof,
            'pod_photo_count' => count($parcel->proofPhotoPaths()),
            'rating' => $parcel->rating,
            'feedback' => $parcel->feedback,
            // Rider details (and live location) are only shared while the parcel is on the road
            'rider' => $showRider ? [
                'name' => $parcel->rider->name,
                'phone' => $parcel->rider->phone,
                'last_lat' => $parcel->rider->last_lat,
                'last_lng' => $parcel->rider->last_lng,
                'location_updated_at' => $parcel->rider->location_updated_at,
            ] : null,
            'events' => $parcel->events->map(fn ($e) => [
                'status' => $e->status,
                'status_label' => $e->status_label,
                'note' => $e->note,
                'lat' => $e->lat,
                'lng' => $e->lng,
                'created_at' => $e->created_at,
            ])->values(),
        ]);
    }

    /** Customer rates the delivery once it is delivered (used to measure usability/satisfaction) */
    public function feedback(Request $request, string $trackingNumber)
    {
        $parcel = $this->find($trackingNumber);
        if (! $parcel) {
            return response()->json(['message' => 'Tracking number not found.'], 404);
        }
        if ($parcel->status !== 'delivered') {
            return response()->json(['message' => 'You can rate a parcel after it has been delivered.'], 422);
        }
        if ($parcel->rating !== null) {
            return response()->json(['message' => 'Feedback was already submitted for this parcel.'], 422);
        }

        $data = $request->validate([
            'rating' => 'required|integer|between:1,5',
            'feedback' => 'nullable|string|max:500',
        ]);

        $parcel->update($data);

        return response()->json(['message' => 'Thank you for your feedback!']);
    }

    private function find(string $trackingNumber): ?Parcel
    {
        return Parcel::with(['events', 'rider:id,name,phone,last_lat,last_lng,location_updated_at'])
            ->where('tracking_number', strtoupper(trim($trackingNumber)))
            ->first();
    }

    /** "Juan Dela Cruz" -> "Juan C." */
    private function mask(string $name): string
    {
        $parts = preg_split('/\s+/', trim($name));
        if (count($parts) < 2) {
            return $parts[0];
        }

        return $parts[0].' '.mb_strtoupper(mb_substr(end($parts), 0, 1)).'.';
    }
}
