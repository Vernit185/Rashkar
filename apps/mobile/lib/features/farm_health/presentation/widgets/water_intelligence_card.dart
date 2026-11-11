import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_paths.dart';
import '../../models/farm_health_models.dart';

/// Section 4: Water Intelligence Summary Widget
///
/// Displays water sources, irrigation methods, key quality parameters (pH, EC, TDS, SAR, RSC),
/// institutional hazard evaluations (BIS IS 11624:2019 / ICAR-CSSRI), and alerts for unmeasured tests.
class WaterIntelligenceCard extends StatelessWidget {
  final String farmId;
  final WaterDomainSummary water;

  const WaterIntelligenceCard({
    super.key,
    required this.farmId,
    required this.water,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = water.availabilityState;

    return Card(
      elevation: 0,
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
                  backgroundColor: const Color(0xFF0288D1).withValues(alpha: 0.15),
                  radius: 18,
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Color(0xFF0288D1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Water Intelligence Summary',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${water.registeredSourcesCount} source(s) registered',
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

            // Age & Lab Metadata
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (water.provenance != null)
                  _buildMetaChip(
                    icon: Icons.verified_outlined,
                    label: water.provenance!,
                    color: const Color(0xFF0288D1),
                  ),
                if (water.laboratoryName != null)
                  _buildMetaChip(
                    icon: Icons.biotech_rounded,
                    label: water.laboratoryName!,
                    color: const Color(0xFF0288D1),
                  ),
                if (water.dataAgeDays != null)
                  _buildMetaChip(
                    icon: Icons.access_time_rounded,
                    label: '${water.dataAgeDays} days old',
                    color: state == DataAvailabilityState.stale ? const Color(0xFFD97706) : Colors.grey[700]!,
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
                        'Water test is ${water.dataAgeDays ?? 365} days old (>1 year). Groundwater salinity fluctuates post-monsoon; updated testing required.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Content: Empty State vs Registered Sources & Water Quality
            if (state == DataAvailabilityState.notAvailable) ...[
              _buildEmptyState(context),
            ] else ...[
              // Sources List
              if (water.sources.isNotEmpty) ...[
                Text(
                  'Registered Sources',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                ...water.sources.map((s) => _buildSourceRow(s)),
                const SizedBox(height: 14),
              ],

              // Water Quality Parameters Grid
              Text(
                'Water Quality Parameters',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              _buildIndicatorsGrid(context),

              // Institutional Evaluations (BIS IS 11624:2019 / ICAR-CSSRI)
              if (water.institutionalEvaluations.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Institutional Hazard Evaluations',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                ...water.institutionalEvaluations.map((eval) => _buildEvaluationCard(eval)),
              ],

              if (water.missingCriticalParameters.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildMissingParamsWarning(water.missingCriticalParameters),
              ],
            ],

            const SizedBox(height: 16),
            // Deep-link Action Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.water_drop_outlined, size: 18),
                label: const Text('Open Water Quality Workspace'),
                onPressed: () => context.push(RoutePaths.farmWaterPath(farmId)),
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

  Widget _buildSourceRow(WaterSourceSummaryItem source) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(_getSourceIcon(source.sourceType), size: 18, color: const Color(0xFF0288D1)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${_capitalize(source.sourceType)} • ${_capitalize(source.seasonalAvailability)} • Method: ${_capitalize(source.irrigationMethod)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (source.measuredCapacityLph != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE1F5FE),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${source.measuredCapacityLph!.toStringAsFixed(0)} L/h',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0288D1)),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getSourceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'borewell':
        return Icons.vertical_align_bottom_rounded;
      case 'open_well':
        return Icons.circle_outlined;
      case 'canal':
        return Icons.alt_route_rounded;
      case 'farm_pond':
        return Icons.pool_rounded;
      default:
        return Icons.water_drop_outlined;
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

  Widget _buildIndicatorsGrid(BuildContext context) {
    final k = water.keyIndicators;
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
          _buildParamTile('pH', k.ph != null ? k.ph!.toStringAsFixed(1) : '—', ''),
          _buildParamTile('EC', k.electricalConductivityDsM != null ? k.electricalConductivityDsM!.toStringAsFixed(2) : '—', 'dS/m'),
          _buildParamTile('TDS', k.tdsMgL != null ? k.tdsMgL!.toStringAsFixed(0) : '—', 'mg/L'),
          _buildParamTile('SAR', k.sar != null ? k.sar!.toStringAsFixed(2) : '—', k.sarStatus ?? ''),
          _buildParamTile('RSC', k.rscMeqL != null ? k.rscMeqL!.toStringAsFixed(2) : '—', 'meq/L'),
          _buildParamTile('Chloride', k.chlorideMeqL != null ? k.chlorideMeqL!.toStringAsFixed(1) : '—', 'meq/L'),
          _buildParamTile('Boron', k.boronMgL != null ? k.boronMgL!.toStringAsFixed(2) : '—', 'mg/L'),
        ],
      ),
    );
  }

  Widget _buildParamTile(String label, String value, String unit) {
    final isMissing = value == '—';
    return SizedBox(
      width: 76,
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
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildEvaluationCard(WaterEvaluationFinding eval) {
    final color = eval.hazardColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  eval.hazardTitle,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  eval.hazardLevel,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            eval.managementGuidance,
            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
          ),
          const SizedBox(height: 4),
          Text(
            'Standard: ${eval.standardApplied}',
            style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic),
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
          Icon(Icons.water_drop_outlined, size: 36, color: Colors.grey[400]),
          const SizedBox(height: 8),
          const Text(
            'No Water Intelligence Available',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Zero water sources registered and no laboratory water test reports uploaded for this farm.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
