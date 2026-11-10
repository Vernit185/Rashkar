import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:cropnet_mobile/core/router/farm_state.dart';
import 'package:cropnet_mobile/core/router/route_paths.dart';
import 'package:cropnet_mobile/features/rashkar/data/rashkar_repository.dart';
import 'package:cropnet_mobile/features/rashkar/models/rashkar_models.dart';
import 'package:cropnet_mobile/main.dart';

/// Complete Extra Income & Diversification screen ported from Rashkar's original
/// 5-category engine, multi-gate feasibility scorer, 3-scenario financial service,
/// 12-month cashflows, 6-question farmer summary, and saved farm plans.
class ExtraIncomeScreen extends StatefulWidget {
  final RashkarRepository? repository;
  final List<FarmItem>? farmsOverride;
  final String? initialFarmId;

  const ExtraIncomeScreen({
    super.key,
    this.repository,
    this.farmsOverride,
    this.initialFarmId,
  });

  @override
  State<ExtraIncomeScreen> createState() => _ExtraIncomeScreenState();
}

class _ExtraIncomeScreenState extends State<ExtraIncomeScreen> {
  late final RashkarRepository _repo;
  final FarmRepository _farmRepo = FarmRepository.instance;

  bool _isLoading = true;
  bool _isCalculating = false;
  bool _isSavingPlan = false;
  bool _isSavingProfile = false;
  bool _needsInitialProfile = false;
  List<String> _missingFields = const [];
  String? _errorMessage;

  String? _selectedFarmId;
  SharedFarmContext? _sharedContext;

  // Farmer Resource Profile State (synchronized with CropNet shared profile)
  double _availableInvestment = 0.0;
  final double _monthlyOperatingBudget = 0.0;
  double _availableLand = 0.5;
  double _unusedLand = 0.25;
  String _waterAvailability = 'seasonal_canal';
  double _familyLaborHours = 2.0;
  bool _hasAnimalShed = false;
  bool _hasStorageRoom = false;
  bool _hasShadedSpace = false;
  bool _fieldBundsAvailable = true;
  bool _hasFpoAccess = false;
  bool _hasTransport = false;
  String _existingLivestock = 'none';
  List<String> _cropByproducts = const ['soybean_straw'];
  final List<String> _interests = const ['open_to_suggestions'];
  String _riskTolerance = 'moderate';
  String _ageRange = '36-45';
  String _workPreference = 'daily_physical';
  String _paybackHorizon = 'within_6_months';
  String _familyManagementRole = 'self';

  // Category filter
  String _selectedCategory = 'all';

  // Engine outputs
  List<ScoredOpportunityItem> _opportunities = const [];
  ScoredOpportunityItem? _selectedOpportunity;
  IncomeScenario? _scenario;
  List<OpportunityComparisonItem> _comparisons = const [];
  List<SavedIncomePlan> _savedPlans = const [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RashkarRepository.instance;
    if (widget.farmsOverride == null) {
      _farmRepo.addListener(_onFarmRepoChanged);
    }
    _bootstrapAndLoad();
  }

  @override
  void dispose() {
    if (widget.farmsOverride == null) {
      _farmRepo.removeListener(_onFarmRepoChanged);
    }
    super.dispose();
  }

  List<FarmItem> get _availableFarms => widget.farmsOverride ?? _farmRepo.farms;

  void _onFarmRepoChanged() {
    if (!mounted) return;
    final repoSelected = _farmRepo.selectedFarmId;
    if (repoSelected != null && repoSelected != _selectedFarmId) {
      setState(() => _selectedFarmId = repoSelected);
      _loadFarmAndOpportunities();
    } else if (_selectedFarmId == null && _availableFarms.isNotEmpty) {
      setState(() => _selectedFarmId = _availableFarms.first.id);
      _loadFarmAndOpportunities();
    } else {
      setState(() {});
    }
  }

  String _normalizeAgeRange(String? raw) {
    switch (raw) {
      case 'under_25':
      case '25-35':
      case '36-45':
      case '46-55':
      case '56-65':
      case 'above_65':
      case 'prefer_not_to_say':
        return raw!;
      case '25_to_35':
        return '25-35';
      case '36_to_45':
        return '36-45';
      case '46_to_55':
        return '46-55';
      case '56_to_65':
        return '56-65';
      default:
        return '36-45';
    }
  }

  String _normalizeWorkPreference(String? raw) {
    switch (raw) {
      case 'daily_physical':
      case 'light_physical':
      case 'manage_supervise':
      case 'family_help':
      case 'hire_labor':
      case 'low_attention':
        return raw!;
      case 'active_physical':
        return 'daily_physical';
      default:
        return 'daily_physical';
    }
  }

  String _normalizePaybackHorizon(String? raw) {
    switch (raw) {
      case 'few_weeks':
      case 'within_6_months':
      case '3_to_6_months':
      case '6_to_12_months':
      case 'more_than_year':
        return raw!;
      case 'within_1_year':
        return '6_to_12_months';
      case 'long_term':
        return 'more_than_year';
      default:
        return 'within_6_months';
    }
  }

