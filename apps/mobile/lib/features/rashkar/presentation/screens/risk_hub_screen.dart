import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:cropnet_mobile/core/router/farm_state.dart';
import 'package:cropnet_mobile/core/router/route_paths.dart';
import 'package:cropnet_mobile/features/rashkar/data/rashkar_repository.dart';
import 'package:cropnet_mobile/features/rashkar/models/rashkar_models.dart';
import 'package:cropnet_mobile/main.dart';

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

  Color _getHazardColor(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
      case 'SEVERE':
      case 'EXTREME':
        return const Color(0xFFC62828);
      case 'HIGH':
        return const Color(0xFFD84315);
      case 'MODERATE':
        return const Color(0xFFEF6C00);
      case 'LOW':
      default:
        return const Color(0xFF2E7D32);
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
      backgroundColor: const Color(0xFFF6F8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Farm & Worker Heat Risk',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _sharedContext != null
                  ? '${_sharedContext!.farmName} · ${_sharedContext!.district}, ${_sharedContext!.state}'
                  : 'WBGT Worker Safety & Crop Thermal Physiology',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (farms.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Switch registered farm',
              icon: const Icon(Icons.agriculture_outlined),
              onSelected: (farmId) {
                if (widget.farmsOverride == null) {
                  _farmRepo.selectFarm(farmId);
                }
                setState(() {
                  _selectedFarmId = farmId;
                  _selectedCycleId = null;
                });
                _loadAllData();
              },
              itemBuilder: (_) => farms
                  .map(
                    (f) => PopupMenuItem<String>(
                      value: f.id,
                      child: Row(
                        children: [
                          Icon(
                            f.id == _selectedFarmId ? Icons.check_circle : Icons.landscape_outlined,
                            size: 16,
                            color: f.id == _selectedFarmId ? const Color(0xFF1B5E20) : Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Flexible(child: Text(f.name, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          IconButton(
            tooltip: 'Refresh weather & heat models',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.engineering_outlined, size: 18), text: 'Worker Heat Risk'),
            Tab(icon: Icon(Icons.eco_outlined, size: 18), text: 'Crop Heat Risk'),
          ],
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
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: Color(0xFF1B5E20), size: 20),
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
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEF6C00), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_late_outlined, color: Color(0xFFEF6C00), size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Complete Missing Worker Profile Details (Saved Once)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
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
      ),
    );
  }

  Widget _buildFarmerWorkerHeatTab(WorkerHeatResponse w) {
    final level = w.currentHazardLevel.toUpperCase();
    final hazardColor = _getHazardColor(level);

    String statusTitle;
    String statusSub;
    IconData statusIcon;
    if (level == 'CRITICAL') {
      statusTitle = 'Dangerous heat outdoors';
      statusSub = 'Avoid heavy field labor during peak hours. Heat stroke hazard.';
      statusIcon = Icons.warning_amber_rounded;
    } else if (level == 'HIGH') {
      statusTitle = 'Hot conditions — take precautions';
      statusSub = 'Frequent shade breaks and regular water intake are essential today.';
      statusIcon = Icons.wb_sunny_rounded;
    } else if (level == 'MODERATE') {
      statusTitle = 'Warm outdoor conditions';
      statusSub = 'Work is manageable with scheduled water breaks and sun protection.';
      statusIcon = Icons.wb_cloudy_rounded;
    } else {
      statusTitle = 'Safe to work outdoors';
      statusSub = 'Conditions are comfortable for regular farm work.';
      statusIcon = Icons.check_circle_rounded;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFarmSwitcherHeader(),
              const SizedBox(height: 12),

              // SECTION A: Today's Outdoor Work Conditions (Main Card)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: hazardColor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: hazardColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(statusIcon, color: hazardColor, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Outdoor Work Condition',
                                      style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: hazardColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        level,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  statusTitle,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: hazardColor,
                                  ),
                                ),
                                Text(
                                  statusSub,
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        w.categorySelectionReason.isNotEmpty
                            ? w.categorySelectionReason
                            : 'Current heat feels like ${w.currentWbgtEstimatedC.toStringAsFixed(1)}°C outdoors in direct sun. Follow field hydration rules.',
                        style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFD84315)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Peak Heat Window: ${w.peakRiskHourIst.isNotEmpty ? w.peakRiskHourIst : "12:00 PM – 3:30 PM"} (Peak: ${w.maxHazardLevelInWindow})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.water_drop, size: 18, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    w.hydrationGuidance['rule_summary']?.toString() ??
                                        'Drink 1 glass of water every 20 minutes. Keep a covered water pot near the plot.',
                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SECTION B: Adjust My Work Conditions
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.tune, color: Color(0xFF2E7D32), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'My Current Farm Work',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          if (_isRecalculatingWorker)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7D32)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildSummaryPill('Work', _getWorkloadFriendlyName(_workload)),
                          _buildSummaryPill(
                            'Sun',
                            _sunExposure == 'direct_sun'
                                ? 'Direct Sun'
                                : (_sunExposure == 'partial_shade' ? 'Partial Shade' : 'Full Shade'),
                          ),
                          _buildSummaryPill('Heat Adapted', _isAcclimatised ? 'Yes' : 'Not used to heat'),
                          _buildSummaryPill('Shift', '${_exposureDurationHours.toStringAsFixed(1)} hrs'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E7D32),
                            side: const BorderSide(color: Color(0xFF2E7D32)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: const Text('Change My Work Details', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _showWorkerSettingsBottomSheet(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SECTION C: 6-Hour Heat Safety Timeline
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Hourly Work Schedule",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Color-coded hours: Green is safe, amber requires extra water, red means rest.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      if (w.hourlyProjections.isNotEmpty)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: w.hourlyProjections.map(_buildSimpleHourlyPill).toList(),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.recommend, size: 18, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                w.shiftExceedsForecastCoverage && w.coverageLimitationWarning != null
                                    ? w.coverageLimitationWarning!
                                    : 'Recommendation: Schedule heavy tasks before 10:30 AM or after 4:00 PM for comfort and safety.',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1B5E20),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SECTION D: Emergency Heat Illness Triage
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.red.shade200),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: const Icon(Icons.health_and_safety, color: Colors.red, size: 22),
                    ),
                    title: const Text(
                      'Signs of Heat Illness & Emergency First Aid',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                    ),
                    subtitle: const Text(
                      'Tap to view what to do if someone falls sick',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.shade300),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Mild: Heat Exhaustion',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors.deepOrange,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '• Dizziness or headache\n• Heavy sweating\n• Weakness, nausea',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'WHAT TO DO:\nMove to shade, loosen shirt, drink cool water with a pinch of salt.',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.brown,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade400),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Severe: Heat Stroke (108)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors.red,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '• High body heat\n• Confusion or fainting\n• Hot, dry or red skin',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'URGENT:\nCall 108 immediately!\nPour water on body while waiting. Do not force drinks if unconscious.',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.phone_in_talk, size: 16, color: Colors.black87),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Ambulance: 108  |  Emergency: 112  |  Kisan Call Centre: 1800-180-1551',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SECTION E: Scientific & Provenance Details
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ExpansionTile(
                  leading: const Icon(Icons.biotech, color: Colors.blueGrey),
                  title: const Text(
                    'Scientific Details & Data Sources',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                  ),
                  subtitle: const Text(
                    'Tap to view WBGT physics, thresholds & weather provider',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildDetailChip('Air Temp', '${w.currentAirTempC.toStringAsFixed(1)}°C'),
                              _buildDetailChip('Humidity', '${w.currentRelativeHumidityPct.toStringAsFixed(0)}%'),
                              _buildDetailChip('Wind Speed', '${w.currentWindSpeedKmh.toStringAsFixed(1)} km/h'),
                              _buildDetailChip('Solar Radiation', '${w.currentSolarRadiationWm2.toStringAsFixed(0)} W/m²'),
                              _buildDetailChip('Effective WBGT', '${w.currentWbgtEstimatedC.toStringAsFixed(1)}°C'),
                              if (w.currentHeatIndexC != null)
                                _buildDetailChip('Heat Index', '${w.currentHeatIndexC!.toStringAsFixed(1)}°C'),
                              if (w.currentUtciC != null)
                                _buildDetailChip('UTCI', '${w.currentUtciC!.toStringAsFixed(1)}°C'),
                              _buildDetailChip('Screening Limit', '${w.screeningThresholdC.toStringAsFixed(1)}°C'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Threshold Comparison: ${w.thresholdComparisonMessage.isNotEmpty ? w.thresholdComparisonMessage : w.peakRiskReason}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Standards: ${w.methodologyStandardsVersion.isNotEmpty ? w.methodologyStandardsVersion : "ACGIH 2023 TLVs & ISO 7243:2017"}',
                                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Provider: ${w.weatherSourceName} (${w.spatialResolution}) · Valid: ${w.validTimeIst} IST · Status: ${w.isObservedOrForecast}',
                                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            w.disclaimer.isNotEmpty
                                ? w.disclaimer
                                : 'Occupational heat screening based on ISO 7243 and ACGIH guidelines. Not a clinical device.',
                            style: const TextStyle(fontSize: 10, color: Colors.black54, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEF6C00), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.grass_outlined, color: Color(0xFFEF6C00), size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Add Active Crop Planting Details (Saved Once)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
            _buildCropFormFields(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
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
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.grass_outlined, color: Color(0xFF2E7D32), size: 20),
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
    final riskColor = _getHazardColor(level);
    final stageLabel = _safeStageLabel(c);

    String statusTitle;
    String statusSub;
    IconData statusIcon;
    if (level == 'CRITICAL' || level == 'HIGH') {
      statusTitle = 'High heat stress — action needed';
      statusSub = 'Temperatures are approaching or exceeding tolerance for your current growth stage.';
      statusIcon = Icons.warning_amber_rounded;
    } else if (level == 'MODERATE') {
      statusTitle = 'Moderate heat — monitor soil moisture';
      statusSub = 'Crop is experiencing warm conditions. Ensure adequate root zone moisture.';
      statusIcon = Icons.water_drop_outlined;
    } else {
      statusTitle = 'Crop is handling temperature well';
      statusSub = 'Temperatures are within the optimal growth range for this stage.';
      statusIcon = Icons.check_circle_rounded;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFarmSwitcherHeader(),
              const SizedBox(height: 8),
              _buildCropPlotSelectorBar(),
              const SizedBox(height: 12),

              // SECTION A: Crop Heat Status (Main Card)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: riskColor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: riskColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(statusIcon, color: riskColor, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${c.cropCommonName.toUpperCase()} · $stageLabel Stage',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  statusTitle,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: riskColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        c.stageBiologicalVulnerability.isNotEmpty ? c.stageBiologicalVulnerability : statusSub,
                        style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSimpleMetric('Expected High', '${c.tmaxForecastC}°C', Icons.wb_sunny, Colors.orange.shade800),
                            _buildSimpleMetric('Critical Limit', '${c.criticalTmaxThresholdC}°C', Icons.thermostat, Colors.red.shade700),
                            _buildSimpleMetric('Optimal Range', '${c.optimalTempMinC}-${c.optimalTempMaxC}°C', Icons.check_circle_outline, Colors.green.shade800),
                          ],
                        ),
                      ),
                      if (c.isSeasonExpired || c.growthStageCode == null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.deepOrange.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_busy, color: Colors.deepOrange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.seasonExpiryMessage ??
                                      'Crop sowing date indicates season has completed. Confirm current growth stage or add a new planting cycle.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SECTION B: Confirm Your Crop Stage
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Confirm Crop Stage',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (_isRecalculatingCrop)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7D32)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Tap your crop's current stage to update heat tolerance thresholds:",
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      if (c.supportedStages.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Text(
                            'General vegetative and thermal thresholds apply. Stage-specific phenological calibrations for this crop will be confirmed by local agronomists.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
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
                              selectedColor: const Color(0xFFE8F5E9),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? const Color(0xFF1B5E20) : Colors.black87,
                              ),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300,
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
              ),
              const SizedBox(height: 16),

              // SECTION C: 4-Day Crop Heat Outlook
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '4-Day Temperature Outlook for Your Crop',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      if (c.dailyOutlook.isNotEmpty)
                        Column(children: c.dailyOutlook.map(_buildSimpleDailyRow).toList())
                      else
                        const Text('Daily outlook unavailable.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SECTION D: Recommended Actions
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Color(0xFF2E7D32), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Recommended Actions for Your Crop',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (c.recommendedInterventions.isNotEmpty)
                        ...c.recommendedInterventions.map(_buildSimpleInterventionCard)
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'No urgent heat interventions needed today.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SECTION E: Scientific & Agronomic Details
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ExpansionTile(
                  leading: const Icon(Icons.science_outlined, color: Colors.blueGrey),
                  title: const Text(
                    'Scientific & Field Research Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                  ),
                  subtitle: const Text(
                    'Tap to view GDD units, soil provenance & research citations',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildDetailChip('Base Temp', '${c.baseTempC}°C'),
                              _buildDetailChip('Exceedance Hours', '${c.hoursAboveCritical.toStringAsFixed(1)} hrs'),
                              _buildDetailChip('Consecutive Hot Days', '${c.consecutiveHotDays}'),
                              _buildDetailChip('GDD Heat Units', c.cumulativeHeatUnitsGdd.toStringAsFixed(1)),
                              _buildDetailChip('Warm Night Hazard', c.warmNightRespirationHazard ? 'YES' : 'NO'),
                              _buildDetailChip('Soil Type', '${c.soilTexture} (${c.soilProvenanceLabel})'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (c.evidenceCitation.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Scientific Evidence Citation: ${c.evidenceCitation}',
                                style: const TextStyle(fontSize: 11, color: Colors.black87, fontStyle: FontStyle.italic),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================
  Widget _buildSummaryPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }

  Widget _buildSimpleMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }

  Widget _buildDetailChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildSimpleHourlyPill(WorkerHourlyProjection p) {
    final color = _getHazardColor(p.hazardLevel);

    return Container(
      width: 78,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: p.exceedsScreeningThreshold ? 1.5 : 1.0),
      ),
      child: Column(
        children: [
          Text(p.validTimeIst, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 4),
          Text('${p.wbgtEffectiveC}°C', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            child: Text(
              p.hazardLevel,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleDailyRow(CropDailyOutlook day) {
    final col = _getHazardColor(day.riskCategory);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.dayLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(day.date, style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              day.explanation,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${day.tmaxC}°C / ${day.tminC}°C', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  day.riskCategory,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleInterventionCard(CropHeatIntervention rec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rec.titleEn,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B5E20)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  rec.category.replaceAll('_', ' '),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(rec.descriptionEn, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3)),
          if (rec.applicationMethod != null) ...[
            const SizedBox(height: 4),
            Text(
              'How: ${rec.applicationMethod} ${rec.applicationDose != null ? "(${rec.applicationDose})" : ""}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ],
          const SizedBox(height: 4),
          Text('Why this helps: ${rec.whyAppropriate}', style: TextStyle(fontSize: 11, color: Colors.green.shade900)),
        ],
      ),
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
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _recalculateWorkerHeat();
                        },
                        child: const Text(
                          'Update & Recalculate Heat Safety',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
