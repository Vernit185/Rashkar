import 'package:flutter/material.dart';

import '../../../../shared/theme/rashkar_colors.dart';
import '../../../../shared/widgets/centered_page_container.dart';
import '../../../../shared/widgets/rashkar_ui.dart';
import '../../models/water_models.dart';
import '../../data/water_repository.dart';

/// Farm Irrigation Water Intelligence Workspace.
/// Provides:
/// - Farm-specific irrigation sources (borewell, open well, canal, etc.)
/// - Seasonal availability and measured vs farmer-reported capacity
/// - Sourced water test laboratory reports
/// - Deterministic SAR and RSC calculations
/// - Institutional evaluation rules (BIS IS 11624:1986 and ICAR-CSSRI Karnal)
class WaterWorkspaceScreen extends StatefulWidget {
  final String farmId;
  final String farmName;

  const WaterWorkspaceScreen({
    super.key,
    required this.farmId,
    this.farmName = 'Farm',
  });

  @override
  State<WaterWorkspaceScreen> createState() => _WaterWorkspaceScreenState();
}

class _WaterWorkspaceScreenState extends State<WaterWorkspaceScreen> {
  final WaterRepository _repository = WaterRepository();

  bool _isLoading = true;
  String? _errorMessage;

  List<WaterSource> _sources = [];
  List<WaterReportSummary> _reports = [];
  WaterQualityEvaluation? _evaluation;

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
      final sourcesFuture = _repository.getWaterSources(widget.farmId);
      final reportsFuture = _repository.getWaterReports(widget.farmId);
      final evalFuture = _repository.getWaterEvaluation(widget.farmId);

      final results = await Future.wait([
        sourcesFuture,
        reportsFuture,
        evalFuture.catchError((_) => WaterQualityEvaluation(
              farmId: widget.farmId,
              evaluations: [],
              calculatedIndices: WaterCalculatedIndices(
                sarStatus: 'UNAVAILABLE',
                rscStatus: 'UNAVAILABLE',
                inputsUsed: {},
                calculationNotes: ['No confirmed laboratory water tests yet.'],
              ),
              soilDrainageCaution:
                  'Ensure adequate drainage before applying high salinity water.',
              cropSensitivityOverview: {},
              disclaimer: 'Institutional evaluation requires lab water test data.',
            )),
      ]);

