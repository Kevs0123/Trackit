<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ParcelEvent extends Model
{
    protected $guarded = ['id'];

    protected $appends = ['status_label'];

    protected function casts(): array
    {
        return ['lat' => 'float', 'lng' => 'float'];
    }

    public function parcel()
    {
        return $this->belongsTo(Parcel::class);
    }

    public function getStatusLabelAttribute(): string
    {
        return Parcel::STATUSES[$this->status] ?? $this->status;
    }
}
