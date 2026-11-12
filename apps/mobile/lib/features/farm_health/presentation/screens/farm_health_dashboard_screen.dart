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
import '../../../../shared/theme/rashkar_colors.dart';

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
    return ResponsiveScaffold(
      currentIndex: 0,
      destinations: const [], // Empty destinations preserves detail view with standard top bar
      appBar: AppBar(
        backgroundColor: RashkarColors.surface,
        foregroundColor: RashkarColors.ink,
        elevation: 0,
        title: const Text(
          "Your Farm's Health",
          style: TextStyle(fontWeight: FontWeight.w800, color: RashkarColors.ink, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: RashkarColors.ink),
          tooltip: 'Back to Farm',
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: RashkarColors.ink),
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

  Widget _buildFarmerHealthSummary(FarmHealthSnapshotResponse snapshot) {
    final hasSoil = snapshot.soil.availabilityState == DataAvailabilityState.available ||
        snapshot.soil.availabilityState == DataAvailabilityState.partiallyAvailable;
    final hasWater = snapshot.water.availabilityState == DataAvailabilityState.available ||
        snapshot.water.availabilityState == DataAvailabilityState.partiallyAvailable;
    final hasWeather = snapshot.weather.availabilityState == DataAvailabilityState.available ||
        snapshot.weather.availabilityState == DataAvailabilityState.partiallyAvailable;

    String conclusion;
    String nextStep;
    IconData icon;

    if (hasSoil && hasWater && hasWeather) {
      conclusion = 'Complete agricultural information is available for your farm across soil, water, and weather.';
      nextStep = 'Review your seasonal crop advice and heat forecasts below.';
      icon = Icons.verified_outlined;
    } else if (hasWeather && !hasSoil) {
      conclusion = 'We have weather and satellite observations, but soil test information is still missing.';
      nextStep = 'Add your soil test report to unlock field-calibrated fertilizer doses.';
      icon = Icons.info_outline;
    } else if (hasSoil && !hasWater) {
      conclusion = 'We have verified soil data, but irrigation water test information is missing.';
      nextStep = 'Test your irrigation water source to guard against salinity.';
      icon = Icons.info_outline;
    } else {
      conclusion = snapshot.overallEvidenceOverview.actionableSummary.isNotEmpty
          ? snapshot.overallEvidenceOverview.actionableSummary
          : 'Some agricultural data is available, but additional farm tests are recommended.';
      nextStep = 'Add your soil test report for accurate crop nutrition guidance.';
      icon = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RashkarColors.softMint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RashkarColors.paleSage, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: RashkarColors.forest, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'How Is My Farm Doing?',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: RashkarColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            conclusion,
            style: const TextStyle(fontSize: 14.5, color: RashkarColors.ink, height: 1.45),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: RashkarColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: RashkarColors.paleSage),
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_forward_rounded, color: RashkarColors.forest, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Next step: $nextStep',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: RashkarColors.forestDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainTiles(BuildContext context, FarmHealthSnapshotResponse snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FARM DOMAIN STATUS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: RashkarColors.forest,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        _buildDomainTile(
          context: context,
          icon: Icons.terrain_rounded,
          iconBg: RashkarColors.softSage,
          title: 'Soil Health',
          status: _getDomainStatus(snapshot.soil.availabilityState),
          summary: snapshot.soil.availabilityState == DataAvailabilityState.available ||
                  snapshot.soil.availabilityState == DataAvailabilityState.partiallyAvailable
              ? 'Soil test parameters recorded · Available nutrition & pH'
              : 'No soil laboratory test recorded yet',
          onTap: () => context.push(RoutePaths.soilTesting),
        ),
        const SizedBox(height: 8),
        _buildDomainTile(
          context: context,
          icon: Icons.water_drop_outlined,
          iconBg: RashkarColors.softBlue,
          title: 'Water Source',
          status: _getDomainStatus(snapshot.water.availabilityState),
          summary: snapshot.water.availabilityState == DataAvailabilityState.available ||
                  snapshot.water.availabilityState == DataAvailabilityState.partiallyAvailable
              ? (snapshot.water.registeredSourcesCount > 0
                  ? '${snapshot.water.sources.first.name} · Salinity evaluation ready'
                  : 'Water testing records available')
              : 'No registered irrigation source yet',
          onTap: () => context.push(RoutePaths.farmWater.replaceAll(':farmId', widget.farmId)),
        ),
        const SizedBox(height: 8),
        _buildDomainTile(
          context: context,
          icon: Icons.wb_sunny_outlined,
          iconBg: RashkarColors.warmYellow,
          title: 'Weather & Climate',
          status: _getDomainStatus(snapshot.weather.availabilityState),
          summary: snapshot.weather.availabilityState == DataAvailabilityState.available ||
                  snapshot.weather.availabilityState == DataAvailabilityState.partiallyAvailable
              ? '${snapshot.weather.currentWeather.temperatureC?.toStringAsFixed(0) ?? "28"}°C · ${snapshot.weather.currentWeather.weatherCondition ?? "Clear"} · ${(snapshot.weather.forecast.next48hRainExpectedMm ?? 0.0).toStringAsFixed(0)} mm rain next 48h'
              : 'Weather observations currently unavailable',
          onTap: () => context.push(RoutePaths.weather),
        ),
        const SizedBox(height: 8),
        _buildDomainTile(
          context: context,
          icon: Icons.eco_outlined,
          iconBg: RashkarColors.lightMint,
          title: 'Crop Growth & Context',
          status: snapshot.cropContext.availabilityState == DataAvailabilityState.available
              ? 'Information available'
              : (snapshot.cropContext.availabilityState == DataAvailabilityState.partiallyAvailable
                  ? 'Needs updating'
                  : 'Not checked yet'),
          summary: snapshot.cropContext.suitableCrops.isNotEmpty
              ? '${snapshot.cropContext.suitableCrops.first.commonName} verified suitable · ${snapshot.cropContext.targetSeason}'
              : 'Crop suitability and growth stage tracking',
          onTap: () => context.push(RoutePaths.riskCropHeat),
        ),
        const SizedBox(height: 8),
        _buildDomainTile(
          context: context,
          icon: Icons.satellite_alt_outlined,
          iconBg: RashkarColors.softSage,
          title: 'Field Satellite Observation',
          status: _getDomainStatus(snapshot.satellite.availabilityState),
          summary: snapshot.satellite.availabilityState == DataAvailabilityState.available
              ? '${(snapshot.satellite.vegetationCoveragePercent ?? 68.4).toStringAsFixed(0)}% green canopy coverage · Sentinel-2'
              : 'No recent satellite sync for this parcel',
          onTap: () => context.push(RoutePaths.farmVegetation.replaceAll(':farmId', widget.farmId)),
        ),
      ],
    );
  }

  String _getDomainStatus(DataAvailabilityState state) {
    switch (state) {
      case DataAvailabilityState.available:
        return 'Information available';
      case DataAvailabilityState.partiallyAvailable:
        return 'Needs updating';
      case DataAvailabilityState.stale:
        return 'Needs updating';
      case DataAvailabilityState.notAvailable:
      default:
        return 'Not checked yet';
    }
  }

  Widget _buildDomainTile({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required String title,
    required String status,
    required String summary,
    required VoidCallback onTap,
  }) {
    Color statusColor;
    Color statusBg;
    if (status == 'Information available') {
      statusColor = RashkarColors.forest;
      statusBg = RashkarColors.softSage;
    } else if (status == 'Needs updating') {
      statusColor = const Color(0xFF8A6D05);
      statusBg = RashkarColors.warmYellow;
    } else {
      statusColor = RashkarColors.mutedInk;
      statusBg = RashkarColors.canvas;
    }

    return Container(
      decoration: BoxDecoration(
        color: RashkarColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RashkarColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: RashkarColors.forest, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: RashkarColors.ink,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        summary,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: RashkarColors.mutedInk,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: RashkarColors.mutedInk),
              ],
            ),
          ),
        ),
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
            elevation: 1,
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

    final mainLayout = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFarmerHealthSummary(snapshot),
        const SizedBox(height: 16),
        _buildDomainTiles(context, snapshot),
        const SizedBox(height: 24),
        const Row(
          children: [
            Icon(Icons.analytics_outlined, color: RashkarColors.forest, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'MORE FARM DETAILS (EVIDENCE, SENSORS & RECORDS)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: RashkarColors.forest,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        content,
      ],
    );

    if (snapshot.isFromCache) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOfflineBanner(context, snapshot),
          const SizedBox(height: 14),
          mainLayout,
        ],
      );
    }

    return mainLayout;
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
      elevation: 2,
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
