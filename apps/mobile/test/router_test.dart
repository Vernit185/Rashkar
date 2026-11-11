import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:cropnet_mobile/core/router/advisory_screen.dart';
import 'package:cropnet_mobile/core/router/app_router.dart';
import 'package:cropnet_mobile/core/router/farm_resolution.dart';
import 'package:cropnet_mobile/core/router/farm_state.dart';
import 'package:cropnet_mobile/core/router/route_names.dart';
import 'package:cropnet_mobile/core/router/route_paths.dart';
import 'package:cropnet_mobile/main.dart';

/// A canonical test farm used by router tests that need a farm in the
/// repository to exercise UI paths that display farm-specific content.
FarmItem _buildTestFarm() => FarmItem(
      id: 'test-farm-baramati',
      name: 'Baramati Pilot Plot',
      taluka: 'Baramati',
      district: 'Pune',
      village: 'Malegaon',
      polygonPoints: [
        const LatLng(18.175, 74.525),
        const LatLng(18.175, 74.535),
        const LatLng(18.185, 74.535),
        const LatLng(18.185, 74.525),
      ],
      areaHectares: 11.82,
      areaAcres: 29.21,
      centroid: const LatLng(18.18, 74.53),
      createdAt: DateTime(2025, 1, 15),
    );

void main() {
  setUp(() {
    // Reset to empty then seed one canonical test farm so that farm-aware
    // screens (dashboard, soil, weather) have a known farm to display.
    FarmRepository.instance.resetToDefault();
    FarmRepository.instance.addFarm(_buildTestFarm());
  });

  void setDesktopViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Route Paths & Name Constants Verification', () {
    test('Mandatory route paths are correctly structured', () {
      expect(RoutePaths.home, '/');
      expect(RoutePaths.soilTesting, '/soil-testing');
      expect(RoutePaths.cropRecommendation, '/crop-recommendation');
      expect(RoutePaths.weather, '/weather');
      expect(RoutePaths.advisory, '/advisory');
      expect(RoutePaths.history, '/history');
      expect(RoutePaths.schemes, '/schemes');
      expect(RoutePaths.cropDoctor, '/crop-doctor');
      expect(RoutePaths.risk, '/risk');
      expect(RoutePaths.riskWorkerHeat, '/risk/worker-heat');
      expect(RoutePaths.riskCropHeat, '/risk/crop-heat');
      expect(RoutePaths.extraIncome, '/extra-income');
    });

    test('Detail and sub-route parameter paths helper methods work as expected', () {
      expect(RoutePaths.farmDetailPath('farm-123'), '/farms/farm-123');
      expect(RoutePaths.soilDetailPath('farm-123'), '/soil-testing/farm-123');
      expect(RoutePaths.weatherDetailPath('farm-123'), '/weather/farm-123');
      expect(RoutePaths.cropDetailPath('crop-sugarcane'), '/crop-recommendation/crop-sugarcane');
    });

    test('Route names are distinctly defined', () {
      final names = [
        RouteNames.home,
        RouteNames.soilTesting,
        RouteNames.cropRecommendation,
        RouteNames.weather,
        RouteNames.advisory,
        RouteNames.history,
        RouteNames.farmNew,
        RouteNames.farmDetail,
        RouteNames.soilDetail,
        RouteNames.weatherDetail,
        RouteNames.cropDetail,
        RouteNames.about,
        RouteNames.schemes,
        RouteNames.cropDoctor,
        RouteNames.risk,
        RouteNames.riskWorkerHeat,
        RouteNames.riskCropHeat,
        RouteNames.extraIncome,
      ];
      final uniqueNames = names.toSet();
      expect(uniqueNames.length, names.length);
    });
  });

  group('FarmRepository Reactive State Tests', () {
    test('FarmRepository starts empty in authenticated multi-tenant architecture', () {
      final repo = FarmRepository.instance;
      repo.clear();
      expect(repo.farms.isEmpty, true);
    });

    test('Adding and deleting farms updates state reactively', () {
      final repo = FarmRepository.instance;
      final initialCount = repo.farms.length;

      final newFarm = FarmItem(
        id: 'test-farm-indapur',
        name: 'Indapur Test Plot',
        taluka: 'Indapur',
        polygonPoints: [
          const LatLng(18.11, 75.01),
          const LatLng(18.11, 75.02),
          const LatLng(18.12, 75.02),
        ],
        areaHectares: 5.5,
        areaAcres: 13.59,
        centroid: const LatLng(18.113, 75.016),
        createdAt: DateTime.now(),
      );

      bool listenerNotified = false;
      void listener() => listenerNotified = true;
      repo.addListener(listener);

      repo.addFarm(newFarm);
      expect(repo.farms.length, initialCount + 1);
      expect(repo.getFarmById('test-farm-indapur'), isNotNull);
      expect(listenerNotified, true);

      listenerNotified = false;
      repo.deleteFarm('test-farm-indapur');
      expect(repo.farms.length, initialCount);
      expect(repo.getFarmById('test-farm-indapur'), isNull);
      expect(listenerNotified, true);

      repo.removeListener(listener);
    });
  });

  group('GoRouter Deep Linking & Widget Integration Tests', () {
    testWidgets('Renders Dashboard at initial / route', (tester) async {
      setDesktopViewport(tester);
      final router = createCropNetRouter(initialLocation: RoutePaths.home);
      await tester.pumpWidget(CropNetApp(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('What would you like to do?'), findsOneWidget);
      expect(find.textContaining('Baramati Pilot Plot'), findsAtLeastNWidgets(1));
    });

    testWidgets('Deep links directly to /soil-testing without crashing', (tester) async {
      setDesktopViewport(tester);
      final router = createCropNetRouter(initialLocation: RoutePaths.soilTesting);
      await tester.pumpWidget(CropNetApp(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Soil Intelligence'), findsOneWidget);
      expect(find.textContaining('Map-Derived Estimates: Values are derived from digital geospatial soil models'), findsOneWidget);
      expect(find.text('Baramati Pilot Plot'), findsOneWidget);
    });

    testWidgets('Deep links directly to /crop-recommendation', (tester) async {
      setDesktopViewport(tester);
      final router = createCropNetRouter(initialLocation: RoutePaths.cropRecommendation);
      await tester.pumpWidget(CropNetApp(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Crop Knowledge Base'), findsOneWidget);
      expect(find.text('Sugarcane'), findsAtLeastNWidgets(1));
    });

    testWidgets('Deep links directly to /weather', (tester) async {
      setDesktopViewport(tester);
      final router = createCropNetRouter(initialLocation: RoutePaths.weather);
      await tester.pumpWidget(CropNetApp(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Weather & Climate Intelligence'), findsOneWidget);
      expect(find.text('Baramati Pilot Plot'), findsOneWidget);
    });

    testWidgets('Deep links directly to /advisory with Qwen dialogue guardrails', (tester) async {
      setDesktopViewport(tester);
      final router = createCropNetRouter(initialLocation: RoutePaths.advisory);
      await tester.pumpWidget(CropNetApp(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.byType(AdvisoryScreen), findsOneWidget);
      expect(find.textContaining('CropNet AI'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Deterministic ICAR & MPKV Decision Engine'), findsOneWidget);
      expect(find.textContaining('Namaste! Welcome to CropNet AI Agricultural Advisory'), findsOneWidget);

      // Advance fake clock past ApiClient timeout so no pending timers remain
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('Deep links directly to /history', (tester) async {
      setDesktopViewport(tester);
      final router = createCropNetRouter(initialLocation: RoutePaths.history);
      await tester.pumpWidget(CropNetApp(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Assessment History'), findsOneWidget);
      expect(find.text('Total Runs'), findsOneWidget);
      expect(find.text('Soil Profiles'), findsOneWidget);
      expect(find.text('No assessment history yet.'), findsOneWidget);
    });

    testWidgets('Deep links to farm soil intelligence sub-route', (tester) async {
      setDesktopViewport(tester);
      final testFarm = FarmItem(
        id: 'test-farm-1',
        name: 'Baramati Test Plot',
        taluka: 'Baramati',
        polygonPoints: [
          const LatLng(18.175, 74.525),
          const LatLng(18.175, 74.535),
          const LatLng(18.185, 74.535),
          const LatLng(18.185, 74.525),
        ],
        areaHectares: 10.0,
        areaAcres: 24.7,
        centroid: const LatLng(18.18, 74.53),
        createdAt: DateTime.now(),
      );
      FarmRepository.instance.addFarm(testFarm);

      final router = createCropNetRouter(initialLocation: '/soil-testing/test-farm-1');
      await tester.pumpWidget(CropNetApp(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Baramati Test Plot — Soil Intelligence'), findsOneWidget);
      expect(find.textContaining('Baramati, Pune, Maharashtra'), findsOneWidget);
      expect(find.text('Soil pH (H2O)'), findsAtLeastNWidgets(1));
      expect(find.textContaining('7.3'), findsAtLeastNWidgets(1));
    });

    testWidgets('Deep links to crop detail sub-route /crop-recommendation/sugarcane', (tester) async {
      setDesktopViewport(tester);
      final router = createCropNetRouter(initialLocation: '/crop-recommendation/sugarcane');
      await tester.pumpWidget(CropNetApp(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Sugarcane'), findsAtLeastNWidgets(1));
      expect(find.text('Saccharum officinarum L.'), findsOneWidget);

      // Advance fake clock past ApiClient timeout so no pending timers remain
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('Gracefully handles invalid route /invalid-unknown-url with error screen', (tester) async {
      setDesktopViewport(tester);
      final router = createCropNetRouter(initialLocation: '/invalid-unknown-url');
      await tester.pumpWidget(CropNetApp(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Page Not Found — CropNet AI'), findsOneWidget);
      expect(find.text('Route or Page Not Found'), findsOneWidget);
      expect(find.text('Return to Dashboard'), findsOneWidget);

      // Tap return to dashboard
      await tester.tap(find.text('Return to Dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('What would you like to do?'), findsOneWidget);
    });

    testWidgets('Gracefully handles missing farm ID in subroute /soil-testing/non-existent-farm', (tester) async {
      setDesktopViewport(tester);
      final router = createCropNetRouter(initialLocation: '/soil-testing/non-existent-farm');
      await tester.pumpWidget(CropNetApp(routerConfig: router));
      await tester.pumpAndSettle();

      final hasNotFound = find.text('Farm No Longer Available').evaluate().isNotEmpty;
      final hasNetError = find.text('Unable to Connect to CropNet').evaluate().isNotEmpty;
      expect(hasNotFound || hasNetError, isTrue);
      expect(find.byType(FarmRouteResolver), findsOneWidget);
    });

    testWidgets('Navigation switches branches seamlessly', (tester) async {
      setDesktopViewport(tester);
      final router = createCropNetRouter(initialLocation: RoutePaths.home);
      await tester.pumpWidget(CropNetApp(routerConfig: router));
      await tester.pumpAndSettle();

      // Initially at Home
      expect(find.text('What would you like to do?'), findsOneWidget);

      // Switch to Soil branch
      await tester.tap(find.text('Soil').first);
      await tester.pumpAndSettle();
      expect(find.text('Soil Intelligence'), findsOneWidget);

      // Switch to Ask Rashkar (Advisory) branch
      await tester.tap(find.text('Ask Rashkar').first);
      await tester.pumpAndSettle();
      expect(find.byType(AdvisoryScreen), findsOneWidget);

      // Switch to History branch
      await tester.tap(find.text('History').first);
      await tester.pumpAndSettle();
      expect(find.text('Assessment History'), findsOneWidget);

      // Switch back to Home branch
      await tester.tap(find.text('Home').first);
      await tester.pumpAndSettle();
      expect(find.text('What would you like to do?'), findsOneWidget);

      // Advance fake clock past ApiClient timeout so no pending timers remain
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('Deep links to /crop-doctor, /risk, /risk/crop-heat and /extra-income', (tester) async {
      setDesktopViewport(tester);

      final cropDocRouter = createCropNetRouter(initialLocation: RoutePaths.cropDoctor);
      await tester.pumpWidget(CropNetApp(routerConfig: cropDocRouter));
      await tester.pump();
      expect(find.text('Crop Doctor'), findsAtLeastNWidgets(1));
      await tester.pump(const Duration(seconds: 31));

      final riskRouter = createCropNetRouter(initialLocation: RoutePaths.riskCropHeat);
      await tester.pumpWidget(CropNetApp(routerConfig: riskRouter));
      await tester.pump();
      expect(find.text('Heat Risk Check'), findsOneWidget);
      expect(find.text('Worker Heat Risk'), findsAtLeastNWidgets(1));
      expect(find.text('Crop Heat Risk'), findsAtLeastNWidgets(1));
      await tester.pump(const Duration(seconds: 31));

      final incomeRouter = createCropNetRouter(initialLocation: RoutePaths.extraIncome);
      await tester.pumpWidget(CropNetApp(routerConfig: incomeRouter));
      await tester.pump();
      expect(find.text('Earn More'), findsAtLeastNWidgets(1));
      await tester.pump(const Duration(seconds: 31));
    });
  });
}
