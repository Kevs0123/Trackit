<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        if (app()->isProduction()) {
            User::whereIn('email', [
                'admin@trackit.test',
                'rider1@trackit.test',
                'rider2@trackit.test',
                'customer@trackit.test',
            ])->get()->each(function (User $user) {
                $user->tokens()->delete();
                $user->update(['is_active' => false]);
            });

            return;
        }
    }
}
