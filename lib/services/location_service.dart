import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  /// Cache road distances to avoid repeated API calls.
  /// Key: "lat1,lng1→lat2,lng2", Value: distance in km.
  final Map<String, double> _roadDistanceCache = {};

  /// Best-effort current position. Returns null (never hangs) if location
  /// is unavailable, denied, or slow — callers fall back to no-distance mode.
  ///
  /// Every await is guarded by a timeout: on the web, a denied/ignored
  /// permission prompt or a stalled fix can otherwise block forever, which
  /// would freeze any screen that awaits location before loading its data.
  Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 4), onTimeout: () => false);
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 4), onTimeout: () => LocationPermission.denied);
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission()
            .timeout(const Duration(seconds: 8), onTimeout: () => LocationPermission.denied);
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      // Any timeout or platform error → proceed without a location.
      return null;
    }
  }

  /// Straight-line distance using the Haversine formula (fallback).
  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  /// Actual road distance via OSRM (free, no API key).
  /// Returns distance in km, or null if the API call fails.
  Future<double?> getRoadDistance(double lat1, double lng1, double lat2, double lng2) async {
    final cacheKey = '${lat1.toStringAsFixed(5)},${lng1.toStringAsFixed(5)}→${lat2.toStringAsFixed(5)},${lng2.toStringAsFixed(5)}';
    if (_roadDistanceCache.containsKey(cacheKey)) {
      return _roadDistanceCache[cacheKey];
    }

    try {
      // OSRM uses lng,lat order (not lat,lng)
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$lng1,$lat1;$lng2,$lat2?overview=false',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok') {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final distanceMeters = (routes[0]['distance'] as num).toDouble();
            final distanceKm = distanceMeters / 1000;
            _roadDistanceCache[cacheKey] = distanceKm;
            return distanceKm;
          }
        }
      }
    } catch (_) {
      // Silently fall back to straight-line distance
    }
    return null;
  }

  /// Batch fetch road distances for multiple destinations from a single origin.
  /// Returns a map of "lat,lng" → distance in km.
  Future<Map<String, double>> getRoadDistances(
    double originLat,
    double originLng,
    List<({double lat, double lng, String id})> destinations,
  ) async {
    final results = <String, double>{};

    // OSRM Table API: one origin → many destinations in a single request
    if (destinations.isEmpty) return results;

    try {
      // Build coordinates string: origin first, then all destinations
      final coords = StringBuffer('$originLng,$originLat');
      for (final dest in destinations) {
        coords.write(';${dest.lng},${dest.lat}');
      }

      final uri = Uri.parse(
        'https://router.project-osrm.org/table/v1/driving/$coords?sources=0&annotations=distance',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok') {
          final distances = data['distances'] as List;
          if (distances.isNotEmpty) {
            final row = distances[0] as List;
            // row[0] is origin→origin (0), rest are origin→dest[i-1]
            for (int i = 1; i < row.length && i <= destinations.length; i++) {
              final distMeters = (row[i] as num).toDouble();
              final distKm = distMeters / 1000;
              results[destinations[i - 1].id] = distKm;

              // Also cache individual pairs
              final dest = destinations[i - 1];
              final cacheKey =
                  '${originLat.toStringAsFixed(5)},${originLng.toStringAsFixed(5)}→${dest.lat.toStringAsFixed(5)},${dest.lng.toStringAsFixed(5)}';
              _roadDistanceCache[cacheKey] = distKm;
            }
          }
        }
      }
    } catch (_) {
      // Fall back silently — callers will use straight-line distances
    }

    return results;
  }

  String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}
