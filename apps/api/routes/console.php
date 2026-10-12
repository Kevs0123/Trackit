<?php

use App\Models\User;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Validator;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('trackit:create-admin', function () {
    $data = [
        'name' => $this->ask('Admin name'),
        'email' => $this->ask('Admin email'),
        'password' => $this->secret('Admin password (at least 12 characters)'),
    ];

    $validator = Validator::make($data, [
        'name' => ['required', 'string', 'max:100'],
        'email' => ['required', 'email', 'max:255', 'unique:users,email'],
        'password' => ['required', 'string', 'min:12'],
    ]);

    if ($validator->fails()) {
        foreach ($validator->errors()->all() as $error) {
            $this->error($error);
        }

        return 1;
    }

    $user = User::create($data + ['role' => 'admin']);
    unset($data['password']);

    $this->info("Admin account created for {$user->email}.");

    return 0;
})->purpose('Create a named admin account without exposing its password');
