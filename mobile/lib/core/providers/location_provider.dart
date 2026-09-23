import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:resqconnect/core/logger/app_logger.dart';

enum LocationStatus { initial, requesting, located, permissionDenied, serviceDisabled, error }

class LocationState {
  final LocationStatus status;
  final double latitude;
  final double longitude;
  final String addressName;
  final String? errorMessage;

  const LocationState({
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.addressName,
    this.errorMessage,
  });

  factory LocationState.initial() => const LocationState(
        status: LocationStatus.initial,
        latitude: 12.9716, // Default fallback coordinates
        longitude: 77.5946,
        addressName: 'Sector 4, Metro Valley',
      );

  LocationState copyWith({
    LocationStatus? status,
    double? latitude,
    double? longitude,
    String? addressName,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LocationState(
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      addressName: addressName ?? this.addressName,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(LocationState.initial()) {
    fetchCurrentLocation();
  }

  Future<void> fetchCurrentLocation() async {
    state = state.copyWith(status: LocationStatus.requesting, clearError: true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('Location services disabled on device');
        state = state.copyWith(
          status: LocationStatus.serviceDisabled,
          errorMessage: 'Location services are disabled on your device. Please turn on GPS.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            status: LocationStatus.permissionDenied,
            errorMessage: 'Location permission was denied.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          status: LocationStatus.permissionDenied,
          errorMessage: 'Location permission is permanently denied. Please enable it in Settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      state = state.copyWith(
        status: LocationStatus.located,
        latitude: position.latitude,
        longitude: position.longitude,
        addressName: 'Sector 4, Metro Valley (${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)})',
        clearError: true,
      );
      debugPrint('[DEBUG_LOCATION] GPS Location obtained: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      AppLogger.warning('Failed to fetch GPS location: $e');
      state = state.copyWith(
        status: LocationStatus.error,
        errorMessage: 'Unable to retrieve location. Using default location.',
      );
    }
  }

  void retry() {
    fetchCurrentLocation();
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier();
});