      setState(() {
        _sources = results[0] as List<WaterSource>;
        _reports = results[1] as List<WaterReportSummary>;
        _evaluation = results[2] as WaterQualityEvaluation;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load water intelligence: $e';
        _isLoading = false;
      });
    }
  }

  void _showAddSourceDialog() {
    final nameCtrl = TextEditingController(text: 'Primary Borewell');
    final descCtrl = TextEditingController();
    final hoursCtrl = TextEditingController(text: '6.0');
    final capacityCtrl = TextEditingController(text: '10000');
    WaterSourceType selectedType = WaterSourceType.borewell;
    String seasonal = 'perennial';
    String reliability = 'reliable';
    String irrigation = 'drip';
    String provenance = 'FARMER_REPORTED';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Add Irrigation Water Source'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Source Name',
                      hintText: 'e.g., North Borewell, River Pump 1',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Location / Remarks',
                      hintText: 'e.g., Near pump room, South corner',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<WaterSourceType>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Source Type'),
                    items: WaterSourceType.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.displayName)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDlgState(() => selectedType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: seasonal,
                    decoration: const InputDecoration(labelText: 'Seasonal Availability'),
                    items: const [
                      DropdownMenuItem(value: 'perennial', child: Text('Perennial (Year-round)')),
                      DropdownMenuItem(value: 'seasonal_monsoon', child: Text('Monsoon & Post-Monsoon')),
                      DropdownMenuItem(value: 'kharif_only', child: Text('Kharif Only')),
                      DropdownMenuItem(value: 'summer_dry', child: Text('Dries in Summer')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => seasonal = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: reliability,
                          decoration: const InputDecoration(labelText: 'Reliability'),
                          items: const [
                            DropdownMenuItem(value: 'reliable', child: Text('Reliable (Daily)')),
                            DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                            DropdownMenuItem(value: 'intermittent', child: Text('Intermittent')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDlgState(() => reliability = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: hoursCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Daily Hours',
                            hintText: 'e.g. 6.0',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: irrigation,
                          decoration: const InputDecoration(labelText: 'Irrigation Method'),
                          items: const [
                            DropdownMenuItem(value: 'drip', child: Text('Drip Irrigation')),
                            DropdownMenuItem(value: 'sprinkler', child: Text('Sprinkler')),
                            DropdownMenuItem(value: 'furrow', child: Text('Furrow / Ridge')),
                            DropdownMenuItem(value: 'flood', child: Text('Flood / Basin')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDlgState(() => irrigation = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: capacityCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Flow Rate (L/h)',
                            hintText: 'Capacity',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: provenance,
                    decoration: const InputDecoration(labelText: 'Capacity Origin'),
                    items: const [
                      DropdownMenuItem(value: 'FARMER_REPORTED', child: Text('Farmer-Reported Estimate')),
                      DropdownMenuItem(value: 'MEASURED', child: Text('Pump / Meter Measured')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => provenance = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  await _repository.createWaterSource(
                    widget.farmId,
                    sourceType: selectedType,
                    name: nameCtrl.text.trim().isEmpty ? 'Borewell' : nameCtrl.text.trim(),
                    locationDescription: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    seasonalAvailability: seasonal,
                    reliability: reliability,
                    dailyAvailableHours: double.tryParse(hoursCtrl.text),
                    irrigationMethod: irrigation,
                    measuredCapacityLph: double.tryParse(capacityCtrl.text),
                    capacityProvenance: provenance,
                  );
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error adding source: $e')),
                  );
                }
              },
              child: const Text('Save Source'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getHazardColor(String level) {
    switch (level.toUpperCase()) {
      case 'SAFE':
      case 'LOW':
        return Colors.green.shade700;
      case 'MEDIUM':
      case 'MARGINAL':
        return Colors.orange.shade800;
      case 'HIGH':
      case 'RESTRICTED':
        return Colors.deepOrange.shade800;
      case 'VERY_HIGH':
      case 'HAZARDOUS':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.farmName} — Water Intelligence'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: RashkarColors.extremeFg),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _loadData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : CenteredPageContainer(
                  scrollable: true,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SECTION 1: WATER SOURCES
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Irrigation Water Sources',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: RashkarColors.ink,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Manage on-farm borewells, canals, ponds and tracked availability.',
                                    style: TextStyle(color: RashkarColors.mutedInk),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: _showAddSourceDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Source'),
                              style: FilledButton.styleFrom(
                                backgroundColor: RashkarColors.forest,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_sources.isEmpty)
                          const RashkarCard(
                            backgroundColor: RashkarColors.surfaceSubtle,
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text('No water sources recorded yet. Click "Add Source" to register one.'),
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 400,
                              mainAxisExtent: 180,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _sources.length,
                            itemBuilder: (context, index) {
                              final src = _sources[index];
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
                                          Icon(
                                            src.sourceType == WaterSourceType.borewell
                                                ? Icons.water_drop
                                                : Icons.waves,
                                            color: const Color(0xFF1976D2),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              src.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Chip(
                                            label: Text(
                                              src.sourceType.displayName,
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Text('Availability: ${src.seasonalAvailability.toUpperCase()}'),
                                      Text('Reliability: ${src.reliability} (${src.dailyAvailableHours ?? 0} hrs/day)'),
                                      const Spacer(),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            src.measuredCapacityLph != null
                                                ? '${src.measuredCapacityLph!.toInt()} L/h'
                                                : 'Capacity unmeasured',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          Chip(
                                            label: Text(
                                              src.capacityProvenance,
                                              style: const TextStyle(fontSize: 10, color: Colors.black87),
                                            ),
                                            backgroundColor: src.capacityProvenance == 'MEASURED'
                                                ? Colors.blue.shade100
                                                : Colors.amber.shade100,
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 32),

                        // SECTION 2: CALCULATED INDICES (SAR & RSC)
                        Text(
                          'Calculated Agricultural Water Indices',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Deterministically computed using ionic concentrations in meq/L.',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            // SAR Card
                            Expanded(
                              child: Card(
                                elevation: 2,
                                color: const Color(0xFFF1F8E9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Sodium Adsorption Ratio (SAR)',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          Icon(Icons.science, color: Color(0xFF33691E)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _evaluation?.calculatedIndices.sar != null
                                            ? '${_evaluation!.calculatedIndices.sar}'
                                            : 'Unavailable',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: _evaluation?.calculatedIndices.sar != null
                                              ? const Color(0xFF2E7D32)
                                              : Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Formula: Na / √((Ca + Mg) / 2) [meq/L]',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Status: ${_evaluation?.calculatedIndices.sarStatus ?? "UNAVAILABLE"}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // RSC Card
                            Expanded(
                              child: Card(
                                elevation: 2,
                                color: const Color(0xFFE8F5E9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Residual Sodium Carbonate (RSC)',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          Icon(Icons.water, color: Color(0xFF1B5E20)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _evaluation?.calculatedIndices.rsc != null
                                            ? '${_evaluation!.calculatedIndices.rsc} meq/L'
                                            : 'Unavailable',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: _evaluation?.calculatedIndices.rsc != null
                                              ? const Color(0xFF2E7D32)
                                              : Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Formula: (CO3 + HCO3) - (Ca + Mg) [meq/L]',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Status: ${_evaluation?.calculatedIndices.rscStatus ?? "UNAVAILABLE"}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // SECTION 3: INSTITUTIONAL RULE EVALUATION
                        Text(
                          'Institutional Water Quality Evaluation',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Evaluated strictly against BIS IS 11624:1986 and ICAR-CSSRI Karnal Guidelines.',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 16),

                        if (_evaluation != null && _evaluation!.evaluations.isNotEmpty)
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _evaluation!.evaluations.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _evaluation!.evaluations[index];
                              final color = _getHazardColor(item.hazardLevel);
                              return Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Chip(
                                            label: Text(
                                              item.hazardLevel,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            backgroundColor: color,
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              '${item.parameterName}: ${item.observedValue} ${item.observedUnit} — ${item.hazardTitle}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.managementGuidance,
                                        style: const TextStyle(fontSize: 13, height: 1.4),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Standard: ${item.sourceCitation}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          Card(
                            elevation: 0,
                            color: Colors.grey.shade100,
                            child: const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: Text('No laboratory test data to evaluate. Upload a water test report to see rule-based findings.'),
                              ),
                            ),
                          ),

                        const SizedBox(height: 32),

                        // SECTION 4: LABORATORY TEST REPORTS LIST
                        Text(
                          'Laboratory Water Reports',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Uploaded physical water testing documents with verification audit status.',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 16),

                        if (_reports.isEmpty)
                          Card(
                            elevation: 0,
                            color: Colors.grey.shade100,
                            child: const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: Text('No water laboratory reports uploaded for this farm.'),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _reports.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final rep = _reports[index];
                              return ListTile(
                                tileColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                leading: const Icon(Icons.description, color: Color(0xFF1B5E20)),
                                title: Text(rep.originalFilename, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  'Lab: ${rep.laboratoryName ?? "Testing Lab"} • ${rep.measurementCount} parameters',
                                ),
                                trailing: Chip(
                                  label: Text(rep.reviewStatus, style: const TextStyle(fontSize: 11)),
                                  backgroundColor: rep.reviewStatus == 'CONFIRMED'
                                      ? Colors.green.shade100
                                      : Colors.amber.shade100,
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 24),

                        // CGWB Notice Banner
                        Container(
                          padding: const EdgeInsets.all(14.0),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            border: Border.all(color: Colors.amber.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber, size: 24),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'REGIONAL CONTEXT NOTICE: Regional Central Ground Water Board (CGWB) aquifer data '
                                  'is provided for geological context only and is NEVER substituted for tested on-farm water quality. '
                                  'All farm decisions require physical laboratory test reports.',
                                  style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
