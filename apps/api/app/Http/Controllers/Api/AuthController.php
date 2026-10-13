<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /** Public sign-up is for customers only. Riders are created by staff. */
    public function register(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:100',
            'email' => 'required|email|max:255|unique:users,email',
            'phone' => 'nullable|string|max:30',
            'password' => 'required|string|min:8',
        ]);

        $user = User::create($data + ['role' => 'customer']);
        $user->sendEmailVerificationNotification();

        return response()->json([
            'message' => 'Account created. Check your email for a verification link before signing in.',
        ], 201);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages(['email' => ['Invalid email or password.']]);
        }
        if (! $user->is_active) {
            throw ValidationException::withMessages(['email' => ['This account has been deactivated.']]);
        }
        if ($user->role === 'customer' && ! $user->hasVerifiedEmail()) {
            return response()->json([
                'message' => 'Verify your email before signing in. You can request another verification email.',
            ], 403);
        }

        return response()->json([
            'token' => $user->createToken('trackit')->plainTextToken,
            'user' => $user,
        ]);
    }

    public function me(Request $request)
    {
        return $request->user();
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out.']);
    }

    public function resendVerification(Request $request)
    {
        $data = $request->validate(['email' => 'required|email']);
        $user = User::where('email', $data['email'])->where('role', 'customer')->first();

        if ($user && ! $user->hasVerifiedEmail() && $user->is_active) {
            $user->sendEmailVerificationNotification();
        }

        return response()->json([
            'message' => 'If an unverified customer account exists for that address, a verification link has been sent.',
        ]);
    }

    public function forgotPassword(Request $request)
    {
        $request->validate(['email' => 'required|email']);

        Password::sendResetLink($request->only('email'));

        return response()->json([
            'message' => 'If an account exists for that address, a password reset link has been sent.',
        ]);
    }

    public function resetPassword(Request $request)
    {
        $data = $request->validate([
            'token' => 'required|string',
            'email' => 'required|email',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $status = Password::reset($data, function (User $user, string $password) {
            $user->forceFill([
                'password' => Hash::make($password),
                'remember_token' => Str::random(60),
            ])->save();
            $user->tokens()->delete();
            event(new PasswordReset($user));
        });

        if ($status !== Password::PASSWORD_RESET) {
            throw ValidationException::withMessages([
                'email' => ['This password reset link is invalid or expired. Request a new one.'],
            ]);
        }

        return response()->json(['message' => 'Password reset successfully. You can now sign in.']);
    }
}
