import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cropnet_mobile/core/router/farm_state.dart';
import 'package:cropnet_mobile/core/utils/native_file_picker.dart';
import 'package:cropnet_mobile/main.dart';
import 'package:cropnet_mobile/core/network/api_exception.dart';

import '../../../../shared/responsive/breakpoints.dart';
import '../../../../shared/theme/rashkar_tokens.dart';
import '../../../../shared/theme/rashkar_components.dart';
import '../../../../shared/widgets/centered_page_container.dart';
import '../../../../shared/widgets/responsive_scaffold.dart';
import '../../data/agri_repository.dart';
import '../../models/agri_models.dart';

/// RASHKAR Design Language - Agri Intelligence Screen
/// Features:
/// 1. Crop Doctor: Image-based disease screening with preliminary AI badge
/// 2. Heat Risk: 11-crop stage physiology, growth stage selector, worker WBGT advisory
class AgriIntelligenceScreen extends StatefulWidget {
  final AgriIntelligenceRepository? repository;
  final int initialTab;

  const AgriIntelligenceScreen({super.key, this.repository, this.initialTab = 0});

  @override
  State<AgriIntelligenceScreen> createState() => _AgriIntelligenceScreenState();
}

class _AgriIntelligenceScreenState extends State<AgriIntelligenceScreen> {
  late final AgriIntelligenceRepository _repo;
  int _activeTab = 0; // 0: Crop Doctor, 1: Heat Risk

  // Crop Doctor state
  PlatformFile? _picked;
  bool _analyzing = false;
  CropDoctorResult? _doctorResult;
  String? _doctorError;

  // Crop heat state
  String _cropCode = 'soybean';
  String? _selectedCropStage;
  static const Map<String, List<String>> _cropStages = {
    'soybean': ['stage_germination', 'stage_vegetative', 'stage_flowering', 'stage_pod_development', 'stage_maturity'],
    'cotton': ['stage_germination', 'stage_vegetative', 'stage_flowering', 'stage_boll_formation', 'stage_maturity'],
    'jowar': ['stage_germination', 'stage_vegetative', 'stage_flowering', 'stage_grain_filling', 'stage_maturity'],
    'onion': ['stage_vegetative', 'stage_bulb_initiation', 'stage_bulb_development', 'stage_maturity'],
    'sugarcane': ['stage_germination', 'stage_grand_growth', 'stage_maturity'],
    'wheat': ['stage_vegetative', 'stage_flowering', 'stage_grain_filling', 'stage_maturity'],
    'gram': ['stage_vegetative', 'stage_flowering', 'stage_pod_development', 'stage_maturity'],
    'tur': ['stage_vegetative', 'stage_flowering', 'stage_pod_development', 'stage_maturity'],
    'bajra': ['stage_germination', 'stage_vegetative', 'stage_flowering', 'stage_grain_filling', 'stage_maturity'],
    'maize': ['stage_germination', 'stage_vegetative', 'stage_flowering', 'stage_grain_filling', 'stage_maturity'],
    'groundnut': ['stage_germination', 'stage_flowering', 'stage_pod_development', 'stage_maturity'],
  };
  final _tmaxCtrl = TextEditingController(text: '38');
  final _tminCtrl = TextEditingController(text: '23');
  bool _cropHeatLoading = false;
  CropHeatResult? _cropHeatResult;
  String? _cropHeatError;

  // Farm heat-risk state
  List<FarmItem> _farms = const [];
  String? _selectedFarmId;
  bool _farmRiskLoading = false;
  FarmHeatRiskResult? _farmRiskResult;
  String? _farmRiskError;

