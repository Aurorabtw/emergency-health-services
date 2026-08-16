import 'package:cloud_firestore/cloud_firestore.dart';

class SeedDataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> hasData() async {
    final snapshot = await _db.collection('organizations').limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> seedAll() async {
    final batch = _db.batch();

    final hospitals = _hospitalData();
    final bloodBanks = _bloodBankData();
    final ambulanceOps = _ambulanceOperatorData();

    for (final org in [...hospitals, ...bloodBanks, ...ambulanceOps]) {
      final orgRef = _db.collection('organizations').doc(org['id'] as String);
      final subcollections = org.remove('_subcollections') as Map<String, List<Map<String, dynamic>>>;
      org['archived'] = false;
      org['archived_at'] = null;
      org['archived_by'] = null;
      batch.set(orgRef, org);

      for (final entry in subcollections.entries) {
        for (final item in entry.value) {
          final legacyId = item.remove('_id') as String;
          final docId = switch (entry.key) {
            'beds' => _bedDocumentId(item['type'] as String),
            'blood_stock' => _bloodDocumentId(item['blood_type'] as String),
            _ => legacyId,
          };
          final subRef = orgRef.collection(entry.key).doc(docId);
          batch.set(subRef, item);
        }
      }
    }

    await batch.commit();
  }

  String _bedDocumentId(String type) => switch (type) {
    'General' => 'general',
    'ICU' => 'icu',
    'NICU' => 'nicu',
    _ => throw ArgumentError('Unsupported bed type.'),
  };

  String _bloodDocumentId(String type) => switch (type) {
    'A+' => 'a_positive',
    'A-' => 'a_negative',
    'B+' => 'b_positive',
    'B-' => 'b_negative',
    'AB+' => 'ab_positive',
    'AB-' => 'ab_negative',
    'O+' => 'o_positive',
    'O-' => 'o_negative',
    _ => throw ArgumentError('Unsupported blood type.'),
  };

