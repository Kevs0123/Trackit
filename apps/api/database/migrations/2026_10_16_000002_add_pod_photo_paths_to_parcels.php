<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('parcels', 'pod_received_by')) {
            Schema::table('parcels', function (Blueprint $table) {
                $table->dropColumn('pod_received_by');
            });
        }

        Schema::table('parcels', function (Blueprint $table) {
            $table->json('pod_photo_paths')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('parcels', function (Blueprint $table) {
            $table->dropColumn('pod_photo_paths');
        });

        if (! Schema::hasColumn('parcels', 'pod_received_by')) {
            Schema::table('parcels', function (Blueprint $table) {
                $table->string('pod_received_by', 100)->nullable();
            });
        }
    }
};
