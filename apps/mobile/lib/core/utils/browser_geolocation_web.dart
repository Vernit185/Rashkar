import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class BrowserLocationResult {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? error;

  BrowserLocationResult({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.error,
  });

  bool get isSuccess => error == null;
}

Future<BrowserLocationResult> getLiveBrowserLocation() {
  final completer = Completer<BrowserLocationResult>();

  try {
    final geolocation = web.window.navigator.geolocation;
    final options = web.PositionOptions(
      enableHighAccuracy: true,
      timeout: 10000,
      maximumAge: 0,
    );

    final successCallback = ((web.GeolocationPosition pos) {
      final lat = pos.coords.latitude.toDouble();
      final lon = pos.coords.longitude.toDouble();
      final accuracy = pos.coords.accuracy.toDouble();
      if (!completer.isCompleted) {
        completer.complete(BrowserLocationResult(
          latitude: lat,
          longitude: lon,
          accuracy: accuracy,
        ));
      }
    }).toJS;

    final errorCallback = ((web.GeolocationPositionError err) {
      String msg;
      switch (err.code) {
        case 1:
          msg = 'Location permission denied by browser. Please choose your location or taluka manually.';
          break;
        case 2:
          msg = 'Location position unavailable. Please choose your location or taluka manually.';
          break;
        case 3:
          msg = 'Location request timed out. Please choose your location or taluka manually.';
          break;
        default:
          msg = 'Could not get location (${err.message}). Please choose your location or taluka manually.';
      }
      if (!completer.isCompleted) {
        completer.complete(BrowserLocationResult(
          latitude: 0,
          longitude: 0,
          error: msg,
        ));
      }
    }).toJS;

    geolocation.getCurrentPosition(
      successCallback as web.PositionCallback,
      errorCallback as web.PositionErrorCallback,
      options,
    );
  } catch (e) {
    if (!completer.isCompleted) {
      completer.complete(BrowserLocationResult(
        latitude: 0,
        longitude: 0,
        error: 'Geolocation not supported: $e',
      ));
    }
  }

  return completer.future;
}
