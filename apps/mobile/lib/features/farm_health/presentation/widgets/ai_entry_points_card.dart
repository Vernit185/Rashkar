import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/farm_state.dart';
import '../../../../core/router/route_paths.dart';
import '../../models/farm_health_models.dart';

/// Section 8: AI Assistant Entry Points Widget
///
/// Generates contextual prompt recommendation chips tailored to the active farm's
/// soil, water, satellite, weather, and crop bottlenecks, and provides seamless
/// navigation to the AI Agricultural Advisory workspace.
class AiEntryPointsCard extends StatelessWidget {
  final FarmHealthSnapshotResponse snapshot;

  const AiEntryPointsCard({
    super.key,
    required this.snapshot,
  });

  List<String> _generateContextualQuestions() {
    final questions = <String>[];

    // Water salinity question
    final waterEc = snapshot.water.keyIndicators.electricalConductivityDsM;
    if (waterEc != null) {
      questions.add(
        'Water EC is ${waterEc.toStringAsFixed(2)} dS/m — which crops tolerate this salinity level?',
      );
    } else if (snapshot.water.availabilityState == DataAvailabilityState.notAvailable) {
      questions.add(
        'Water quality is unmeasured — what hazards should I test before irrigating?',
      );
    }

    // Soil question
    final soilPh = snapshot.soil.keyIndicators.soilPh;
    if (soilPh != null) {
      questions.add(
        'Soil pH is ${soilPh.toStringAsFixed(1)} — what nutrient management is recommended?',
      );
    } else if (snapshot.soil.availabilityState == DataAvailabilityState.notAvailable) {
      questions.add(
        'What soil test parameters should I prioritize in ${snapshot.taluka}?',
      );
    }

    // Satellite question
    if (snapshot.satellite.canopyNdvi != null) {
      questions.add(
        'Explain Sentinel-2 canopy vigor (${snapshot.satellite.canopyNdvi!.toStringAsFixed(2)}) vs bare soil paths',
      );
    }

    // Crop question
    if (snapshot.cropContext.suitableCrops.isNotEmpty) {
      final crop = snapshot.cropContext.suitableCrops.first.commonName;
      questions.add(
        'What are the critical irrigation stages for $crop?',
      );
    }

    // Climate question
    questions.add(
      'How does local 30-year climatology in ${snapshot.district} affect crop risk?',
    );

    return questions.take(4).toList();
  }

  void _navigateToAdvisory(BuildContext context, {String? initialQuery}) {
    // Synchronize selected farm ID into FarmRepository state for Advisory
    FarmRepository.instance.selectedFarmId = snapshot.farmId;
    context.push(RoutePaths.advisory, extra: initialQuery);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = _generateContextualQuestions();

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
                  backgroundColor: const Color(0xFF673AB7).withValues(alpha: 0.15),
                  radius: 18,
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: Color(0xFF673AB7),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Assistant Entry Points',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Contextual agronomic dialogue grounded in farm snapshot',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Prompt chips prompt text
            Text(
              'Recommended Inquiries for this Farm:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),

            // Contextual Prompt Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: questions.map((query) {
                return ActionChip(
                  avatar: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF673AB7)),
                  label: Text(
                    query,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: const Color(0xFFEDE7F6),
                  side: const BorderSide(color: Color(0xFFD1C4E9)),
                  onPressed: () => _navigateToAdvisory(context, initialQuery: query),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Primary Action Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Consult CropNet AI Advisor'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5E35B1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _navigateToAdvisory(context),
              ),
            ),
            const SizedBox(height: 12),

            // Grounding & Governance Notice
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
                  const Icon(Icons.gavel_rounded, size: 14, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CropNet AI explanations are strictly bound to deterministic agricultural rules and institutional citations. AI does not invent chemical dosages or override decisions.',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey[700], fontStyle: FontStyle.italic),
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
}
