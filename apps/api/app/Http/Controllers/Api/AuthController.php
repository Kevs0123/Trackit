<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /** Public sign-up is for customers only. Riders are created by staff. */
    public function register(Request $request)
    {
        $this->normalizeEmail($request);

        $data = $request->validate([
            'name' => 'required|string|max:100',
            'email' => 'required|email|max:255|unique:users,email',
            'phone' => 'nullable|string|max:30',
            'password' => 'required|string|min:8',
        ]);

        if (User::whereRaw('LOWER(email) = ?', [$data['email']])->exists()) {
            throw ValidationException::withMessages([
                'email' => ['The email has already been taken.'],
            ]);
        }

        $account = DB::transaction(function () use ($data) {
            $user = User::create($data + ['role' => 'customer']);

            return [
                'token' => $user->createToken('trackit')->plainTextToken,
                'user' => $user,
            ];
        });

        return response()->json($account, 201);
    }

    public function login(Request $request)
    {
        $this->normalizeEmail($request);

        $data = $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::whereRaw('LOWER(email) = ?', [$data['email']])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Invalid email or password. Check both, or use Forgot password to reset it.'],
            ]);
        }
        if (! $user->is_active) {
            throw ValidationException::withMessages(['email' => ['This account has been deactivated.']]);
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

    public function forgotPassword(Request $request)
    {
        $this->normalizeEmail($request);
        $data = $request->validate(['email' => 'required|email']);

        $user = User::whereRaw('LOWER(email) = ?', [$data['email']])->first();
        if (app()->isLocal()) {
            if (! $user) {
                return response()->json([
                    'message' => 'If an account exists for this email, a password reset link has been sent.',
                ]);
            }

            $token = Password::broker()->createToken($user);
            $resetUrl = rtrim(config('trackit.frontend_url'), '/')
                .'/#/reset-password?'.http_build_query([
                    'token' => $token,
                    'email' => $user->email,
                ], '', '&', PHP_QUERY_RFC3986);

            return response()->json([
                'message' => 'Email delivery is disabled in local development. Open the reset page below.',
                'reset_url' => $resetUrl,
            ]);
        }

        try {
            Password::sendResetLink(['email' => $user?->email ?? $data['email']]);
        } catch (\Throwable $exception) {
            Log::error('Password reset email delivery failed.', [
                'exception' => $exception::class,
            ]);

            return response()->json([
                'message' => 'The password reset email could not be sent because the email service is unavailable. Please try again later or contact support.',
            ], 503);
        }

        return response()->json([
            'message' => 'If an account exists for that address, a password reset link has been sent.',
        ]);
    }

    public function resetPassword(Request $request)
    {
        $this->normalizeEmail($request);

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

    private function normalizeEmail(Request $request): void
    {
        $email = $request->input('email');

        if (is_string($email)) {
            $request->merge(['email' => Str::lower(trim($email))]);
        }
    }
}
