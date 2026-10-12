<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ParcelNotification extends Model
{
    protected $guarded = ['id'];

    protected function casts(): array
    {
        return ['read_at' => 'datetime'];
    }

    public function parcel()
    {
        return $this->belongsTo(Parcel::class);
    }
}
