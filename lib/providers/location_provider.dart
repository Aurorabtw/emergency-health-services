import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();

  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLocation => _currentPosition != null;

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

  double? distanceTo(double lat, double lng) {
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
