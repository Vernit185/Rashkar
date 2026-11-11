import 'package:flutter/material.dart';
import '../../models/farm_health_models.dart';

/// Section 2: Overall Evidence Status Board Widget
///
/// Displays categorical counts for AVAILABLE, PARTIALLY_AVAILABLE, NOT_AVAILABLE,
/// STALE, and INSUFFICIENT_EVIDENCE across all 5 evaluated domains, alongside
/// individual domain status indicators and actionable summary guidance.
///
/// In accordance with institutional agronomic standards, NO universal farm health
/// score or percentage is calculated or displayed.
class OverallEvidenceCard extends StatelessWidget {
  final OverallEvidenceOverview overview;
  final SoilDomainSummary soil;
  final WaterDomainSummary water;
  final SatelliteDomainSummary satellite;
  final WeatherDomainSummary weather;
  final CropContextDomainSummary cropContext;

  const OverallEvidenceCard({
    super.key,
    required this.overview,
    required this.soil,
    required this.water,
    required this.satellite,
    required this.weather,
    required this.cropContext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Title & Evidence Count
            Row(
              children: [
                Icon(
                  Icons.assessment_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Evidence Status Board',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Evidence completeness across 5 agricultural domains',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Categorical Counts Board
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCountChip(
                  label: 'Available',
                  count: overview.domainsAvailable,
                  color: const Color(0xFF2E7D32),
                  bgColor: const Color(0xFFE8F5E9),
                  icon: Icons.check_circle_outline_rounded,
                ),
                _buildCountChip(
                  label: 'Partial',
                  count: overview.domainsPartiallyAvailable,
                  color: const Color(0xFFF57C00),
                  bgColor: const Color(0xFFFFF3E0),
                  icon: Icons.warning_amber_rounded,
                ),
                _buildCountChip(
                  label: 'Stale',
                  count: overview.domainsStale,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  icon: Icons.history_rounded,
                ),
                _buildCountChip(
                  label: 'Not Available',
                  count: overview.domainsNotAvailable,
                  color: const Color(0xFF757575),
                  bgColor: const Color(0xFFF5F5F5),
                  icon: Icons.remove_circle_outline_rounded,
                ),
                if (overview.domainsInsufficientEvidence > 0)
                  _buildCountChip(
                    label: 'Insufficient',
                    count: overview.domainsInsufficientEvidence,
                    color: const Color(0xFFC62828),
                    bgColor: const Color(0xFFFFEBEE),
                    icon: Icons.error_outline_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Actionable Summary Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      overview.actionableSummary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Domain Status Breakdown Grid
            Text(
              'Domain Availability Breakdown',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDomainStatusPill('Soil Intelligence', soil.availabilityState),
                _buildDomainStatusPill('Water Quality', water.availabilityState),
                _buildDomainStatusPill('Sentinel-2 Satellite', satellite.availabilityState),
                _buildDomainStatusPill('Weather & Climate', weather.availabilityState),
                _buildDomainStatusPill('Crop Feasibility', cropContext.availabilityState),
              ],
            ),
            const SizedBox(height: 12),

            // Governance Notice (Truth in UI)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No composite health score is computed (Liebig’s Law of the Minimum applied).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Colors.blueGrey[700],
                        fontStyle: FontStyle.italic,
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

  Widget _buildCountChip({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainStatusPill(String domainName, DataAvailabilityState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: state.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: state.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(state.icon, size: 14, color: state.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              domainName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: state.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              state.displayName,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: state.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
