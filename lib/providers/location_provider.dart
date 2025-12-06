import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';

class LocationState {
  final bool isLoading;
  final bool isInitialized;
  final String? error;
  final String? address;
  final String? formattedCoordinates;

  const LocationState({
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
    this.address,
    this.formattedCoordinates,
  });

  LocationState copyWith({
    bool? isLoading,
    bool? isInitialized,
    String? error,
    String? address,
    String? formattedCoordinates,
  }) {
    return LocationState(
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error ?? this.error,
      address: address ?? this.address,
      formattedCoordinates: formattedCoordinates ?? this.formattedCoordinates,
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  final LocationService locationService;
  LocationNotifier(this.locationService) : super(const LocationState()) {
    initLocation();
  }

  static final provider =
      StateNotifierProvider<LocationNotifier, LocationState>(
        (ref) => LocationNotifier(LocationService()),
      );

  Future<void> initLocation() async {
    state = state.copyWith(isLoading: true);
    try {
      final success = await locationService.getCurrentLocation();
      if (success) {
        state = state.copyWith(
          isInitialized: true,
          isLoading: false,
          address: locationService.currentAddress,
          formattedCoordinates: locationService.getFormattedCoordinates(),
        );
      } else {
        state = state.copyWith(
          isInitialized: false,
          isLoading: false,
          error: 'Location services unavailable',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isInitialized: false,
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}
