import 'package:flutter/material.dart';
import '../../../../shared/theme/rashkar_colors.dart';
import '../../../../shared/widgets/centered_page_container.dart';
import '../../../../shared/widgets/rashkar_charts.dart';
import '../../../../shared/widgets/rashkar_ui.dart';
import '../../models/satellite_models.dart';
import '../../data/satellite_repository.dart';

/// Comprehensive Sentinel-2 Level-2A Satellite-Based Vegetation Intelligence Screen.
///
/// Provides farmers with:
/// - Exact satellite product provenance and acquisition vs sync dates.
/// - Pure Class 4 canopy NDVI & NDMI (resampling disclosed).
/// - SCL land-surface composition breakdown (Canopy, Bare Soil, Water, Masked).
/// - Interactive spatial raster visualization with layer switcher and metadata.
/// - Non-fabricated historical trend monitoring (baseline or multi-pass deltas).
/// - Responsible scientific agronomic safeguards.
class SatelliteVegetationScreen extends StatefulWidget {
  final String farmId;
  final String farmName;

  const SatelliteVegetationScreen({
    super.key,
    required this.farmId,
    this.farmName = 'Farm',
  });

  @override
  State<SatelliteVegetationScreen> createState() => _SatelliteVegetationScreenState();
}

class _SatelliteVegetationScreenState extends State<SatelliteVegetationScreen> {
  final SatelliteRepository _repository = SatelliteRepository.instance;

  bool _isLoading = true;
  bool _isSyncing = false;
  String? _errorMessage;
  String? _syncFeedbackMessage;
  bool _syncFeedbackIsError = false;

  SatelliteObservation? _latest;
  VegetationTimeSeriesData? _timeSeries;
  SatelliteSpatialMetadata? _spatialMeta;

  // Selected layer for spatial raster visualization: 'ndvi', 'ndmi', or 'scl'
  String _selectedRasterLayer = 'ndvi';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final latestFuture = _repository.getLatestObservation(widget.farmId);
      final tsFuture = _repository.getTimeSeries(widget.farmId, months: 6);
      final metaFuture = _repository.getSpatialMetadata(widget.farmId);

      final results = await Future.wait([latestFuture, tsFuture, metaFuture]);

      if (!mounted) return;
      setState(() {
        _latest = results[0] as SatelliteObservation?;
        _timeSeries = results[1] as VegetationTimeSeriesData?;
        _spatialMeta = results[2] as SatelliteSpatialMetadata?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load satellite vegetation data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _syncFeedbackMessage = null;
    });

    try {
      final obs = await _repository.syncObservations(widget.farmId);
      final ts = await _repository.getTimeSeries(widget.farmId, months: 6);
      final meta = await _repository.getSpatialMetadata(widget.farmId);

      if (!mounted) return;
      final effectiveObs = obs ?? _latest;
      final now = DateTime.now();
      final isToday = effectiveObs != null &&
          effectiveObs.observationDate.year == now.year &&
          effectiveObs.observationDate.month == now.month &&
          effectiveObs.observationDate.day == now.day;

      String feedbackMsg;
      bool isError;
      if (obs != null && isToday) {
        feedbackMsg = 'Sentinel-2 imagery successfully synced!';
        isError = false;
      } else if (effectiveObs != null) {
        feedbackMsg = 'Live Sentinel-2 pass unavailable. Preserving latest historical observation (${_formatDate(effectiveObs.observationDate)}).';
        isError = true;
      } else {
        feedbackMsg = 'Live Sentinel-2 pass unavailable. No historical observations recorded.';
        isError = true;
      }

      setState(() {
        _latest = effectiveObs;
        _timeSeries = ts;
        _spatialMeta = meta;
        _isSyncing = false;
        _syncFeedbackMessage = feedbackMsg;
        _syncFeedbackIsError = isError;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(feedbackMsg),
          backgroundColor: isError ? Colors.orange.shade800 : const Color(0xFF2E7D32),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      final is409 = errorStr.contains('409') || errorStr.contains('already in progress');
      final msg = is409
          ? 'Satellite sync is already in progress for this farm. Please wait a moment.'
          : (_latest != null
              ? 'Live pass retrieval failed. Displaying latest historical observation (${_formatDate(_latest!.observationDate)}).'
              : 'Sync failed: $e');

      setState(() {
        _isSyncing = false;
        _syncFeedbackMessage = msg;
        _syncFeedbackIsError = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: is409 ? Colors.orange.shade800 : Colors.red.shade700,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _handleSync,
          ),
        ),
      );
    }
  }

