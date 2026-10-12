<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Parcel;
use App\Models\User;
use App\Services\RouteService;
use Illuminate\Http\Request;

class RiderController extends Controller
{
    /** Staff: list riders with how many active parcels each has */
    public function index()
    {
        return User::where('role', 'rider')
            ->withCount(['riderParcels as active_parcels' => fn ($q) => $q->whereIn('status', Parcel::ACTIVE)])
            ->orderBy('name')
            ->get();
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:100',
            'email' => 'required|email|max:255|unique:users,email',
            'phone' => 'nullable|string|max:30',
            'password' => 'required|string|min:6',
        ]);

        return response()->json(User::create($data + ['role' => 'rider']), 201);
    }

    public function update(Request $request, User $rider)
    {
        abort_unless($rider->role === 'rider', 404);

        $data = $request->validate([
            'name' => 'sometimes|string|max:100',
            'phone' => 'nullable|string|max:30',
            'is_active' => 'sometimes|boolean',
        ]);

        $rider->update($data);

        return $rider;
    }

    /** Rider: my active parcels (in route order) + recent history */
    public function myParcels(Request $request)
    {
        $riderId = $request->user()->id;

        $active = Parcel::where('rider_id', $riderId)
            ->whereIn('status', Parcel::ACTIVE)
            ->orderByRaw('route_order IS NULL, route_order ASC')
            ->orderBy('assigned_at')
            ->get();

        $history = Parcel::where('rider_id', $riderId)
            ->whereIn('status', ['delivered', 'failed'])
            ->latest('updated_at')
            ->limit(10)
            ->get();

        return response()->json(['active' => $active, 'history' => $history]);
    }

    /** Rider shares live location (the customer's tracking map reads it) */
    public function updateLocation(Request $request)
    {
        $data = $request->validate([
            'lat' => 'required|numeric|between:-90,90',
            'lng' => 'required|numeric|between:-180,180',
        ]);

        $request->user()->update([
            'last_lat' => $data['lat'],
            'last_lng' => $data['lng'],
            'location_updated_at' => now(),
        ]);

        return response()->json(['message' => 'Location updated.']);
    }

    /** Staff (any rider) or the rider (themselves) */
    public function optimizeRoute(Request $request, User $rider, RouteService $routes)
    {
        $user = $request->user();
        abort_unless($rider->role === 'rider', 404);
        abort_unless($user->role === 'admin' || (int) $user->id === (int) $rider->id, 403);

        return response()->json($routes->optimize($rider));
    }
}
