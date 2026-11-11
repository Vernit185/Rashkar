import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cropnet_mobile/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:cropnet_mobile/features/onboarding/presentation/screens/farmer_onboarding_wizard.dart';
import 'package:cropnet_mobile/shared/theme/rashkar_theme.dart';

void main() {
  group('Farmer Onboarding & Startup Tests (Phase B)', () {
    testWidgets('SplashScreen displays clean white background, logo, and RASHKAR wordmark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RashkarTheme.light(),
          home: const SplashScreen(),
        ),
      );

      // Verify immediate appearance of branding
      expect(find.text('RASHKAR'), findsOneWidget);
      expect(find.text('Farmer Service'), findsOneWidget);
      expect(find.byIcon(Icons.eco_rounded), findsOneWidget);

      // Advance clock past timer
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('FarmerOnboardingWizard steps through questions progressively', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
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
      expect(find.text('What is your name?'), findsOneWidget);

      // Validation check on empty submit
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Please enter your name to continue.'), findsOneWidget);

      // Enter name
      await tester.enterText(find.byType(TextField).first, 'Suresh Jadhav');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2: Age
      expect(find.text('Step 2 of 6'), findsOneWidget);
      expect(find.text('How old are you?'), findsOneWidget);
      expect(find.textContaining('heat safety, hydration alerts'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 3: Location
      expect(find.text('Step 3 of 6'), findsOneWidget);
      expect(find.text('Where is your farm?'), findsOneWidget);
      expect(find.text('Use My Location'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 4: Land size
      expect(find.text('Step 4 of 6'), findsOneWidget);
      expect(find.text('How much land do you have?'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 5: Current crop
      expect(find.text('Step 5 of 6'), findsOneWidget);
      expect(find.text('What are you growing?'), findsOneWidget);
      expect(find.text('Sugarcane'), findsOneWidget);
      expect(find.text('I haven’t planted anything yet'), findsOneWidget);

      // Test Back button navigation
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Step 4 of 6'), findsOneWidget);
      expect(find.text('How much land do you have?'), findsOneWidget);
    });
  });
}
