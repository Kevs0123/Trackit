<?php

namespace Tests\Feature;

use App\Models\Parcel;
use App\Models\ParcelNotification;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CustomerParcelTabsTest extends TestCase
{
    use RefreshDatabase;

    public function test_customer_can_see_their_parcels(): void
    {
        $customer = $this->createCustomer();
        $parcel = $this->createParcel($customer);

        $this->actingAs($customer)
            ->getJson('/api/parcels/mine')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.tracking_number', $parcel->tracking_number)
            ->assertJsonPath('0.status_label', 'Booked');
    }

    public function test_notifications_include_their_parcel_without_serialization_errors(): void
    {
        $customer = $this->createCustomer();
        $parcel = $this->createParcel($customer);
        ParcelNotification::create([
            'parcel_id' => $parcel->id,
            'user_id' => $customer->id,
            'channel' => 'app',
            'recipient' => (string) $customer->id,
            'message' => 'Your parcel was booked.',
            'status' => 'sent',
        ]);

        $this->actingAs($customer)
            ->getJson('/api/notifications')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.parcel.tracking_number', $parcel->tracking_number)
            ->assertJsonPath('0.parcel.status_label', 'Booked')
            ->assertJsonPath('0.parcel.maps_url', 'https://www.google.com/maps/search/?api=1&query=10+Main+Street');
    }

    public function test_partial_parcel_without_a_status_has_a_string_status_label(): void
    {
        $parcel = new Parcel(['tracking_number' => 'TRK123']);

        $this->assertSame('Unknown', $parcel->status_label);
    }

    private function createCustomer(): User
    {
        return User::create([
            'name' => 'Parcel Customer',
            'email' => 'customer@example.test',
            'password' => 'password',
            'role' => 'customer',
            'is_active' => true,
        ]);
    }

    private function createParcel(User $customer): Parcel
    {
        return Parcel::create([
            'tracking_number' => 'TRK123',
            'customer_id' => $customer->id,
            'sender_name' => 'Sender',
            'sender_phone' => '123456789',
            'pickup_address' => '1 Pickup Road',
            'receiver_name' => 'Receiver',
            'receiver_phone' => '987654321',
            'delivery_address' => '10 Main Street',
            'weight_kg' => 1,
            'service_type' => 'standard',
            'fee' => 60,
            'status' => 'booked',
        ]);
    }
}
