<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;

/** Turns an address into coordinates using OpenStreetMap Nominatim. Fails silently. */
class GeocodingService
{
    public function geocode(string $address): ?array
    {
        if (! config('trackit.geocode_enabled')) {
            return null;
        }

        try {
            $response = Http::timeout(6)
                ->withHeaders(['User-Agent' => 'TrackIt-Parcel-Tracking/1.0 (school project)'])
                ->get('https://nominatim.openstreetmap.org/search', [
                    'q' => $address,
                    'format' => 'json',
                    'limit' => 1,
                    'countrycodes' => config('trackit.geocode_country'),
                ]);

            $row = $response->json()[0] ?? null;

            return $row ? ['lat' => (float) $row['lat'], 'lng' => (float) $row['lon']] : null;
        } catch (\Throwable $e) {
            return null;
        }
    }
}
