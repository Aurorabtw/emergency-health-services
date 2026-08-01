import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  BitmapDescriptor get markerColor {
    if (available <= 0) return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    if (available <= 4) return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  }
}

class SharedMapView extends StatefulWidget {
  final List<MapMarker> markers;
  final double? centerLat;
  final double? centerLng;
  final double zoom;
  final double height;
  final void Function(GoogleMapController)? onMapCreated;

  const SharedMapView({
    super.key,
    required this.markers,
    this.centerLat,
    this.centerLng,
    this.zoom = 12,
    this.height = 300,
    this.onMapCreated,
  });

  @override
  State<SharedMapView> createState() => _SharedMapViewState();
}

class _SharedMapViewState extends State<SharedMapView> {
  Set<Marker> get _googleMarkers {
    return widget.markers.map((m) {
      return Marker(
        markerId: MarkerId(m.id),
        position: LatLng(m.latitude, m.longitude),
        icon: m.markerColor,
        infoWindow: InfoWindow(
          title: m.title,
          snippet: m.snippet,
        ),
        onTap: m.onTap,
      );
    }).toSet();
  }

  LatLng get _center {
    if (widget.centerLat != null && widget.centerLng != null) {
      return LatLng(widget.centerLat!, widget.centerLng!);
    }
    if (widget.markers.isNotEmpty) {
      final avgLat = widget.markers.map((m) => m.latitude).reduce((a, b) => a + b) / widget.markers.length;
      final avgLng = widget.markers.map((m) => m.longitude).reduce((a, b) => a + b) / widget.markers.length;
      return LatLng(avgLat, avgLng);
    }
    return const LatLng(23.8103, 90.4125); // Dhaka default
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: _center, zoom: widget.zoom),
          markers: _googleMarkers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          onMapCreated: widget.onMapCreated,
        ),
      ),
    );
  }
}