  List<Map<String, dynamic>> _hospitalData() {
    final now = Timestamp.now();
    return [
      {
        'id': 'hospital_1',
        'type': 'hospital',
        'name': 'Dhaka Medical College Hospital',
        'address': 'Secretariat Rd, Dhaka 1000',
        'latitude': 23.7260,
        'longitude': 90.3976,
        'phone': '+880-2-55165001',
        'email': 'info@dmch.gov.bd',
        'verified': true,
        'created_at': now,
        'updated_at': now,
        '_subcollections': <String, List<Map<String, dynamic>>>{
          'beds': [
            {'_id': 'bed_gen_1', 'type': 'General', 'total_beds': 50, 'held_beds': 3, 'admitted_beds': 35, 'price_per_day': 500.0, 'hold_duration_minutes': 30},
            {'_id': 'bed_icu_1', 'type': 'ICU', 'total_beds': 15, 'held_beds': 1, 'admitted_beds': 10, 'price_per_day': 3000.0, 'hold_duration_minutes': 30},
            {'_id': 'bed_nicu_1', 'type': 'NICU', 'total_beds': 8, 'held_beds': 0, 'admitted_beds': 5, 'price_per_day': 4000.0, 'hold_duration_minutes': 30},
          ],
          'tests': [
            {'_id': 'test_1', 'test_name': 'CBC (Complete Blood Count)', 'price': 500.0, 'turnaround_time': '2 hours', 'home_collection': false},
            {'_id': 'test_2', 'test_name': 'X-Ray Chest', 'price': 800.0, 'turnaround_time': '1 hour', 'home_collection': false},
            {'_id': 'test_3', 'test_name': 'MRI Brain', 'price': 8000.0, 'turnaround_time': '24 hours', 'home_collection': false},
            {'_id': 'test_4', 'test_name': 'CT Scan Abdomen', 'price': 5000.0, 'turnaround_time': '4 hours', 'home_collection': false},
          ],
        },
      },
      {
        'id': 'hospital_2',
        'type': 'hospital',
        'name': 'Square Hospital',
        'address': '18/F Bir Uttam Qazi Nuruzzaman Sarak, Dhaka 1205',
        'latitude': 23.7525,
        'longitude': 90.3876,
        'phone': '+880-2-8159457',
        'email': 'info@squarehospital.com',
        'verified': true,
        'created_at': now,
        'updated_at': now,
        '_subcollections': <String, List<Map<String, dynamic>>>{
          'beds': [
            {'_id': 'bed_gen_2', 'type': 'General', 'total_beds': 30, 'held_beds': 2, 'admitted_beds': 18, 'price_per_day': 5000.0, 'hold_duration_minutes': 45},
            {'_id': 'bed_icu_2', 'type': 'ICU', 'total_beds': 20, 'held_beds': 0, 'admitted_beds': 12, 'price_per_day': 15000.0, 'hold_duration_minutes': 30},
            {'_id': 'bed_nicu_2', 'type': 'NICU', 'total_beds': 10, 'held_beds': 1, 'admitted_beds': 6, 'price_per_day': 18000.0, 'hold_duration_minutes': 30},
          ],
          'tests': [
            {'_id': 'test_5', 'test_name': 'CBC (Complete Blood Count)', 'price': 800.0, 'turnaround_time': '1 hour', 'home_collection': true, 'home_collection_surcharge': 200.0},
            {'_id': 'test_6', 'test_name': 'Lipid Profile', 'price': 1500.0, 'turnaround_time': '4 hours', 'home_collection': true, 'home_collection_surcharge': 200.0},
            {'_id': 'test_7', 'test_name': 'MRI Brain', 'price': 12000.0, 'turnaround_time': '6 hours', 'home_collection': false},
            {'_id': 'test_8', 'test_name': 'Echocardiogram', 'price': 4000.0, 'turnaround_time': '2 hours', 'home_collection': false},
            {'_id': 'test_9', 'test_name': 'Thyroid Panel', 'price': 2000.0, 'turnaround_time': '6 hours', 'home_collection': true, 'home_collection_surcharge': 200.0},
          ],
        },
      },
      {
        'id': 'hospital_3',
        'type': 'hospital',
        'name': 'United Hospital',
        'address': 'Plot 15, Rd 71, Gulshan, Dhaka 1212',
        'latitude': 23.7937,
        'longitude': 90.4150,
        'phone': '+880-2-8836000',
        'email': 'info@uhlbd.com',
        'verified': true,
        'created_at': now,
        'updated_at': now,
        '_subcollections': <String, List<Map<String, dynamic>>>{
          'beds': [
            {'_id': 'bed_gen_3', 'type': 'General', 'total_beds': 40, 'held_beds': 1, 'admitted_beds': 25, 'price_per_day': 4500.0, 'hold_duration_minutes': 30},
            {'_id': 'bed_icu_3', 'type': 'ICU', 'total_beds': 18, 'held_beds': 2, 'admitted_beds': 14, 'price_per_day': 12000.0, 'hold_duration_minutes': 30},
          ],
          'tests': [
            {'_id': 'test_10', 'test_name': 'Liver Function Test', 'price': 1800.0, 'turnaround_time': '4 hours', 'home_collection': true, 'home_collection_surcharge': 300.0},
            {'_id': 'test_11', 'test_name': 'Kidney Function Test', 'price': 1600.0, 'turnaround_time': '4 hours', 'home_collection': true, 'home_collection_surcharge': 300.0},
            {'_id': 'test_12', 'test_name': 'CT Scan Chest', 'price': 6000.0, 'turnaround_time': '3 hours', 'home_collection': false},
          ],
        },
      },
      {
        'id': 'hospital_4',
        'type': 'hospital',
        'name': 'Labaid Hospital',
        'address': 'House 1, Road 4, Dhanmondi, Dhaka 1205',
        'latitude': 23.7415,
        'longitude': 90.3755,
        'phone': '+880-2-9116551',
        'email': 'info@labaidgroup.com',
        'verified': true,
        'created_at': now,
        'updated_at': now,
        '_subcollections': <String, List<Map<String, dynamic>>>{
          'beds': [
            {'_id': 'bed_gen_4', 'type': 'General', 'total_beds': 25, 'held_beds': 0, 'admitted_beds': 15, 'price_per_day': 3500.0, 'hold_duration_minutes': 30},
            {'_id': 'bed_icu_4', 'type': 'ICU', 'total_beds': 10, 'held_beds': 1, 'admitted_beds': 7, 'price_per_day': 10000.0, 'hold_duration_minutes': 30},
          ],
          'tests': [
            {'_id': 'test_13', 'test_name': 'Blood Sugar (Fasting)', 'price': 300.0, 'turnaround_time': '1 hour', 'home_collection': true, 'home_collection_surcharge': 150.0},
            {'_id': 'test_14', 'test_name': 'HbA1c', 'price': 1200.0, 'turnaround_time': '4 hours', 'home_collection': true, 'home_collection_surcharge': 150.0},
            {'_id': 'test_15', 'test_name': 'Ultrasound Abdomen', 'price': 2500.0, 'turnaround_time': '1 hour', 'home_collection': false},
          ],
        },
      },
    ];
  }

