import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();

  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;

  /// Cached road distances: orgId → distance in km.
  final Map<String, double> _roadDistances = {};
  bool _roadDistancesLoaded = false;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLocation => _currentPosition != null;
  bool get hasRoadDistances => _roadDistancesLoaded;

  double? get latitude => _currentPosition?.latitude;
  double? get longitude => _currentPosition?.longitude;

  Future<void> getCurrentLocation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentPosition = await _locationService.getCurrentPosition();
      if (_currentPosition == null) {
        _error = 'Unable to get location. Please enable location services.';
      }
    } catch (e) {
      _error = 'Failed to get location: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch real road distances from user's location to all destinations in one API call.
  /// Call this after getting user location and loading organizations.
  Future<void> fetchRoadDistances(List<({double lat, double lng, String id})> destinations) async {
    if (_currentPosition == null || destinations.isEmpty) return;

    final results = await _locationService.getRoadDistances(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      destinations,
    );

    if (results.isNotEmpty) {
      _roadDistances.addAll(results);
      _roadDistancesLoaded = true;
      notifyListeners();
    }
  }

  /// Get the road distance for a specific org. Returns null if not fetched yet.
  double? roadDistanceTo(String orgId) {
    return _roadDistances[orgId];
  }

  /// Get the best available distance: road distance if available, otherwise straight-line.
  double? distanceTo(double lat, double lng, {String? orgId}) {
    // Prefer road distance if we have it for this org
    if (orgId != null && _roadDistances.containsKey(orgId)) {
      return _roadDistances[orgId];
    }
    // Fall back to straight-line
    if (_currentPosition == null) return null;
    return _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
  }

  /// Legacy straight-line only distance (for backward compatibility).
  double? straightLineDistanceTo(double lat, double lng) {
    if (_currentPosition == null) return null;
    return _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
  }

  String formatDistance(double distanceKm) {
    return _locationService.formatDistance(distanceKm);
  }
}
