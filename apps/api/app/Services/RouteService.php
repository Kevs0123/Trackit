<?php

namespace App\Services;

use App\Models\Parcel;
use App\Models\User;

/**
 * Route optimization: nearest-neighbour ordering of a rider's active deliveries.
 * Distances are straight-line (haversine) x a road factor, which is a good estimate
 * for small courier areas and needs no paid routing API.
 */
class RouteService
{
    public function optimize(User $rider): array
    {
        $parcels = Parcel::where('rider_id', $rider->id)
            ->whereIn('status', Parcel::ACTIVE)
            ->get();

        $withCoords = $parcels->filter(fn ($p) => $p->drop_lat !== null && $p->drop_lng !== null)->values();
        $withoutCoords = $parcels->filter(fn ($p) => $p->drop_lat === null || $p->drop_lng === null)->values();

        $currentLat = $rider->last_lat ?? config('trackit.depot.lat');
        $currentLng = $rider->last_lng ?? config('trackit.depot.lng');
        $factor = config('trackit.road_factor');

        $remaining = $withCoords->all();
        $ordered = [];
        $order = 1;
        $totalKm = 0.0;

        while (! empty($remaining)) {
            $bestKey = null;
            $bestDistance = INF;

            foreach ($remaining as $key => $parcel) {
                $d = $this->haversine($currentLat, $currentLng, $parcel->drop_lat, $parcel->drop_lng) * $factor;
                if ($d < $bestDistance) {
                    $bestDistance = $d;
                    $bestKey = $key;
                }
            }

            $next = $remaining[$bestKey];
            unset($remaining[$bestKey]);

            $next->update(['route_order' => $order++, 'route_distance_km' => round($bestDistance, 2)]);
            $totalKm += $bestDistance;
            $currentLat = $next->drop_lat;
            $currentLng = $next->drop_lng;
            $ordered[] = $next;
        }

        // Parcels without coordinates go last (still numbered so riders see a full list)
        foreach ($withoutCoords as $parcel) {
            $parcel->update(['route_order' => $order++, 'route_distance_km' => null]);
            $ordered[] = $parcel;
        }

        $minutes = (int) round(($totalKm / max(1, config('trackit.avg_speed_kmh'))) * 60)
            + count($ordered) * config('trackit.minutes_per_stop');

        return [
            'rider_id' => $rider->id,
            'rider_name' => $rider->name,
            'total_distance_km' => round($totalKm, 2),
            'estimated_minutes' => $minutes,
            'stops' => $ordered,
        ];
    }

    private function haversine(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $r = 6371.0;
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return $r * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
