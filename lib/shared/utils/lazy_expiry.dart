import 'package:cloud_firestore/cloud_firestore.dart';

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
      final resourceId = switch (booking.type) {
        'bed' => booking.bedId,
        'blood' => booking.bloodStockId,
        'ambulance' => booking.ambulanceId,
        _ => null,
      };
      if (resourceId == null) return booking;

      final collection = switch (booking.type) {
        'bed' => 'beds',
        'blood' => 'blood_stock',
        'ambulance' => 'ambulances',
        _ => null,
      };
      if (collection == null) return booking;

      var expired = false;
      await firestoreService.runTransaction((transaction) async {
        expired = false;
        final bookingDoc = firestoreService.db.doc(
          'booking_requests/${booking.id}',
        );
        final resourceDoc = firestoreService.db.doc(
          'organizations/${booking.organizationId}/$collection/$resourceId',
        );
        final bookingSnapshot = await transaction.get(bookingDoc);
        final resourceSnapshot = await transaction.get(resourceDoc);
        if (!bookingSnapshot.exists || !resourceSnapshot.exists) return;

        final bookingData = bookingSnapshot.data() as Map<String, dynamic>;
        final resourceData = resourceSnapshot.data() as Map<String, dynamic>;
        final heldUntil = bookingData['held_until'] as Timestamp?;
        if (bookingData['status'] != 'confirmed' ||
            bookingData['type'] != booking.type ||
            bookingData['organization_id'] != booking.organizationId ||
            heldUntil == null ||
            heldUntil.toDate().isAfter(DateTime.now())) {
          return;
        }

        final bookingUpdates = <String, dynamic>{'status': 'expired'};
        final resourceUpdates = <String, dynamic>{
          'last_expired_booking_id': booking.id,
        };

        if (booking.type == 'bed') {
          final storedId = bookingData['bed_id'] as String?;
          final currentHeld = resourceData['held_beds'] as int?;
          if ((storedId != null && storedId != resourceId) ||
              bookingData['bed_type'] != resourceData['type'] ||
              currentHeld == null ||
              currentHeld < 1) {
            return;
          }
          bookingUpdates['bed_id'] = resourceId;
          resourceUpdates['held_beds'] = currentHeld - 1;
        } else if (booking.type == 'blood') {
          final storedId = bookingData['blood_stock_id'] as String?;
          final units = bookingData['units_needed'] as int?;
          final currentHeld = resourceData['held_units'] as int?;
          if ((storedId != null && storedId != resourceId) ||
              bookingData['blood_type'] != resourceData['blood_type'] ||
              units == null ||
              units <= 0 ||
              currentHeld == null ||
              currentHeld < units) {
            return;
          }
          bookingUpdates['blood_stock_id'] = resourceId;
          resourceUpdates['held_units'] = currentHeld - units;
        } else if (booking.type == 'ambulance') {
          if (bookingData['ambulance_id'] != resourceId ||
              bookingData['ambulance_type'] != resourceData['type'] ||
              resourceData['status'] != 'busy') {
            return;
          }
          resourceUpdates['status'] = 'available';
        }

        transaction.update(resourceDoc, resourceUpdates);
        transaction.update(bookingDoc, bookingUpdates);
        expired = true;
      });

      if (!expired) return booking;
      return booking.copyWith(
        status: 'expired',
        bedId: booking.type == 'bed' ? resourceId : booking.bedId,
        bloodStockId: booking.type == 'blood'
            ? resourceId
            : booking.bloodStockId,
      );
    } catch (_) {
      return booking;
    }
  }
}
