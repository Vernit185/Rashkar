import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/farm_state.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../shared/theme/rashkar_colors.dart';

/// Professional Rashkar Startup Splash Screen (Specification Part 2).
///
/// Features:
/// - Clean white background.
/// - Centered Rashkar logo badge with bold wordmark.
/// - Subtle fade-in (350ms) and fade-out (300ms) transitions.
/// - Authoritative startup check: loads existing user farms/profile.
/// - Routes to [RoutePaths.home] if farms exist, or [RoutePaths.onboarding] for first-time farmers.
/// - Respects reduced-motion accessibility settings.
class SplashScreen extends StatefulWidget {
  final VoidCallback? onInitialized;

  const SplashScreen({super.key, this.onInitialized});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();
    _runStartupSequence();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _runStartupSequence() async {
    final startTime = DateTime.now();

    // Authoritative profile & farms check
    try {
      final repo = FarmRepository.instance;
      if (repo.farms.isEmpty && !repo.isLoading) {
        await repo.loadFarms();
      }
    } catch (_) {
      // Preserve resilience on offline / temporary network blips
    }

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    // Brief gentle hold (approx 600ms total) so logo is comfortably perceived
    final remainingWait = 650 - elapsed;
    if (remainingWait > 0) {
      await Future.delayed(Duration(milliseconds: remainingWait));
    }

    if (!mounted || _isNavigating) return;
    _isNavigating = true;

    // Gentle fade out before routing
    await _animController.reverse();

    if (!mounted) return;

    if (widget.onInitialized != null) {
      widget.onInitialized!();
      return;
    }

    if (GoRouter.maybeOf(context) != null) {
      final repo = FarmRepository.instance;
      if (repo.farms.isNotEmpty) {
        context.go(RoutePaths.home);
      } else {
        context.go(RoutePaths.onboarding);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: reduceMotion
            ? _buildBranding()
            : FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildBranding(),
                ),
              ),
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Centered Rashkar Leaf / Crop Emblem
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: RashkarColors.forestTint,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: RashkarColors.forestTint.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.eco_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'RASHKAR',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
            color: RashkarColors.forestTint,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Farmer Service',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: RashkarColors.mutedInk,
          ),
        ),
      ],
    );
  }
}
