<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Parcel extends Model
{
    public const STATUSES = [
        'booked' => 'Booked',
        'assigned' => 'Rider Assigned',
        'picked_up' => 'Picked Up',
        'in_transit' => 'In Transit',
        'out_for_delivery' => 'Out for Delivery',
        'delivered' => 'Delivered',
        'failed' => 'Delivery Failed',
        'cancelled' => 'Cancelled',
    ];

    /** Parcels a rider is still working on */
    public const ACTIVE = ['assigned', 'picked_up', 'in_transit', 'out_for_delivery'];

    /** No more changes allowed once a parcel reaches one of these */
    public const FINAL = ['delivered', 'cancelled'];

    protected $guarded = ['id'];

    protected $appends = ['status_label', 'maps_url'];

    protected function casts(): array
    {
        return [
            'weight_kg' => 'float',
            'fee' => 'float',
            'pickup_lat' => 'float',
            'pickup_lng' => 'float',
            'drop_lat' => 'float',
            'drop_lng' => 'float',
            'route_distance_km' => 'float',
            'assigned_at' => 'datetime',
            'delivered_at' => 'datetime',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    public function rider(): BelongsTo
    {
        return $this->belongsTo(User::class, 'rider_id');
    }

    public function events(): HasMany
    {
        return $this->hasMany(ParcelEvent::class)->orderBy('id');
    }

    public function getStatusLabelAttribute(): string
    {
        return self::STATUSES[$this->status] ?? ($this->status ?: 'Unknown');
    }

    public function getMapsUrlAttribute(): string
    {
        if ($this->drop_lat !== null && $this->drop_lng !== null) {
            return "https://www.google.com/maps/dir/?api=1&destination={$this->drop_lat},{$this->drop_lng}";
        }

        return 'https://www.google.com/maps/search/?api=1&query='.urlencode((string) $this->delivery_address);
    }
}
