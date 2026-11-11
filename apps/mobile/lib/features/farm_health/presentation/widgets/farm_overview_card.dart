import 'package:flutter/material.dart';
import '../../models/farm_health_models.dart';

/// Section 1: Farm Overview Widget
///
/// Displays farm name, location (taluka, district, state), area in ha and acres,
/// snapshot timestamp, and a refresh action button.
class FarmOverviewCard extends StatelessWidget {
  final FarmHealthSnapshotResponse snapshot;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  const FarmOverviewCard({
    super.key,
    required this.snapshot,
    required this.onRefresh,
    this.isRefreshing = false,
  });

  String _formatDateTime(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min UTC';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF214E34), // RashkarColors.forest (solid, no gradients)
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  radius: 26,
                  child: const Icon(
                    Icons.agriculture_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot.farmName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${snapshot.taluka}, ${snapshot.district}, ${snapshot.state}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Refresh Button
                Tooltip(
                  message: snapshot.isFromCache
                      ? 'Offline — Tap to retry synchronization'
                      : 'Force refresh farm health snapshot',
                  child: isRefreshing
                      ? const Padding(
                          padding: EdgeInsets.all(10.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            snapshot.isFromCache ? Icons.sync_problem_rounded : Icons.refresh_rounded,
                            color: Colors.white,
                          ),
                          onPressed: onRefresh,
                        ),
                ),
              ],
            ),
          ),

          // Details row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _buildInfoBadge(
                  context,
                  icon: Icons.square_foot_rounded,
                  label: 'Farm Area',
                  value:
                      '${snapshot.calculatedAreaHectares.toStringAsFixed(2)} ha (${snapshot.calculatedAreaAcres.toStringAsFixed(2)} ac)',
                ),
                _buildInfoBadge(
                  context,
                  icon: Icons.schedule_rounded,
                  label: 'Snapshot Assembled',
                  value: _formatDateTime(snapshot.snapshotTimestamp),
                ),
                _buildInfoBadge(
                  context,
                  icon: snapshot.isFromCache ? Icons.wifi_off_rounded : Icons.cloud_done_rounded,
                  label: 'Sync Status',
                  value: snapshot.isFromCache ? 'Cached Offline' : 'Live Synced',
                  valueColor: snapshot.isFromCache ? const Color(0xFFD97706) : const Color(0xFF2E7D32),
                ),
                _buildInfoBadge(
                  context,
                  icon: Icons.verified_user_outlined,
                  label: 'Contract Version',
                  value: 'v${snapshot.contractVersion}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: valueColor ?? theme.colorScheme.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