  List<Map<String, dynamic>> _bloodBankData() {
    final now = Timestamp.now();
    return [
      {
        'id': 'blood_bank_1',
        'type': 'blood_bank',
        'name': 'Sandhani Blood Bank',
        'address': 'Dhaka Medical College Campus, Dhaka 1000',
        'latitude': 23.7255,
        'longitude': 90.3965,
        'phone': '+880-2-8626812',
        'email': 'sandhani@dhaka.org',
        'verified': true,
        'created_at': now,
        'updated_at': now,
        '_subcollections': <String, List<Map<String, dynamic>>>{
          'blood_stock': [
            {'_id': 'bs_ap', 'blood_type': 'A+', 'total_units': 25, 'held_units': 2, 'issued_units': 5, 'processing_fee_per_unit': 0.0, 'last_updated': now},
            {'_id': 'bs_an', 'blood_type': 'A-', 'total_units': 8, 'held_units': 0, 'issued_units': 1, 'processing_fee_per_unit': 0.0, 'last_updated': now},
            {'_id': 'bs_bp', 'blood_type': 'B+', 'total_units': 30, 'held_units': 3, 'issued_units': 8, 'processing_fee_per_unit': 0.0, 'last_updated': now},
            {'_id': 'bs_bn', 'blood_type': 'B-', 'total_units': 5, 'held_units': 0, 'issued_units': 0, 'processing_fee_per_unit': 0.0, 'last_updated': now},
            {'_id': 'bs_abp', 'blood_type': 'AB+', 'total_units': 10, 'held_units': 1, 'issued_units': 2, 'processing_fee_per_unit': 0.0, 'last_updated': now},
            {'_id': 'bs_abn', 'blood_type': 'AB-', 'total_units': 3, 'held_units': 0, 'issued_units': 0, 'processing_fee_per_unit': 0.0, 'last_updated': now},
            {'_id': 'bs_op', 'blood_type': 'O+', 'total_units': 35, 'held_units': 4, 'issued_units': 10, 'processing_fee_per_unit': 0.0, 'last_updated': now},
            {'_id': 'bs_on', 'blood_type': 'O-', 'total_units': 6, 'held_units': 0, 'issued_units': 1, 'processing_fee_per_unit': 0.0, 'last_updated': now},
          ],
        },
      },
      {
        'id': 'blood_bank_2',
        'type': 'blood_bank',
        'name': 'Bangladesh Red Crescent Blood Centre',
        'address': '7/5 Aurangzeb Road, Mohammadpur, Dhaka 1207',
        'latitude': 23.7650,
        'longitude': 90.3590,
        'phone': '+880-2-9116563',
        'email': 'info@redcrescent.org.bd',
        'verified': true,
        'created_at': now,
        'updated_at': now,
        '_subcollections': <String, List<Map<String, dynamic>>>{
          'blood_stock': [
            {'_id': 'bs_ap2', 'blood_type': 'A+', 'total_units': 40, 'held_units': 5, 'issued_units': 12, 'processing_fee_per_unit': 500.0, 'last_updated': now},
            {'_id': 'bs_an2', 'blood_type': 'A-', 'total_units': 12, 'held_units': 1, 'issued_units': 3, 'processing_fee_per_unit': 500.0, 'last_updated': now},
            {'_id': 'bs_bp2', 'blood_type': 'B+', 'total_units': 45, 'held_units': 6, 'issued_units': 15, 'processing_fee_per_unit': 500.0, 'last_updated': now},
            {'_id': 'bs_bn2', 'blood_type': 'B-', 'total_units': 8, 'held_units': 0, 'issued_units': 2, 'processing_fee_per_unit': 500.0, 'last_updated': now},
            {'_id': 'bs_abp2', 'blood_type': 'AB+', 'total_units': 15, 'held_units': 2, 'issued_units': 4, 'processing_fee_per_unit': 500.0, 'last_updated': now},
            {'_id': 'bs_abn2', 'blood_type': 'AB-', 'total_units': 5, 'held_units': 0, 'issued_units': 1, 'processing_fee_per_unit': 500.0, 'last_updated': now},
            {'_id': 'bs_op2', 'blood_type': 'O+', 'total_units': 50, 'held_units': 7, 'issued_units': 18, 'processing_fee_per_unit': 500.0, 'last_updated': now},
            {'_id': 'bs_on2', 'blood_type': 'O-', 'total_units': 10, 'held_units': 1, 'issued_units': 2, 'processing_fee_per_unit': 500.0, 'last_updated': now},
          ],
        },
      },
    ];
  }

