import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/farm_state.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../main.dart';
import '../../../../shared/responsive/breakpoints.dart';
import '../../../../shared/widgets/centered_page_container.dart';
import '../../../../shared/widgets/responsive_scaffold.dart';
import '../../data/farm_health_repository.dart';
import '../../models/farm_health_models.dart';
import '../widgets/ai_entry_points_card.dart';
import '../widgets/farm_overview_card.dart';
import '../widgets/farm_timeline_card.dart';
import '../widgets/overall_evidence_card.dart';
import '../widgets/satellite_vegetation_card.dart';
import '../widgets/soil_intelligence_card.dart';
import '../widgets/water_intelligence_card.dart';
import '../widgets/weather_summary_card.dart';

/// Unified Farm Health Dashboard Screen (Phase 5.9B)
///
/// Centralized operational dashboard consuming the Phase 5.9A Farm Health Snapshot API.
/// Renders all 8 required sections across responsive mobile, tablet, and desktop layouts
/// using native Flutter widgets without calculating a universal farm health score
/// and without manufacturing synthetic demo values.
class FarmHealthDashboardScreen extends StatefulWidget {
  final String farmId;
  final FarmItem? farm;
  final FarmHealthRepository? repository;
  final bool simulateOffline;

  const FarmHealthDashboardScreen({
    super.key,
    required this.farmId,
    this.farm,
    this.repository,
    this.simulateOffline = false,
  });

  @override
  State<FarmHealthDashboardScreen> createState() => _FarmHealthDashboardScreenState();
}

