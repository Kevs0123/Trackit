<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('parcels', function (Blueprint $table) {
            $table->string('pod_photo_path')->nullable();
            $table->string('pod_received_by', 100)->nullable();
            $table->timestamp('pod_delivered_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('parcels', function (Blueprint $table) {
            $table->dropColumn([
                'pod_photo_path',
                'pod_received_by',
                'pod_delivered_at',
            ]);
        });
    }
};