  List<Map<String, dynamic>> _ambulanceOperatorData() {
    final now = Timestamp.now();
    return [
      {
        'id': 'ambulance_1',
        'type': 'ambulance_operator',
        'name': 'Dhaka Ambulance Service',
        'address': 'Mirpur Road, Dhaka 1216',
        'latitude': 23.7590,
        'longitude': 90.3710,
        'phone': '+880-1711-999999',
        'email': 'dispatch@dhakaambulance.com',
        'verified': true,
        'created_at': now,
        'updated_at': now,
        '_subcollections': <String, List<Map<String, dynamic>>>{
          'ambulances': [
            {'_id': 'amb_1', 'type': 'Basic', 'status': 'available', 'base_fare': 1500.0, 'per_km_rate': 30.0},
            {'_id': 'amb_2', 'type': 'Basic', 'status': 'available', 'base_fare': 1500.0, 'per_km_rate': 30.0},
            {'_id': 'amb_3', 'type': 'AC', 'status': 'available', 'base_fare': 3000.0, 'per_km_rate': 50.0},
            {'_id': 'amb_4', 'type': 'ICU', 'status': 'busy', 'base_fare': 8000.0, 'per_km_rate': 80.0},
          ],
        },
      },
      {
        'id': 'ambulance_2',
        'type': 'ambulance_operator',
        'name': 'Emergency Rescue BD',
        'address': 'Gulshan-2, Dhaka 1212',
        'latitude': 23.7940,
        'longitude': 90.4140,
        'phone': '+880-1811-888888',
        'email': 'help@emergencyrescuebd.com',
        'verified': true,
        'created_at': now,
        'updated_at': now,
        '_subcollections': <String, List<Map<String, dynamic>>>{
          'ambulances': [
            {'_id': 'amb_5', 'type': 'Basic', 'status': 'available', 'base_fare': 1200.0, 'per_km_rate': 25.0},
            {'_id': 'amb_6', 'type': 'AC', 'status': 'available', 'base_fare': 2500.0, 'per_km_rate': 45.0},
            {'_id': 'amb_7', 'type': 'ICU', 'status': 'available', 'base_fare': 7000.0, 'per_km_rate': 75.0},
          ],
        },
      },
      {
        'id': 'ambulance_3',
        'type': 'ambulance_operator',
        'name': 'LifeLine Ambulance',
        'address': 'Uttara Sector 7, Dhaka 1230',
        'latitude': 23.8700,
        'longitude': 90.3990,
        'phone': '+880-1911-777777',
        'email': 'info@lifelinebd.com',
        'verified': true,
        'created_at': now,
        'updated_at': now,
        '_subcollections': <String, List<Map<String, dynamic>>>{
          'ambulances': [
            {'_id': 'amb_8', 'type': 'Basic', 'status': 'available', 'base_fare': 1000.0, 'per_km_rate': 20.0},
            {'_id': 'amb_9', 'type': 'AC', 'status': 'busy', 'base_fare': 2000.0, 'per_km_rate': 40.0},
            {'_id': 'amb_10', 'type': 'ICU', 'status': 'available', 'base_fare': 6500.0, 'per_km_rate': 70.0},
          ],
        },
      },
    ];
  }
}