class _FarmHealthDashboardScreenState extends State<FarmHealthDashboardScreen> {
  late final FarmHealthRepository _repository;
  FarmHealthSnapshotResponse? _snapshot;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FarmHealthRepository.instance;
    _fetchSnapshot();
  }

  @override
  void didUpdateWidget(covariant FarmHealthDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.farmId != widget.farmId || oldWidget.simulateOffline != widget.simulateOffline) {
      _fetchSnapshot();
    }
  }

  Future<void> _fetchSnapshot({bool forceRefresh = false}) async {
    if (forceRefresh) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      var res = await _repository.getFarmHealthSnapshot(
        widget.farmId,
        forceRefresh: forceRefresh,
      );
      if (widget.simulateOffline) {
        res = res.copyWith(
          isFromCache: true,
          cachedAt: DateTime.now().subtract(const Duration(minutes: 14)),
        );
      }
      if (!mounted) return;
      setState(() {
        _snapshot = res;
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.farm?.name ?? _snapshot?.farmName ?? 'Farm Health Dashboard';

    return ResponsiveScaffold(
      currentIndex: 0,
      destinations: const [], // Empty destinations preserves detail view with standard top bar
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Farm',
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Snapshot',
            onPressed: () => _fetchSnapshot(forceRefresh: true),
          ),
        ],
      ),
      body: CenteredPageContainer(
        maxWidth: AppBreakpoints.maxContentWidthWide, // 1440px wide desktop container
        scrollable: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Assembling multi-domain farm health snapshot...',
                style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _snapshot == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFC62828)),
                  const SizedBox(height: 12),
                  const Text(
                    'Failed to Load Farm Health Dashboard',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry Connection'),
                    onPressed: () => _fetchSnapshot(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final timelineItems = snapshot.buildTimelineItems();

    // Responsive layout switching
    Widget content;
    final breakpoint = context.breakpoint;
    if (breakpoint == AppBreakpoint.desktop) {
      content = _buildDesktopLayout(context, snapshot, timelineItems);
    } else if (breakpoint == AppBreakpoint.tablet) {
      content = _buildTabletLayout(context, snapshot, timelineItems);
    } else {
      content = _buildMobileLayout(context, snapshot, timelineItems);
    }

    if (snapshot.isFromCache) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOfflineBanner(context, snapshot),
          const SizedBox(height: 14),
          content,
        ],
      );
    }

    return content;
  }

  /// Prominent offline banner when viewing cached snapshots.
  Widget _buildOfflineBanner(BuildContext context, FarmHealthSnapshotResponse snapshot) {
    final cachedTimeStr = snapshot.cachedAt != null
        ? '${snapshot.cachedAt!.hour.toString().padLeft(2, '0')}:${snapshot.cachedAt!.minute.toString().padLeft(2, '0')}'
        : 'recent session';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE68A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFB45309),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Offline Mode — Showing Cached Snapshot',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Retrieved at $cachedTimeStr. Real-time synchronization will automatically resume when network connectivity is restored.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF92400E),
              side: const BorderSide(color: Color(0xFFD97706)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.sync_rounded, size: 16),
            label: const Text('Retry'),
            onPressed: () => _fetchSnapshot(forceRefresh: true),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE LAYOUT (<600px): Single-Column Vertical Stack
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(
    BuildContext context,
    FarmHealthSnapshotResponse snapshot,
    List<FarmObservationTimelineItem> timelineItems,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section 1: Overview
        FarmOverviewCard(
          snapshot: snapshot,
          onRefresh: () => _fetchSnapshot(forceRefresh: true),
          isRefreshing: _isRefreshing,
        ),
        const SizedBox(height: 16),

        // Section 2: Overall Evidence Status Board
        OverallEvidenceCard(
          overview: snapshot.overallEvidenceOverview,
          soil: snapshot.soil,
          water: snapshot.water,
          satellite: snapshot.satellite,
          weather: snapshot.weather,
          cropContext: snapshot.cropContext,
        ),
        const SizedBox(height: 16),

        // Section 8: AI Assistant Entry Points (Prominently placed near top on mobile)
        AiEntryPointsCard(snapshot: snapshot),
        const SizedBox(height: 16),

        // Section 3: Soil Intelligence
        SoilIntelligenceCard(farmId: widget.farmId, soil: snapshot.soil),
        const SizedBox(height: 16),

        // Section 4: Water Intelligence
        WaterIntelligenceCard(farmId: widget.farmId, water: snapshot.water),
        const SizedBox(height: 16),

        // Section 5: Satellite Vegetation
        SatelliteVegetationCard(farmId: widget.farmId, satellite: snapshot.satellite),
        const SizedBox(height: 16),

        // Section 6: Weather & Climate
        WeatherSummaryCard(farmId: widget.farmId, weather: snapshot.weather),
        const SizedBox(height: 16),

        // Section 7: Observations Timeline
        FarmTimelineCard(timelineItems: timelineItems),
        const SizedBox(height: 16),

        // Quick Workspace Navigation Shortcuts
        _buildQuickNavShortcuts(context),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TABLET LAYOUT (600px–1024px): 2-Column Balanced Grid
  // ---------------------------------------------------------------------------
  Widget _buildTabletLayout(
    BuildContext context,
    FarmHealthSnapshotResponse snapshot,
    List<FarmObservationTimelineItem> timelineItems,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section 1: Farm Overview spans full width
        FarmOverviewCard(
          snapshot: snapshot,
          onRefresh: () => _fetchSnapshot(forceRefresh: true),
          isRefreshing: _isRefreshing,
        ),
        const SizedBox(height: 16),

        // 2-Column Content Grid
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OverallEvidenceCard(
                    overview: snapshot.overallEvidenceOverview,
                    soil: snapshot.soil,
                    water: snapshot.water,
                    satellite: snapshot.satellite,
                    weather: snapshot.weather,
                    cropContext: snapshot.cropContext,
                  ),
                  const SizedBox(height: 16),
                  SoilIntelligenceCard(farmId: widget.farmId, soil: snapshot.soil),
                  const SizedBox(height: 16),
                  WaterIntelligenceCard(farmId: widget.farmId, water: snapshot.water),
                  const SizedBox(height: 16),
                  _buildQuickNavShortcuts(context),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Right Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AiEntryPointsCard(snapshot: snapshot),
                  const SizedBox(height: 16),
                  SatelliteVegetationCard(farmId: widget.farmId, satellite: snapshot.satellite),
                  const SizedBox(height: 16),
                  WeatherSummaryCard(farmId: widget.farmId, weather: snapshot.weather),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Section 7: Timeline spans full width at bottom
        FarmTimelineCard(timelineItems: timelineItems),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP LAYOUT (>1024px): 3-Column High-Density Responsive Layout
  // ---------------------------------------------------------------------------
  Widget _buildDesktopLayout(
    BuildContext context,
    FarmHealthSnapshotResponse snapshot,
    List<FarmObservationTimelineItem> timelineItems,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Column 1 (Left, 30%): Farm Overview & Chronological Timeline
            Expanded(
              flex: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FarmOverviewCard(
                    snapshot: snapshot,
                    onRefresh: () => _fetchSnapshot(forceRefresh: true),
                    isRefreshing: _isRefreshing,
                  ),
                  const SizedBox(height: 16),
                  FarmTimelineCard(timelineItems: timelineItems),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Column 2 (Center, 40%): Core Intelligence Cards (Soil, Water, Satellite, Weather)
            Expanded(
              flex: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SoilIntelligenceCard(farmId: widget.farmId, soil: snapshot.soil),
                  const SizedBox(height: 16),
                  WaterIntelligenceCard(farmId: widget.farmId, water: snapshot.water),
                  const SizedBox(height: 16),
                  SatelliteVegetationCard(farmId: widget.farmId, satellite: snapshot.satellite),
                  const SizedBox(height: 16),
                  WeatherSummaryCard(farmId: widget.farmId, weather: snapshot.weather),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Column 3 (Right, 30%): Evidence Status Board, AI Advisor Entry Points & Shortcuts
            Expanded(
              flex: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OverallEvidenceCard(
                    overview: snapshot.overallEvidenceOverview,
                    soil: snapshot.soil,
                    water: snapshot.water,
                    satellite: snapshot.satellite,
                    weather: snapshot.weather,
                    cropContext: snapshot.cropContext,
                  ),
                  const SizedBox(height: 16),
                  AiEntryPointsCard(snapshot: snapshot),
                  const SizedBox(height: 16),
                  _buildQuickNavShortcuts(context),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Workspace Navigation Shortcuts Card
  // ---------------------------------------------------------------------------
  Widget _buildQuickNavShortcuts(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.hub_outlined, size: 20, color: Color(0xFF1B5E20)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Workspace Shortcuts',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildShortcutChip(
                  context,
                  icon: Icons.layers_outlined,
                  label: 'Soil Testing',
                  onTap: () => context.push(RoutePaths.soilDetailPath(widget.farmId)),
                ),
                _buildShortcutChip(
                  context,
                  icon: Icons.water_drop_outlined,
                  label: 'Water Quality',
                  onTap: () => context.push(RoutePaths.farmWaterPath(widget.farmId)),
                ),
                _buildShortcutChip(
                  context,
                  icon: Icons.satellite_alt_outlined,
                  label: 'Satellite',
                  onTap: () => context.push(RoutePaths.farmVegetationPath(widget.farmId)),
                ),
                _buildShortcutChip(
                  context,
                  icon: Icons.cloud_outlined,
                  label: 'Weather',
                  onTap: () => context.push(RoutePaths.weatherDetailPath(widget.farmId)),
                ),
                _buildShortcutChip(
                  context,
                  icon: Icons.agriculture_outlined,
                  label: 'Crops Catalog',
                  onTap: () => context.push(RoutePaths.cropRecommendation),
                ),
                _buildShortcutChip(
                  context,
                  icon: Icons.psychology_outlined,
                  label: 'AI Advisory',
                  onTap: () {
                    FarmRepository.instance.selectedFarmId = widget.farmId;
                    context.push(RoutePaths.advisory);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
    );
  }
}
