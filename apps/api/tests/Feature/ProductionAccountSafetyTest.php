<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class ProductionAccountSafetyTest extends TestCase
{
    use RefreshDatabase;

    public function test_production_seeding_disables_demo_accounts_and_revokes_their_tokens(): void
    {
        $demo = User::create([
            'name' => 'Demo Admin',
            'email' => 'admin@trackit.test',
            'password' => 'password',
            'role' => 'admin',
        ]);
        $demo->createToken('demo');

        $this->app['env'] = 'production';
        $this->artisan('db:seed', [
            '--class' => DatabaseSeeder::class,
            '--force' => true,
        ])->assertExitCode(0);

        $this->assertFalse($demo->fresh()->is_active);
        $this->assertDatabaseCount('personal_access_tokens', 0);
        $this->assertDatabaseCount('users', 1);
    }

    public function test_admin_command_creates_an_admin_with_a_hashed_password(): void
    {
        $this->artisan('trackit:create-admin')
            ->expectsQuestion('Admin name', 'Private Admin')
            ->expectsQuestion('Admin email', 'private-admin@example.com')
            ->expectsQuestion('Admin password (at least 12 characters)', 'a-unique-long-password')
            ->expectsOutput('Admin account created for private-admin@example.com.')
            ->assertExitCode(0);

        $user = User::where('email', 'private-admin@example.com')->firstOrFail();
        $this->assertSame('admin', $user->role);
        $this->assertTrue(Hash::check('a-unique-long-password', $user->password));
    }
}
