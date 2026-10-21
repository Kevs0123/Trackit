import 'package:flutter_test/flutter_test.dart';
import 'package:trackit_app/models.dart';
import 'package:trackit_app/services/api.dart';

void main() {
  test('authenticated image requests use the current API bearer token', () {
    final api = ApiClient()..token = 'test-session-token';

    expect(
      api.authenticatedHeaders['Authorization'],
      'Bearer test-session-token',
    );
    expect(api.authenticatedHeaders['Accept'], 'application/json');
  });

  test('parcel parses proof metadata and photo count without storage paths',
      () {
    final parcel = Parcel.fromJson({
      'id': 42,
      'tracking_number': 'TRK-PROOF-001',
      'status': 'delivered',
      'pod_delivered_at': '2026-10-16T10:30:00Z',
      'has_proof': true,
      'pod_photo_count': 3,
    });

    expect(parcel.hasProof, isTrue);
    expect(parcel.podPhotoCount, 3);
    expect(parcel.podDeliveredAt, isNotNull);
  });

  test('public tracking parcel can load proof without a database ID', () {
    final parcel = Parcel.fromJson({
      'tracking_number': 'TRK-PROOF-001',
      'status': 'delivered',
      'has_proof': true,
      'pod_photo_count': 1,
    });

    expect(parcel.id, 0);
    expect(parcel.trackingNumber, 'TRK-PROOF-001');
    expect(parcel.hasProof, isTrue);
  });

  test('parcel without proof remains compatible with existing responses', () {
    final parcel = Parcel.fromJson({
      'id': 43,
      'tracking_number': 'TRK-OLD-001',
      'status': 'in_transit',
    });

    expect(parcel.hasProof, isFalse);
    expect(parcel.podPhotoCount, 0);
    expect(parcel.podDeliveredAt, isNull);
  });
}
