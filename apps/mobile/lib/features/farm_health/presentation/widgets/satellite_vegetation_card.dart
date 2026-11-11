import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_paths.dart';
import '../../models/farm_health_models.dart';

/// Section 5: Satellite Vegetation Summary Widget
///
/// Displays Copernicus Sentinel-2 L2A observations, Pure Class 4 Canopy NDVI & NDMI,
/// bare soil vs vegetation coverage %, valid pixel count, small-farm warning,
/// mandatory scientific disclaimer, and deep link to the Satellite Vegetation workspace.
class SatelliteVegetationCard extends StatelessWidget {
  final String farmId;
  final SatelliteDomainSummary satellite;

  const SatelliteVegetationCard({
    super.key,
    required this.farmId,
    required this.satellite,
  });

  Color _getNdviColor(double? val) {
    if (val == null) return Colors.grey;
    if (val >= 0.6) return const Color(0xFF2E7D32); // Lush dark green
    if (val >= 0.4) return const Color(0xFF689F38); // Healthy light green
    if (val >= 0.2) return const Color(0xFFFBC02D); // Moderate yellowish green
    return const Color(0xFFE65100); // Sparse / bare soil
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = satellite.availabilityState;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF388E3C).withValues(alpha: 0.15),
                  radius: 18,
                  child: const Icon(
                    Icons.satellite_alt_rounded,
                    color: Color(0xFF2E7D32),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Satellite Vegetation Summary',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Copernicus Sentinel-2 L2A (10m Optical)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStateBadge(state),
              ],
            ),
            const SizedBox(height: 12),

            // Metadata Chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (satellite.provenance != null)
                  _buildMetaChip(
                    icon: Icons.verified_outlined,
                    label: satellite.provenance!,
                    color: const Color(0xFF1565C0),
                  ),
                if (satellite.observationDate != null)
                  _buildMetaChip(
                    icon: Icons.calendar_today_rounded,
                    label: _formatDate(satellite.observationDate),
                    color: const Color(0xFF2E7D32),
                  ),
                if (satellite.observationDate != null && (satellite.observationAgeDays ?? 0) > 0)
                  _buildMetaChip(
                    icon: Icons.history_rounded,
                    label: 'Historical (${_formatDate(satellite.observationDate)})',
                    color: const Color(0xFFB45309),
                  ),
                if (satellite.observationAgeDays != null)
                  _buildMetaChip(
                    icon: Icons.access_time_rounded,
                    label: '${satellite.observationAgeDays} days ago',
                    color: state == DataAvailabilityState.stale ? const Color(0xFFD97706) : Colors.grey[700]!,
                  ),
                if (satellite.validPixelCount > 0)
                  _buildMetaChip(
                    icon: Icons.grid_view_rounded,
                    label: '${satellite.validPixelCount} valid 10m pixels',
                    color: Colors.blueGrey,
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Stale Warning Banner if STALE
            if (state == DataAvailabilityState.stale) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 18, color: Color(0xFFB45309)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Satellite observation is ${satellite.observationAgeDays ?? 30} days old (>30 days). Historical canopy vigor may not reflect current vegetative stage. Trigger satellite sync.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Small Farm Warning Banner
            if (satellite.isSmallFarmWarning) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFE65100)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Small Farm Warning: Parcel area is < 0.5 ha (< 5 Sentinel-2 10m pixels). Satellite indices may have edge-pixel mixing.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Content: Empty State vs Metrics
            if (state == DataAvailabilityState.notAvailable) ...[
              _buildEmptyState(context),
            ] else ...[
              // Primary Indices Grid (Pure Canopy NDVI & NDMI)
              _buildIndicesGrid(context),
              const SizedBox(height: 12),

              // Surface Coverage Breakdown Bar
              if (satellite.vegetationCoveragePercent != null || satellite.bareSoilCoveragePercent != null)
                _buildCoverageBar(context),

              // Agronomic Interpretation
              if (satellite.agronomicInterpretation != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.eco_rounded, size: 16, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          satellite.agronomicInterpretation!,
                          style: TextStyle(fontSize: 12, color: Colors.green[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 14),
            // Mandatory Scientific Disclaimer
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      satellite.scientificDisclaimer,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            // Deep-link Action Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.satellite_outlined, size: 18),
                label: const Text('Open Satellite Vegetation Workspace'),
                onPressed: () => context.push(RoutePaths.farmVegetationPath(farmId)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateBadge(DataAvailabilityState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: state.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: state.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(state.icon, size: 14, color: state.color),
          const SizedBox(width: 4),
          Text(
            state.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: state.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicesGrid(BuildContext context) {
    final ndviColor = _getNdviColor(satellite.canopyNdvi);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceAround,
        children: [
          _buildIndexBox(
            label: 'Canopy NDVI',
            subLabel: 'Class 4 Pure Canopy',
            value: satellite.canopyNdvi != null ? satellite.canopyNdvi!.toStringAsFixed(2) : '—',
            color: ndviColor,
          ),
          _buildIndexBox(
            label: 'Canopy NDMI',
            subLabel: 'Leaf Moisture',
            value: satellite.canopyNdmi != null ? satellite.canopyNdmi!.toStringAsFixed(2) : '—',
            color: const Color(0xFF0288D1),
          ),
          _buildIndexBox(
            label: 'Bare Soil NDVI',
            subLabel: 'Inter-row Paths',
            value: satellite.bareSoilMeanNdvi != null ? satellite.bareSoilMeanNdvi!.toStringAsFixed(2) : '—',
            color: const Color(0xFF8D6E63),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexBox({
    required String label,
    required String subLabel,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Text(
          subLabel,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverageBar(BuildContext context) {
    final veg = satellite.vegetationCoveragePercent ?? 0.0;
    final soil = satellite.bareSoilCoveragePercent ?? 0.0;
    final other = (100.0 - veg - soil).clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text('Surface Composition', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            Text(
              '${veg.toStringAsFixed(1)}% Veg / ${soil.toStringAsFixed(1)}% Soil',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (veg > 0)
                  Expanded(
                    flex: (veg * 10).toInt(),
                    child: Container(color: const Color(0xFF2E7D32)),
                  ),
                if (soil > 0)
                  Expanded(
                    flex: (soil * 10).toInt(),
                    child: Container(color: const Color(0xFF8D6E63)),
                  ),
                if (other > 0)
                  Expanded(
                    flex: (other * 10).toInt(),
                    child: Container(color: Colors.grey[300]),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.satellite_alt_outlined, size: 36, color: Colors.grey[400]),
          const SizedBox(height: 8),
          const Text(
            'No Satellite Synchronization Recorded',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Zero Copernicus Sentinel-2 L2A observations recorded for this farm boundary. Trigger satellite sync to compute canopy vigor.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
