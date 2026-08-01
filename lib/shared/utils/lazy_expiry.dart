import '../../models/booking_request_model.dart';
import '../../services/firestore_service.dart';

class LazyExpiry {
  static Future<BookingRequestModel> checkAndExpire(
    BookingRequestModel booking,
    FirestoreService firestoreService,
  ) async {
    if (!booking.isConfirmed || booking.heldUntil == null) return booking;
    if (!DateTime.now().isAfter(booking.heldUntil!)) return booking;

    try {
      await firestoreService.updateDocument('booking_requests/${booking.id}', {
        'status': 'expired',
      });

      String? resourcePath;
      String? heldField;

      if (booking.type == 'bed') {
        resourcePath = 'organizations/${booking.organizationId}/beds/${booking.bedType}';
        heldField = 'held_beds';
      } else if (booking.type == 'blood') {
        resourcePath = 'organizations/${booking.organizationId}/blood_stock/${booking.bloodType}';
        heldField = 'held_units';
      } else if (booking.type == 'ambulance') {
        heldField = 'held_vehicles';
      }

      if (resourcePath != null && heldField != null) {
        final doc = await firestoreService.getDocument(resourcePath);
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final currentHeld = data[heldField] ?? 0;
          if (currentHeld > 0) {
            await firestoreService.updateDocument(resourcePath, {
              heldField: currentHeld - 1,
            });
          }
        }
      }

      return booking.copyWith(status: 'expired');
    } catch (e) {
      return booking;
    }
  }
}
