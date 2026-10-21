<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Parcel;
use App\Models\User;
use App\Services\ParcelService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ParcelController extends Controller
{
    public function __construct(private ParcelService $service)
    {
    }

    /** Staff: all parcels with search + filters */
    public function index(Request $request)
    {
        $query = Parcel::with('rider:id,name,phone')->latest('id');

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }
        if ($riderId = $request->query('rider_id')) {
            $query->where('rider_id', $riderId);
        }
        if ($search = trim((string) $request->query('q'))) {
            $query->where(function ($w) use ($search) {
                $w->where('tracking_number', 'like', "%{$search}%")
                    ->orWhere('sender_name', 'like', "%{$search}%")
                    ->orWhere('receiver_name', 'like', "%{$search}%");
            });
        }

        return $query->paginate(15);
    }

    /** Customer: parcels they booked (or that were booked for their email) */
    public function mine(Request $request)
    {
        $user = $request->user();

        return Parcel::with('rider:id,name,phone')
            ->where(function ($q) use ($user) {
                $q->where('customer_id', $user->id)->orWhere('sender_email', $user->email);
            })
            ->latest('id')
            ->get();
    }

    /** Staff and customers can book. Staff may book on behalf of walk-in customers. */
    public function store(Request $request)
    {
        $user = $request->user();
        abort_if($user->role === 'rider', 403, 'Riders cannot book parcels.');

        $request->validate([
            'sender_name' => 'required|string|max:100',
            'sender_phone' => 'required|string|max:30',
            'sender_email' => 'nullable|email|max:255',
            'pickup_address' => 'required|string|max:255',
            'receiver_name' => 'required|string|max:100',
            'receiver_phone' => 'required|string|max:30',
            'receiver_email' => 'nullable|email|max:255',
            'delivery_address' => 'required|string|max:255',
            'description' => 'nullable|string|max:255',
            'weight_kg' => 'required|numeric|min:0.1|max:50',
            'service_type' => 'required|in:standard,express',
            'pickup_lat' => 'nullable|numeric|between:-90,90',
            'pickup_lng' => 'nullable|numeric|between:-180,180',
            'drop_lat' => 'nullable|numeric|between:-90,90',
            'drop_lng' => 'nullable|numeric|between:-180,180',
            'customer_id' => 'nullable|exists:users,id',
        ]);

        if ($user->role !== 'admin') {
            unset($data['customer_id']);
        }

        return response()->json($this->service->book($data, $user), 201);
    }

    public function show(Request $request, Parcel $parcel)
    {
        abort_unless($this->canView($request->user(), $parcel), 403, 'You cannot view this parcel.');

        return $parcel->load(['events', 'rider:id,name,phone', 'customer:id,name,email']);
    }

    /** Rider assigned to this parcel submits its proof before marking delivery complete. */
    public function storeProof(Request $request, Parcel $parcel)
    {
        $user = $request->user();
        abort_unless(
            $user->role === 'rider' && (int) $parcel->rider_id === (int) $user->id,
            403,
            'Only the rider assigned to this parcel can submit proof of delivery.'
        );
        abort_unless($parcel->status === 'out_for_delivery', 422, 'Proof can only be submitted for an out-for-delivery parcel.');

        $request->validate([
            'photos' => 'required|array|min:1|max:10',
            'photos.*' => 'required|image|mimes:jpg,jpeg,png,webp,gif,bmp,avif|max:4096',
        ]);

        $diskName = $this->privateDiskName();
        $disk = Storage::disk($diskName);
        $paths = [];
        try {
            foreach ($request->file('photos') as $photo) {
                $path = $disk->putFileAs(
                    "proof-of-delivery/{$parcel->id}",
                    $photo,
                    Str::uuid().'.'.$photo->extension(),
                    ['visibility' => 'private'],
                );
                if (! is_string($path) || $path === '') {
                    throw new \RuntimeException("Could not store proof of delivery on the [{$diskName}] disk.");
                }
                $paths[] = $path;
            }
        } catch (\Throwable $exception) {
            if ($paths !== []) {
                $disk->delete($paths);
            }
            throw $exception;
        }

        $previousPaths = $parcel->proofPhotoPaths();
        try {
            $parcel->update([
                'pod_photo_path' => $paths[0],
                'pod_photo_paths' => $paths,
                'pod_delivered_at' => now(),
            ]);
        } catch (\Throwable $exception) {
            $disk->delete($paths);
            throw $exception;
        }

        $obsoletePaths = array_values(array_diff($previousPaths, $paths));
        if ($obsoletePaths !== []) {
            $disk->delete($obsoletePaths);
        }

        return response()->json([
            'message' => 'Proof of delivery saved.',
            'photo_count' => count($paths),
            'delivered_at' => $parcel->pod_delivered_at,
        ]);
    }

    /** Only staff, the assigned rider, and matching sender or receiver accounts can view proof. */
    public function showProof(Request $request, Parcel $parcel, int $photo = 0)
    {
        abort_unless($this->canViewProof($request->user(), $parcel), 403, 'You cannot view this proof of delivery.');

        return $this->proofResponse($parcel, $photo);
    }

    /** Tracking page companion to the authenticated parcel proof endpoint. */
    public function showProofByTrackingNumber(Request $request, string $trackingNumber, int $photo = 0)
    {
        $parcel = Parcel::where('tracking_number', strtoupper(trim($trackingNumber)))->firstOrFail();
        abort_unless($this->canViewProof($request->user(), $parcel), 403, 'You cannot view this proof of delivery.');

        return $this->proofResponse($parcel, $photo);
    }

    /** Staff: assign (or reassign) a rider */
    public function assign(Request $request, Parcel $parcel)
    {
        $data = $request->validate(['rider_id' => 'required|exists:users,id']);
        $rider = User::findOrFail($data['rider_id']);

        return $this->service->assign($parcel, $rider, $request->user());
    }

    /** Rider (own parcels) or staff: update delivery status */
    public function updateStatus(Request $request, Parcel $parcel)
    {
        $data = $request->validate([
            'status' => 'required|in:picked_up,in_transit,out_for_delivery,delivered,failed,cancelled',
            'note' => 'nullable|string|max:255',
            'lat' => 'nullable|numeric|between:-90,90',
            'lng' => 'nullable|numeric|between:-180,180',
        ]);

        $user = $request->user();

        if ($user->role === 'rider') {
            abort_unless((int) $parcel->rider_id === (int) $user->id, 403, 'This parcel is not assigned to you.');
            abort_if($data['status'] === 'cancelled', 403, 'Riders cannot cancel parcels.');

            if (isset($data['lat'], $data['lng'])) {
                $user->update([
                    'last_lat' => $data['lat'],
                    'last_lng' => $data['lng'],
                    'location_updated_at' => now(),
                ]);
            }
        } elseif ($user->role !== 'admin') {
            abort(403, 'You cannot change parcel status.');
        }

        return $this->service->changeStatus(
            $parcel,
            $data['status'],
            $data['note'] ?? null,
            isset($data['lat']) ? (float) $data['lat'] : null,
            isset($data['lng']) ? (float) $data['lng'] : null,
            $user
        );
    }

    /** Customer can cancel their own parcel while it is still only "booked" */
    public function cancel(Request $request, Parcel $parcel)
    {
        $user = $request->user();

        abort_unless(
            $user->role === 'customer' && (int) $parcel->customer_id === (int) $user->id && $parcel->status === 'booked',
            403,
            'Only your own parcels that have not been assigned yet can be cancelled.'
        );

        return $this->service->changeStatus($parcel, 'cancelled', 'Cancelled by customer.', null, null, $user);
    }

    private function canView(User $user, Parcel $parcel): bool
    {
        return match ($user->role) {
            'admin' => true,
            'rider' => (int) $parcel->rider_id === (int) $user->id,
            'customer' => (int) $parcel->customer_id === (int) $user->id || ($parcel->sender_email && $parcel->sender_email === $user->email),
            default => false,
        };
    }

    private function proofResponse(Parcel $parcel, int $photo)
    {
        $paths = $parcel->proofPhotoPaths();
        abort_unless(isset($paths[$photo]), 404, 'Proof of delivery photo was not found.');

        $disk = Storage::disk($this->privateDiskName());
        $path = $paths[$photo];
        $stream = $disk->readStream($path);
        abort_if($stream === false, 404, 'Proof of delivery image was not found.');

        $mimeType = $disk->mimeType($path);

        return response()->stream(function () use ($stream) {
            try {
                fpassthru($stream);
            } finally {
                fclose($stream);
            }
        }, 200, [
            'Content-Type' => $mimeType ?: 'application/octet-stream',
            'Cache-Control' => 'private, no-store',
            'X-Content-Type-Options' => 'nosniff',
            'Content-Disposition' => 'inline; filename="proof-of-delivery"',
        ]);
    }

    private function canViewProof(User $user, Parcel $parcel): bool
    {
        return $user->role === 'admin'
            || ($user->role === 'rider' && (int) $parcel->rider_id === (int) $user->id)
            || ($user->role === 'customer'
                && ((int) $parcel->customer_id === (int) $user->id
                    || ($parcel->sender_email && $parcel->sender_email === $user->email)
                    || ($parcel->receiver_email && $parcel->receiver_email === $user->email)));
    }

    private function privateDiskName(): string
    {
        $diskName = (string) config('filesystems.default');
        $diskConfig = config("filesystems.disks.{$diskName}", []);
        $root = $diskConfig['root'] ?? null;
        $publicRoot = realpath(public_path());
        $resolvedRoot = $root ? realpath($root) : false;
        $isPublicLocalRoot = ($diskConfig['driver'] ?? null) === 'local'
            && $resolvedRoot
            && $publicRoot
            && str_starts_with(
                strtolower($resolvedRoot.DIRECTORY_SEPARATOR),
                strtolower($publicRoot.DIRECTORY_SEPARATOR)
            );

        abort_if(
            ($diskConfig['visibility'] ?? 'private') === 'public' || $isPublicLocalRoot,
            500,
            'Proof-of-delivery storage must use a private disk. Configure FILESYSTEM_DISK to a private local or cloud disk.'
        );

        return $diskName;
    }
}
