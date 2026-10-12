<?php

namespace Database\Seeders;

use App\Models\User;
use App\Services\ParcelService;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(ParcelService $service): void
    {
        $admin = User::create([
            'name' => 'TrackIt Admin', 'email' => 'admin@trackit.test', 'password' => 'password',
            'role' => 'admin', 'phone' => '09170000000',
        ]);

        $rico = User::create([
            'name' => 'Rico Santos', 'email' => 'rider1@trackit.test', 'password' => 'password',
            'role' => 'rider', 'phone' => '09171110001',
            'last_lat' => 14.5547, 'last_lng' => 121.0244, 'location_updated_at' => now(),
        ]);

        $mara = User::create([
            'name' => 'Mara Reyes', 'email' => 'rider2@trackit.test', 'password' => 'password',
            'role' => 'rider', 'phone' => '09171110002',
            'last_lat' => 14.6091, 'last_lng' => 121.0223, 'location_updated_at' => now(),
        ]);

        $customer = User::create([
            'name' => 'Demo Customer', 'email' => 'customer@trackit.test', 'password' => 'password',
            'role' => 'customer', 'phone' => '09172220001',
        ]);

        // Coordinates are given so seeding never needs internet access
        $base = [
            'sender_name' => 'Demo Customer', 'sender_phone' => '09172220001', 'sender_email' => 'customer@trackit.test',
            'pickup_address' => 'Ayala Avenue, Makati City', 'pickup_lat' => 14.5547, 'pickup_lng' => 121.0244,
            'weight_kg' => 1, 'service_type' => 'standard',
        ];

        $parcels = [
            $service->book($base + [
                'receiver_name' => 'Ana Cruz', 'receiver_phone' => '09173330001',
                'delivery_address' => 'Bonifacio Global City, Taguig', 'drop_lat' => 14.5509, 'drop_lng' => 121.0480,
                'description' => 'Documents',
            ], $customer),
            $service->book($base + [
                'receiver_name' => 'Ben Lim', 'receiver_phone' => '09173330002',
                'delivery_address' => 'Ortigas Center, Pasig City', 'drop_lat' => 14.5866, 'drop_lng' => 121.0615,
                'description' => 'Phone case', 'weight_kg' => 2,
            ], $customer),
            $service->book($base + [
                'receiver_name' => 'Cara Dizon', 'receiver_phone' => '09173330003',
                'delivery_address' => 'Quezon Avenue, Quezon City', 'drop_lat' => 14.6272, 'drop_lng' => 121.0364,
                'description' => 'Shoes', 'weight_kg' => 3, 'service_type' => 'express',
            ], $customer),
            $service->book($base + [
                'receiver_name' => 'Dan Uy', 'receiver_phone' => '09173330004',
                'delivery_address' => 'Mandaluyong City Hall', 'drop_lat' => 14.5794, 'drop_lng' => 121.0359,
                'description' => 'Books',
            ], $customer),
        ];

        // 1st stays "booked"; 2nd assigned; 3rd out for delivery; 4th delivered + rated
        $service->assign($parcels[1], $rico, $admin);

        $service->assign($parcels[2], $rico, $admin);
        $service->changeStatus($parcels[2], 'picked_up', null, null, null, $rico);
        $service->changeStatus($parcels[2], 'in_transit', null, 14.5700, 121.0300, $rico);
        $service->changeStatus($parcels[2], 'out_for_delivery', 'On my way', 14.6000, 121.0330, $rico);

        $service->assign($parcels[3], $mara, $admin);
        $service->changeStatus($parcels[3], 'picked_up', null, null, null, $mara);
        $service->changeStatus($parcels[3], 'delivered', 'Received by Dan', 14.5794, 121.0359, $mara);
        $parcels[3]->update(['rating' => 5, 'feedback' => 'Fast and friendly rider!']);
    }
}
