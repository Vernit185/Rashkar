import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cropnet_mobile/features/onboarding/presentation/screens/farmer_onboarding_wizard.dart';
import 'package:cropnet_mobile/shared/theme/rashkar_theme.dart';

void main() {
  group('Farmer Onboarding Wizard - GPS, Polygon & Area Tests', () {
    testWidgets('Map boundary drawing calculates live area and auto-confirms in Step 4', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: RashkarTheme.light(),
          home: const FarmerOnboardingWizard(),
        ),
      );

      // Step 1: Name
      expect(find.text('Step 1 of 6'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Suresh Patil');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2: Age
      expect(find.text('Step 2 of 6'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 3: Location
      expect(find.text('Step 3 of 6'), findsOneWidget);
      expect(find.text('Where is your farm?'), findsOneWidget);
      expect(find.text('Use My Location'), findsOneWidget);

      // Verify map starts with initial guidance
      expect(find.textContaining('Tap corners around your field'), findsOneWidget);

      final mapFinder = find.byType(FlutterMap);
      expect(mapFinder, findsOneWidget);

      // Tap 4 points to form a farm plot
      final mapCenter = tester.getCenter(mapFinder);

      await tester.tapAt(Offset(mapCenter.dx - 60, mapCenter.dy - 40));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Marked 1 point'), findsOneWidget);

      await tester.tapAt(Offset(mapCenter.dx + 60, mapCenter.dy - 40));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Marked 2 points'), findsOneWidget);

      await tester.tapAt(Offset(mapCenter.dx + 60, mapCenter.dy + 40));
      await tester.pump(const Duration(milliseconds: 300));
      // 3 points forms a valid polygon with live area!
      expect(find.textContaining('Your farm is about'), findsOneWidget);

      // Add 4th point
      await tester.tapAt(Offset(mapCenter.dx - 60, mapCenter.dy + 40));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Your farm is about'), findsOneWidget);
      expect(find.text('Undo Point'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // Advance to Step 4
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 4: Land size should be automatically confirmed without typing!
      expect(find.text('Step 4 of 6'), findsOneWidget);
      expect(find.text('Farm Land Size Confirmed'), findsOneWidget);
      expect(find.textContaining('Your farm is about'), findsOneWidget);
      expect(find.textContaining('calculated directly from your map boundary'), findsOneWidget);

      // Advance to Step 5: Crop
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Step 5 of 6'), findsOneWidget);
      expect(find.text('What are you growing?'), findsOneWidget);
    });

    testWidgets('Self-intersecting polygon shows warning and blocks Continue until resolved', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: RashkarTheme.light(),
          home: const FarmerOnboardingWizard(),
        ),
      );

      // Step 1 -> Step 2 -> Step 3
      await tester.enterText(find.byType(TextField).first, 'Suresh Patil');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 6'), findsOneWidget);

      final mapFinder = find.byType(FlutterMap);
      final mapCenter = tester.getCenter(mapFinder);

      // Tap crossing bowtie / figure-8 points:
      await tester.tapAt(Offset(mapCenter.dx - 60, mapCenter.dy - 40)); // Top-left
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tapAt(Offset(mapCenter.dx + 60, mapCenter.dy + 40)); // Bottom-right
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tapAt(Offset(mapCenter.dx + 60, mapCenter.dy - 40)); // Top-right
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tapAt(Offset(mapCenter.dx - 60, mapCenter.dy + 40)); // Bottom-left
      await tester.pump(const Duration(milliseconds: 300));

      // Crossing lines detected!
      expect(find.textContaining('Boundary lines cannot cross each other'), findsOneWidget);

      // Try tapping Continue - blocked by validation
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Boundary lines cannot cross each other'), findsAtLeastNWidgets(1));
      // Still on Step 3
      expect(find.text('Step 3 of 6'), findsOneWidget);

      // Tap Undo Point to remove crossing segment
      await tester.tap(find.text('Undo Point'));
      await tester.pump(const Duration(milliseconds: 100));

      // Intersection resolved!
      expect(find.textContaining('Your farm is about'), findsOneWidget);

      // Now Continue works!
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Step 4 of 6'), findsOneWidget);
    });

    testWidgets('Reset button clears all map points cleanly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: RashkarTheme.light(),
          home: const FarmerOnboardingWizard(),
        ),
      );

      // Step 1 -> Step 2 -> Step 3
      await tester.enterText(find.byType(TextField).first, 'Suresh Patil');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final mapFinder = find.byType(FlutterMap);
      final mapCenter = tester.getCenter(mapFinder);

      await tester.tapAt(Offset(mapCenter.dx - 40, mapCenter.dy - 40));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Reset'), findsOneWidget);

      // Tap Reset
      await tester.tap(find.text('Reset'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Tap corners around your field'), findsOneWidget);
      expect(find.text('Reset'), findsNothing);
    });
  });
}
