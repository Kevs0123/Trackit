<?php

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\URL;

Route::get('/email/verify/{id}/{hash}', function (Request $request, string $id, string $hash) {
    $user = User::find($id);
    $validLink = URL::hasValidSignature($request)
        && $user
        && hash_equals($hash, sha1($user->getEmailForVerification()));

    if ($validLink && ! $user->hasVerifiedEmail()) {
        $user->markEmailAsVerified();
    }

    $status = $validLink ? 'success' : 'invalid';

    return redirect()->away(rtrim(config('trackit.frontend_url'), '/').'/#/verify-email?status='.$status);
})->middleware('throttle:6,1')->name('verification.verify');

Route::get('/', function () {
    return view('welcome');
});