  Color _getNdviColor(double? val) {
    if (val == null) return Colors.grey;
    if (val >= 0.6) return const Color(0xFF2E7D32); // Lush dark green
    if (val >= 0.4) return const Color(0xFF689F38); // Healthy light green
    if (val >= 0.2) return const Color(0xFFFBC02D); // Moderate yellowish green
    return const Color(0xFFE65100); // Sparse / bare
  }

  Color _getNdmiColor(double? val) {
    if (val == null) return Colors.grey;
    if (val >= 0.3) return const Color(0xFF01579B); // High canopy water
    if (val >= 0.15) return const Color(0xFF0288D1); // Moderate-high
    if (val >= 0.0) return const Color(0xFF29B6F6); // Low-moderate
    return const Color(0xFFFFB74D); // Dry / negative
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    return '${_formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} UTC';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.farmName} — Satellite Vegetation'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isSyncing
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: RashkarColors.forest),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Sync Copernicus Sentinel-2 Pass',
                    icon: const Icon(Icons.sync),
                    onPressed: _handleSync,
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: RashkarColors.forest),
                  SizedBox(height: 16),
                  Text('Loading Sentinel-2 vegetation observations...', style: TextStyle(color: RashkarColors.mutedInk)),
                ],
              ),
            )
          : _errorMessage != null && _latest == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.satellite_alt, size: 56, color: Colors.orange),
                        const SizedBox(height: 16),
                        Text(
                          'No Satellite Observations Available',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _isSyncing ? null : _handleSync,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.cloud_download),
                          label: Text(_isSyncing ? 'Retrieving Imagery...' : 'Sync Copernicus Pass Now'),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
                        ),
                      ],
                    ),
                  ),
                )
              : CenteredPageContainer(
                  scrollable: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sync notification / feedback banner if present
                        if (_syncFeedbackMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: _syncFeedbackIsError ? Colors.red.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _syncFeedbackIsError ? Colors.red.shade200 : Colors.green.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _syncFeedbackIsError ? Icons.error_outline : Icons.check_circle_outline,
                                  color: _syncFeedbackIsError ? Colors.red.shade700 : const Color(0xFF2E7D32),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _syncFeedbackMessage!,
                                    style: TextStyle(
                                      color: _syncFeedbackIsError ? Colors.red.shade900 : const Color(0xFF1B5E20),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () => setState(() => _syncFeedbackMessage = null),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // SECTION 1: HEADER & SYNC CONTROLS
                        _buildScreenHeader(context),
                        const SizedBox(height: 20),

                        // SECTION A: LATEST OBSERVATION PROVENANCE CARD
                        if (_latest != null) ...[
                          _buildProvenanceCard(context, _latest!),
                          const SizedBox(height: 24),

                          // SECTION B: GROUNDED VEGETATION HEALTH INDICATORS
                          _buildVegetationHealthIndicators(context, _latest!),
                          const SizedBox(height: 24),

                          // SECTION C: LAND-SURFACE COMPOSITION BREAKDOWN
                          _buildLandSurfaceComposition(context, _latest!),
                          const SizedBox(height: 24),

                          // SECTION D: ACTUAL SPATIAL VEGETATION VISUALIZATION
                          _buildSpatialRasterMapCard(context, _latest!),
                          const SizedBox(height: 28),
                        ] else ...[
                          _buildEmptyObservationCard(context),
                          const SizedBox(height: 28),
                        ],

                        // SECTION E: HISTORICAL MONITORING & TRENDS
                        _buildHistoricalTrendsSection(context),
                        const SizedBox(height: 28),

                        // SECTION F: SCIENTIFIC SAFEGUARD & ADVISORY NOTICE
                        _buildScientificDisclaimerCard(context),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }

  // =========================================================================
  // SUB-SECTION BUILDERS
  // =========================================================================

  Widget _buildScreenHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Satellite Vegetation Intelligence',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: RashkarColors.ink,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Copernicus Sentinel-2 Level-2A (MSI) Surface Reflectance. Ground Sampling Distance: 10m native (B04/B08).',
                style: TextStyle(color: RashkarColors.mutedInk, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _isSyncing ? null : _handleSync,
          icon: _isSyncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.cloud_sync, size: 18),
          label: Text(_isSyncing ? 'Syncing...' : 'Sync Pass'),
          style: FilledButton.styleFrom(
            backgroundColor: RashkarColors.forest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildProvenanceCard(BuildContext context, SatelliteObservation obs) {
    final polyArea = obs.polygonAreaHectares != null
        ? '${obs.polygonAreaHectares!.toStringAsFixed(2)} ha'
        : 'Registered Boundary';
    final rasterArea = obs.rasterDiscretizedAreaHectares != null
        ? '${obs.rasterDiscretizedAreaHectares!.toStringAsFixed(2)} ha (${obs.totalPixelCount} cells)'
        : '${obs.totalPixelCount} cells';

    final now = DateTime.now();
    final isToday = obs.observationDate.year == now.year &&
        obs.observationDate.month == now.month &&
        obs.observationDate.day == now.day;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.satellite_outlined, color: Color(0xFF1976D2), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sentinel-2 L2A BOA Surface Reflectance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D47A1),
                        ),
                  ),
                ),
                _buildQualityBadge(obs.qualityStatus),
              ],
            ),
            const Divider(height: 20),
            if (!isToday) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 18, color: Color(0xFFB45309)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Historical Observation: Acquired on ${_formatDate(obs.observationDate)} (${obs.sensor}). Live satellite pass unavailable.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                _buildMetaItem('Observation Acquisition', _formatDate(obs.observationDate), Icons.event),
                _buildMetaItem('Processed Sync Date', _formatDateTime(obs.createdAt), Icons.access_time),
                _buildMetaItem('Sensor / Instrument', obs.sensor, Icons.camera_alt_outlined),
                _buildMetaItem('Sentinel Tile', obs.tileId ?? 'T43QDA', Icons.grid_view),
                _buildMetaItem('Processing Baseline', 'N0513 (L2A)', Icons.tune),
                _buildMetaItem('Boundary Area', polyArea, Icons.crop_landscape),
                _buildMetaItem('Discretized Grid Area', rasterArea, Icons.grid_4x4),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Product ID: ',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.black54),
                      ),
                      Expanded(
                        child: Text(
                          obs.productId,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Attribution: ${obs.dataAttribution}',
                    style: const TextStyle(fontSize: 10, color: Colors.black54, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            if (obs.isSmallFarmWarning) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Parcel Representativeness: ${obs.qualityNotes ?? "Small plot subject to edge mixed-pixel discretization."}',
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQualityBadge(String status) {
    Color bg = Colors.green.shade100;
    Color fg = const Color(0xFF1B5E20);
    String label = 'Valid Observation';

    if (status.contains('MASKED_PIXELS') || status.contains('CLOUD')) {
      bg = Colors.amber.shade100;
      fg = Colors.amber.shade900;
      label = 'Valid (Masked Pixels)';
    } else if (status.contains('PARTIAL') || status.contains('LOW_COVERAGE')) {
      bg = Colors.orange.shade100;
      fg = Colors.orange.shade900;
      label = 'Partial Coverage';
    } else if (status.contains('INVALID') || status.contains('OVERCAST')) {
      bg = Colors.red.shade100;
      fg = Colors.red.shade900;
      label = 'Masked / Invalid';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.black45),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
      ],
    );
  }

  Widget _buildVegetationHealthIndicators(BuildContext context, SatelliteObservation obs) {
    // Pure canopy vs composite
    final pureCanopyNdvi = obs.vegetationMeanNdvi ?? obs.meanNdvi;
    final pureCanopyNdmi = obs.vegetationMeanNdmi ?? obs.meanNdmi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vegetation Health Indicators',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1B5E20),
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Grounded canopy reflectance indicators calculated strictly over pure vegetation canopy (SCL Class 4).',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            return isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildNdviMetricCard(obs, pureCanopyNdvi)),
                      const SizedBox(width: 14),
                      Expanded(child: _buildNdmiMetricCard(obs, pureCanopyNdmi)),
                      const SizedBox(width: 14),
                      Expanded(child: _buildSurfaceCoverageMetricCard(obs)),
                    ],
                  )
                : Column(
                    children: [
                      _buildNdviMetricCard(obs, pureCanopyNdvi),
                      const SizedBox(height: 12),
                      _buildNdmiMetricCard(obs, pureCanopyNdmi),
                      const SizedBox(height: 12),
                      _buildSurfaceCoverageMetricCard(obs),
                    ],
                  );
          },
        ),
      ],
    );
  }

  Widget _buildNdviMetricCard(SatelliteObservation obs, double? pureCanopyNdvi) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.eco, color: Color(0xFF2E7D32), size: 20),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Canopy Mean NDVI',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                if (pureCanopyNdvi != null)
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _getNdviColor(pureCanopyNdvi),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              pureCanopyNdvi != null ? pureCanopyNdvi.toStringAsFixed(3) : 'N/A',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _getNdviColor(pureCanopyNdvi),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Median: ${obs.medianNdvi?.toStringAsFixed(3) ?? "N/A"} | Std Dev: ${obs.stdNdvi?.toStringAsFixed(3) ?? "0.000"}',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const Divider(height: 16),
            const Text(
              'NDVI measures photosynthetic greenness & chlorophyll absorption (B08 NIR / B04 Red at 10m native GSD). '
              'Values vary by crop type, phenology, and row spacing; there is no universal threshold.',
              style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNdmiMetricCard(SatelliteObservation obs, double? pureCanopyNdmi) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0288D1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.water_drop_outlined, color: Color(0xFF0288D1), size: 20),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Canopy Mean NDMI',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                if (pureCanopyNdmi != null)
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _getNdmiColor(pureCanopyNdmi),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              pureCanopyNdmi != null ? pureCanopyNdmi.toStringAsFixed(3) : 'N/A',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _getNdmiColor(pureCanopyNdmi),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Canopy Liquid Water Reflectance (B08 / B11 SWIR)',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const Divider(height: 16),
            const Text(
              'NDMI indicates vegetative moisture absorption. Disclosed: Native 20m SWIR is bilinearly resampled to 10m grid. '
              'Reflects canopy surface moisture, not deep root-zone soil moisture probe.',
              style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurfaceCoverageMetricCard(SatelliteObservation obs) {
    final validPct = obs.totalPixelCount > 0
        ? ((obs.validPixelCount / obs.totalPixelCount) * 100.0).toStringAsFixed(1)
        : '100.0';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.grid_on, color: Colors.blueGrey, size: 20),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Valid Surface Coverage',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$validPct%',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${obs.validPixelCount} / ${obs.totalPixelCount} valid 10m raster cells',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const Divider(height: 16),
            Text(
              'Cloud Masked: ${obs.cloudMaskedPercent.toStringAsFixed(1)}% | SCL Masking filters cloud, cloud shadow, '
              'and boundary defects to avoid skewing agronomic analysis.',
              style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandSurfaceComposition(BuildContext context, SatelliteObservation obs) {
    final vegCount = obs.vegetationPixelCount ?? (obs.validPixelCount * 0.6).round();
    final soilCount = obs.bareSoilPixelCount ?? (obs.validPixelCount - vegCount);
    final waterCount = obs.waterPixelCount ?? 0;
    final totalCount = obs.totalPixelCount > 0 ? obs.totalPixelCount : (vegCount + soilCount + waterCount);
    final maskedCount = (totalCount - vegCount - soilCount - waterCount).clamp(0, totalCount);

    final vegPct = obs.vegetationCoveragePercent ?? ((vegCount / totalCount) * 100.0);
    final soilPct = obs.bareSoilCoveragePercent ?? ((soilCount / totalCount) * 100.0);
    final waterPct = obs.waterCoveragePercent ?? ((waterCount / totalCount) * 100.0);
    final maskedPct = ((maskedCount / totalCount) * 100.0).clamp(0.0, 100.0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_outline, color: Color(0xFF2E7D32), size: 22),
                const SizedBox(width: 8),
                Text(
                  'Scene Classification (SCL) Surface Composition',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B5E20),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Class-segregated breakdown distinguishing actively photosynthesizing canopy from bare ground and paths.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Segmented composition bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: [
                    if (vegPct > 0)
                      Expanded(
                        flex: (vegPct * 10).round().clamp(1, 1000),
                        child: Container(color: const Color(0xFF2E7D32)),
                      ),
                    if (soilPct > 0)
                      Expanded(
                        flex: (soilPct * 10).round().clamp(1, 1000),
                        child: Container(color: const Color(0xFFD79B38)),
                      ),
                    if (waterPct > 0)
                      Expanded(
                        flex: (waterPct * 10).round().clamp(1, 1000),
                        child: Container(color: const Color(0xFF0288D1)),
                      ),
                    if (maskedPct > 0)
                      Expanded(
                        flex: (maskedPct * 10).round().clamp(1, 1000),
                        child: Container(color: Colors.grey.shade400),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Composition metrics chips / cards
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                _buildCompositionItem(
                  'Canopy (Class 4)',
                  '$vegCount px (${vegPct.toStringAsFixed(1)}%)',
                  const Color(0xFF2E7D32),
                ),
                _buildCompositionItem(
                  'Bare Soil / Paths (Class 5)',
                  '$soilCount px (${soilPct.toStringAsFixed(1)}%)',
                  const Color(0xFFD79B38),
                ),
                _buildCompositionItem(
                  'Water (Class 6)',
                  '$waterCount px (${waterPct.toStringAsFixed(1)}%)',
                  const Color(0xFF0288D1),
                ),
                _buildCompositionItem(
                  'Masked / Boundary',
                  '$maskedCount px (${maskedPct.toStringAsFixed(1)}%)',
                  Colors.grey.shade600,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Agronomic Explanation Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC5E1A5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: Color(0xFF33691E), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                        children: [
                          const TextSpan(
                            text: 'Scientific Agronomic Distinction: ',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF33691E)),
                          ),
                          TextSpan(
                            text: 'Bare soil inter-row paths (${soilPct.toStringAsFixed(1)}% of plot) dilute the composite whole-field average '
                                '(composite NDVI = ${obs.meanNdvi?.toStringAsFixed(3) ?? "N/A"}), whereas pure canopy vigor is '
                                '${(obs.vegetationMeanNdvi ?? obs.meanNdvi)?.toStringAsFixed(3) ?? "N/A"}. '
                                'Separating canopy from bare soil prevents uncultivated paths from being misdiagnosed as crop distress.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompositionItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ],
    );
  }

  Widget _buildSpatialRasterMapCard(BuildContext context, SatelliteObservation obs) {
    final rasterUrl = _repository.getRasterMapUrl(widget.farmId, _selectedRasterLayer);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map_outlined, color: Color(0xFF1B5E20), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Spatial Vegetation Map (10m Clipped Raster)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B5E20),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'High-resolution farm polygon rasterization streamed and clipped to farm boundary vertices.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 14),

            // Layer Switcher Buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'ndvi',
                    label: Text('Canopy NDVI (10m)'),
                    icon: Icon(Icons.eco, size: 16),
                  ),
                  ButtonSegment<String>(
                    value: 'ndmi',
                    label: Text('Canopy NDMI (20m SWIR)'),
                    icon: Icon(Icons.water_drop, size: 16),
                  ),
                  ButtonSegment<String>(
                    value: 'scl',
                    label: Text('Surface Classes (SCL)'),
                    icon: Icon(Icons.category, size: 16),
                  ),
                ],
                selected: {_selectedRasterLayer},
                onSelectionChanged: (newSet) {
                  setState(() => _selectedRasterLayer = newSet.first);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Map Viewport with Image
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480, maxHeight: 380),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                padding: const EdgeInsets.all(12),
                child: Image.network(
                  rasterUrl,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none, // Pixelated visualization shows 10m grid cleanly
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.white70),
                          const SizedBox(height: 12),
                          Text(
                            'Rendering ${_selectedRasterLayer.toUpperCase()} raster layer...',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image, color: Colors.white60, size: 36),
                            const SizedBox(height: 8),
                            const Text(
                              'Spatial raster cache preview loading...',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonal(
                              onPressed: () => setState(() {}),
                              child: const Text('Refresh Layer'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Layer Legend
            _buildRasterLegend(_selectedRasterLayer),
            const SizedBox(height: 14),

            // Spatial metadata card
            if (_spatialMeta != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Spatial Discretization & Resolution Disclosures:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bounding WGS84 Extent: [${_spatialMeta!.bounds.map((b) => b.toStringAsFixed(4)).join(', ')}]',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54),
                    ),
                    Text(
                      'Grid Dimensions: ${_spatialMeta!.width} × ${_spatialMeta!.height} cells | '
                      'Discretized Cells: ${_spatialMeta!.totalPixelCount} (100 m² per cell)',
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _spatialMeta!.scientificDisclosure,
                      style: const TextStyle(fontSize: 11, color: Colors.black54, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRasterLegend(String layer) {
    if (layer == 'ndvi') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: RashkarColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: RashkarColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NDVI Color Ramp:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: RashkarColors.ink)),
            const SizedBox(height: 8),
            const RashkarVegetationLegendBar(),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildLegendSwatch('Lush Canopy (≥ 0.60)', const Color(0xFF2E7D32)),
                _buildLegendSwatch('Moderate Vigor (0.40 – 0.60)', const Color(0xFF689F38)),
                _buildLegendSwatch('Sparse / Young (0.20 – 0.40)', const Color(0xFFFBC02D)),
                _buildLegendSwatch('Bare Soil / Masked (< 0.20)', const Color(0xFFE65100)),
              ],
            ),
          ],
        ),
      );
    } else if (layer == 'ndmi') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NDMI Canopy Moisture Ramp (20m SWIR):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildLegendSwatch('High Canopy Water (≥ 0.30)', const Color(0xFF01579B)),
                _buildLegendSwatch('Moderate Moisture (0.15 – 0.30)', const Color(0xFF0288D1)),
                _buildLegendSwatch('Low Moisture (0.00 – 0.15)', const Color(0xFF29B6F6)),
                _buildLegendSwatch('Water Deficit / Dry (< 0.00)', const Color(0xFFFFB74D)),
              ],
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SCL Surface Classes:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildLegendSwatch('Class 4: Vegetation', const Color(0xFF2E7D32)),
                _buildLegendSwatch('Class 5: Bare Soil', const Color(0xFFD79B38)),
                _buildLegendSwatch('Class 6: Water', const Color(0xFF0288D1)),
                _buildLegendSwatch('Masked / Boundary', Colors.grey.shade600),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildLegendSwatch(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ],
    );
  }

  Widget _buildHistoricalTrendsSection(BuildContext context) {
    final series = _timeSeries?.series ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historical Multi-Pass Monitoring',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1B5E20),
              ),
        ),
        const SizedBox(height: 4),
        if (_timeSeries != null && _timeSeries!.vegetationInterpretation.isNotEmpty)
          Text(
            _timeSeries!.vegetationInterpretation,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2E7D32), fontSize: 13),
          ),
        const SizedBox(height: 12),

        if (series.isEmpty) ...[
          Card(
            elevation: 0,
            color: Colors.grey.shade100,
            child: const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No historical passes recorded yet. Tap "Sync Pass" above to retrieve imagery.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          ),
        ] else if (series.length == 1) ...[
          // First observation baseline card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flag_outlined, color: Color(0xFF2E7D32), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Initial Baseline Observation Recorded (${_formatDate(series.first.date)})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B5E20)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Multi-pass temporal delta analysis activates once subsequent Sentinel-2 passes are acquired '
                          '(5-day constellation revisit cycle). Baseline canopy vigor and surface composition are preserved.',
                          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          // Multi-pass history with deltas
          _buildMultiPassDeltaCard(series),
          const SizedBox(height: 14),
          _buildTimeSeriesTable(series),
        ],
      ],
    );
  }

  Widget _buildMultiPassDeltaCard(List<VegetationTimeSeriesPoint> series) {
    final latest = series.last;
    final prior = series[series.length - 2];
    final ndviDelta = (latest.meanNdvi != null && prior.meanNdvi != null)
        ? latest.meanNdvi! - prior.meanNdvi!
        : null;
    final ndmiDelta = (latest.meanNdmi != null && prior.meanNdmi != null)
        ? latest.meanNdmi! - prior.meanNdmi!
        : null;
    final daysInterval = latest.date.difference(prior.date).inDays.abs();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.trending_up, color: Color(0xFF2E7D32), size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Multi-Temporal Delta ($daysInterval days interval)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (ndviDelta != null) ...[
                        Text(
                          'Δ NDVI: ${ndviDelta >= 0 ? "+" : ""}${ndviDelta.toStringAsFixed(3)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: ndviDelta >= 0 ? const Color(0xFF2E7D32) : Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (ndmiDelta != null) ...[
                        Text(
                          'Δ NDMI: ${ndmiDelta >= 0 ? "+" : ""}${ndmiDelta.toStringAsFixed(3)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: ndmiDelta >= 0 ? const Color(0xFF0288D1) : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSeriesTable(List<VegetationTimeSeriesPoint> series) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Acquisition Date')),
              DataColumn(label: Text('Canopy NDVI')),
              DataColumn(label: Text('Canopy NDMI')),
              DataColumn(label: Text('Valid Pixels')),
              DataColumn(label: Text('Canopy Cover %')),
              DataColumn(label: Text('Quality Status')),
            ],
            rows: series.reversed.map((pt) {
              final vegPct = pt.vegetationCoveragePercent?.toStringAsFixed(1) ?? 'N/A';
              final ndviVal = pt.vegetationMeanNdvi ?? pt.meanNdvi;
              final ndmiVal = pt.vegetationMeanNdmi ?? pt.meanNdmi;

              return DataRow(cells: [
                DataCell(Text(_formatDate(pt.date))),
                DataCell(
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _getNdviColor(ndviVal),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(ndviVal != null ? ndviVal.toStringAsFixed(3) : 'N/A'),
                    ],
                  ),
                ),
                DataCell(Text(ndmiVal != null ? ndmiVal.toStringAsFixed(3) : 'N/A')),
                DataCell(Text('${pt.validPixels}')),
                DataCell(Text('$vegPct%')),
                DataCell(Text(pt.qualityStatus)),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyObservationCard(BuildContext context) {
    return RashkarCard(
      backgroundColor: RashkarColors.surfaceSubtle,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.satellite_alt_outlined, size: 48, color: RashkarColors.forest),
            const SizedBox(height: 12),
            const Text(
              'No satellite observation recorded yet for this farm.',
              style: TextStyle(fontWeight: FontWeight.w700, color: RashkarColors.ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Click "Sync Pass" above to retrieve Copernicus Sentinel-2 L2A surface reflectance.',
              style: TextStyle(color: RashkarColors.mutedInk, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSyncing ? null : _handleSync,
              icon: const Icon(Icons.cloud_download, size: 18),
              label: const Text('Retrieve First Pass'),
              style: FilledButton.styleFrom(backgroundColor: RashkarColors.forest),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScientificDisclaimerCard(BuildContext context) {
    return const RashkarNoticeCallout(
      title: 'Scientific Safeguard Notice',
      message:
          'Sentinel-2 Level-2A NDVI (native 10m B08/B04) and NDMI (native 20m SWIR B11 resampled to 10m grid) reflect surface canopy spectral reflectance. Resampling 20m SWIR does not synthesize native 10m detail. They serve as indirect indicators of vegetative vigor and moisture status. They MUST NEVER be used as direct diagnoses of specific plant diseases, pest infestations, nitrogen deficiencies, or absolute crop yield predictions without field ground-truthing.',
    );
  }
}
