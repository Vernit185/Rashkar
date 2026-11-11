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

Future<BrowserLocationResult> getLiveBrowserLocation() async {
  return BrowserLocationResult(
    latitude: 0,
    longitude: 0,
    error: 'Browser geolocation is only available in web environment.',
  );
}
