import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:cropnet_mobile/core/router/farm_state.dart';
import 'package:cropnet_mobile/core/router/route_paths.dart';
import 'package:cropnet_mobile/features/rashkar/data/rashkar_repository.dart';
import 'package:cropnet_mobile/features/rashkar/models/rashkar_models.dart';
import 'package:cropnet_mobile/main.dart';
import 'package:cropnet_mobile/shared/theme/rashkar_colors.dart';
import 'package:cropnet_mobile/shared/widgets/centered_page_container.dart';
import 'package:cropnet_mobile/shared/widgets/rashkar_charts.dart';
import 'package:cropnet_mobile/shared/widgets/rashkar_ui.dart';

/// Unified Risk Hub preserving Rashkar's complete original Worker Heat Risk
/// and Crop Heat Risk engines, thresholds, and workflows inside CropNet.
class RiskHubScreen extends StatefulWidget {
  final int initialTab;
  final RashkarRepository? repository;
  final List<FarmItem>? farmsOverride;
  final String? initialFarmId;

  const RiskHubScreen({
    super.key,
    this.initialTab = 0,
    this.repository,
    this.farmsOverride,
    this.initialFarmId,
  });

  @override
  State<RiskHubScreen> createState() => _RiskHubScreenState();
}

class _RiskHubScreenState extends State<RiskHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final RashkarRepository _repo;
  final FarmRepository _farmRepo = FarmRepository.instance;

  bool _isLoading = true;
  bool _isRecalculatingWorker = false;
  bool _isRecalculatingCrop = false;
  bool _isSavingMissingContext = false;

  String? _selectedFarmId;
  SharedFarmContext? _sharedContext;
  WorkerHeatResponse? _workerHeat;
  CropHeatAssessment? _cropHeat;
  String? _errorMessage;
  MissingSharedContextException? _workerMissingContext;
  MissingSharedContextException? _cropMissingContext;

  // Worker inputs synchronized with shared farmer profile
  String _workload = 'moderate';
  String _clothingType = 'standard_work_clothes';
  bool _isAcclimatised = true;
  String _sunExposure = 'direct_sun';
  double _exposureDurationHours = 3.0;

  // Missing worker name controller if registration left full_name empty
  final TextEditingController _missingFarmerNameController = TextEditingController();
  final TextEditingController _missingPhoneController = TextEditingController();

  // Crop selection state
  String? _selectedCycleId;
  String? _selectedCropStage;
  List<Map<String, dynamic>> _supportedCrops = const [];

  // Missing crop context form state
  final TextEditingController _plotNameController = TextEditingController(text: 'Main Plot 1');
  final TextEditingController _cropVarietyController = TextEditingController();
  final TextEditingController _sowingDateController = TextEditingController();
  String _newCropCode = 'soybean';
  String _newSeason = 'kharif';
  double _newPlantedAcres = 2.0;

  static const List<Map<String, String>> _fallbackSupportedCrops = [
    {'crop_code': 'soybean', 'common_name_en': 'Soybean'},
    {'crop_code': 'cotton', 'common_name_en': 'Cotton'},
    {'crop_code': 'wheat', 'common_name_en': 'Wheat'},
    {'crop_code': 'maize', 'common_name_en': 'Maize'},
    {'crop_code': 'rice', 'common_name_en': 'Rice (Paddy)'},
    {'crop_code': 'pigeonpea', 'common_name_en': 'Pigeonpea (Tur)'},
    {'crop_code': 'chickpea', 'common_name_en': 'Chickpea (Gram)'},
    {'crop_code': 'groundnut', 'common_name_en': 'Groundnut'},
    {'crop_code': 'sugarcane', 'common_name_en': 'Sugarcane'},
    {'crop_code': 'tomato', 'common_name_en': 'Tomato'},
    {'crop_code': 'onion', 'common_name_en': 'Onion'},
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RashkarRepository.instance;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _sowingDateController.text = _defaultSowingDate();
    if (widget.farmsOverride == null) {
      _farmRepo.addListener(_onFarmRepoChanged);
    }
    _bootstrapAndLoad();
  }

  @override
  void didUpdateWidget(covariant RiskHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab &&
        widget.initialTab >= 0 &&
        widget.initialTab < 2 &&
        _tabController.index != widget.initialTab) {
      _tabController.animateTo(widget.initialTab);
    }
    if (widget.initialFarmId != null && widget.initialFarmId != _selectedFarmId) {
      _selectedFarmId = widget.initialFarmId;
      _loadAllData();
    }
  }

  @override
  void dispose() {
    if (widget.farmsOverride == null) {
      _farmRepo.removeListener(_onFarmRepoChanged);
    }
    _tabController.dispose();
    _missingFarmerNameController.dispose();
    _missingPhoneController.dispose();
    _plotNameController.dispose();
    _cropVarietyController.dispose();
    _sowingDateController.dispose();
    super.dispose();
  }

  String _defaultSowingDate() {
    final now = DateTime.now().subtract(const Duration(days: 45));
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }

  List<FarmItem> get _availableFarms => widget.farmsOverride ?? _farmRepo.farms;

  void _onFarmRepoChanged() {
    if (!mounted) return;
    final repoSelected = _farmRepo.selectedFarmId;
    if (repoSelected != null && repoSelected != _selectedFarmId) {
      setState(() => _selectedFarmId = repoSelected);
      _loadAllData();
    } else if (_selectedFarmId == null && _availableFarms.isNotEmpty) {
      setState(() => _selectedFarmId = _availableFarms.first.id);
      _loadAllData();
    } else {
      setState(() {});
    }
  }

  Future<void> _bootstrapAndLoad() async {
    if (widget.farmsOverride == null && _farmRepo.farms.isEmpty) {
      try {
        await _farmRepo.loadFarms();
      } catch (_) {}
    }

    final farms = _availableFarms;
    final resolvedFarmId = widget.initialFarmId ??
        (widget.farmsOverride == null ? _farmRepo.selectedFarmId : null) ??
        (farms.isNotEmpty ? farms.first.id : null);

    if (!mounted) return;
    setState(() {
      _selectedFarmId = resolvedFarmId;
    });

    if (resolvedFarmId == null) {
      setState(() => _isLoading = false);
      return;
    }

    await _loadAllData();
  }

  Future<void> _loadAllData() async {
    final farmId = _selectedFarmId;
    if (farmId == null || farmId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _workerMissingContext = null;
      _cropMissingContext = null;
    });

    try {
      final results = await Future.wait([
        _repo.getSharedContext(farmId),
        _repo.getSupportedHeatCrops().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      final ctx = results[0] as SharedFarmContext;
      final crops = results[1] as List<Map<String, dynamic>>;

      if (!mounted) return;
      final defaultCycle = ctx.cropCycles.isNotEmpty
          ? (ctx.cropCycles.where((c) => c.cycleId == _selectedCycleId).firstOrNull ??
              ctx.cropCycles.where((c) => c.isActive).firstOrNull ??
              ctx.cropCycles.first)
          : null;

      setState(() {
        _sharedContext = ctx;
        _supportedCrops = crops.isNotEmpty ? crops : _fallbackSupportedCrops;
        _workload = ctx.farmerProfile.defaultWorkloadCategory ?? _workload;
        _clothingType = ctx.farmerProfile.defaultClothingType ?? _clothingType;
        _isAcclimatised = ctx.farmerProfile.defaultIsAcclimatised ?? _isAcclimatised;
        _sunExposure = ctx.farmerProfile.defaultSunExposure ?? _sunExposure;
        _exposureDurationHours = ctx.farmerProfile.defaultExposureDurationHours ?? _exposureDurationHours;
        _missingFarmerNameController.text = ctx.farmerProfile.fullName ?? '';
        _missingPhoneController.text = ctx.farmerProfile.phoneNumber ?? '';
        _selectedCycleId = defaultCycle?.cycleId;
        _newPlantedAcres = ctx.totalAreaAcres > 0 ? ctx.totalAreaAcres : 2.0;
        if (ctx.plots.isNotEmpty) {
          _plotNameController.text = ctx.plots.first.plotName;
        }
      });

      await Future.wait([
        _loadWorkerHeat(farmId),
        _loadCropHeat(farmId, cycleId: _selectedCycleId),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWorkerHeat(String farmId) async {
    try {
      final resp = await _repo.assessWorkerHeat(
        farmId,
        workloadCategory: _workload,
        clothingType: _clothingType,
        isAcclimatised: _isAcclimatised,
        sunExposure: _sunExposure,
        exposureDurationHours: _exposureDurationHours,
        saveAsDefault: false,
      );
      if (!mounted) return;
      setState(() {
        _workerHeat = resp;
        _workerMissingContext = null;
      });
    } catch (e) {
      final missing = MissingSharedContextException.tryParse(e);
      if (!mounted) return;
      if (missing != null) {
        setState(() {
          _workerHeat = null;
          _workerMissingContext = missing;
        });
      } else {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  Future<void> _loadCropHeat(String farmId, {String? cycleId, String? confirmedStage}) async {
    try {
      final resp = await _repo.assessCropHeat(
        farmId,
        cycleId: cycleId,
        farmerConfirmedStage: confirmedStage,
      );
      if (!mounted) return;
      setState(() {
        _cropHeat = resp;
        _cropMissingContext = null;
        _selectedCropStage = resp.farmerConfirmedStage ?? resp.growthStageCode;
      });
    } catch (e) {
      final missing = MissingSharedContextException.tryParse(e);
      if (!mounted) return;
      if (missing != null) {
        setState(() {
          _cropHeat = null;
          _cropMissingContext = missing;
        });
      } else {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  Future<void> _recalculateWorkerHeat() async {
    final farmId = _selectedFarmId;
    if (farmId == null) return;
    setState(() => _isRecalculatingWorker = true);
    try {
      final res = await _repo.assessWorkerHeat(
        farmId,
        workloadCategory: _workload,
        clothingType: _clothingType,
        isAcclimatised: _isAcclimatised,
        sunExposure: _sunExposure,
        exposureDurationHours: _exposureDurationHours,
        saveAsDefault: true,
      );
      if (!mounted) return;
      setState(() {
        _workerHeat = res;
        _workerMissingContext = null;
        _isRecalculatingWorker = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRecalculatingWorker = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to recalculate worker risk: $e')),
      );
    }
  }

  Future<void> _recalculateCropHeat(String newStageCode) async {
    final farmId = _selectedFarmId;
    if (farmId == null) return;
    setState(() {
      _selectedCropStage = newStageCode;
      _isRecalculatingCrop = true;
    });
    try {
      final res = await _repo.assessCropHeat(
        farmId,
        cycleId: _selectedCycleId,
        farmerConfirmedStage: newStageCode,
      );
      if (!mounted) return;
      setState(() {
        _cropHeat = res;
        _cropMissingContext = null;
        _selectedCropStage = res.farmerConfirmedStage ?? res.growthStageCode;
        _isRecalculatingCrop = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRecalculatingCrop = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update crop growth stage: $e')),
      );
    }
  }

  Future<void> _saveMissingWorkerContext() async {
    final farmId = _selectedFarmId;
    if (farmId == null) return;
    setState(() => _isSavingMissingContext = true);
    try {
      final fullName = _missingFarmerNameController.text.trim();
      final phone = _missingPhoneController.text.trim();
      final updated = await _repo.updateSharedContext(
        farmId,
        farmerProfile: SharedFarmerProfile(
          fullName: fullName.isNotEmpty ? fullName : null,
          phoneNumber: phone.isNotEmpty ? phone : null,
          defaultWorkloadCategory: _workload,
          defaultClothingType: _clothingType,
          defaultIsAcclimatised: _isAcclimatised,
          defaultSunExposure: _sunExposure,
          defaultExposureDurationHours: _exposureDurationHours,
        ),
      );
      if (!mounted) return;
      setState(() {
        _sharedContext = updated;
        _isSavingMissingContext = false;
      });
      await _loadWorkerHeat(farmId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingMissingContext = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save farmer worker profile: $e')),
      );
    }
  }

  Future<void> _saveNewCropCycle({NavigatorState? dialogNavigator}) async {
    final farmId = _selectedFarmId;
    if (farmId == null) return;
    final sowingDate = _sowingDateController.text.trim();
    if (sowingDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a sowing date (YYYY-MM-DD).')),
      );
      return;
    }

    setState(() => _isSavingMissingContext = true);
    try {
      final created = await _repo.createCropCycle(
        farmId,
        plotName: _plotNameController.text.trim().isEmpty ? 'Main Plot 1' : _plotNameController.text.trim(),
        cropCode: _newCropCode,
        varietyName: _cropVarietyController.text.trim().isEmpty ? null : _cropVarietyController.text.trim(),
        season: _newSeason,
        sowingDate: sowingDate,
        plantedAreaAcres: _newPlantedAcres,
        irrigationType: _sharedContext?.irrigationType,
      );
      dialogNavigator?.pop();
      final refreshedCtx = await _repo.getSharedContext(farmId);
      if (!mounted) return;
      setState(() {
        _sharedContext = refreshedCtx;
        _selectedCycleId = created.cycleId;
        _cropMissingContext = null;
        _isSavingMissingContext = false;
      });
      await _loadCropHeat(farmId, cycleId: created.cycleId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingMissingContext = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save crop planting details: $e')),
      );
    }
  }

  Future<void> _pickSowingDate() async {
    final initial = DateTime.tryParse(_sowingDateController.text.trim()) ??
        DateTime.now().subtract(const Duration(days: 45));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      final mm = picked.month.toString().padLeft(2, '0');
      final dd = picked.day.toString().padLeft(2, '0');
      setState(() {
        _sowingDateController.text = '${picked.year}-$mm-$dd';
      });
    }
  }

  String _safeStageLabel(CropHeatAssessment c) {
    final nameEn = c.growthStageNameEn.trim();
    if (nameEn.isNotEmpty && nameEn.toLowerCase() != 'null') {
      return nameEn;
    }
    final code = c.growthStageCode?.trim() ?? '';
    if (code.isNotEmpty && code.toLowerCase() != 'null') {
      return code.replaceAll('stage_', '').replaceAll('_', ' ').toUpperCase();
    }
    return c.isSeasonExpired ? 'Season Complete — Confirm Crop Stage' : 'Active Growth Stage';
  }

  @override
  Widget build(BuildContext context) {
    final farms = _availableFarms;
    return Scaffold(
      backgroundColor: RashkarColors.canvas,
      appBar: AppBar(
        backgroundColor: RashkarColors.surface,
        foregroundColor: RashkarColors.ink,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Heat Risk Check',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: RashkarColors.ink),
            ),
            if (_sharedContext != null)
              Text(
                '${_sharedContext!.farmName} · ${_sharedContext!.taluka}, ${_sharedContext!.district}',
                style: const TextStyle(fontSize: 12.5, color: RashkarColors.mutedInk, fontWeight: FontWeight.w500),
              ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
            onPressed: _isLoading ? null : _loadAllData,
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Container(
            decoration: const BoxDecoration(
              color: RashkarColors.surface,
              border: Border(bottom: BorderSide(color: RashkarColors.border, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: RashkarColors.forestTint,
              indicatorWeight: 3.5,
              labelColor: RashkarColors.forest,
              unselectedLabelColor: RashkarColors.mutedInk,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              tabs: const [
                Tab(text: 'Worker Heat Risk'),
                Tab(text: 'Crop Heat Risk'),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(farms),
    );
  }

  Widget _buildBody(List<FarmItem> farms) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF2E7D32)),
            SizedBox(height: 12),
            Text('Loading WMO weather, Liljegren WBGT & crop physiology...'),
          ],
        ),
      );
    }

    if (farms.isEmpty || _selectedFarmId == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.agriculture_outlined, size: 48, color: Color(0xFF2E7D32)),
                  const SizedBox(height: 12),
                  const Text(
                    'Register a Farm First',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Risk assessments automatically reuse your registered farm location, crop plantings, and farmer profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
                    onPressed: () => context.push(RoutePaths.farmNew),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Farm in CropNet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null && _workerHeat == null && _cropHeat == null && _workerMissingContext == null && _cropMissingContext == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
                    onPressed: _loadAllData,
                    child: const Text('Retry Assessment'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildWorkerTabRoot(),
        _buildCropTabRoot(),
      ],
    );
  }

  Widget _buildFarmSwitcherHeader() {
    final farms = _availableFarms;
    if (farms.isEmpty) return const SizedBox.shrink();
    return RashkarCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: RashkarColors.mintBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.spa_outlined, color: RashkarColors.forest, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const Key('risk_farm_selector'),
                isExpanded: true,
                value: farms.any((f) => f.id == _selectedFarmId) ? _selectedFarmId : farms.first.id,
                items: farms
                    .map(
                      (f) => DropdownMenuItem<String>(
                        value: f.id,
                        child: Text(
                          '${f.name}${_sharedContext != null && f.id == _selectedFarmId ? " (${_sharedContext!.totalAreaAcres.toStringAsFixed(1)} ac · ${_sharedContext!.taluka})" : ""}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: RashkarColors.ink),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (farmId) {
                  if (farmId == null || farmId == _selectedFarmId) return;
                  if (widget.farmsOverride == null) {
                    _farmRepo.selectFarm(farmId);
                  }
                  setState(() {
                    _selectedFarmId = farmId;
                    _selectedCycleId = null;
                  });
                  _loadAllData();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // WORKER HEAT RISK TAB (ORIGINAL RASHKAR DESIGN + SHARED MISSING CONTEXT)
  // =========================================================================
  Widget _buildWorkerTabRoot() {
    if (_workerMissingContext != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFarmSwitcherHeader(),
                const SizedBox(height: 12),
                _buildMissingWorkerContextCard(_workerMissingContext!),
              ],
            ),
          ),
        ),
      );
    }

    if (_workerHeat == null) {
      return Center(
        child: FilledButton(
          onPressed: () => _loadWorkerHeat(_selectedFarmId!),
          child: const Text('Run Worker Heat Assessment'),
        ),
      );
    }

    return _buildFarmerWorkerHeatTab(_workerHeat!);
  }

  Widget _buildMissingWorkerContextCard(MissingSharedContextException missing) {
    final fields = missing.missingFields;
    final needsName = fields.contains('farmer_profile.full_name');
    final needsPhone = fields.contains('farmer_profile.phone_number');
    return RashkarCard(
      borderColor: RashkarColors.marigold,
      backgroundColor: RashkarColors.marigoldTint,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_late_outlined, color: RashkarColors.marigoldInk, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Complete Missing Worker Profile Details (Saved Once)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: RashkarColors.ink),
                ),
              ),
            ],
          ),
            const SizedBox(height: 8),
            Text(
              missing.message,
              style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.35),
            ),
            const SizedBox(height: 14),
            if (needsName) ...[
              TextField(
                controller: _missingFarmerNameController,
                decoration: const InputDecoration(
                  labelText: 'Farmer / Lead Worker Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (needsPhone) ...[
              TextField(
                controller: _missingPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text('Default Field Workload:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey('missing_wl_$_workload'),
              initialValue: _workload,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'light', child: Text('Light (weeding, sitting)')),
                DropdownMenuItem(value: 'moderate', child: Text('Normal Farm Work (walking, hoeing)')),
                DropdownMenuItem(value: 'heavy', child: Text('Heavy (digging, lifting)')),
                DropdownMenuItem(value: 'very_heavy', child: Text('Very Heavy (continuous strenuous labor)')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _workload = v);
              },
            ),
            const SizedBox(height: 12),
            const Text('Sun Exposure:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey('missing_sun_$_sunExposure'),
              initialValue: _sunExposure,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'direct_sun', child: Text('In direct sun')),
                DropdownMenuItem(value: 'partial_shade', child: Text('Partial shade')),
                DropdownMenuItem(value: 'full_shade', child: Text('Full shade / shed')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _sunExposure = v);
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: RashkarColors.forest),
                onPressed: _isSavingMissingContext ? null : _saveMissingWorkerContext,
                icon: _isSavingMissingContext
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSavingMissingContext ? 'Saving & Assessing...' : 'Save to Farm Profile & Assess Worker Risk',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFarmerWorkerHeatTab(WorkerHeatResponse w) {
    final level = w.currentHazardLevel.toUpperCase();
    final sevStyle = RashkarColors.severityFor(level);

    String statusTitle;
    String statusSub;
    String plainRiskLabel;
    IconData statusIcon;
    if (level == 'CRITICAL' || level == 'EXTREME') {
      statusTitle = 'Heat conditions are dangerous for your selected work activity right now.';
      statusSub = 'Avoid heavy outdoor work and move to a cool, shaded place immediately.';
      plainRiskLabel = 'DANGER';
      statusIcon = Icons.warning_amber_rounded;
    } else if (level == 'HIGH') {
      statusTitle = w.peakRiskHourIst.isNotEmpty
          ? 'Heat risk is expected to increase around ${w.peakRiskHourIst}.'
          : 'Heat risk is expected to increase this afternoon.';
      statusSub = 'Consider moving heavy fieldwork to an earlier, lower-risk period before peak heat.';
      plainRiskLabel = 'HIGH HEAT';
      statusIcon = Icons.warning_amber_rounded;
    } else if (level == 'MODERATE') {
      statusTitle = 'Warm weather today with moderate heat during peak sun.';
      statusSub = 'Stay hydrated with regular water breaks every 15–20 minutes and rest in shade.';
      plainRiskLabel = 'MODERATE';
      statusIcon = Icons.wb_sunny_outlined;
    } else {
      statusTitle = 'Outdoor conditions are currently comfortable for fieldwork.';
      statusSub = 'Stay hydrated throughout the day and rest in shade when tired.';
      plainRiskLabel = 'SAFE';
      statusIcon = Icons.check_circle_outline;
    }

    final waterRule = w.hydrationGuidance['rule_summary']?.toString().trim();
    final adviceList = <String>[
      if (waterRule != null && waterRule.isNotEmpty)
        waterRule
      else
        'Drink 1 glass (250 ml) of water every 15–20 minutes while working.',
      if (w.shiftExceedsForecastCoverage && w.coverageLimitationWarning != null)
        w.coverageLimitationWarning!
      else if (level == 'HIGH' || level == 'CRITICAL' || level == 'EXTREME')
        'Finish heavy field tasks before 10:30 AM or after 4:00 PM.'
      else
        'Rest in shade for a few minutes whenever you feel tired or thirsty.',
      if (level != 'LOW' && w.highRiskActions.isNotEmpty)
        w.highRiskActions.first
      else if (w.duringWorkGuidance.isNotEmpty &&
          !w.duringWorkGuidance.first.toUpperCase().contains('WBGT'))
        w.duringWorkGuidance.first
      else
        'Wear loose cotton clothes and a head cloth when working in sunlight.',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 36),
      child: CenteredPageContainer(
        maxWidth: 820,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (MediaQuery.sizeOf(context).width < 780 && _availableFarms.length > 1) ...[
              _buildFarmSwitcherHeader(),
              const SizedBox(height: 14),
            ],
            // 1. PAGE HEADING
            const Text(
              "Today's Heat Risk",
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: RashkarColors.ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Worker heat safety guidance for your farm today',
              style: TextStyle(fontSize: 14.5, color: RashkarColors.mutedInk),
            ),
            const SizedBox(height: 14),

            // 3. MINIMUM INFO & PRIMARY ACTION TO UPDATE WORK
            RashkarCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current work setup',
                          style: TextStyle(fontSize: 13, color: RashkarColors.mutedInk, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_getWorkloadFriendlyName(_workload)} · ${_sunLabel(_sunExposure)}',
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: RashkarColors.ink),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => _showWorkerSettingsBottomSheet(context),
                    child: const Text('Change Work Details'),
                  ),
                ],
              ),
            ),
            if (_isRecalculatingWorker) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(color: RashkarColors.forestTint, backgroundColor: RashkarColors.mintBg),
            ],
            const SizedBox(height: 16),

            // 4. SIMPLE RESULT CARD (AgriNova Clean White Hero Card)
            RashkarCard(
              padding: const EdgeInsets.all(20),
              borderRadius: 14,
              borderColor: level == 'LOW' ? RashkarColors.paleSage : sevStyle.border,
              backgroundColor: level == 'LOW' ? RashkarColors.surface : sevStyle.background.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(statusIcon, color: sevStyle.foreground, size: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: sevStyle.background,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: sevStyle.border),
                        ),
                        child: Text(
                          level == 'MODERATE' ? 'MODERATE' : plainRiskLabel,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: sevStyle.foreground,
                          ),
                        ),
                      ),
                      const Text(
                        'Outdoor Work Condition',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: RashkarColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    statusTitle,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: level == 'LOW' ? RashkarColors.ink : sevStyle.foreground,
                      letterSpacing: -0.3,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusSub,
                    style: const TextStyle(fontSize: 14.5, color: RashkarColors.ink, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    children: [
                      _SimpleStatReadout(
                        label: 'Air temperature now',
                        value: '${w.currentAirTempC.toStringAsFixed(0)}°C',
                      ),
                      _SimpleStatReadout(
                        label: 'Warmest time today',
                        value: w.peakRiskHourIst.isNotEmpty ? w.peakRiskHourIst : 'Afternoon',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. CLEAR RECOMMENDATIONS / NEXT STEPS
            RashkarCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What you should do today',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: RashkarColors.ink),
                  ),
                  const SizedBox(height: 12),
                  for (int i = 0; i < adviceList.length; i++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: RashkarColors.mintBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: RashkarColors.forest,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              adviceList[i],
                              style: const TextStyle(fontSize: 15, color: RashkarColors.ink, height: 1.45),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (i < adviceList.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 6. SAFE HOURS TODAY (Simple, plain-worded list)
            if (w.hourlyProjections.isNotEmpty) ...[
              RashkarCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next hours today',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: RashkarColors.ink),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Plan heavier fieldwork during safer green hours.',
                      style: TextStyle(fontSize: 14, color: RashkarColors.mutedInk),
                    ),
                    const SizedBox(height: 14),
                    ...w.hourlyProjections.take(6).map((p) {
                      final hStyle = RashkarColors.severityFor(p.hazardLevel);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: RashkarColors.canvas,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: RashkarColors.border),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 82,
                              child: Text(
                                p.validTimeIst,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: RashkarColors.ink,
                                ),
                              ),
                            ),
                            Text(
                              '${p.airTempC.round()}°C',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: RashkarColors.ink,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: hStyle.background,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: hStyle.border),
                              ),
                              child: Text(
                                _plainRiskWord(p.hazardLevel),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: hStyle.foreground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 7. EMERGENCY FIRST AID (Collapsed unless needed)
            RashkarCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: const ExpansionTile(
                  leading: Icon(Icons.local_hospital_outlined, color: RashkarColors.extremeFg),
                  title: Text(
                    'If someone feels sick from heat',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: RashkarColors.ink),
                  ),
                  subtitle: Text(
                    'First aid signs and emergency number 108',
                    style: TextStyle(fontSize: 13.5, color: RashkarColors.mutedInk),
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'If dizzy, weak, or sweating heavily:\n• Move the person to cool shade right away.\n• Loosen clothes and give cool water slowly.\n\nIf very confused, hot, or fainting:\n• Call 108 for ambulance immediately.\n• Pour cool water on the body while waiting.',
                            style: TextStyle(fontSize: 14.5, color: RashkarColors.ink, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 8. EXPANDABLE TECHNICAL DETAILS (Hidden until tapped)
            RashkarCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: const Icon(Icons.info_outline, color: RashkarColors.forest),
                  title: const Text(
                    'More details',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: RashkarColors.ink),
                  ),
                  subtitle: const Text(
                    'Technical risk meter, WBGT measurements, and trend charts',
                    style: TextStyle(fontSize: 13.5, color: RashkarColors.mutedInk),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RashkarRiskMeter(severity: level),
                          const SizedBox(height: 14),
                          RashkarIndicatorListCard(
                            rows: [
                              MapEntry('Air Temperature', '${w.currentAirTempC.toStringAsFixed(1)}°C'),
                              MapEntry('Humidity', '${w.currentRelativeHumidityPct.toStringAsFixed(0)}%'),
                              MapEntry('Wind Speed', '${w.currentWindSpeedKmh.toStringAsFixed(1)} km/h'),
                              MapEntry('Solar Radiation', '${w.currentSolarRadiationWm2.toStringAsFixed(0)} W/m²'),
                              MapEntry('Effective WBGT', '${w.currentWbgtEstimatedC.toStringAsFixed(1)}°C'),
                              MapEntry('Screening Limit', '${w.screeningThresholdC.toStringAsFixed(1)}°C'),
                              MapEntry('Shift Planned', '${w.plannedShiftDurationHours.toStringAsFixed(1)} hours'),
                            ],
                          ),
                          if (w.categorySelectionReason.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              w.categorySelectionReason,
                              style: const TextStyle(fontSize: 13.5, color: RashkarColors.ink, height: 1.45),
                            ),
                          ],
                          if (w.hourlyProjections.length >= 2) ...[
                            const SizedBox(height: 14),
                            RashkarTempRiskBandChart(
                              points: w.hourlyProjections
                                  .map((p) => RashkarChartSeriesPoint(label: p.validTimeIst, primaryValue: p.wbgtEffectiveC))
                                  .toList(),
                              primaryLegend: 'Effective WBGT (°C)',
                              highThreshold: w.screeningThresholdC,
                              extremeThreshold: w.screeningThresholdC + 2.5,
                              height: 150,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            'Source: ${w.weatherSourceName} · Method: ${w.methodologyReference} (${w.methodologyStandardsVersion}).',
                            style: const TextStyle(fontSize: 12.5, color: RashkarColors.mutedInk),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sunLabel(String sunExposure) {
    if (sunExposure == 'partial_shade') return 'Partial shade';
    if (sunExposure == 'full_shade') return 'Under shed / full shade';
    return 'Direct sun';
  }

  String _plainRiskWord(String hazardLevel) {
    switch (hazardLevel.toUpperCase()) {
      case 'CRITICAL':
      case 'EXTREME':
        return 'Danger';
      case 'HIGH':
        return 'High heat';
      case 'MODERATE':
        return 'Take breaks';
      default:
        return 'Safe';
    }
  }

  // =========================================================================
  // CROP HEAT RISK TAB (ORIGINAL RASHKAR DESIGN + SHARED CROP REGISTRATION)
  // =========================================================================
  Widget _buildCropTabRoot() {
    if (_cropMissingContext != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFarmSwitcherHeader(),
                const SizedBox(height: 12),
                _buildMissingCropContextCard(_cropMissingContext!),
              ],
            ),
          ),
        ),
      );
    }

    if (_cropHeat == null) {
      return Center(
        child: FilledButton(
          onPressed: () => _loadCropHeat(_selectedFarmId!, cycleId: _selectedCycleId),
          child: const Text('Run Crop Heat Assessment'),
        ),
      );
    }

    return _buildFarmerCropHeatTab(_cropHeat!);
  }

  Widget _buildCropFormFields({bool inDialog = false}) {
    final crops = _supportedCrops.isNotEmpty ? _supportedCrops : _fallbackSupportedCrops;
    final cropExists = crops.any((c) => c['crop_code']?.toString() == _newCropCode);
    final effectiveCropCode = cropExists ? _newCropCode : (crops.first['crop_code']?.toString() ?? 'soybean');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _plotNameController,
          decoration: const InputDecoration(
            labelText: 'Plot Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('crop_code_$effectiveCropCode'),
          initialValue: effectiveCropCode,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Planted Crop Species',
            border: OutlineInputBorder(),
          ),
          items: crops
              .map(
                (c) => DropdownMenuItem<String>(
                  value: c['crop_code']?.toString() ?? 'soybean',
                  child: Text(c['common_name_en']?.toString() ?? c['crop_code']?.toString() ?? 'Crop'),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _newCropCode = v);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _sowingDateController,
                decoration: InputDecoration(
                  labelText: 'Sowing Date (YYYY-MM-DD)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    onPressed: _pickSowingDate,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('season_$_newSeason'),
                initialValue: _newSeason,
                decoration: const InputDecoration(
                  labelText: 'Season',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'kharif', child: Text('Kharif')),
                  DropdownMenuItem(value: 'rabi', child: Text('Rabi')),
                  DropdownMenuItem(value: 'summer', child: Text('Summer')),
                  DropdownMenuItem(value: 'perennial', child: Text('Perennial')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _newSeason = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cropVarietyController,
          decoration: const InputDecoration(
            labelText: 'Variety (Optional)',
            border: OutlineInputBorder(),
          ),
        ),
        if (!inDialog) const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMissingCropContextCard(MissingSharedContextException missing) {
    return RashkarCard(
      borderColor: RashkarColors.marigold,
      backgroundColor: RashkarColors.marigoldTint,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.grass_outlined, color: RashkarColors.marigoldInk, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add Active Crop Planting Details (Saved Once)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: RashkarColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            missing.message,
            style: const TextStyle(fontSize: 13, color: RashkarColors.ink, height: 1.35),
          ),
          const SizedBox(height: 14),
          _buildCropFormFields(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: RashkarColors.forest),
              onPressed: _isSavingMissingContext ? null : () => _saveNewCropCycle(),
              icon: _isSavingMissingContext
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _isSavingMissingContext ? 'Saving Planting...' : 'Save Crop & Assess Heat Risk',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCropCycleDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Add Crop Planting Cycle'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(child: _buildCropFormFields(inDialog: true)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
              onPressed: _isSavingMissingContext
                  ? null
                  : () => _saveNewCropCycle(dialogNavigator: Navigator.of(dialogCtx)),
              child: const Text('Save Crop Cycle'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCropPlotSelectorBar() {
    final cycles = _sharedContext?.cropCycles ?? const <CropCycleRecord>[];
    if (cycles.isEmpty) return const SizedBox.shrink();
    final activeValue = cycles.any((c) => c.cycleId == _selectedCycleId) ? _selectedCycleId : cycles.first.cycleId;

    return Card(
      elevation: 0,
      color: RashkarColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: RashkarColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.grass_outlined, color: RashkarColors.forest, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const Key('crop_cycle_selector'),
                  isExpanded: true,
                  value: activeValue,
                  items: cycles
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c.cycleId,
                          child: Text(
                            '${c.plotName} · ${c.cropCode.toUpperCase()} (${c.sowingDate})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (cycleId) {
                    if (cycleId == null || cycleId == _selectedCycleId) return;
                    setState(() => _selectedCycleId = cycleId);
                    _loadCropHeat(_selectedFarmId!, cycleId: cycleId);
                  },
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _showAddCropCycleDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Crop'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmerCropHeatTab(CropHeatAssessment c) {
    final level = c.overallCropHeatRisk.toUpperCase();
    final sevStyle = RashkarColors.severityFor(level);
    final stageLabel = _safeStageLabel(c);

    String statusTitle;
    String statusSub;
    String plainRiskLabel;
    IconData statusIcon;
    if (level == 'CRITICAL' || level == 'EXTREME' || level == 'HIGH') {
      statusTitle = 'High heat stress is forecast for ${c.cropCommonName} during the $stageLabel stage.';
      statusSub = c.recommendedInterventions.isNotEmpty
          ? c.recommendedInterventions.first.titleEn
          : 'Provide protective irrigation during cooler morning or evening hours.';
      plainRiskLabel = 'HIGH HEAT';
      statusIcon = Icons.warning_amber_rounded;
    } else if (level == 'MODERATE') {
      statusTitle = 'Mild heat is forecast for ${c.cropCommonName} — afternoon heat may dry soil faster.';
      statusSub = 'Check field moisture and irrigate during cooler morning or evening hours.';
      plainRiskLabel = 'MODERATE';
      statusIcon = Icons.water_drop_outlined;
    } else {
      statusTitle = 'No heat-stress warning is forecast for ${c.cropCommonName} over the next 4 days at its confirmed $stageLabel stage.';
      statusSub = 'Temperatures are within safe limits. Continue regular crop care and check soil moisture.';
      plainRiskLabel = 'SAFE';
      statusIcon = Icons.check_circle_outline;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 36),
      child: CenteredPageContainer(
        maxWidth: 820,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (MediaQuery.sizeOf(context).width < 780 && _availableFarms.length > 1) ...[
              _buildFarmSwitcherHeader(),
              const SizedBox(height: 14),
            ],
            // 1. PAGE HEADING
            const Text(
              "Your Crop's Heat Outlook",
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: RashkarColors.ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Heat forecast and thermal safety for ${c.cropCommonName}',
              style: const TextStyle(fontSize: 14.5, color: RashkarColors.mutedInk),
            ),
            const SizedBox(height: 14),

            // 3. ACTIVE CROP BAR & STAGE CONFIRMATION
            _buildCropPlotSelectorBar(),
            const SizedBox(height: 14),

            // 4. SIMPLE RESULT CARD (AgriNova Clean White Hero Card)
            RashkarCard(
              padding: const EdgeInsets.all(20),
              borderRadius: 14,
              borderColor: level == 'LOW' ? RashkarColors.paleSage : sevStyle.border,
              backgroundColor: level == 'LOW' ? RashkarColors.surface : sevStyle.background.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(statusIcon, color: sevStyle.foreground, size: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: sevStyle.background,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: sevStyle.border),
                        ),
                        child: Text(
                          plainRiskLabel,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: sevStyle.foreground,
                          ),
                        ),
                      ),
                      Text(
                        '${c.cropCommonName.toUpperCase()} · $stageLabel Stage',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: RashkarColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    statusTitle,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: level == 'LOW' ? RashkarColors.ink : sevStyle.foreground,
                      letterSpacing: -0.3,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusSub,
                    style: const TextStyle(fontSize: 14.5, color: RashkarColors.ink, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    children: [
                      _SimpleStatReadout(
                        label: "Today's expected high",
                        value: '${c.tmaxForecastC.toStringAsFixed(1)}°C',
                      ),
                      _SimpleStatReadout(
                        label: 'Safe limit for this stage',
                        value: '${c.criticalTmaxThresholdC.toStringAsFixed(1)}°C',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Note: This assessment covers forecast heat risk and does not replace regular field scouting.',
                    style: TextStyle(fontSize: 12.5, color: RashkarColors.mutedInk),
                  ),
                  if (c.warmNightRespirationHazard) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: RashkarColors.marigoldTint,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: RashkarColors.marigoldBorder),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.nights_stay_outlined, size: 17, color: RashkarColors.marigoldInk),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Warm nights expected — watch crop watering closely.',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: RashkarColors.marigoldInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (c.isSeasonExpired || c.growthStageCode == null) ...[
                    const SizedBox(height: 12),
                    RashkarNoticeCallout(
                      title: 'Check sowing date',
                      message: c.seasonExpiryMessage ??
                          'Sowing date indicates this season may have finished. Select current stage or add a new crop planting.',
                      icon: Icons.event_busy_outlined,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // CONFIRM CROP GROWTH STAGE
            RashkarCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Confirm Crop Stage',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: RashkarColors.ink),
                      ),
                      if (_isRecalculatingCrop)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: RashkarColors.forestTint),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Tap your crop's stage right now to update heat safety limits:",
                    style: TextStyle(fontSize: 14.5, color: RashkarColors.mutedInk),
                  ),
                  const SizedBox(height: 12),
                  if (c.supportedStages.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: RashkarColors.canvas,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: RashkarColors.border),
                      ),
                      child: const Text(
                        'General temperature safety limits apply for this crop.',
                        style: TextStyle(fontSize: 14, color: RashkarColors.mutedInk),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: c.supportedStages.map((s) {
                        final rawCode = s['stage_code']?.toString().trim();
                        final safeCode = (rawCode != null && rawCode.isNotEmpty && rawCode != 'null')
                            ? rawCode
                            : 'stage_unknown';
                        final rawName = s['stage_name_en'] ?? s['stage_name'] ?? s['name'];
                        final stageName = (rawName != null &&
                                rawName.toString().trim().isNotEmpty &&
                                rawName.toString().trim().toLowerCase() != 'null')
                            ? rawName.toString().trim()
                            : (safeCode != 'stage_unknown'
                                ? safeCode.replaceAll('stage_', '').replaceAll('_', ' ').toUpperCase()
                                : 'Growth Stage');
                        final critTmax = s['crit_tmax'];
                        final limitLabel = critTmax != null ? ' ($critTmax°C limit)' : '';
                        final isSelected = (_selectedCropStage ?? c.growthStageCode) == safeCode;

                        return ChoiceChip(
                          label: Text('$stageName$limitLabel'),
                          selected: isSelected,
                          checkmarkColor: Colors.white,
                          selectedColor: RashkarColors.forestTint,
                          backgroundColor: RashkarColors.surface,
                          labelStyle: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? Colors.white : RashkarColors.ink,
                          ),
                          side: BorderSide(
                            color: isSelected ? RashkarColors.forestTint : RashkarColors.border,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          onSelected: (selected) {
                            if (selected && safeCode != 'stage_unknown') {
                              _recalculateCropHeat(safeCode);
                            }
                          },
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. NEXT 4 DAYS AT A GLANCE (Clean high-contrast rows)
            RashkarCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Next 4 days for your crop',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: RashkarColors.ink),
                  ),
                  const SizedBox(height: 12),
                  if (c.dailyOutlook.isNotEmpty)
                    Column(children: c.dailyOutlook.map(_buildSimpleDailyRow).toList())
                  else
                    const Text(
                      '4-day crop outlook is unavailable right now.',
                      style: TextStyle(fontSize: 14.5, color: RashkarColors.mutedInk),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 6. WHAT TO DO TO PROTECT YOUR CROP
            RashkarCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What you can do for your crop',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: RashkarColors.ink),
                  ),
                  const SizedBox(height: 12),
                  if (c.recommendedInterventions.isNotEmpty)
                    for (int i = 0; i < c.recommendedInterventions.length; i++) ...[
                      _buildSimpleInterventionCard(c.recommendedInterventions[i], stepNumber: i + 1),
                      if (i < c.recommendedInterventions.length - 1) const SizedBox(height: 12),
                    ]
                  else
                    const Text(
                      'No extra heat care needed today. Continue normal watering.',
                      style: TextStyle(fontSize: 15, color: RashkarColors.mutedInk),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 7. EXPANDABLE "MORE DETAILS" (Technical risk meter, charts, biological physiology & citations)
            RashkarCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: const Icon(Icons.info_outline, color: RashkarColors.forest),
                  title: const Text(
                    'More details',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: RashkarColors.ink),
                  ),
                  subtitle: const Text(
                    'Technical risk meter, 4-day temperature chart, GDD & scientific sources',
                    style: TextStyle(fontSize: 13.5, color: RashkarColors.mutedInk),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RashkarRiskMeter(severity: level),
                          const SizedBox(height: 14),
                          if (c.dailyOutlook.isNotEmpty) ...[
                            RashkarThresholdBarChart(
                              thresholdValue: c.criticalTmaxThresholdC,
                              thresholdLabel: 'Danger > ${c.criticalTmaxThresholdC.toStringAsFixed(1)}°C',
                              bars: c.dailyOutlook.map((day) {
                                final sev = RashkarColors.severityFor(day.riskCategory);
                                return RashkarBarPoint(
                                  label: day.dayLabel,
                                  value: day.tmaxC,
                                  valueText: '${day.tmaxC.toStringAsFixed(0)}°',
                                  color: sev.bar,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),
                          ],
                          RashkarIndicatorListCard(
                            rows: [
                              MapEntry('Optimal Range', '${c.optimalTempMinC}–${c.optimalTempMaxC}°C'),
                              MapEntry('Base Temperature', '${c.baseTempC}°C'),
                              MapEntry('Hours Above Limit', '${c.hoursAboveCritical.toStringAsFixed(1)} hrs'),
                              MapEntry('Hot Days in Row', '${c.consecutiveHotDays}'),
                              MapEntry('GDD Heat Units', c.cumulativeHeatUnitsGdd.toStringAsFixed(1)),
                              MapEntry('Soil Type', '${c.soilTexture} (${c.soilProvenanceLabel})'),
                            ],
                          ),
                          if (c.stageBiologicalVulnerability.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              c.stageBiologicalVulnerability,
                              style: const TextStyle(fontSize: 13.5, color: RashkarColors.ink, height: 1.45),
                            ),
                          ],
                          if (c.evidenceCitation.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            RashkarNoticeCallout(
                              title: 'Research Citation',
                              message: c.evidenceCitation,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================
  Widget _buildSimpleDailyRow(CropDailyOutlook day) {
    final dayStyle = RashkarColors.severityFor(day.riskCategory);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RashkarColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: RashkarColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.dayLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: RashkarColors.ink)),
                Text(day.date, style: const TextStyle(fontSize: 12, color: RashkarColors.mutedInk)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              day.explanation,
              style: const TextStyle(fontSize: 14, color: RashkarColors.ink, height: 1.35),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${day.tmaxC.round()}° / ${day.tminC.round()}°C',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: RashkarColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: dayStyle.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: dayStyle.border),
                ),
                child: Text(
                  _plainRiskWord(day.riskCategory),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: dayStyle.foreground,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleInterventionCard(CropHeatIntervention rec, {int stepNumber = 1}) {
    final detail = rec.applicationMethod != null
        ? 'How: ${rec.applicationMethod} ${rec.applicationDose != null ? "(${rec.applicationDose})" : ""} · Why: ${rec.whyAppropriate}'
        : 'Why this helps: ${rec.whyAppropriate}';

    return RashkarActionCard(
      stepNumber: stepNumber,
      title: rec.titleEn,
      subtitle: rec.descriptionEn,
      icon: Icons.eco_outlined,
      technicalDetail: detail,
    );
  }

  String _getWorkloadFriendlyName(String code) {
    switch (code) {
      case 'light':
        return 'Light (weeding, sitting)';
      case 'moderate':
        return 'Normal Farm Work';
      case 'heavy':
        return 'Heavy (digging, lifting)';
      case 'very_heavy':
        return 'Very Heavy (strenuous)';
      default:
        return code;
    }
  }

  void _showWorkerSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Adjust Farm Work Details',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('What kind of farm work?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey('sheet_wl_$_workload'),
                      initialValue: _workload,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'light', child: Text('Light (sitting, light weeding)')),
                        DropdownMenuItem(value: 'moderate', child: Text('Normal Farm Work (walking, hoeing)')),
                        DropdownMenuItem(value: 'heavy', child: Text('Heavy (digging, carrying heavy loads)')),
                        DropdownMenuItem(value: 'very_heavy', child: Text('Very Heavy (continuous strenuous labor)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => _workload = val);
                          setState(() => _workload = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text('Where are you working?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey('sheet_sun_$_sunExposure'),
                      initialValue: _sunExposure,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'direct_sun', child: Text('In direct sun')),
                        DropdownMenuItem(value: 'partial_shade', child: Text('Partial shade (near trees/cover)')),
                        DropdownMenuItem(value: 'full_shade', child: Text('Full shade / shed')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => _sunExposure = val);
                          setState(() => _sunExposure = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text('Clothing & Protection:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey('sheet_cloth_$_clothingType'),
                      initialValue: _clothingType,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'light_cotton', child: Text('Light Cotton / Loose Clothes')),
                        DropdownMenuItem(value: 'standard_work_clothes', child: Text('Standard Farm Work Clothes')),
                        DropdownMenuItem(value: 'chemical_spray_ppe', child: Text('Pesticide Spray Suit / Apron (+CAV)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => _clothingType = val);
                          setState(() => _clothingType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Used to working in hot weather?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text(
                        "Turn off if worker is new to this region or hasn't worked in sun this week",
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _isAcclimatised,
                      activeThumbColor: const Color(0xFF2E7D32),
                      onChanged: (val) {
                        setModalState(() => _isAcclimatised = val);
                        setState(() => _isAcclimatised = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Planned shift duration:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                          '${_exposureDurationHours.toStringAsFixed(1)} hours',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                    Slider(
                      value: _exposureDurationHours.clamp(1.0, 8.0),
                      min: 1.0,
                      max: 8.0,
                      divisions: 7,
                      activeColor: const Color(0xFF2E7D32),
                      label: '${_exposureDurationHours.toStringAsFixed(1)}h',
                      onChanged: (val) {
                        setModalState(() => _exposureDurationHours = val);
                        setState(() => _exposureDurationHours = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RashkarColors.forestTint,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _recalculateWorkerHeat();
                        },
                        child: const Text(
                          'Update Heat Risk Check',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SimpleStatReadout extends StatelessWidget {
  final String label;
  final String value;

  const _SimpleStatReadout({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: RashkarColors.canvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RashkarColors.paleSage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: RashkarColors.mutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: RashkarColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
