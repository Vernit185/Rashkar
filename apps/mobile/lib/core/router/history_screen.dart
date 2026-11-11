import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cropnet_mobile/core/router/farm_state.dart';
import 'package:cropnet_mobile/core/router/route_paths.dart';
import 'package:cropnet_mobile/features/history/assessment_history_repository.dart';
import 'package:cropnet_mobile/shared/theme/rashkar_colors.dart';
import 'package:cropnet_mobile/shared/widgets/centered_page_container.dart';
import 'package:cropnet_mobile/shared/widgets/rashkar_ui.dart';
import 'package:cropnet_mobile/shared/widgets/responsive_grid.dart';

export 'package:cropnet_mobile/features/history/assessment_history_repository.dart'
    show AssessmentHistoryRecord, AssessmentHistoryRepository;

/// Soil & Crop Assessment History Screen styled with the Rashkar Verification & Claims language.
class AssessmentHistoryScreen extends StatefulWidget {
  const AssessmentHistoryScreen({super.key});

  @override
  State<AssessmentHistoryScreen> createState() => _AssessmentHistoryScreenState();
}

class _AssessmentHistoryScreenState extends State<AssessmentHistoryScreen> {
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Baramati', 'Indapur', 'Maval', 'Mulshi'];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AssessmentHistoryRepository.instance,
      builder: (context, _) {
        final allRecords = AssessmentHistoryRepository.instance.records;
        final filtered = allRecords.where((r) {
          if (_selectedFilter == 'All') return true;
          return r.taluka.toLowerCase() == _selectedFilter.toLowerCase();
        }).toList();

        return Scaffold(
          backgroundColor: RashkarColors.canvas,
          appBar: AppBar(
            title: const Text('Assessment History'),
          ),
          body: CenteredPageContainer(
            maxWidth: 1120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RashkarHeroBanner(
                  eyebrow: 'SESSION RECORDS',
                  title: 'Past Farm Checks',
                  subtitle: 'Past soil, crop, and farm checks recorded during this session.',
                ),
                const SizedBox(height: 14),
                ResponsiveGrid.metrics(
                  mobileColumns: 2,
                  tabletColumns: 4,
                  desktopColumns: 4,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    RashkarMetricTile(
                      icon: Icons.analytics_outlined,
                      label: 'Total Runs',
                      value: '${allRecords.length}',
                    ),
                    RashkarMetricTile(
                      icon: Icons.terrain_outlined,
                      label: 'Soil Profiles',
                      value: '${allRecords.where((r) => r.assessmentType.contains("Soil")).length}',
                    ),
                    RashkarMetricTile(
                      icon: Icons.grass_outlined,
                      label: 'Crop Feasibility',
                      value: '${allRecords.where((r) => r.assessmentType.contains("Crop")).length}',
                    ),
                    RashkarMetricTile(
                      icon: Icons.location_on_outlined,
                      label: 'Regions',
                      value: '${allRecords.map((r) => r.taluka).toSet().length}',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = filter == _selectedFilter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            filter,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : RashkarColors.ink,
                            ),
                          ),
                          selected: isSelected,
                          checkmarkColor: Colors.white,
                          selectedColor: RashkarColors.ink,
                          backgroundColor: RashkarColors.surface,
                          onSelected: (val) {
                            if (val) setState(() => _selectedFilter = filter);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: RashkarCard(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: const BoxDecoration(
                                    color: RashkarColors.mintBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.history_rounded, size: 30, color: RashkarColors.forest),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'No assessment history yet.',
                                  style: TextStyle(
                                    color: RashkarColors.ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Assessments will be automatically recorded here when you run Soil Intelligence extractions, Crop Feasibility evaluations, or AI Advisory dialogues.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: RashkarColors.mutedInk, fontSize: 13),
                                ),
                                const SizedBox(height: 18),
                                ElevatedButton.icon(
                                  onPressed: () => context.go(RoutePaths.soilTesting),
                                  icon: const Icon(Icons.science_outlined),
                                  label: const Text('Analyse Soil Profile Now'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (ctx, idx) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildRecordCard(filtered[idx]),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecordCard(AssessmentHistoryRecord record) {
    final farmExists = FarmRepository.instance.getFarmById(record.farmId) != null;
    final isSoil = record.assessmentType.contains('Soil');

    return RashkarCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              isSoil
                  ? RashkarSeverityBadge.success(record.assessmentType, icon: Icons.terrain_outlined, compact: true)
                  : RashkarSeverityBadge.info(record.assessmentType, icon: Icons.grass_outlined, compact: true),
              const Spacer(),
              Text(
                _formatDate(record.date),
                style: const TextStyle(fontSize: 12, color: RashkarColors.mutedInk, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${record.farmName} (${record.taluka})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: RashkarColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            record.summary,
            style: const TextStyle(fontSize: 13, color: RashkarColors.ink, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RashkarColors.canvas,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: RashkarColors.border),
            ),
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              children: record.keyMetrics.entries.map((e) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 11, color: RashkarColors.mutedInk)),
                    const SizedBox(height: 2),
                    Text(
                      e.value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: RashkarColors.forest,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.verified_outlined, size: 14, color: RashkarColors.forest),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Provenance: ${record.provenance}',
                  style: const TextStyle(fontSize: 11.5, color: RashkarColors.mutedInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (farmExists && isSoil)
                OutlinedButton.icon(
                  onPressed: () => context.push(RoutePaths.soilDetailPath(record.farmId)),
                  icon: const Icon(Icons.terrain_outlined, size: 16),
                  label: const Text('View Soil Report'),
                )
              else if (record.cropId != null)
                OutlinedButton.icon(
                  onPressed: () => context.push(RoutePaths.cropDetailPath(record.cropId!)),
                  icon: const Icon(Icons.grass_outlined, size: 16),
                  label: Text(record.cropName != null ? 'View ${record.cropName}' : 'View Crop Guide'),
                )
              else if (farmExists)
                OutlinedButton.icon(
                  onPressed: () => context.push(RoutePaths.farmDetailPath(record.farmId)),
                  icon: const Icon(Icons.pin_drop_outlined, size: 16),
                  label: const Text('View Farm'),
                ),
              ElevatedButton.icon(
                onPressed: () {
                  FarmRepository.instance.selectedFarmId = record.farmId;
                  context.go(RoutePaths.advisory);
                },
                icon: const Icon(Icons.psychology_outlined, size: 16),
                label: const Text('Jump to Advisory'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
