import 'package:flutter/material.dart';

class AvailabilityBadge extends StatelessWidget {
  final int available;
  final String? label;

  const AvailabilityBadge({
    super.key,
    required this.available,
    this.label,
  });

  Color get _color {
    if (available <= 0) return Colors.red;
    if (available <= 4) return Colors.orange;
    return Colors.green;
  }

  String get _text {
    if (available <= 0) return 'Full';
    final suffix = label ?? 'available';
    return '$available $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _text,
            style: TextStyle(
              color: _color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
