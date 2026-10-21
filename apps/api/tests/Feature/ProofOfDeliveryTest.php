<?php

namespace Tests\Feature;

use App\Models\Parcel;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ProofOfDeliveryTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('local');
        config(['filesystems.default' => 'local']);
    }

    public function test_assigned_rider_can_submit_multiple_photos_and_deliver_parcel(): void
    {
        [, $rider, $parcel] = $this->deliveryFixture();
        $photos = [$this->proofPhoto(), $this->proofPhoto('second.png')];

        $this->actingAs($rider)
            ->post("/api/parcels/{$parcel->id}/proof", [
                'photos' => $photos,
            ])
            ->assertOk()
            ->assertJsonPath('photo_count', 2)
            ->assertJsonMissingPath('pod_photo_path')
            ->assertJsonMissingPath('received_by');

        $parcel->refresh();
        $this->assertCount(2, $parcel->proofPhotoPaths());
        $this->assertNotNull($parcel->pod_delivered_at);
        foreach ($parcel->proofPhotoPaths() as $path) {
            Storage::disk('local')->assertExists($path);
        }

        $this->actingAs($rider)
            ->postJson("/api/parcels/{$parcel->id}/status", ['status' => 'delivered'])
            ->assertOk()
            ->assertJsonPath('status', 'delivered');

        $this->assertSame('delivered', $parcel->fresh()->status);
    }

    public function test_delivery_status_is_rejected_until_complete_proof_is_submitted(): void
    {
        [, $rider, $parcel] = $this->deliveryFixture();

        $this->actingAs($rider)
            ->postJson("/api/parcels/{$parcel->id}/status", ['status' => 'delivered'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['status'])
            ->assertJsonPath(
                'errors.status.0',
                'Delivery not completed. Upload at least one supported proof photo (maximum 4 MB each) first.',
            );

        $this->assertSame('out_for_delivery', $parcel->fresh()->status);
    }

    public function test_only_the_assigned_rider_can_submit_proof_for_an_out_for_delivery_parcel(): void
    {
        [, , $parcel] = $this->deliveryFixture();
        $otherRider = $this->createUser('other-rider@example.test', 'rider');
        $photo = $this->proofPhoto();

        $this->actingAs($otherRider)
            ->post("/api/parcels/{$parcel->id}/proof", [
                'photos' => [$photo],
            ])
            ->assertForbidden();

        $this->assertNull($parcel->fresh()->pod_photo_path);
    }

    public function test_proof_requires_supported_images_under_four_megabytes_each(): void
    {
        [, $rider, $parcel] = $this->deliveryFixture();

        $this->actingAs($rider)
            ->post("/api/parcels/{$parcel->id}/proof", [
                'photos' => [UploadedFile::fake()->create('notes.txt', 8, 'text/plain')],
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['photos.0']);

        $this->actingAs($rider)
            ->post("/api/parcels/{$parcel->id}/proof", [
                'photos' => [$this->proofPhoto(
                    'large.png',
                    str_repeat("\0", 4 * 1024 * 1024 + 1),
                )],
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['photos.0']);
    }

    public function test_proof_photo_is_available_only_to_staff_and_owning_customer(): void
    {
        [$customer, $rider, $parcel] = $this->deliveryFixture();
        $otherCustomer = $this->createUser('other-customer@example.test', 'customer');
        $otherRider = $this->createUser('other-rider@example.test', 'rider');
        $admin = $this->createUser('admin@example.test', 'admin');
        $image = $this->proofPhoto();
        $secondImage = $this->proofPhoto('second.png');
        $path = $image->store("proof-of-delivery/{$parcel->id}", 'local');
        $secondPath = $secondImage->store("proof-of-delivery/{$parcel->id}", 'local');
        $parcel->update([
            'pod_photo_path' => $path,
            'pod_photo_paths' => [$path, $secondPath],
            'pod_delivered_at' => now(),
        ]);

        $this->getJson("/api/parcels/{$parcel->id}/proof")->assertUnauthorized();

        $this->actingAs($otherCustomer)
            ->getJson("/api/parcels/{$parcel->id}/proof")
            ->assertForbidden();

        $this->actingAs($otherRider)
            ->getJson("/api/parcels/{$parcel->id}/proof")
            ->assertForbidden();

        $this->actingAs($rider)
            ->getJson("/api/parcels/{$parcel->id}/proof")
            ->assertOk()
            ->assertStreamedContent($image->getContent());

        $this->actingAs($customer)
            ->getJson("/api/parcels/{$parcel->id}/proof")
            ->assertOk()
            ->assertHeader('Content-Type', 'image/png')
            ->assertHeader('Cache-Control', 'no-store, private')
            ->assertStreamedContent($image->getContent());

        $this->actingAs($customer)
            ->getJson("/api/parcels/{$parcel->id}/proof/1")
            ->assertOk()
            ->assertStreamedContent($secondImage->getContent());

        $this->actingAs($customer)
            ->getJson("/api/track/{$parcel->tracking_number}/proof/0")
            ->assertOk()
            ->assertStreamedContent($image->getContent());

        $this->getJson("/api/parcels/{$parcel->id}")
            ->assertOk()
            ->assertJsonMissingPath('pod_photo_paths');
        $this->assertFalse(\Illuminate\Support\Facades\Schema::hasColumn('parcels', 'pod_received_by'));

        $this->actingAs($admin)
            ->getJson("/api/parcels/{$parcel->id}/proof")
            ->assertOk();

        $this->actingAs($admin)
            ->getJson("/api/track/{$parcel->tracking_number}/proof/0")
            ->assertOk()
            ->assertStreamedContent($image->getContent());
    }

    public function test_receiver_can_view_proof_with_the_email_on_their_customer_account(): void
    {
        [, , $parcel] = $this->deliveryFixture();
        $receiver = $this->createUser('receiver@example.test', 'customer');
        $parcel->update(['receiver_email' => $receiver->email]);

        $photo = $this->proofPhoto();
        $path = $photo->store("proof-of-delivery/{$parcel->id}", 'local');
        $parcel->update([
            'pod_photo_path' => $path,
            'pod_photo_paths' => [$path],
            'pod_delivered_at' => now(),
        ]);

        $this->actingAs($receiver)
            ->getJson("/api/parcels/{$parcel->id}/proof")
            ->assertOk()
            ->assertStreamedContent($photo->getContent());

        $this->actingAs($receiver)
            ->getJson("/api/track/{$parcel->tracking_number}/proof/0")
            ->assertOk()
            ->assertStreamedContent($photo->getContent());
    }

    public function test_public_tracking_does_not_expose_recipient_name_or_photo(): void
    {
        [, , $parcel] = $this->deliveryFixture();
        $path = $this->proofPhoto()
            ->store("proof-of-delivery/{$parcel->id}", 'local');
        $parcel->update([
            'pod_photo_path' => $path,
            'pod_photo_paths' => [$path],
            'pod_delivered_at' => now(),
        ]);

        $this->getJson("/api/track/{$parcel->tracking_number}")
            ->assertOk()
            ->assertJsonPath('has_proof', true)
            ->assertJsonPath('pod_photo_count', 1)
            ->assertJsonMissingPath('pod_received_by')
            ->assertJsonMissingPath('pod_photo_path');

        $this->getJson("/api/track/{$parcel->tracking_number}/proof")
            ->assertUnauthorized();
    }

    public function test_proof_cannot_be_saved_to_a_public_filesystem_disk(): void
    {
        [, $rider, $parcel] = $this->deliveryFixture();
        Storage::fake('public');
        config(['filesystems.default' => 'public']);

        $this->actingAs($rider)
            ->post("/api/parcels/{$parcel->id}/proof", [
                'photos' => [$this->proofPhoto()],
            ])
            ->assertInternalServerError();

        $this->assertNull($parcel->fresh()->pod_photo_path);
    }

    public function test_reassigning_a_parcel_clears_the_previous_riders_proof(): void
    {
        [, , $parcel] = $this->deliveryFixture();
        $paths = [
            $this->proofPhoto()->store(
                "proof-of-delivery/{$parcel->id}",
                'local',
            ),
            $this->proofPhoto('second.png')->store(
                "proof-of-delivery/{$parcel->id}",
                'local',
            ),
        ];
        $parcel->update([
            'pod_photo_path' => $paths[0],
            'pod_photo_paths' => $paths,
            'pod_delivered_at' => now(),
        ]);

        $newRider = $this->createUser('new-rider@example.test', 'rider');
        app(\App\Services\ParcelService::class)->assign($parcel, $newRider);

        $parcel->refresh();
        $this->assertSame($newRider->id, $parcel->rider_id);
        $this->assertNull($parcel->pod_photo_path);
        $this->assertSame([], $parcel->proofPhotoPaths());
        $this->assertNull($parcel->pod_delivered_at);
        foreach ($paths as $path) {
            Storage::disk('local')->assertMissing($path);
        }
    }

    private function deliveryFixture(): array
    {
        $customer = $this->createUser('customer@example.test', 'customer');
        $rider = $this->createUser('rider@example.test', 'rider');
        $parcel = Parcel::create([
            'tracking_number' => 'TRK-PROOF-001',
            'customer_id' => $customer->id,
            'rider_id' => $rider->id,
            'sender_name' => 'Parcel Sender',
            'sender_phone' => '123456789',
            'sender_email' => $customer->email,
            'pickup_address' => '1 Pickup Road',
            'receiver_name' => 'Parcel Receiver',
            'receiver_phone' => '987654321',
            'delivery_address' => '10 Delivery Street',
            'weight_kg' => 1,
            'service_type' => 'standard',
            'fee' => 60,
            'status' => 'out_for_delivery',
        ]);

        return [$customer, $rider, $parcel];
    }

    private function createUser(string $email, string $role): User
    {
        return User::create([
            'name' => ucfirst(strstr($email, '@', true)),
            'email' => $email,
            'password' => 'a-secure-password',
            'role' => $role,
            'is_active' => true,
        ]);
    }

    private function proofPhoto(
        string $name = 'delivery.png',
        ?string $content = null,
    ): UploadedFile {
        $content ??= base64_decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jN6sAAAAASUVORK5CYII=',
            true,
        );

        return UploadedFile::fake()->createWithContent($name, $content);
    }
}
