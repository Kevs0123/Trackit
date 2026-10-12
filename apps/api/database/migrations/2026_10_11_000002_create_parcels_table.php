<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('parcels', function (Blueprint $table) {
            $table->id();
            $table->string('tracking_number', 30)->unique();
            $table->foreignId('customer_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('rider_id')->nullable()->constrained('users')->nullOnDelete();

            $table->string('sender_name', 100);
            $table->string('sender_phone', 30);
            $table->string('sender_email')->nullable();
            $table->string('pickup_address');

            $table->string('receiver_name', 100);
            $table->string('receiver_phone', 30);
            $table->string('receiver_email')->nullable();
            $table->string('delivery_address');

            $table->string('description')->nullable();
            $table->decimal('weight_kg', 8, 2)->default(1);
            $table->string('service_type', 20)->default('standard'); // standard | express
            $table->decimal('fee', 10, 2)->default(0);
            $table->string('status', 30)->default('booked')->index();

            $table->decimal('pickup_lat', 10, 7)->nullable();
            $table->decimal('pickup_lng', 10, 7)->nullable();
            $table->decimal('drop_lat', 10, 7)->nullable();
            $table->decimal('drop_lng', 10, 7)->nullable();

            $table->unsignedSmallInteger('route_order')->nullable();
            $table->decimal('route_distance_km', 8, 2)->nullable();

            $table->timestamp('assigned_at')->nullable();
            $table->timestamp('delivered_at')->nullable();

            $table->unsignedTinyInteger('rating')->nullable();
            $table->text('feedback')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('parcels');
    }
};
