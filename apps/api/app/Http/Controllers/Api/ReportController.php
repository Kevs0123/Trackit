<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Parcel;
use App\Models\ParcelNotification;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ReportController extends Controller
{
    public function dashboard()
    {
        return response()->json([
            'total' => Parcel::count(),
            'booked_today' => Parcel::whereDate('created_at', today())->count(),
            'delivered_today' => Parcel::whereDate('delivered_at', today())->count(),
            'active' => Parcel::whereIn('status', Parcel::ACTIVE)->count(),
            'awaiting_assignment' => Parcel::where('status', 'booked')->count(),
            'riders' => User::where('role', 'rider')->where('is_active', true)->count(),
            'by_status' => Parcel::select('status', DB::raw('count(*) as c'))->groupBy('status')->pluck('c', 'status'),
        ]);
    }

    /** Delivery report + efficiency/usability measures for a date range */
    public function deliveries(Request $request)
    {
        [$from, $to] = $this->range($request);

        $parcels = Parcel::with('rider:id,name')->whereBetween('created_at', [$from, $to])->get();

        $delivered = $parcels->where('status', 'delivered');
        $failed = $parcels->where('status', 'failed');
        $finished = $delivered->count() + $failed->count();
        $rated = $parcels->whereNotNull('rating');

        $byRider = $parcels->whereNotNull('rider_id')->groupBy('rider_id')->map(function ($group) {
            $del = $group->where('status', 'delivered');
            $fail = $group->where('status', 'failed');
            $fin = $del->count() + $fail->count();

            return [
                'rider' => $group->first()->rider?->name ?? 'Unknown',
                'assigned' => $group->count(),
                'delivered' => $del->count(),
                'failed' => $fail->count(),
                'success_rate' => $fin ? round($del->count() / $fin * 100, 1) : null,
                'avg_minutes' => $del->count() ? (int) round($del->avg(fn ($p) => $this->minutes($p))) : null,
            ];
        })->values();

        $daily = $parcels->groupBy(fn ($p) => $p->created_at->toDateString())
            ->map(fn ($group, $date) => [
                'date' => $date,
                'booked' => $group->count(),
                'delivered' => $group->where('status', 'delivered')->count(),
            ])
            ->sortKeys()
            ->values();

        return response()->json([
            'from' => $from->toDateString(),
            'to' => $to->toDateString(),
            'total_booked' => $parcels->count(),
            'delivered' => $delivered->count(),
            'failed' => $failed->count(),
            'cancelled' => $parcels->where('status', 'cancelled')->count(),
            'in_progress' => $parcels->whereIn('status', Parcel::ACTIVE)->count(),
            'success_rate' => $finished ? round($delivered->count() / $finished * 100, 1) : null,
            'avg_delivery_minutes' => $delivered->count() ? (int) round($delivered->avg(fn ($p) => $this->minutes($p))) : null,
            'total_fees' => round($parcels->where('status', '!=', 'cancelled')->sum('fee'), 2),
            'avg_rating' => $rated->count() ? round($rated->avg('rating'), 2) : null,
            'ratings_count' => $rated->count(),
            'notifications_sent' => ParcelNotification::whereBetween('created_at', [$from, $to])->where('status', 'sent')->count(),
            'by_rider' => $byRider,
            'daily' => $daily,
        ]);
    }

    public function export(Request $request)
    {
        [$from, $to] = $this->range($request);
        $rows = Parcel::with('rider:id,name')->whereBetween('created_at', [$from, $to])->orderBy('created_at')->get();

        return response()->streamDownload(function () use ($rows) {
            $out = fopen('php://output', 'w');
            $put = fn (array $row) => fputcsv($out, $row, ',', '"', '\\');

            $put(['Tracking No', 'Status', 'Sender', 'Receiver', 'Delivery Address', 'Rider', 'Service', 'Weight (kg)', 'Fee', 'Booked At', 'Delivered At', 'Delivery Minutes', 'Rating']);
            foreach ($rows as $p) {
                $put([
                    $p->tracking_number, $p->status_label, $p->sender_name, $p->receiver_name, $p->delivery_address,
                    $p->rider?->name, $p->service_type, $p->weight_kg, $p->fee,
                    $p->created_at, $p->delivered_at, $p->delivered_at ? $this->minutes($p) : '', $p->rating,
                ]);
            }
            fclose($out);
        }, 'trackit-delivery-report.csv', ['Content-Type' => 'text/csv']);
    }

    private function range(Request $request): array
    {
        $from = Carbon::parse($request->query('from', now()->subDays(29)->toDateString()))->startOfDay();
        $to = Carbon::parse($request->query('to', now()->toDateString()))->endOfDay();

        return [$from, $to];
    }

    private function minutes(Parcel $p): float
    {
        return $p->delivered_at ? abs($p->created_at->diffInMinutes($p->delivered_at)) : 0;
    }
}
