import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:cropnet_mobile/core/router/farm_state.dart';
import 'package:cropnet_mobile/main.dart';

void main() {
  testWidgets('CropNet AI app shell navigates to Soil Intelligence report correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testFarm = FarmItem(
      id: 'test-farm-pune',
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
      createdAt: DateTime.now(),
    );
    FarmRepository.instance.addFarm(testFarm);

    // 1. Pump the app shell
    await tester.pumpWidget(const CropNetApp());
    await tester.pumpAndSettle();

    // Verify farmer-first Home screen on initial load
    expect(find.text('What would you like to do?'), findsOneWidget);
    expect(find.textContaining('Baramati Pilot Plot'), findsAtLeastNWidgets(1));
    expect(find.text('Soil'), findsOneWidget);

    // 2. Switch to Soil tab
    await tester.tap(find.text('Soil'));
    await tester.pumpAndSettle();

    // Verify Soil Intelligence Screen
    expect(find.text('Soil Intelligence'), findsOneWidget);
    expect(find.textContaining('Map-Derived Estimates:'), findsOneWidget);
    expect(find.text('Baramati Pilot Plot'), findsOneWidget);

    // 3. Open Soil Intelligence Report for Baramati Pilot Plot
    await tester.tap(find.text('Baramati Pilot Plot'));
    await tester.pumpAndSettle();

    // Verify Soil Report Screen and Safeguards
    expect(find.text('Baramati Pilot Plot — Soil Intelligence'), findsOneWidget);
    expect(find.text('Soil pH (H2O)'), findsAtLeastNWidgets(1));
    expect(find.text('Total Nitrogen (N)'), findsOneWidget);
    expect(find.textContaining('Available Nitrogen (N)'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Physical soil test required'), findsAtLeastNWidgets(1));
  });
}
