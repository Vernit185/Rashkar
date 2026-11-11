import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_paths.dart';
import '../../models/farm_health_models.dart';

/// Section 6: Weather & Climate Summary Widget
///
/// Displays observed current weather, 5-day forecast outlook, 30-year climatology normals,
/// active weather alerts, and deep link to the Weather workspace.
class WeatherSummaryCard extends StatelessWidget {
  final String farmId;
  final WeatherDomainSummary weather;

  const WeatherSummaryCard({
    super.key,
    required this.farmId,
    required this.weather,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = weather.availabilityState;
    final cur = weather.currentWeather;
    final fc = weather.forecast;
    final clim = weather.climateNormals;

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
                  backgroundColor: const Color(0xFF0288D1).withValues(alpha: 0.15),
                  radius: 18,
                  child: const Icon(
                    Icons.cloud_queue_rounded,
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
                        'Weather & Climate Summary',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'OpenWeather + 30-Yr Climatology (NASA POWER)',
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

            // Metadata Chips: Provenance
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildMetaChip(
                  icon: Icons.cloud_outlined,
                  label: weather.currentWeather.provenance,
                  color: const Color(0xFF0288D1),
                ),
                _buildMetaChip(
                  icon: Icons.history_edu_outlined,
                  label: weather.climateNormals.provenance,
                  color: const Color(0xFF5D4037),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stale Warning Banner if STALE
            if (state == DataAvailabilityState.stale) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.history_rounded, size: 18, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Weather cache is over 2 hours old. Live agro-meteorological conditions may have changed.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Content: Empty State vs Weather Data
            if (state == DataAvailabilityState.notAvailable) ...[
              _buildEmptyState(context),
            ] else ...[
              // Current Weather Row
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE1F5FE),
                      Color(0xFFE8F5E9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(_getWeatherIcon(cur.weatherCondition), size: 36, color: const Color(0xFF0288D1)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                cur.temperatureC != null ? '${cur.temperatureC!.toStringAsFixed(1)}°C' : '—',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  cur.weatherCondition ?? 'Clear',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Humidity: ${cur.humidityPercent?.toStringAsFixed(0) ?? "—"}% • Rain: ${cur.precipitationMm?.toStringAsFixed(1) ?? "0.0"} mm • Wind: ${cur.windSpeedMs?.toStringAsFixed(1) ?? "—"} m/s',
                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Forecast Outlook & 30-Year Climatology
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 320;
                  final forecastBox = Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.wb_sunny_outlined, size: 14, color: Colors.amber),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${fc.forecastDaysCount}-Day Forecast',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Next 48h Rain: ${fc.next48hRainExpectedMm?.toStringAsFixed(1) ?? "0.0"} mm',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Range: ${fc.tempMinC?.toStringAsFixed(0) ?? "—"}°C – ${fc.tempMaxC?.toStringAsFixed(0) ?? "—"}°C',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );

                  final climateBox = Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.public_rounded, size: 14, color: Colors.teal),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '30-Yr Climatology',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Annual: ${clim.annualRainfallMm?.toStringAsFixed(0) ?? "—"} mm',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Monsoon: ${clim.monsoonRainfallMm?.toStringAsFixed(0) ?? "—"} mm',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        forecastBox,
                        const SizedBox(height: 10),
                        climateBox,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: forecastBox),
                      const SizedBox(width: 10),
                      Expanded(child: climateBox),
                    ],
                  );
                },
              ),

              if (fc.weatherAlerts.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF5350)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFC62828)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Alert: ${fc.weatherAlerts.join(", ")}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFC62828), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 16),
            // Deep-link Action Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.thermostat_outlined, size: 18),
                label: const Text('View Weather & Climate Details'),
                onPressed: () => context.push(RoutePaths.weatherDetailPath(farmId)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getWeatherIcon(String? condition) {
    if (condition == null) return Icons.wb_sunny_rounded;
    switch (condition.toLowerCase()) {
      case 'rain':
      case 'drizzle':
        return Icons.water_drop_rounded;
      case 'thunderstorm':
        return Icons.flash_on_rounded;
      case 'snow':
        return Icons.ac_unit_rounded;
      case 'clouds':
        return Icons.cloud_rounded;
      case 'haze':
      case 'mist':
      case 'fog':
        return Icons.blur_on_rounded;
      default:
        return Icons.wb_sunny_rounded;
    }
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
          Icon(Icons.cloud_off_outlined, size: 36, color: Colors.grey[400]),
          const SizedBox(height: 8),
          const Text(
            'Weather Observations Unavailable',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Live agro-meteorological data could not be retrieved from provider.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
              style: TextStyle(
                fontSize: 11,
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
}
