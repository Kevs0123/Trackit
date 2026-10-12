<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ParcelNotification;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request)
    {
        return ParcelNotification::with('parcel:id,tracking_number,status,drop_lat,drop_lng,delivery_address')
            ->where('user_id', $request->user()->id)
            ->where('channel', 'app')
            ->latest('id')
            ->limit(50)
            ->get();
    }

    public function markAllRead(Request $request)
    {
        ParcelNotification::where('user_id', $request->user()->id)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return response()->json(['message' => 'All notifications marked as read.']);
    }
}
