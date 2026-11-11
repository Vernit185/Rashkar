import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cropnet_mobile/core/router/route_paths.dart';
import 'package:cropnet_mobile/shared/theme/rashkar_tokens.dart';
import 'package:cropnet_mobile/shared/theme/rashkar_components.dart';

/// RASHKAR Design Language - Friendly Route Error Screen
class AppRouteErrorScreen extends StatelessWidget {
  final Exception? error;
  final String? uri;

  const AppRouteErrorScreen({
    super.key,
    this.error,
    this.uri,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RashkarColors.cream,
      appBar: const RashkarTopBar(
        title: 'Page Not Found — CropNet AI',
        subtitle: 'RASHKAR Platform Navigation',
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: RashkarCard(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: RashkarColors.sand,
                      borderRadius: RashkarRadii.iconTileBorderRadius,
                    ),
                    child: const Icon(
                      Icons.wrong_location_outlined,
                      size: 32,
                      color: RashkarColors.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Route or Page Not Found', style: RashkarTypography.cardTitle),
                  const SizedBox(height: 8),
                  Text(
                    uri != null
                        ? 'The requested URL path "$uri" does not exist or has been relocated.'
                        : 'The requested resource could not be found.',
                    style: RashkarTypography.body,
                    textAlign: TextAlign.center,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    RashkarNotice(
                      message: error.toString(),
                      type: RashkarNoticeType.error,
                    ),
                  ],
                  const SizedBox(height: 24),
                  RashkarButton(
                    label: 'Return to Dashboard',
                    leadingIcon: Icons.home_outlined,
                    onPressed: () => context.go(RoutePaths.home),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
