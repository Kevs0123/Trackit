import 'package:flutter/material.dart';

const Map<String, String> statusLabels = {
  'booked': 'Booked',
  'assigned': 'Rider Assigned',
  'picked_up': 'Picked Up',
  'in_transit': 'In Transit',
  'out_for_delivery': 'Out for Delivery',
  'delivered': 'Delivered',
  'failed': 'Delivery Failed',
  'cancelled': 'Cancelled',
};

const List<String> progressSteps = [
  'booked',
  'assigned',
  'picked_up',
  'in_transit',
  'out_for_delivery',
  'delivered',
];

Color statusColor(String s) {
  switch (s) {
    case 'delivered':
      return Colors.green.shade700;
    case 'failed':
      return Colors.red.shade700;
    case 'cancelled':
      return Colors.grey.shade600;
    case 'out_for_delivery':
      return Colors.orange.shade800;
    case 'in_transit':
    case 'picked_up':
      return Colors.blue.shade700;
    case 'assigned':
      return Colors.indigo.shade400;
    default:
      return Colors.teal.shade700;
  }
}

double? _d(dynamic v) => v == null ? null : double.tryParse(v.toString());
int? _i(dynamic v) => v == null ? null : int.tryParse(v.toString());
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class AppUser {
  final int id;
  final String name;
  final String email;
  final String role; // admin | rider | customer
  final String? phone;
  final bool isActive;
  final int activeParcels;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.isActive = true,
    this.activeParcels = 0,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _i(j['id']) ?? 0,
        name: j['name']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        role: j['role']?.toString() ?? 'customer',
        phone: j['phone']?.toString(),
        isActive: j['is_active'] == null ? true : (j['is_active'] == true || j['is_active'] == 1),
        activeParcels: _i(j['active_parcels']) ?? 0,
      );
}

class ParcelEvent {
  final String status;
  final String statusLabel;
  final String? note;
  final DateTime? createdAt;

  ParcelEvent({required this.status, required this.statusLabel, this.note, this.createdAt});

  factory ParcelEvent.fromJson(Map<String, dynamic> j) => ParcelEvent(
        status: j['status']?.toString() ?? '',
        statusLabel: j['status_label']?.toString() ?? statusLabels[j['status']] ?? '',
        note: j['note']?.toString(),
        createdAt: _dt(j['created_at']),
      );
}

class Parcel {
  final int id;
  final String trackingNumber;
  final String status;
  final String statusLabel;
  final String senderName;
  final String senderPhone;
  final String pickupAddress;
  final String receiverName;
  final String receiverPhone;
  final String deliveryAddress;
  final String? description;
  final double weightKg;
  final String serviceType;
  final double fee;
  final String? riderName;
  final String? riderPhone;
  final double? riderLat;
  final double? riderLng;
  final DateTime? riderUpdated;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final int? routeOrder;
  final double? routeDistanceKm;
  final String? mapsUrl;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final int? rating;
  final String? feedback;
  final List<ParcelEvent> events;

  Parcel({
    required this.id,
    required this.trackingNumber,
    required this.status,
    required this.statusLabel,
    required this.senderName,
    required this.senderPhone,
    required this.pickupAddress,
    required this.receiverName,
    required this.receiverPhone,
    required this.deliveryAddress,
    this.description,
    required this.weightKg,
    required this.serviceType,
    required this.fee,
    this.riderName,
    this.riderPhone,
    this.riderLat,
    this.riderLng,
    this.riderUpdated,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    this.routeOrder,
    this.routeDistanceKm,
    this.mapsUrl,
    this.createdAt,
    this.deliveredAt,
    this.rating,
    this.feedback,
    this.events = const [],
  });

  /// Works for the full parcel JSON (staff/customer/rider) and the public tracking JSON.
  factory Parcel.fromJson(Map<String, dynamic> j) {
    final rider = j['rider'] is Map ? Map<String, dynamic>.from(j['rider']) : null;
    final events = (j['events'] as List? ?? [])
        .map((e) => ParcelEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final status = j['status']?.toString() ?? 'booked';

    return Parcel(
      id: _i(j['id']) ?? 0,
      trackingNumber: j['tracking_number']?.toString() ?? '',
      status: status,
      statusLabel: j['status_label']?.toString() ?? statusLabels[status] ?? status,
      senderName: j['sender_name']?.toString() ?? '',
      senderPhone: j['sender_phone']?.toString() ?? '',
      pickupAddress: j['pickup_address']?.toString() ?? '',
      receiverName: j['receiver_name']?.toString() ?? '',
      receiverPhone: j['receiver_phone']?.toString() ?? '',
      deliveryAddress: j['delivery_address']?.toString() ?? '',
      description: j['description']?.toString(),
      weightKg: _d(j['weight_kg']) ?? 0,
      serviceType: j['service_type']?.toString() ?? 'standard',
      fee: _d(j['fee']) ?? 0,
      riderName: rider?['name']?.toString(),
      riderPhone: rider?['phone']?.toString(),
      riderLat: _d(rider?['last_lat']),
      riderLng: _d(rider?['last_lng']),
      riderUpdated: _dt(rider?['location_updated_at']),
      pickupLat: _d(j['pickup_lat']),
      pickupLng: _d(j['pickup_lng']),
      dropLat: _d(j['drop_lat']),
      dropLng: _d(j['drop_lng']),
      routeOrder: _i(j['route_order']),
      routeDistanceKm: _d(j['route_distance_km']),
      mapsUrl: j['maps_url']?.toString(),
      createdAt: _dt(j['created_at']),
      deliveredAt: _dt(j['delivered_at']),
      rating: _i(j['rating']),
      feedback: j['feedback']?.toString(),
      events: events,
    );
  }

  bool get isFinal => status == 'delivered' || status == 'cancelled';
}

List<Parcel> parseParcels(dynamic list) =>
    (list as List? ?? []).map((e) => Parcel.fromJson(Map<String, dynamic>.from(e))).toList();
