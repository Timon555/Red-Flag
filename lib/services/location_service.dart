import 'package:geolocator/geolocator.dart';

/// Why the position could not be read, in words the user can act on.
class LocationException implements Exception {
  LocationException(this.message, {this.canOpenSettings = false});

  final String message;
  final bool canOpenSettings;

  @override
  String toString() => message;
}

class LocationService {
  /// The phone's current position at the best accuracy it offers.
  ///
  /// Asks for permission when needed and throws [LocationException] when the
  /// user said no or location is switched off.
  Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException(
        'Die Standortdienste sind ausgeschaltet. Schalte sie ein, damit wir '
        'Restaurants in deiner Nähe finden können.',
        canOpenSettings: true,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationException(
        'Red Flag braucht deinen Standort, um Restaurants in der Nähe zu '
        'finden.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Der Standortzugriff ist blockiert. Erlaube ihn in den Einstellungen.',
        canOpenSettings: true,
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<void> openSettings() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  double distanceBetween(double lat1, double lng1, double lat2, double lng2) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
}