  String _normalizeWater(String? raw) {
    switch (raw) {
      case 'reliable_year_round':
      case 'seasonal_canal':
      case 'rainfed_limited':
      case 'rainfed_only':
      case 'limited':
      case 'none':
        return raw == 'rainfed_only' || raw == 'limited' ? 'rainfed_limited' : raw!;
      default:
        return 'seasonal_canal';
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
    setState(() => _selectedFarmId = resolvedFarmId);

    if (resolvedFarmId == null) {
      setState(() => _isLoading = false);
      return;
    }

    await _loadFarmAndOpportunities();
  }

  Future<void> _loadFarmAndOpportunities() async {
    final farmId = _selectedFarmId;
    if (farmId == null || farmId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _needsInitialProfile = false;
      _missingFields = const [];
    });

    try {
      final results = await Future.wait([
        _repo.getSharedContext(farmId),
        _repo.getFarmResourceProfile(farmId),
      ]);
      final ctx = results[0] as SharedFarmContext;
      final profile = results[1] as SharedResourceProfileDTO;

      if (!mounted) return;
      _applyProfileState(ctx, profile);

      if (!profile.profileCompleted && profile.missingFields.isNotEmpty) {
        setState(() {
          _needsInitialProfile = true;
          _missingFields = profile.missingFields;
          _isLoading = false;
        });
        await _loadSavedPlans(farmId);
        return;
      }

      await Future.wait([
        _discoverOpportunities(farmId),
        _loadSavedPlans(farmId),
      ]);
    } catch (e) {
      final missing = MissingSharedContextException.tryParse(e);
      if (!mounted) return;
      if (missing != null) {
        setState(() {
          _needsInitialProfile = true;
          _missingFields = missing.missingFields;
        });
      } else {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyProfileState(SharedFarmContext ctx, SharedResourceProfileDTO profile) {
    setState(() {
      _sharedContext = ctx;
      _availableInvestment = profile.availableInvestmentInr ?? 0.0;
      _availableLand = (profile.availableLandAcres ?? 0.5).clamp(0.0, 2.0);
      _unusedLand = (profile.unusedLandAcres ?? 0.25).clamp(0.0, 2.0);
      _waterAvailability = _normalizeWater(profile.waterAvailability);
      _familyLaborHours = (profile.familyLaborHoursDay ?? 2.0).clamp(0.5, 6.0);
      _hasAnimalShed = profile.hasAnimalShed ?? false;
      _hasStorageRoom = profile.hasStorageRoom ?? false;
      _hasShadedSpace = profile.hasShadedSpace ?? false;
      _fieldBundsAvailable = profile.fieldBundsAvailable ?? true;
      _hasFpoAccess = profile.hasFpoAccess ?? false;
      _hasTransport = profile.hasTransport ?? false;
      _existingLivestock = profile.existingLivestock ?? 'none';
      _cropByproducts = profile.cropByproducts;
      _riskTolerance = profile.riskTolerance ?? 'moderate';
      _ageRange = _normalizeAgeRange(profile.ageRange ?? ctx.farmerProfile.ageRange);
      _workPreference = _normalizeWorkPreference(profile.workPreference ?? ctx.farmerProfile.workPreference);
      _paybackHorizon = _normalizePaybackHorizon(profile.paybackHorizon ?? ctx.farmerProfile.paybackHorizon);
      _familyManagementRole = profile.familyManagementRole ?? ctx.farmerProfile.familyManagementRole ?? 'self';
    });
  }

  FarmerResourceProfile _buildResourceProfilePayload(String farmId) {
    final activeCropCode = _sharedContext?.cropCycles.isNotEmpty == true
        ? _sharedContext!.cropCycles.first.cropCode
        : _sharedContext?.resourceProfile.currentCropCode;
    final activeCropStage = _sharedContext?.cropCycles.isNotEmpty == true
        ? (_sharedContext!.cropCycles.first.currentStageCode ??
            _sharedContext!.cropCycles.first.estimatedStageCode)
        : _sharedContext?.resourceProfile.currentCropStage;

    return FarmerResourceProfile(
      farmId: farmId,
      farmerId: _sharedContext?.farmerProfile.farmerId ?? '',
      availableInvestmentInr: _availableInvestment,
      monthlyOperatingBudgetInr: _monthlyOperatingBudget,
      totalFarmAcres: _sharedContext?.totalAreaAcres,
      availableLandAcres: _availableLand,
      unusedLandAcres: _unusedLand,
      fieldBundsAvailable: _fieldBundsAvailable,
      hasAnimalShed: _hasAnimalShed,
      hasStorageRoom: _hasStorageRoom,
      hasShadedSpace: _hasShadedSpace,
      waterAvailability: _waterAvailability,
      familyLaborHoursDay: _familyLaborHours,
      existingLivestock: _existingLivestock,
      cropByproducts: _cropByproducts,
      byproductSurplusAvailable: _cropByproducts.isNotEmpty,
      interests: _interests,
      hasTransport: _hasTransport,
      hasFpoAccess: _hasFpoAccess,
      riskTolerance: _riskTolerance,
      categoryPreference: _selectedCategory,
      ageRange: _ageRange,
      workPreference: _workPreference,
      paybackHorizon: _paybackHorizon,
      familyManagementRole: _familyManagementRole,
      currentCropCode: activeCropCode,
      currentCropStage: activeCropStage,
    );
  }

  Future<void> _discoverOpportunities(String farmId) async {
    try {
      final list = await _repo.discoverFarmOpportunities(farmId);
      if (!mounted) return;
      setState(() {
        _opportunities = list;
        _needsInitialProfile = false;
        if (list.isNotEmpty) {
          final currentMatch = _selectedOpportunity != null
              ? list.where((i) => i.opportunity.opportunityId == _selectedOpportunity!.opportunity.opportunityId).firstOrNull
              : null;
          _selectedOpportunity = currentMatch ?? list.first;
        } else {
          _selectedOpportunity = null;
          _scenario = null;
        }
      });

      if (_selectedOpportunity != null) {
        await Future.wait([
          _calculateScenario(),
          _loadComparisons(),
        ]);
      }
    } catch (e) {
      final missing = MissingSharedContextException.tryParse(e);
      if (!mounted) return;
      if (missing != null) {
        setState(() {
          _needsInitialProfile = true;
          _missingFields = missing.missingFields;
        });
      } else {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  Future<void> _calculateScenario() async {
    final oppItem = _selectedOpportunity;
    if (oppItem == null) return;
    final opp = oppItem.opportunity;

    if (mounted) setState(() => _isCalculating = true);
    try {
      final budgetToCalc = opp.minInvestmentInr == 0.0
          ? 0.0
          : (_availableInvestment > opp.minInvestmentInr ? _availableInvestment : opp.minInvestmentInr);
      final sc = await _repo.calculateIncomeScenario(
        opportunityId: opp.opportunityId,
        customBudgetInr: budgetToCalc,
        labourHours: _familyLaborHours,
        landAcres: _availableLand,
        waterAvailability: _waterAvailability,
      );
      if (!mounted) return;
      setState(() {
        _scenario = sc;
        _isCalculating = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  Future<void> _loadComparisons() async {
    if (_opportunities.isEmpty) return;
    final topIds = _filteredOpportunities.take(3).map((e) => e.opportunity.opportunityId).toList();
    if (topIds.isEmpty) return;

    try {
      final comps = await _repo.compareOpportunities(
        opportunityIds: topIds,
        customBudgetInr: _availableInvestment,
      );
      if (!mounted) return;
      setState(() => _comparisons = comps);
    } catch (_) {}
  }

  Future<void> _loadSavedPlans(String farmId) async {
    try {
      final plans = await _repo.getSavedIncomePlans(farmId);
      if (!mounted) return;
      setState(() => _savedPlans = plans);
    } catch (_) {}
  }

  Future<void> _handleSavePlan() async {
    final farmId = _selectedFarmId;
    final oppItem = _selectedOpportunity;
    if (farmId == null || oppItem == null) return;

    setState(() => _isSavingPlan = true);
    try {
      final budget = oppItem.opportunity.minInvestmentInr == 0.0
          ? 0.0
          : (_availableInvestment > oppItem.opportunity.minInvestmentInr
              ? _availableInvestment
              : oppItem.opportunity.minInvestmentInr);
      await _repo.saveIncomePlan(
        farmId,
        opportunityId: oppItem.opportunity.opportunityId,
        chosenBudgetInr: budget,
        notes: 'Selected from CropNet Extra Income for ${_sharedContext?.farmName ?? "farm"}',
      );
      await _loadSavedPlans(farmId);
      if (!mounted) return;
      setState(() => _isSavingPlan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${oppItem.opportunity.title}" to My Farm Plans!'),
          backgroundColor: const Color(0xFF1B5E20),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingPlan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save plan: $e')),
      );
    }
  }

  Future<void> _handleDeletePlan(SavedIncomePlan plan) async {
    final farmId = _selectedFarmId;
    if (farmId == null) return;
    try {
      await _repo.deleteSavedIncomePlan(farmId, plan.planId);
      await _loadSavedPlans(farmId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "${plan.opportunityTitle}" from saved plans.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove saved plan: $e')),
      );
    }
  }

  Future<void> _saveProfileAndRecalculate() async {
    final farmId = _selectedFarmId;
    if (farmId == null) return;

    setState(() => _isSavingProfile = true);
    try {
      final profile = _buildResourceProfilePayload(farmId);
      await _repo.saveFarmResourceProfile(farmId, profile);
      final updatedCtx = await _repo.getSharedContext(farmId);
      if (!mounted) return;
      setState(() {
        _sharedContext = updatedCtx;
        _needsInitialProfile = false;
        _isSavingProfile = false;
      });
      await Future.wait([
        _discoverOpportunities(farmId),
        _loadSavedPlans(farmId),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update resources: $e')),
      );
    }
  }

  List<ScoredOpportunityItem> get _filteredOpportunities {
    if (_selectedCategory == 'all') return _opportunities;
    return _opportunities.where((i) => i.opportunity.category == _selectedCategory).toList();
  }

  String _formatCurrency(double val) {
    final intVal = val.round().abs();
    final str = intVal.toString();
    if (str.length <= 3) return '${val < 0 ? "-" : ""}₹$str';
    final lastThree = str.substring(str.length - 3);
    final rest = str.substring(0, str.length - 3);
    final reg = RegExp(r'\B(?=(\d{2})+(?!\d))');
    final formattedRest = rest.replaceAllMapped(reg, (match) => ',');
    return '${val < 0 ? "-" : ""}₹$formattedRest,$lastThree';
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
              'Extra Income & Diversification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _sharedContext != null
                  ? '${_sharedContext!.farmName} · ${_sharedContext!.district}, ${_sharedContext!.state}'
                  : 'Zero-Budget First · Real Constraints · Verified Markets',
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
                  _selectedOpportunity = null;
                });
                _loadFarmAndOpportunities();
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
            tooltip: 'Adjust Farm Resources & Budget',
            icon: const Icon(Icons.tune),
            onPressed: _selectedFarmId == null ? null : () => _showResourceSettingsBottomSheet(context),
          ),
          IconButton(
            tooltip: 'Refresh Income Options',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadFarmAndOpportunities,
          ),
        ],
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
            Text('Evaluating farm resources & APMC income opportunities...'),
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
                  const Icon(Icons.savings_outlined, size: 48, color: Color(0xFF2E7D32)),
                  const SizedBox(height: 12),
                  const Text(
                    'Register a Farm First',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Extra Income automatically uses your registered land area, water source, active crops, and farmer profile.',
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

    if (_errorMessage != null && _opportunities.isEmpty && !_needsInitialProfile) {
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
                    onPressed: _loadFarmAndOpportunities,
                    child: const Text('Retry Discovery'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
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

              if (_needsInitialProfile) ...[
                _buildMissingResourcesCard(),
                const SizedBox(height: 16),
              ] else ...[
                _buildOverviewCard(),
                const SizedBox(height: 16),
                _buildCategoryFilterBar(),
                const SizedBox(height: 16),
                _buildOpportunitiesSection(),
                const SizedBox(height: 16),
                if (_selectedOpportunity != null && _scenario != null) ...[
                  _buildOpportunityDetailCard(),
                  const SizedBox(height: 16),
                ],
                if (_comparisons.isNotEmpty) ...[
                  _buildComparisonCard(),
                  const SizedBox(height: 16),
                ],
              ],

              if (_savedPlans.isNotEmpty) ...[
                _buildSavedPlansCard(),
                const SizedBox(height: 16),
              ],
              _buildProvenanceCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
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
                  key: const Key('income_farm_selector'),
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
                      _selectedOpportunity = null;
                    });
                    _loadFarmAndOpportunities();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingResourcesCard() {
    final budgetChips = [0.0, 5000.0, 15000.0, 50000.0, 100000.0];
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
                Icon(Icons.assignment_turned_in_outlined, color: Color(0xFFEF6C00), size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tell Us Your Farm Resource Profile (Saved Once)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'We already imported your farm location, area (${_sharedContext?.totalAreaAcres.toStringAsFixed(1) ?? "0"} ac), and crops from CropNet. Confirm only the remaining income constraints${_missingFields.isNotEmpty ? " (${_missingFields.join(", ")})" : ""}:',
              style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.35),
            ),
            const SizedBox(height: 14),
            const Text('Available Starting Cash Budget:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: budgetChips.map((b) {
                final isSel = (_availableInvestment - b).abs() < 1.0;
                return ChoiceChip(
                  label: Text(b == 0 ? '₹0 (Zero Cash)' : _formatCurrency(b)),
                  selected: isSel,
                  selectedColor: const Color(0xFFE8F5E9),
                  onSelected: (v) {
                    if (v) setState(() => _availableInvestment = b);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('init_water_$_waterAvailability'),
                    initialValue: _waterAvailability,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Water Supply',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'reliable_year_round', child: Text('Perennial / Borewell')),
                      DropdownMenuItem(value: 'seasonal_canal', child: Text('Seasonal Canal / Pond')),
                      DropdownMenuItem(value: 'rainfed_limited', child: Text('Rainfed / Limited')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _waterAvailability = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('init_age_$_ageRange'),
                    initialValue: _ageRange,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Farmer Age Range',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'under_25', child: Text('Under 25')),
                      DropdownMenuItem(value: '25-35', child: Text('25–35 yrs')),
                      DropdownMenuItem(value: '36-45', child: Text('36–45 yrs')),
                      DropdownMenuItem(value: '46-55', child: Text('46–55 yrs')),
                      DropdownMenuItem(value: '56-65', child: Text('56–65 yrs')),
                      DropdownMenuItem(value: 'above_65', child: Text('Above 65')),
                      DropdownMenuItem(value: 'prefer_not_to_say', child: Text('Prefer not to say')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _ageRange = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Family Labor Hours/Day:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  '${_familyLaborHours.toStringAsFixed(1)} hrs/day',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                ),
              ],
            ),
            Slider(
              value: _familyLaborHours,
              min: 0.5,
              max: 6.0,
              divisions: 11,
              activeColor: const Color(0xFF1B5E20),
              onChanged: (v) => setState(() => _familyLaborHours = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Unused / Spare Land (Acres):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  '${_availableLand.toStringAsFixed(2)} ac',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                ),
              ],
            ),
            Slider(
              value: _availableLand,
              min: 0.0,
              max: 2.0,
              divisions: 20,
              activeColor: const Color(0xFF1B5E20),
              onChanged: (v) => setState(() {
                _availableLand = v;
                _unusedLand = v;
              }),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
                onPressed: _isSavingProfile ? null : _saveProfileAndRecalculate,
                icon: _isSavingProfile
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSavingProfile ? 'Saving & Discovering...' : 'Save Resource Profile & Discover Opportunities',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 1. FARM RESOURCE OVERVIEW CARD ====================
  Widget _buildOverviewCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.savings_outlined, color: Color(0xFF1B5E20), size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Find Extra Income from Your Farm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Start with zero additional cash. Then explore affordable low-investment options.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildResourceMini(
                    'Budget',
                    _availableInvestment == 0 ? '₹0 (Zero Cash)' : _formatCurrency(_availableInvestment),
                    Icons.account_balance_wallet_outlined,
                  ),
                  _buildResourceMini(
                    'Spare Land',
                    '${_availableLand.toStringAsFixed(2)} ac',
                    Icons.landscape_outlined,
                  ),
                  _buildResourceMini(
                    'Water',
                    _getWaterLabel(_waterAvailability),
                    Icons.water_drop_outlined,
                  ),
                  _buildResourceMini(
                    'Family Labor',
                    '${_familyLaborHours.toStringAsFixed(1)} h/day',
                    Icons.people_outline,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('Age: $_ageRange', style: const TextStyle(fontSize: 11)),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('Work: ${_workPreference.replaceAll('_', ' ')}', style: const TextStyle(fontSize: 11)),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('Payback: ${_paybackHorizon.replaceAll('_', ' ')}', style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1B5E20),
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text(
                  'Change Farm Resources & Affordability',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => _showResourceSettingsBottomSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceMini(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }

  String _getWaterLabel(String code) {
    switch (code) {
      case 'reliable_year_round':
        return 'Perennial';
      case 'seasonal_canal':
        return 'Seasonal';
      case 'rainfed_limited':
      case 'rainfed_only':
        return 'Rainfed';
      default:
        return 'Seasonal';
    }
  }

  // ==================== 2. CATEGORY FILTER BAR ====================
  Widget _buildCategoryFilterBar() {
    final categories = [
      {'id': 'all', 'label': 'All Possibilities'},
      {'id': 'zero_cash', 'label': 'Zero Cash / Savings'},
      {'id': 'very_low_cost', 'label': 'Very Low Cost (< ₹15k)'},
      {'id': 'moderate_enterprise', 'label': 'Commercial Units'},
      {'id': 'crop_diversification', 'label': 'Crop Options'},
      {'id': 'group_external', 'label': 'FPO / Collective'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(
                cat['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : const Color(0xFF1B5E20),
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF1B5E20),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade300,
                ),
              ),
              onSelected: (bool selected) {
                setState(() {
                  _selectedCategory = selected ? cat['id']! : 'all';
                  final filtered = _filteredOpportunities;
                  if (filtered.isNotEmpty &&
                      (_selectedOpportunity == null ||
                          !filtered.any((o) => o.opportunity.opportunityId == _selectedOpportunity!.opportunity.opportunityId))) {
                    _selectedOpportunity = filtered.first;
                  }
                });
                _calculateScenario();
                _loadComparisons();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==================== 3. DISCOVERED OPPORTUNITIES FEED ====================
  Widget _buildOpportunitiesSection() {
    final list = _filteredOpportunities;

    if (list.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const Icon(Icons.search_off, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              const Text(
                'No opportunities match this specific filter.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Try selecting "All Possibilities" or adjust your farm resources.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => setState(() => _selectedCategory = 'all'),
                child: const Text('Show All Opportunities'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${list.length} FEASIBLE POSSIBILITIES FOUND',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
                letterSpacing: 0.8,
              ),
            ),
            const Text(
              'Ranked by resource fit',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...list.map(_buildOpportunityCard),
      ],
    );
  }

  Widget _buildOpportunityCard(ScoredOpportunityItem item) {
    final isSelected = _selectedOpportunity?.opportunity.opportunityId == item.opportunity.opportunityId;
    final isFeasible = item.isFeasible;
    final opp = item.opportunity;

    Color statusBgColor;
    Color statusTextColor;
    String statusLabel;

    if (item.feasibilityStatus == 'HIGHLY_FEASIBLE' ||
        item.feasibilityStatus == 'FEASIBLE_NOW' ||
        item.feasibilityStatus == 'USES_EXISTING_RESOURCES') {
      statusBgColor = const Color(0xFFE8F5E9);
      statusTextColor = const Color(0xFF1B5E20);
      statusLabel = opp.category == 'zero_cash' ? 'Zero Extra Cash' : 'Affordable Now';
    } else if (item.feasibilityStatus == 'NOT_CURRENTLY_AFFORDABLE') {
      statusBgColor = const Color(0xFFFFF3E0);
      statusTextColor = const Color(0xFFE65100);
      statusLabel = 'Capital Shortfall: ${_formatCurrency(item.capitalGapInr)}';
    } else {
      statusBgColor = Colors.grey.shade100;
      statusTextColor = Colors.black87;
      statusLabel = item.suitabilityVerdict;
    }

    return Card(
      elevation: isSelected ? 3 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade200,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => _selectedOpportunity = item);
          _calculateScenario();
          _loadComparisons();
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusTextColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusTextColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade500,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                opp.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (opp.tagline.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  opp.tagline,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricCol(
                      opp.isCostSaving ? 'Cash Required' : 'Initial Outlay',
                      opp.minInvestmentInr == 0.0 ? '₹0 (Free)' : _formatCurrency(opp.minInvestmentInr),
                    ),
                    _buildMetricCol(
                      opp.isCostSaving ? 'Annual Cost Saved' : 'Expected Yearly Profit',
                      opp.isCostSaving
                          ? '${_formatCurrency(opp.potentialAnnualSavingsInr)} / yr'
                          : '${_formatCurrency(opp.potentialAnnualProfitInr)} / yr',
                      color: const Color(0xFF1B5E20),
                    ),
                    _buildMetricCol(
                      'Payback',
                      opp.minInvestmentInr == 0.0 ? 'Immediate' : '${opp.paybackPeriodMonths} mos',
                    ),
                    _buildMetricCol(
                      'Space',
                      opp.requiredLandAcres == 0.0 ? 'None' : '${opp.requiredLandAcres} ac',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (item.matchingResources.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '✓ ${item.matchingResources.first}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (!isFeasible && item.capitalGapInr > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '⚠ Available budget: ${_formatCurrency(_availableInvestment)} · Needs ${_formatCurrency(opp.minInvestmentInr)} (Shortfall: ${_formatCurrency(item.capitalGapInr)})',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showFarmerQaBottomSheet(context, item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1B5E20),
                    side: const BorderSide(color: Color(0xFF2E7D32)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  icon: const Icon(Icons.help_outline, size: 14),
                  label: const Text(
                    'Farmer Summary (6 Plain Questions)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFarmerQaBottomSheet(BuildContext context, ScoredOpportunityItem item) {
    final qa = item.farmerSummaryQa ??
        {
          'what_is_it': item.opportunity.summary,
          'why_suits_my_farm': item.matchingResources.isNotEmpty
              ? item.matchingResources.join(' · ')
              : 'Matches your farm profile resources.',
          'what_will_i_need':
              'Initial investment: ${_formatCurrency(item.opportunity.minInvestmentInr)} · Space: ${item.opportunity.requiredSpaceType} · Daily labor: ${item.opportunity.dailyLaborHours} hrs/day',
          'how_will_i_earn_or_save': item.opportunity.isCostSaving
              ? 'Saves ~${_formatCurrency(item.opportunity.potentialAnnualSavingsInr)}/year in farm inputs'
              : 'Earns ~${_formatCurrency(item.opportunity.potentialAnnualProfitInr)}/year in net cash income',
          'when_will_i_receive_money':
              'Expected returns in ~${item.opportunity.paybackPeriodMonths} months based on regional crop and market cycle.',
          'what_to_be_careful_about': item.missingRequirements.isNotEmpty
              ? item.missingRequirements.first
              : 'Manage input hygiene and market linkage timing carefully.',
        };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView(
                controller: controller,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline, color: Color(0xFF1B5E20), size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Plain Farmer Summary: ${item.opportunity.title}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  _buildQaItem('1. What is it?', qa['what_is_it'] ?? ''),
                  _buildQaItem('2. Why does it suit my farm?', qa['why_suits_my_farm'] ?? ''),
                  _buildQaItem('3. What will I need to start?', qa['what_will_i_need'] ?? ''),
                  _buildQaItem('4. How will I earn or save money?', qa['how_will_i_earn_or_save'] ?? ''),
                  _buildQaItem('5. When will I receive money?', qa['when_will_i_receive_money'] ?? ''),
                  _buildQaItem(
                    '6. What should I be careful about?',
                    qa['what_to_be_careful_about'] ?? '',
                    isWarning: true,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Back to Opportunities'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQaItem(String question, String answer, {bool isWarning = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFFF3E0) : const Color(0xFFF9FBE7).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isWarning ? const Color(0xFFFFB74D) : const Color(0xFFDCEDC8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isWarning ? const Color(0xFFE65100) : const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 4),
          Text(answer, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: color ?? Colors.black87,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }

  // ==================== 4. OPPORTUNITY DETAIL & CASHFLOW ====================
  Widget _buildOpportunityDetailCard() {
    final sc = _scenario!;
    final opp = _selectedOpportunity!.opportunity;
    final isCostSaving = opp.isCostSaving;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1B5E20), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Color(0xFF1B5E20), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Financial Outlook: ${opp.title}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
                if (_isCalculating)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B5E20)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isCostSaving
                    ? 'This opportunity requires ${_formatCurrency(opp.minInvestmentInr)} upfront cash and generates an estimated ${_formatCurrency(opp.potentialAnnualSavingsInr)} in annual farm input savings.'
                    : 'Initial investment: ${_formatCurrency(sc.calculatedCapexInr)} (plus ${_formatCurrency(sc.workingCapitalInr)} working capital). Net annual cash surplus: ${_formatCurrency(sc.calculatedNetProfitAnnualInr)}.',
                style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
              ),
            ),
            const SizedBox(height: 14),
            if (sc.scenarios.isNotEmpty) ...[
              const Text(
                'Realistic Annual Scenarios:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (sc.scenarios.containsKey('conservative'))
                    Expanded(
                      child: _buildScenarioCard(
                        'Low',
                        _formatCurrency(sc.scenarios['conservative']!.netAnnualProfitInr),
                        '${sc.scenarios['conservative']!.breakEvenMonths.toStringAsFixed(0)}m payback',
                        Colors.orange.shade800,
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (sc.scenarios.containsKey('base'))
                    Expanded(
                      child: _buildScenarioCard(
                        'Expected',
                        _formatCurrency(sc.scenarios['base']!.netAnnualProfitInr),
                        '${sc.scenarios['base']!.breakEvenMonths.toStringAsFixed(0)}m payback',
                        const Color(0xFF1B5E20),
                        isHighlight: true,
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (sc.scenarios.containsKey('optimistic'))
                    Expanded(
                      child: _buildScenarioCard(
                        'High',
                        _formatCurrency(sc.scenarios['optimistic']!.netAnnualProfitInr),
                        '${sc.scenarios['optimistic']!.breakEvenMonths.toStringAsFixed(0)}m payback',
                        Colors.green.shade800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (sc.scenarios.containsKey('base') &&
                sc.scenarios['base']!.monthlyNetCashFlowInr.isNotEmpty) ...[
              const Text(
                '12-Month Cash Flow Horizon (Shows delay until first harvest/sale):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(
                    sc.scenarios['base']!.monthlyNetCashFlowInr.length,
                    (idx) {
                      final val = sc.scenarios['base']!.monthlyNetCashFlowInr[idx];
                      final isNegative = val < 0;
                      return Container(
                        width: 62,
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isNegative ? Colors.red.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isNegative ? Colors.red.shade200 : Colors.green.shade200,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Month ${idx + 1}',
                              style: const TextStyle(fontSize: 9, color: Colors.black54),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${isNegative ? "-" : "+"}₹${val.abs().toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isNegative ? Colors.red.shade800 : Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Key Operational Assumptions & Risks to Monitor',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1B5E20)),
              ),
              children: [
                if (opp.keyAssumptions.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Assumptions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  ...opp.keyAssumptions.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('• $a', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (opp.keyRisks.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Risks & Precautions:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange),
                    ),
                  ),
                  ...opp.keyRisks.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('• $r', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isSavingPlan
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.bookmark_add_outlined, size: 20),
                label: Text(
                  _isSavingPlan ? 'Saving Plan...' : 'Save This Opportunity to My Farm Plan',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _isSavingPlan ? null : _handleSavePlan,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioCard(String label, String profit, String payback, Color color, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: isHighlight ? 1.5 : 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: color)),
          const SizedBox(height: 2),
          Text(profit, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
          Text(payback, style: const TextStyle(fontSize: 9, color: Colors.black54)),
        ],
      ),
    );
  }

  // ==================== 5. COMPARISON TABLE CARD ====================
  Widget _buildComparisonCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Side-by-Side Comparison of Top Options',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'All metrics calculated from identical authoritative unit cost models:',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 14,
                headingRowHeight: 36,
                dataRowMinHeight: 42,
                dataRowMaxHeight: 50,
                columns: const [
                  DataColumn(label: Text('Enterprise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('Initial Cost', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(
                    label: Text('Yearly Return / Savings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  DataColumn(label: Text('Payback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('Water Needs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                ],
                rows: _comparisons.map((c) {
                  return DataRow(
                    cells: [
                      DataCell(Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                      DataCell(Text(_formatCurrency(c.initialInvestmentInr), style: const TextStyle(fontSize: 11))),
                      DataCell(
                        Text(
                          c.isCostSaving
                              ? '+${_formatCurrency(c.annualSavingsInr)} (Saved)'
                              : '+${_formatCurrency(c.netAnnualProfitInr)} (Profit)',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20), fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          c.paybackMonths <= 1 ? 'Immediate' : '${c.paybackMonths.toStringAsFixed(0)} mos',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(Text(c.waterNeeds, style: const TextStyle(fontSize: 11))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 6. SAVED PLANS CARD ====================
  Widget _buildSavedPlansCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bookmark_added, color: Color(0xFF1B5E20), size: 20),
                const SizedBox(width: 8),
                Text(
                  'My Saved Farm Plans (${_savedPlans.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._savedPlans.map((plan) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.opportunityTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            'Planned Investment: ${_formatCurrency(plan.plannedInvestmentInr)} · Saved on ${plan.createdAt.split("T").first}',
                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        plan.category.isNotEmpty ? plan.category.toUpperCase() : 'SAVED',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF1B5E20)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove saved plan',
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      onPressed: () => _handleDeletePlan(plan),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==================== 7. PROVENANCE & TRANSPARENCY CARD ====================
  Widget _buildProvenanceCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        leading: const Icon(Icons.verified_outlined, color: Colors.blueGrey),
        title: const Text(
          'Scientific Citations, NABARD Norms & Mandi Transparency',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey),
        ),
        subtitle: const Text(
          'Tap to view data sources, market benchmarks and University packages of practice',
          style: TextStyle(fontSize: 10, color: Colors.black54),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedOpportunity != null) ...[
                  Text(
                    'Opportunity Provenance: ${_selectedOpportunity!.opportunity.sourceAttribution}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  if (_selectedOpportunity!.opportunity.marketCommodity.isNotEmpty)
                    Text(
                      'Market Commodity Benchmark: ${_selectedOpportunity!.opportunity.marketCommodity} (${_selectedOpportunity!.opportunity.marketBenchmarkPrice}) · Source: ${_selectedOpportunity!.opportunity.marketSource}',
                      style: const TextStyle(fontSize: 10, color: Colors.black87),
                    ),
                  const SizedBox(height: 8),
                ],
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Methodology Standards: NABARD State Focus Paper for Maharashtra FY 2026-27 unit cost norms, MPKV Rahuri University Packages of Practices, ICAR-NIASM Baramati, and Agmarknet APMC modal mandi rates. No revenue guarantees provided; outputs are planning projections based on stated resource constraints.',
                    style: TextStyle(fontSize: 10, color: Colors.black54, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 8. RESOURCE SETTINGS BOTTOM SHEET ====================
  void _showResourceSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final budgetChips = [0.0, 1000.0, 5000.0, 15000.0, 30000.0, 50000.0, 100000.0];

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
                          'Adjust Farm Resources & Budget',
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

                    const Text('Your Age Range (Optional):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey('sheet_age_$_ageRange'),
                      isExpanded: true,
                      initialValue: _ageRange,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'under_25', child: Text('Under 25 years')),
                        DropdownMenuItem(value: '25-35', child: Text('25 – 35 years')),
                        DropdownMenuItem(value: '36-45', child: Text('36 – 45 years')),
                        DropdownMenuItem(value: '46-55', child: Text('46 – 55 years')),
                        DropdownMenuItem(value: '56-65', child: Text('56 – 65 years')),
                        DropdownMenuItem(value: 'above_65', child: Text('Above 65 years')),
                        DropdownMenuItem(value: 'prefer_not_to_say', child: Text('Prefer not to say')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => _ageRange = val);
                          setState(() => _ageRange = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    const Text('Daily Work Preference:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey('sheet_work_$_workPreference'),
                      isExpanded: true,
                      initialValue: _workPreference,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'daily_physical', child: Text('Active Physical Fieldwork (Can do heavy tasks)')),
                        DropdownMenuItem(value: 'light_physical', child: Text('Light Physical Work (Prefers less strenuous tasks)')),
                        DropdownMenuItem(value: 'manage_supervise', child: Text('Manage & Supervise (Family/hired labor will do heavy lifting)')),
                        DropdownMenuItem(value: 'family_help', child: Text('Family Co-managed Operations')),
                        DropdownMenuItem(value: 'hire_labor', child: Text('Delegated to Hired Workers')),
                        DropdownMenuItem(value: 'low_attention', child: Text('Low Daily Attention Activity')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => _workPreference = val);
                          setState(() => _workPreference = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    const Text('Desired Payback Timeline:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey('sheet_payback_$_paybackHorizon'),
                      isExpanded: true,
                      initialValue: _paybackHorizon,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'few_weeks', child: Text('Within a few weeks (Immediate cash / quick cycle)')),
                        DropdownMenuItem(value: 'within_6_months', child: Text('Within 6 months (Quick seasonal turnover)')),
                        DropdownMenuItem(value: '3_to_6_months', child: Text('3 to 6 months (Single season crop/poultry cycle)')),
                        DropdownMenuItem(value: '6_to_12_months', child: Text('6 to 12 months (Annual farm cycle)')),
                        DropdownMenuItem(value: 'more_than_year', child: Text('Longer term (> 1 year, e.g. horticulture/livestock)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => _paybackHorizon = val);
                          setState(() => _paybackHorizon = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Starting Cash Budget Available:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _availableInvestment == 0.0
                          ? '₹0 — Zero Extra Cash (Recycling, Better Selling, Cost Savings)'
                          : _formatCurrency(_availableInvestment),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B5E20)),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: budgetChips.map((b) {
                          final isSel = (_availableInvestment - b).abs() < 1.0;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(
                                b == 0 ? '₹0 (Free)' : _formatCurrency(b),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  color: isSel ? Colors.white : Colors.black87,
                                ),
                              ),
                              selected: isSel,
                              selectedColor: const Color(0xFF1B5E20),
                              onSelected: (val) {
                                if (val) {
                                  setModalState(() => _availableInvestment = b);
                                  setState(() => _availableInvestment = b);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Available Spare Land:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                          '${_availableLand.toStringAsFixed(2)} acres',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        ),
                      ],
                    ),
                    Slider(
                      value: _availableLand.clamp(0.0, 2.0),
                      min: 0.0,
                      max: 2.0,
                      divisions: 20,
                      activeColor: const Color(0xFF1B5E20),
                      label: '${_availableLand.toStringAsFixed(2)} ac',
                      onChanged: (val) {
                        setModalState(() => _availableLand = val);
                        setState(() {
                          _availableLand = val;
                          _unusedLand = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    const Text('Water Availability on Farm:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey('sheet_water_$_waterAvailability'),
                      isExpanded: true,
                      initialValue: _waterAvailability,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'reliable_year_round', child: Text('Borewell / Perennial Water (All Year)')),
                        DropdownMenuItem(value: 'seasonal_canal', child: Text('Seasonal Canal / Farm Pond (Oct–Mar)')),
                        DropdownMenuItem(value: 'rainfed_limited', child: Text('Rainfed / Limited Moisture (Kharif only)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => _waterAvailability = val);
                          setState(() => _waterAvailability = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Family Labor Available:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                          '${_familyLaborHours.toStringAsFixed(1)} hrs/day',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        ),
                      ],
                    ),
                    Slider(
                      value: _familyLaborHours.clamp(0.5, 6.0),
                      min: 0.5,
                      max: 6.0,
                      divisions: 11,
                      activeColor: const Color(0xFF1B5E20),
                      label: '${_familyLaborHours.toStringAsFixed(1)}h',
                      onChanged: (val) {
                        setModalState(() => _familyLaborHours = val);
                        setState(() => _familyLaborHours = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    const Text('Existing Assets on Farm:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Animal shed or enclosure available', style: TextStyle(fontSize: 12)),
                      value: _hasAnimalShed,
                      activeColor: const Color(0xFF1B5E20),
                      onChanged: (val) {
                        setModalState(() => _hasAnimalShed = val ?? false);
                        setState(() => _hasAnimalShed = val ?? false);
                      },
                    ),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Covered storage room / shed available', style: TextStyle(fontSize: 12)),
                      value: _hasStorageRoom,
                      activeColor: const Color(0xFF1B5E20),
                      onChanged: (val) {
                        setModalState(() => _hasStorageRoom = val ?? false);
                        setState(() => _hasStorageRoom = val ?? false);
                      },
                    ),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Surplus crop residue / cow dung on farm', style: TextStyle(fontSize: 12)),
                      value: _cropByproducts.isNotEmpty,
                      activeColor: const Color(0xFF1B5E20),
                      onChanged: (val) {
                        final list = val == true ? const ['soybean_straw', 'cow_dung'] : const <String>[];
                        setModalState(() => _cropByproducts = list);
                        setState(() => _cropByproducts = list);
                      },
                    ),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active FPO / Cooperative access nearby', style: TextStyle(fontSize: 12)),
                      value: _hasFpoAccess,
                      activeColor: const Color(0xFF1B5E20),
                      onChanged: (val) {
                        setModalState(() => _hasFpoAccess = val ?? false);
                        setState(() => _hasFpoAccess = val ?? false);
                      },
                    ),
                    const SizedBox(height: 14),

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
                          _saveProfileAndRecalculate();
                        },
                        child: const Text(
                          'Update & Discover Opportunities',
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
