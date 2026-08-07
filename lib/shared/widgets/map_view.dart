import 'dart:math';

import 'package:flutter/material.dart';

class MapMarker {
  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String? snippet;
  final int available;
  final VoidCallback? onTap;

  MapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
    this.snippet,
    this.available = 0,
    this.onTap,
  });

  Color get markerColor {
    if (available <= 0) return Colors.red;
    if (available <= 4) return Colors.orange;
    return Colors.green;
  }
}

class SharedMapView extends StatefulWidget {
  final List<MapMarker> markers;
  final double? centerLat;
  final double? centerLng;
  final double zoom;
  final double height;

  const SharedMapView({
    super.key,
    required this.markers,
    this.centerLat,
    this.centerLng,
    this.zoom = 12,
    this.height = 300,
  });

  @override
  State<SharedMapView> createState() => _SharedMapViewState();
}

class _SharedMapViewState extends State<SharedMapView> {
  int? _hoveredIndex;
  int? _selectedIndex;

  /// Compute center from explicit values, marker average, or Dhaka default.
  ({double lat, double lng}) get _center {
    if (widget.centerLat != null && widget.centerLng != null) {
      return (lat: widget.centerLat!, lng: widget.centerLng!);
    }
    if (widget.markers.isNotEmpty) {
      final avgLat = widget.markers.map((m) => m.latitude).reduce((a, b) => a + b) / widget.markers.length;
      final avgLng = widget.markers.map((m) => m.longitude).reduce((a, b) => a + b) / widget.markers.length;
      return (lat: avgLat, lng: avgLng);
    }
    return (lat: 23.8103, lng: 90.4125); // Dhaka default
  }

  /// Convert lat/lng to pixel position within the given size.
  Offset _toPixel(double lat, double lng, Size size, double cLat, double cLng, double spanLat, double spanLng) {
    final x = ((lng - cLng) / spanLng + 0.5) * size.width;
    final y = ((cLat - lat) / spanLat + 0.5) * size.height;
    return Offset(x.clamp(20, size.width - 20), y.clamp(20, size.height - 20));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.markers.isEmpty) return const SizedBox.shrink();

    final center = _center;

    // Compute span to fit all markers with padding
    double minLat = center.lat, maxLat = center.lat;
    double minLng = center.lng, maxLng = center.lng;
    for (final m in widget.markers) {
      minLat = min(minLat, m.latitude);
      maxLat = max(maxLat, m.latitude);
      minLng = min(minLng, m.longitude);
      maxLng = max(maxLng, m.longitude);
    }
    // Add 30% padding, minimum span of 0.01 degrees (~1 km)
    final spanLat = max((maxLat - minLat) * 1.6, 0.01);
    final spanLng = max((maxLng - minLng) * 1.6, 0.01);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, widget.height);
            final positions = widget.markers.map((m) {
              return _toPixel(m.latitude, m.longitude, size, center.lat, center.lng, spanLat, spanLng);
            }).toList();

            return Stack(
              children: [
                // Background — grid pattern to suggest a map
                CustomPaint(
                  size: size,
                  painter: _MapBackgroundPainter(isDark: isDark),
                ),
                // Markers
                for (int i = 0; i < widget.markers.length; i++)
                  Positioned(
                    left: positions[i].dx - 16,
                    top: positions[i].dy - 36,
                    child: _MarkerWidget(
                      marker: widget.markers[i],
                      isHovered: _hoveredIndex == i,
                      isSelected: _selectedIndex == i,
                      onHover: (hovered) => setState(() => _hoveredIndex = hovered ? i : null),
                      onTap: () {
                        setState(() => _selectedIndex = _selectedIndex == i ? null : i);
                        widget.markers[i].onTap?.call();
                      },
                    ),
                  ),
                // Tooltip for selected marker
                if (_selectedIndex != null && _selectedIndex! < widget.markers.length)
                  _buildTooltip(positions[_selectedIndex!], widget.markers[_selectedIndex!], size),
                // Legend
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.grey.shade800 : Colors.white).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _legendDot(Colors.green, '>5'),
                        const SizedBox(width: 8),
                        _legendDot(Colors.orange, '1-4'),
                        const SizedBox(width: 8),
                        _legendDot(Colors.red, '0'),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTooltip(Offset pos, MapMarker marker, Size size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Position tooltip so it stays on-screen
    double left = pos.dx - 80;
    if (left < 8) left = 8;
    if (left + 160 > size.width - 8) left = size.width - 168;
    double top = pos.dy - 80;
    if (top < 8) top = pos.dy + 10;

    return Positioned(
      left: left,
      top: top,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: isDark ? Colors.grey.shade800 : Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: marker.onTap,
          child: Container(
            width: 180,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  marker.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (marker.snippet != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      marker.snippet!,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: marker.markerColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${marker.available} available',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: marker.markerColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Tap to view →', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _MarkerWidget extends StatelessWidget {
  final MapMarker marker;
  final bool isHovered;
  final bool isSelected;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  const _MarkerWidget({
    required this.marker,
    required this.isHovered,
    required this.isSelected,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scale = (isHovered || isSelected) ? 1.2 : 1.0;
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: marker.markerColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: marker.markerColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${marker.available}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              CustomPaint(
                size: const Size(12, 8),
                painter: _TrianglePainter(color: marker.markerColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapBackgroundPainter extends CustomPainter {
  final bool isDark;
  _MapBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Base fill
    final basePaint = Paint()
      ..color = isDark ? const Color(0xFF2A2D35) : const Color(0xFFE8EAF0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // Grid lines to suggest streets
    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF353840) : const Color(0xFFD5D9E2)
      ..strokeWidth = 1;

    const spacing = 40.0;
    // Horizontal
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // Vertical
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // A few "road" lines (thicker diagonals)
    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF404550) : const Color(0xFFCDD1DA)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.7), roadPaint);
    canvas.drawLine(Offset(size.width * 0.2, 0), Offset(size.width * 0.8, size.height), roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
