import 'dart:js_interop';

import 'package:intl/intl.dart';
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;

import '../../models/booking_request_model.dart';

/// Opens a clean, print-friendly HTML receipt in a new window and triggers the
/// browser print dialog. Web-only (the app runs on the web). Bypasses Flutter's
/// canvas rendering so the printout is a proper document, not a screenshot.
void printBookingReceipt(BookingRequestModel booking) {
  final win = web.window.open('', '_blank', 'width=840,height=920');
  if (win == null) return; // popup blocked by the browser
  win.document.open();
  win.document.write(_receiptHtml(booking).toJS);
  win.document.close();
  win.focus();
  win.print();
}

String _receiptHtml(BookingRequestModel b) {
  final dateFmt = DateFormat('EEE, d MMM yyyy • h:mm a');
  final rows = <List<String>>[
    ['Receipt ID', b.id],
    ['Type', _typeLabel(b.type)],
    ['Status', _titleCase(b.status)],
    ['Organization', b.organizationName ?? '—'],
    ['Patient Name', b.patientName],
    ['Contact', b.contactNumber],
  ];
  switch (b.type) {
    case 'bed':
      rows.add(['Bed Type', b.bedType ?? '—']);
      break;
    case 'blood':
      rows.add(['Blood Type', b.bloodType ?? '—']);
      rows.add(['Units Needed', '${b.unitsNeeded ?? '—'}']);
      if (b.hospitalName != null) {
        rows.add(['Hospital Where Needed', b.hospitalName!]);
      }
      if (b.prescribingDoctor != null) {
        rows.add(['Prescribing Doctor', b.prescribingDoctor!]);
      }
      break;
    case 'ambulance':
      rows.add(['Ambulance Type', b.ambulanceType ?? '—']);
      if (b.pickupAddress != null) rows.add(['Pickup', b.pickupAddress!]);
      if (b.destinationAddress != null) {
        rows.add(['Destination', b.destinationAddress!]);
      }
      break;
    case 'test':
      rows.add(['Test', b.testName ?? '—']);
      if (b.serialNumber != null) rows.add(['Serial Number', '#${b.serialNumber}']);
      if (b.estimatedArrivalTime != null) {
        rows.add(['Estimated Arrival', dateFmt.format(b.estimatedArrivalTime!)]);
      }
      break;
  }
  rows.add(['Created', dateFmt.format(b.createdAt)]);
  if (b.estimatedPrice != null) {
    rows.add(['Estimated Price', '৳${b.estimatedPrice!.toStringAsFixed(0)}']);
  }

  final rowsHtml = rows
      .map(
        (r) =>
            '<tr><td class="k">${_esc(r[0])}</td><td class="v">${_esc(r[1])}</td></tr>',
      )
      .join();

  return '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Receipt — ${_esc(b.id)}</title>
<style>
  * { box-sizing: border-box; }
  body { font-family: -apple-system, "Segoe UI", Roboto, Arial, sans-serif; color: #1f2937; margin: 0; padding: 32px; }
  .receipt { max-width: 640px; margin: 0 auto; border: 1px solid #e5e7eb; border-radius: 14px; padding: 32px; }
  .brand { display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid #2563eb; padding-bottom: 16px; margin-bottom: 20px; }
  .brand h1 { font-size: 20px; margin: 0; color: #111827; }
  .brand .sub { color: #6b7280; font-size: 13px; margin-top: 2px; }
  .badge { background: #eff6ff; color: #2563eb; font-weight: 700; font-size: 12px; padding: 6px 12px; border-radius: 999px; text-transform: uppercase; }
  table { width: 100%; border-collapse: collapse; }
  td { padding: 10px 0; vertical-align: top; border-bottom: 1px solid #f3f4f6; }
  td.k { color: #6b7280; font-size: 13px; width: 42%; }
  td.v { font-weight: 600; font-size: 14px; text-align: right; }
  .foot { margin-top: 24px; color: #9ca3af; font-size: 12px; text-align: center; }
  @media print { body { padding: 0; } .receipt { border: none; } }
</style>
</head>
<body>
  <div class="receipt">
    <div class="brand">
      <div>
        <h1>Emergency Healthcare</h1>
        <div class="sub">Booking Receipt</div>
      </div>
      <div class="badge">${_esc(_typeLabel(b.type))}</div>
    </div>
    <table>$rowsHtml</table>
    <div class="foot">This is a system-generated receipt. Please keep it for your records.</div>
  </div>
</body>
</html>
''';
}

String _typeLabel(String type) {
  switch (type) {
    case 'bed':
      return 'Bed Booking';
    case 'blood':
      return 'Blood Request';
    case 'ambulance':
      return 'Ambulance Booking';
    case 'test':
      return 'Diagnostic Test';
    default:
      return type;
  }
}

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
