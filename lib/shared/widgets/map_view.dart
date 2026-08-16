import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

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
  String? _selectedMarkerId;

  ll.LatLng get _center {
    if (widget.centerLat != null && widget.centerLng != null) {
      return ll.LatLng(widget.centerLat!, widget.centerLng!);
    }
    if (widget.markers.isNotEmpty) {
      final avgLat = widget.markers.map((m) => m.latitude).reduce((a, b) => a + b) / widget.markers.length;
      final avgLng = widget.markers.map((m) => m.longitude).reduce((a, b) => a + b) / widget.markers.length;
      return ll.LatLng(avgLat, avgLng);
    }
    return const ll.LatLng(23.8103, 90.4125); // Dhaka default
  }

  double get _fitZoom {
    if (widget.markers.length <= 1) return widget.zoom;
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLng = double.infinity, maxLng = -double.infinity;
    for (final m in widget.markers) {
      minLat = min(minLat, m.latitude);
      maxLat = max(maxLat, m.latitude);
      minLng = min(minLng, m.longitude);
      maxLng = max(maxLng, m.longitude);
    }
    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final span = max(latSpan, lngSpan);
    if (span < 0.005) return 15;
    if (span < 0.02) return 14;
    if (span < 0.05) return 13;
    if (span < 0.1) return 12;
    if (span < 0.3) return 11;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.markers.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: _center,
                initialZoom: _fitZoom,
                onTap: (_, __) => setState(() => _selectedMarkerId = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.hospital_services.app',
                ),
                // User location dot
                if (widget.centerLat != null && widget.centerLng != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: ll.LatLng(widget.centerLat!, widget.centerLng!),
                        radius: 8,
                        color: Colors.blue.withValues(alpha: 0.3),
                        borderColor: Colors.blue,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: widget.markers.map((m) {
                    return Marker(
                      point: ll.LatLng(m.latitude, m.longitude),
                      width: 36,
                      height: 46,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMarkerId = _selectedMarkerId == m.id ? null : m.id;
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: m.markerColor,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: m.markerColor.withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${m.available}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, height: 1.2),
                              ),
                            ),
                            Icon(Icons.location_on, color: m.markerColor, size: 24),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            // Popup for selected marker
            if (_selectedMarkerId != null)
              ..._buildPopup(),
            // Legend
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
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
        ),
      ),
    );
  }

  List<Widget> _buildPopup() {
    final marker = widget.markers.where((m) => m.id == _selectedMarkerId).firstOrNull;
    if (marker == null) return [];

    return [
      Positioned(
        top: 8,
        left: 8,
        right: 8,
        child: Center(
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                marker.onTap?.call();
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 40,
                      decoration: BoxDecoration(
                        color: marker.markerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            marker.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (marker.snippet != null)
                            Text(
                              marker.snippet!,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            '${marker.available} available — Tap to book →',
                            style: TextStyle(fontSize: 11, color: marker.markerColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _selectedMarkerId = null),
                      child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ];
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
