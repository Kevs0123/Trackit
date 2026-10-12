<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\ParcelController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\RiderController;
use App\Http\Controllers\Api\TrackingController;
use Illuminate\Support\Facades\Route;

// ---------- Public ----------
Route::post('/auth/register', [AuthController::class, 'register']);
Route::post('/auth/login', [AuthController::class, 'login']);

Route::middleware('throttle:60,1')->group(function () {
    Route::get('/track/{trackingNumber}', [TrackingController::class, 'show']);
    Route::post('/track/{trackingNumber}/feedback', [TrackingController::class, 'feedback']);
});

// ---------- Logged in ----------
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    // Customers (and staff) book parcels; everyone sees only what they are allowed to
    Route::get('/parcels/mine', [ParcelController::class, 'mine']);
    Route::post('/parcels', [ParcelController::class, 'store']);
    Route::get('/parcels/{parcel}', [ParcelController::class, 'show'])->whereNumber('parcel');
    Route::post('/parcels/{parcel}/status', [ParcelController::class, 'updateStatus'])->whereNumber('parcel');
    Route::post('/parcels/{parcel}/cancel', [ParcelController::class, 'cancel'])->whereNumber('parcel');

    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::post('/notifications/read', [NotificationController::class, 'markAllRead']);

    // Route optimization: staff for any rider, rider for themselves
    Route::post('/riders/{rider}/optimize-route', [RiderController::class, 'optimizeRoute'])
        ->whereNumber('rider')
        ->middleware('role:admin,rider');

    // Courier staff
    Route::middleware('role:admin')->group(function () {
        Route::get('/parcels', [ParcelController::class, 'index']);
        Route::post('/parcels/{parcel}/assign', [ParcelController::class, 'assign'])->whereNumber('parcel');

        Route::get('/riders', [RiderController::class, 'index']);
        Route::post('/riders', [RiderController::class, 'store']);
        Route::put('/riders/{rider}', [RiderController::class, 'update'])->whereNumber('rider');

        Route::get('/dashboard', [ReportController::class, 'dashboard']);
        Route::get('/reports/deliveries', [ReportController::class, 'deliveries']);
        Route::get('/reports/export', [ReportController::class, 'export']);
    });

    // Riders
    Route::middleware('role:rider')->group(function () {
        Route::get('/rider/parcels', [RiderController::class, 'myParcels']);
        Route::post('/rider/location', [RiderController::class, 'updateLocation']);
    });
});
