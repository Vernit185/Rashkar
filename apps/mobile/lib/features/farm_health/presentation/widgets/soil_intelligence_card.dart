import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_paths.dart';
import '../../models/farm_health_models.dart';

/// Section 3: Soil Intelligence Summary Widget
///
/// Displays pH, Organic Carbon, EC, NPK, provenance badge, data age,
/// missing tests alerts, and navigation to the Soil Testing workspace.
class SoilIntelligenceCard extends StatelessWidget {
  final String farmId;
  final SoilDomainSummary soil;

  const SoilIntelligenceCard({
    super.key,
    required this.farmId,
    required this.soil,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = soil.availabilityState;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header: Title & Availability State Pill
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF8D6E63).withValues(alpha: 0.15),
                  radius: 18,
                  child: const Icon(
                    Icons.layers_rounded,
                    color: Color(0xFF5D4037),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Soil Intelligence Summary',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (soil.laboratoryName != null)
                        Text(
                          soil.laboratoryName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _buildStateBadge(state),
              ],
            ),
            const SizedBox(height: 12),

            // Provenance & Age Metadata Chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (soil.provenance != null)
                  _buildMetaChip(
                    icon: Icons.verified_outlined,
                    label: _formatProvenance(soil.provenance!),
                    color: const Color(0xFF388E3C),
                  ),
                if (soil.dataAgeDays != null)
                  _buildMetaChip(
                    icon: Icons.access_time_rounded,
                    label: '${soil.dataAgeDays} days old',
                    color: state == DataAvailabilityState.stale ? const Color(0xFFD97706) : Colors.grey[700]!,
                  ),
                if (soil.sampleDepth != null)
                  _buildMetaChip(
                    icon: Icons.straighten_rounded,
                    label: 'Depth: ${soil.sampleDepth}',
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
                        'Soil test report is ${soil.dataAgeDays ?? 1095} days old (>3 years). Nutrient and carbon levels may have shifted significantly. Updated testing recommended.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Content: Empty State vs Key Indicators
            if (state == DataAvailabilityState.notAvailable) ...[
              _buildEmptyState(context),
            ] else ...[
              _buildIndicatorsGrid(context),
              if (soil.missingCriticalParameters.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildMissingParamsWarning(soil.missingCriticalParameters),
              ],
              if (soil.agronomicNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildAgronomicNotes(soil.agronomicNotes),
              ],
            ],

            const SizedBox(height: 16),
            // Deep-link Action Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text('Manage Soil & Lab Reports'),
                onPressed: () => context.push(RoutePaths.soilDetailPath(farmId)),
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

  String _formatProvenance(String prov) {
    switch (prov.toUpperCase()) {
      case 'LABORATORY_CONFIRMED':
        return 'Lab Verified';
      case 'SPATIALLY_ESTIMATED_ISRIC':
        return 'ISRIC SoilGrids 250m';
      case 'MIXED_DUAL_SOURCE':
        return 'Mixed Lab & Spatial';
      default:
        return prov;
    }
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
          Icon(Icons.inventory_2_outlined, size: 36, color: Colors.grey[400]),
          const SizedBox(height: 8),
          const Text(
            'No Soil Intelligence Available',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'No soil test reports uploaded or spatial profiles generated for this farm parcel.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorsGrid(BuildContext context) {
    final k = soil.keyIndicators;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceAround,
        children: [
          _buildParamTile('pH', k.soilPh != null ? k.soilPh!.toStringAsFixed(1) : '—', ''),
          _buildParamTile('Organic C', k.organicCarbonPct != null ? '${k.organicCarbonPct!.toStringAsFixed(2)}%' : '—', ''),
          _buildParamTile('EC', k.electricalConductivityDsM != null ? k.electricalConductivityDsM!.toStringAsFixed(2) : '—', 'dS/m'),
          _buildParamTile('Avail. N', k.availableNitrogenKgHa != null ? k.availableNitrogenKgHa!.toStringAsFixed(0) : '—', 'kg/ha'),
          _buildParamTile('Avail. P', k.availablePhosphorusKgHa != null ? k.availablePhosphorusKgHa!.toStringAsFixed(1) : '—', 'kg/ha'),
          _buildParamTile('Avail. K', k.availablePotassiumKgHa != null ? k.availablePotassiumKgHa!.toStringAsFixed(0) : '—', 'kg/ha'),
          _buildParamTile('Texture', k.soilTexture ?? '—', ''),
          _buildParamTile('CEC', k.cationExchangeCapacity != null ? k.cationExchangeCapacity!.toStringAsFixed(1) : '—', 'cmol/kg'),
        ],
      ),
    );
  }

  Widget _buildParamTile(String label, String value, String unit) {
    final isMissing = value == '—';
    return SizedBox(
      width: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isMissing ? Colors.grey[400] : Colors.black87,
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  Widget _buildMissingParamsWarning(List<String> missing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFE65100)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Unmeasured: ${missing.join(", ")}',
              style: const TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgronomicNotes(List<String> notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: notes.map((note) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Expanded(
                child: Text(
                  note,
                  style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
