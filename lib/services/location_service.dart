import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  Position? currentPosition;
  String? currentAddress;
  bool isLoading = false;

  // Get current location and address
  Future<bool> getCurrentLocation() async {
    try {
      isLoading = true;

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return false;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions permanently denied');
        return false;
      }

      // Get position
      currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      await _getAddressFromCoordinates();

      isLoading = false;
      return true;
    } catch (e) {
      print('Error getting location: $e');
      isLoading = false;
      return false;
    }
  }

  // Convert coordinates to address
  Future<void> _getAddressFromCoordinates() async {
    if (currentPosition == null) return;

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        currentPosition!.latitude,
        currentPosition!.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Format address: "City, State, Country"
        List<String> addressParts = [];

        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!); // City
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!); // State
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!); // Country
        }

        currentAddress = addressParts.join(', ');

        // If no address found, use coordinates
        if (currentAddress == null || currentAddress!.isEmpty) {
          currentAddress =
              '${currentPosition!.latitude.toStringAsFixed(4)}, ${currentPosition!.longitude.toStringAsFixed(4)}';
        }
      }
    } catch (e) {
      print('Error getting address: $e');
      // Fallback to coordinates
      currentAddress =
          '${currentPosition!.latitude.toStringAsFixed(4)}, ${currentPosition!.longitude.toStringAsFixed(4)}';
    }
  }

  // Format coordinates for display
  String getFormattedCoordinates() {
    if (currentPosition == null) return 'Getting location...';
    return '${currentPosition!.latitude.toStringAsFixed(6)}°, ${currentPosition!.longitude.toStringAsFixed(6)}°';
  }

  // Get Google Maps static image URL
  String getMapImageUrl({int width = 120, int height = 80}) {
    if (currentPosition == null) return '';

    final lat = currentPosition!.latitude;
    final lng = currentPosition!.longitude;

    // Google Maps Static API URL (without API key, shows placeholder)
    return 'https://maps.googleapis.com/maps/api/staticmap?'
        'center=$lat,$lng'
        '&zoom=15'
        '&size=${width}x$height'
        '&markers=color:red%7C$lat,$lng'
        '&key=YOUR_API_KEY'; //API key
  }
}