  // Worker heat state
  final _airTempCtrl = TextEditingController(text: '37');
  final _rhCtrl = TextEditingController(text: '60');
  final _windCtrl = TextEditingController(text: '1.5');
  final _solarCtrl = TextEditingController(text: '700');
  String _workload = 'heavy';
  bool _workerHeatLoading = false;
  WorkerHeatResult? _workerHeatResult;
  String? _workerHeatError;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AgriIntelligenceRepository.instance;
    _activeTab = widget.initialTab;
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    try {
      if (FarmRepository.instance.farms.isEmpty) {
        await FarmRepository.instance.loadFarms();
      }
      final list = FarmRepository.instance.farms;
      if (!mounted) return;
      setState(() {
        _farms = list;
        if (list.isNotEmpty) {
          _selectedFarmId = FarmRepository.instance.selectedFarmId ?? list.first.id;
        }
      });
      if (_selectedFarmId != null) {
        _assessFarmHeat();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tmaxCtrl.dispose();
    _tminCtrl.dispose();
    _airTempCtrl.dispose();
    _rhCtrl.dispose();
    _windCtrl.dispose();
    _solarCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyze() async {
    PlatformFile? picked;
    try {
      if (kIsWeb) {
        picked = await pickDocumentNative(
          allowedExtensions: const ['jpg', 'jpeg', 'png'],
        );
      } else {
        picked = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png'],
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _doctorError = 'Could not open the photo chooser. Please try again.');
      }
      return;
    }
    if (picked == null) return;
    setState(() {
      _picked = picked;
      _doctorResult = null;
      _doctorError = null;
    });
  }

  Future<void> _analyzeCrop() async {
    final file = _picked;
    if (file == null) return;
    setState(() {
      _analyzing = true;
      _doctorError = null;
      _doctorResult = null;
    });

    try {
      final bytes = await file.readAsBytes();
      final name = file.name.toLowerCase();
      final res = await _repo.analyzeCropImage(
        bytes: bytes,
        fileName: file.name,
        mimeType: name.endsWith('.png') ? 'image/png' : 'image/jpeg',
      );
      if (!mounted) return;
      setState(() {
        _doctorResult = res;
        _analyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _doctorError = e is ApiException ? e.message : 'The photo could not be analysed. Please try again.';
      });
    }
  }

  Future<void> _assessFarmHeat() async {
    final fid = _selectedFarmId;
    if (fid == null) return;
    setState(() {
      _farmRiskLoading = true;
      _farmRiskError = null;
    });
    try {
      final res = await _repo.assessFarmHeat(
        fid,
        cropCode: _cropCode,
      );
      if (!mounted) return;
      setState(() {
        _farmRiskResult = res;
        _farmRiskLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _farmRiskLoading = false;
        _farmRiskError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _assessCropHeat() async {
    setState(() {
      _cropHeatLoading = true;
      _cropHeatError = null;
    });
    try {
      final res = await _repo.assessCropHeat(
        cropCode: _cropCode,
        tmaxC: double.tryParse(_tmaxCtrl.text) ?? 38,
        tminC: double.tryParse(_tminCtrl.text) ?? 23,
        growthStage: _selectedCropStage,
      );
      if (!mounted) return;
      setState(() {
        _cropHeatResult = res;
        _cropHeatLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cropHeatLoading = false;
        _cropHeatError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _assessWorkerHeat() async {
    setState(() {
      _workerHeatLoading = true;
      _workerHeatError = null;
    });
    try {
      final res = await _repo.assessWorkerHeat(
        airTempC: double.tryParse(_airTempCtrl.text) ?? 37,
        relativeHumidityPct: double.tryParse(_rhCtrl.text) ?? 60,
        windSpeedMs: double.tryParse(_windCtrl.text) ?? 1.5,
        solarIrradianceWm2: double.tryParse(_solarCtrl.text) ?? 700,
        workloadCategory: _workload,
      );
      if (!mounted) return;
      setState(() {
        _workerHeatResult = res;
        _workerHeatLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _workerHeatLoading = false;
        _workerHeatError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      currentIndex: 0,
      destinations: const [],
      body: CenteredPageContainer(
        maxWidth: AppBreakpoints.maxContentWidthReadable,
        scrollable: true,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RashkarPageHeader(
              title: 'Agri Intelligence',
              subtitle: 'Crop Doctor screening and stage-specific heat risk physiology',
            ),
            const SizedBox(height: 12),
            RashkarSegmentedControl<int>(
              options: const {
                0: 'Crop Doctor',
                1: 'Heat Risk',
              },
              selected: _activeTab,
              onSelected: (v) => setState(() => _activeTab = v),
            ),
            const SizedBox(height: 20),
            if (_activeTab == 0) _buildCropDoctorTab() else _buildHeatRiskTab(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CROP DOCTOR TAB
  // ---------------------------------------------------------------------------
  Widget _buildCropDoctorTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RashkarNotice(
          title: 'Screening Aid',
          message:
              'Image-based screening assistance. Always verify diagnoses with an accredited local agronomy extension service before chemical pesticide or fungicide intervention.',
          type: RashkarNoticeType.info,
        ),
        const SizedBox(height: 16),
        RashkarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Leaf Image Capture', style: RashkarTypography.cardTitle),
                  RashkarPreliminaryBadge(),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload a clear, focused image of the affected plant leaf showing discoloration, pustules, or lesions.',
                style: RashkarTypography.body,
              ),
              const SizedBox(height: 16),
              RashkarButton(
                label: _picked == null ? 'Select Leaf Photo' : 'Change Selected Photo',
                leadingIcon: Icons.camera_alt_outlined,
                variant: RashkarButtonVariant.accent,
                onPressed: _analyzing ? null : _pickAndAnalyze,
              ),
              if (_picked != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: const BoxDecoration(
                    color: RashkarColors.sand,
                    borderRadius: RashkarRadii.buttonBorderRadius,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.image_outlined, color: RashkarColors.forest, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _picked!.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                RashkarButton(
                  label: _analyzing ? 'Analyzing Leaf Pattern...' : 'Run Disease Diagnosis',
                  leadingIcon: Icons.search_rounded,
                  isLoading: _analyzing,
                  onPressed: _analyzing ? null : _analyzeCrop,
                ),
              ],
            ],
          ),
        ),
        if (_doctorError != null) ...[
          const SizedBox(height: 16),
          RashkarNotice(
            title: 'Diagnosis Failed',
            message: _doctorError!,
            type: RashkarNoticeType.error,
          ),
        ],
        if (_doctorResult != null) ...[
          const SizedBox(height: 16),
          _buildDoctorResultCard(_doctorResult!),
        ],
      ],
    );
  }

  Widget _buildDoctorResultCard(CropDoctorResult r) {
    final status = r.isHealthy ? RashkarStatusLevel.low : RashkarStatusLevel.high;

    return Container(
      decoration: BoxDecoration(
        color: RashkarColors.white,
        borderRadius: RashkarRadii.cardBorderRadius,
        border: Border.all(color: RashkarColors.line, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: status.softColor,
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: status.color,
                    borderRadius: RashkarRadii.iconTileBorderRadius,
                  ),
                  child: Icon(status.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.diagnosis,
                              style: TextStyle(
                                fontFamily: RashkarTypography.primaryFont,
                                fontSize: 18.0,
                                fontWeight: FontWeight.w800,
                                color: status.textColor,
                              ),
                            ),
                          ),
                          const RashkarPreliminaryBadge(),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Crop: ${r.crop} • Confidence: ${r.confidence.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: status.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Management & Cultural Practices', style: RashkarTypography.cardTitle),
                    RashkarListenButton(),
                  ],
                ),
                const SizedBox(height: 12),
                for (final tip in r.advice)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 3.0),
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: RashkarColors.leafSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, color: RashkarColors.forest, size: 12),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(tip, style: RashkarTypography.body),
                        ),
                      ],
                    ),
                  ),
                if (r.disclaimer != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(r.disclaimer!, style: RashkarTypography.meta),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEAT RISK TAB
  // ---------------------------------------------------------------------------
  Widget _buildHeatRiskTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFarmHeatSection(),
        const SizedBox(height: 24),
        const Text('Crop Heat-Stress Simulation', style: RashkarTypography.sectionTitle),
        const SizedBox(height: 4),
        const Text(
          'Verified thermal physiology for 11 crops across key vegetative and reproductive stages.',
          style: RashkarTypography.meta,
        ),
        const SizedBox(height: 14),
        RashkarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _cropCode,
                decoration: const InputDecoration(labelText: 'Crop Species'),
                items: const [
                  DropdownMenuItem(value: 'soybean', child: Text('Soybean')),
                  DropdownMenuItem(value: 'cotton', child: Text('Cotton')),
                  DropdownMenuItem(value: 'jowar', child: Text('Sorghum (Jowar)')),
                  DropdownMenuItem(value: 'onion', child: Text('Onion')),
                  DropdownMenuItem(value: 'sugarcane', child: Text('Sugarcane')),
                  DropdownMenuItem(value: 'wheat', child: Text('Wheat')),
                  DropdownMenuItem(value: 'gram', child: Text('Chickpea (Gram)')),
                  DropdownMenuItem(value: 'tur', child: Text('Pigeon Pea (Tur)')),
                  DropdownMenuItem(value: 'bajra', child: Text('Pearl Millet (Bajra)')),
                  DropdownMenuItem(value: 'maize', child: Text('Maize')),
                  DropdownMenuItem(value: 'groundnut', child: Text('Groundnut')),
                ],
                onChanged: (v) => setState(() {
                  _cropCode = v ?? 'soybean';
                  _selectedCropStage = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCropStage,
                decoration: const InputDecoration(
                  labelText: 'Growth Stage (optional — auto-derived if omitted)',
                ),
                items: (_cropStages[_cropCode] ?? const [])
                    .map((s) => DropdownMenuItem<String>(value: s, child: Text(_stageLabel(s))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCropStage = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tmaxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Forecast Max °C'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _tminCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Forecast Min °C'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RashkarButton(
                label: _cropHeatLoading ? 'Assessing Thermal Risk...' : 'Assess Crop Heat Risk',
                leadingIcon: Icons.thermostat_rounded,
                isLoading: _cropHeatLoading,
                onPressed: _cropHeatLoading ? null : _assessCropHeat,
              ),
            ],
          ),
        ),
        if (_cropHeatError != null) ...[
          const SizedBox(height: 16),
          RashkarNotice(title: 'Assessment Error', message: _cropHeatError!, type: RashkarNoticeType.error),
        ],
        if (_cropHeatResult != null) ...[
          const SizedBox(height: 16),
          _buildCropHeatCard(_cropHeatResult!),
        ],
        const SizedBox(height: 28),
        const Text('Worker Heat-Hazard (WBGT Advisory)', style: RashkarTypography.sectionTitle),
        const SizedBox(height: 4),
        const Text(
          'ACGIH 2023 / ISO 7243:2017 screening limits for field workers under radiant solar load.',
          style: RashkarTypography.meta,
        ),
        const SizedBox(height: 14),
        RashkarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _airTempCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Air Temp °C'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _rhCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Relative Humidity %'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _windCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Wind Speed m/s'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _solarCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Solar W/m²'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _workload,
                decoration: const InputDecoration(labelText: 'Physical Workload Category'),
                items: const [
                  DropdownMenuItem(value: 'light', child: Text('Light (inspection / driving)')),
                  DropdownMenuItem(value: 'moderate', child: Text('Moderate (weeding / spraying)')),
                  DropdownMenuItem(value: 'heavy', child: Text('Heavy (harvesting / digging)')),
                  DropdownMenuItem(value: 'very_heavy', child: Text('Very Heavy (manual tilling)')),
                ],
                onChanged: (v) => setState(() => _workload = v ?? 'heavy'),
              ),
              const SizedBox(height: 16),
              RashkarButton(
                label: _workerHeatLoading ? 'Calculating WBGT...' : 'Assess Worker Heat Hazard',
                leadingIcon: Icons.engineering_rounded,
                variant: RashkarButtonVariant.secondary,
                isLoading: _workerHeatLoading,
                onPressed: _workerHeatLoading ? null : _assessWorkerHeat,
              ),
            ],
          ),
        ),
        if (_workerHeatError != null) ...[
          const SizedBox(height: 16),
          RashkarNotice(title: 'Hazard Error', message: _workerHeatError!, type: RashkarNoticeType.error),
        ],
        if (_workerHeatResult != null) ...[
          const SizedBox(height: 16),
          _buildWorkerHeatCard(_workerHeatResult!),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildFarmHeatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Active Farm Heat Outlook', style: RashkarTypography.sectionTitle),
        const SizedBox(height: 4),
        const Text(
          'Uses active 5-day weather forecast and crop growth context.',
          style: RashkarTypography.meta,
        ),
        const SizedBox(height: 14),
        if (_farms.isEmpty)
          const RashkarNotice(
            title: 'No Farms Configured',
            message: 'Create or select a farm to assess location-specific heat risk.',
            type: RashkarNoticeType.info,
          )
        else
          RashkarCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedFarmId,
                  decoration: const InputDecoration(labelText: 'Selected Farm'),
                  items: _farms
                      .map((f) => DropdownMenuItem<String>(
                            value: f.id,
                            child: Text(f.name),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedFarmId = v),
                ),
                const SizedBox(height: 16),
                RashkarButton(
                  label: _farmRiskLoading ? 'Retrieving Forecast & Risk...' : 'Run Farm Heat Outlook',
                  leadingIcon: Icons.wb_sunny_rounded,
                  isLoading: _farmRiskLoading,
                  onPressed: _farmRiskLoading || _selectedFarmId == null ? null : _assessFarmHeat,
                ),
              ],
            ),
          ),
        if (_farmRiskError != null) ...[
          const SizedBox(height: 16),
          RashkarNotice(title: 'Farm Risk Error', message: _farmRiskError!, type: RashkarNoticeType.error),
        ],
        if (_farmRiskResult != null) ...[
          const SizedBox(height: 16),
          _buildFarmRiskCard(_farmRiskResult!),
        ],
      ],
    );
  }

  Widget _buildFarmRiskCard(FarmHeatRiskResult r) {
    final status = RashkarStatusLevel.fromString(r.riskCategory);

    return Container(
      decoration: BoxDecoration(
        color: RashkarColors.white,
        borderRadius: RashkarRadii.cardBorderRadius,
        border: Border.all(color: RashkarColors.line, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: status.softColor,
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: status.color,
                    borderRadius: RashkarRadii.iconTileBorderRadius,
                  ),
                  child: Icon(status.icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            r.riskLabel,
                            style: TextStyle(
                              fontFamily: RashkarTypography.primaryFont,
                              fontSize: 18.0,
                              fontWeight: FontWeight.w800,
                              color: status.textColor,
                            ),
                          ),
                          RashkarStatusPill(status: status),
                        ],
                      ),
                      Text(
                        '${r.farmName} • ${r.cropCommonName} (${r.stageName})',
                        style: TextStyle(fontSize: 13.0, color: status.textColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RashkarFourSegmentMeter(level: status.level, activeColor: status.color),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.only(left: 10.0),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: status.color, width: 4.0)),
                  ),
                  child: Text(
                    'Forecast maximum ${r.tmax.toStringAsFixed(1)}°C / minimum ${r.tmin.toStringAsFixed(1)}°C. '
                    'Expected ${r.hoursAbove.toStringAsFixed(1)} hours above physiological critical threshold. '
                    'Warm night stress: ${r.warmNight ? "Detected" : "None"}.',
                    style: RashkarTypography.body,
                  ),
                ),
                if (r.dailyOutlook.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('5-Day Thermal Outlook', style: RashkarTypography.cardTitle),
                  const SizedBox(height: 8),
                  for (final d in r.dailyOutlook)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              d["date"]?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              '${d["tmax_c"]}°C / ${d["tmin_c"]}°C',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: RashkarStatusPill(
                                status: RashkarStatusLevel.fromString(d["risk_category"]?.toString()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (r.interventions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Prescribed Field Interventions', style: RashkarTypography.cardTitle),
                  const SizedBox(height: 8),
                  for (final i in r.interventions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4.0),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: RashkarColors.forest,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(color: RashkarColors.ink, fontSize: 13.5),
                                children: [
                                  TextSpan(
                                    text: '${i["title"]}: ',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  TextSpan(text: i["description"]?.toString() ?? ''),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text(r.provenance, style: RashkarTypography.meta),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropHeatCard(CropHeatResult r) {
    final status = RashkarStatusLevel.fromString(r.riskCategory);

    return RashkarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${r.riskLabel} Risk', style: RashkarTypography.cardTitle),
              RashkarStatusPill(status: status),
            ],
          ),
          const SizedBox(height: 10),
          RashkarFourSegmentMeter(level: status.level, activeColor: status.color),
          const SizedBox(height: 12),
          Text(r.explanation, style: RashkarTypography.body),
          const SizedBox(height: 8),
          Text(
            'Stage: ${r.stageName} • Thermal GDD: ${r.gdd} • Warm night stress: ${r.warmNightHazard ? "Yes" : "No"}',
            style: RashkarTypography.meta,
          ),
          const SizedBox(height: 8),
          Text(r.evidenceCitation, style: const TextStyle(fontSize: 11, color: RashkarColors.muted)),
        ],
      ),
    );
  }

  Widget _buildWorkerHeatCard(WorkerHeatResult r) {
    final status = RashkarStatusLevel.fromString(r.hazardLevel);

    return RashkarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${r.hazardLevel} Hazard Level', style: RashkarTypography.cardTitle),
              RashkarStatusPill(status: status),
            ],
          ),
          const SizedBox(height: 10),
          RashkarFourSegmentMeter(level: status.level, activeColor: status.color),
          const SizedBox(height: 12),
          Text(
            'WBGT: ${r.wbgt.toStringAsFixed(1)}°C • Effective WBGT: ${r.wbgtEffective.toStringAsFixed(1)}°C • ACGIH Threshold: ${r.threshold.toStringAsFixed(1)}°C',
            style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, color: RashkarColors.ink),
          ),
          const SizedBox(height: 8),
          Text(r.recommendation, style: RashkarTypography.body),
          const SizedBox(height: 6),
          Text('Recommended Work/Rest Cycle: ${r.workRestCycle}', style: RashkarTypography.meta),
        ],
      ),
    );
  }

  String _stageLabel(String code) {
    final cleaned = code.replaceFirst('stage_', '').replaceAll('_', ' ');
    if (cleaned.isEmpty) return code;
    return '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
  }
}
