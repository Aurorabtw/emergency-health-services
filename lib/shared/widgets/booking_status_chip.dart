import 'package:flutter/material.dart';

class BookingStatusChip extends StatelessWidget {
  final String status;

  const BookingStatusChip({super.key, required this.status});

  Color get _color {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'admitted':
        return Colors.green;
      case 'expired':
        return Colors.grey;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData get _icon {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'admitted':
        return Icons.check_circle;
      case 'expired':
        return Icons.timer_off;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String get _label {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'admitted':
        return 'Completed';
      case 'expired':
        return 'Expired';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(_icon, color: _color, size: 18),
      label: Text(_label, style: TextStyle(color: _color, fontWeight: FontWeight.w600)),
      backgroundColor: _color.withValues(alpha: 0.1),
      side: BorderSide(color: _color.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
