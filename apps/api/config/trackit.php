<?php

return [
    // Used in notification emails so customers can open the tracking page
    'frontend_url' => env('FRONTEND_URL') ?: (
        env('APP_ENV') === 'production'
            ? env('APP_URL', 'http://localhost')
            : 'http://localhost:8080'
    ),

    // Address -> coordinates lookup (OpenStreetMap Nominatim, free, no API key)
    'geocode_enabled' => env('GEOCODE_ENABLED', true),
    'geocode_country' => env('GEOCODE_COUNTRY', 'ph'),

    // Where riders start their route when they have not shared a location yet
    'depot' => [
        'lat' => (float) env('DEPOT_LAT', 14.5995),
        'lng' => (float) env('DEPOT_LNG', 120.9842),
    ],

    // Route estimates
    'road_factor' => 1.3,       // straight-line km -> approx. road km
    'avg_speed_kmh' => 25,
    'minutes_per_stop' => 8,
];
