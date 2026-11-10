import 'package:cropnet_mobile/core/network/api_client.dart';
import 'package:cropnet_mobile/core/network/api_constants.dart';
import 'package:cropnet_mobile/features/rashkar/models/rashkar_models.dart';

/// Typed repository connecting Rashkar's integrated Risk and Extra Income screens
/// to CropNet's authenticated FastAPI backend using the single shared Farm & Farmer context.
class RashkarRepository {
  RashkarRepository._internal({ApiClient? client}) : _client = client ?? ApiClient();
  static final RashkarRepository instance = RashkarRepository._internal();

  final ApiClient _client;

  Future<SharedFarmContext> getSharedContext(String farmId) {
    return _client.get<SharedFarmContext>(
      ApiConstants.farmSharedContext(farmId),
      fromJson: (json) => SharedFarmContext.fromJson(Map<String, dynamic>.from(json as Map)),
    );
  }

  Future<SharedFarmContext> updateSharedContext(
    String farmId, {
    SharedFarmerProfile? farmerProfile,
    FarmerResourceProfile? resourceProfile,
  }) {
    return _client.put<SharedFarmContext>(
      ApiConstants.farmSharedContext(farmId),
      body: {
        if (farmerProfile != null) 'farmer_profile': farmerProfile.toJson(),
        if (resourceProfile != null) 'resource_profile': resourceProfile.toJson(),
      },
      fromJson: (json) => SharedFarmContext.fromJson(Map<String, dynamic>.from(json as Map)),
    );
  }

  Future<FarmPlotRecord> createPlot(
    String farmId, {
    required String plotName,
    required double areaAcres,
    String? irrigationType,
  }) {
    return _client.post<FarmPlotRecord>(
      ApiConstants.farmPlots(farmId),
      body: {
        'plot_name': plotName,
        'area_acres': areaAcres,
        if (irrigationType != null) 'irrigation_type': irrigationType,
      },
      fromJson: (json) => FarmPlotRecord.fromJson(Map<String, dynamic>.from(json as Map)),
    );
  }

  Future<CropCycleRecord> createCropCycle(
    String farmId, {
    String? plotId,
    String plotName = 'Main Plot 1',
    required String cropCode,
    String? varietyName,
    String season = 'kharif',
    required String sowingDate,
    double? plantedAreaAcres,
    String? irrigationType,
    String? farmerConfirmedStage,
  }) {
    return _client.post<CropCycleRecord>(
      ApiConstants.farmCropCycles(farmId),
      body: {
        if (plotId != null) 'plot_id': plotId,
        'plot_name': plotName,
        'crop_code': cropCode,
        if (varietyName != null && varietyName.isNotEmpty) 'variety_name': varietyName,
        'season': season,
        'sowing_date': sowingDate,
        if (plantedAreaAcres != null) 'planted_area_acres': plantedAreaAcres,
        if (irrigationType != null) 'irrigation_type': irrigationType,
        if (farmerConfirmedStage != null) 'farmer_confirmed_stage': farmerConfirmedStage,
      },
      fromJson: (json) => CropCycleRecord.fromJson(Map<String, dynamic>.from(json as Map)),
    );
  }

  Future<List<Map<String, dynamic>>> getSupportedHeatCrops() {
    return _client.get<List<Map<String, dynamic>>>(
      ApiConstants.cropHeatSupportedCrops,
      fromJson: (json) {
        final raw = (json as Map)['crops'] as List<dynamic>? ?? const [];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      },
    );
  }

  Future<WorkerHeatResponse> assessWorkerHeat(
    String farmId, {
    String? workloadCategory,
    String? clothingType,
    bool? isAcclimatised,
    String? sunExposure,
    double? exposureDurationHours,
    bool saveAsDefault = true,
  }) {
    return _client.post<WorkerHeatResponse>(
      ApiConstants.farmWorkerHeat(farmId),
      body: {
        if (workloadCategory != null) 'workload_category': workloadCategory,
        if (clothingType != null) 'clothing_type': clothingType,
        if (isAcclimatised != null) 'is_acclimatised': isAcclimatised,
        if (sunExposure != null) 'sun_exposure': sunExposure,
        if (exposureDurationHours != null) 'exposure_duration_hours': exposureDurationHours,
        'save_as_default': saveAsDefault,
      },
      fromJson: (json) => WorkerHeatResponse.fromJson(Map<String, dynamic>.from(json as Map)),
    );
  }

  Future<CropHeatAssessment> assessCropHeat(
    String farmId, {
    String? plotId,
    String? cycleId,
    String? farmerConfirmedStage,
    double? forecastTmaxC,
    double? forecastTminC,
  }) {
    return _client.post<CropHeatAssessment>(
      ApiConstants.farmCropHeat(farmId),
      body: {
        if (plotId != null) 'plot_id': plotId,
        if (cycleId != null) 'cycle_id': cycleId,
        if (farmerConfirmedStage != null) 'farmer_confirmed_stage': farmerConfirmedStage,
        if (forecastTmaxC != null) 'forecast_tmax_c': forecastTmaxC,
        if (forecastTminC != null) 'forecast_tmin_c': forecastTminC,
      },
      fromJson: (json) => CropHeatAssessment.fromJson(Map<String, dynamic>.from(json as Map)),
    );
  }

  Future<SharedResourceProfileDTO> getFarmResourceProfile(String farmId) {
    return _client.get<SharedResourceProfileDTO>(
      ApiConstants.incomeFarmProfile(farmId),
      fromJson: (json) => SharedResourceProfileDTO.fromJson(Map<String, dynamic>.from(json as Map)),
    );
  }

  Future<SharedResourceProfileDTO> saveFarmResourceProfile(String farmId, FarmerResourceProfile profile) {
    return _client.put<SharedResourceProfileDTO>(
      ApiConstants.incomeFarmProfile(farmId),
      body: profile.toJson(),
      fromJson: (json) => SharedResourceProfileDTO.fromJson(Map<String, dynamic>.from(json as Map)),
    );
  }

  Future<List<ScoredOpportunityItem>> discoverFarmOpportunities(
    String farmId, {
    FarmerResourceProfile? overrideProfile,
  }) {
    return _client.post<List<ScoredOpportunityItem>>(
      ApiConstants.incomeFarmDiscover(farmId),
      body: overrideProfile?.toJson(),
      fromJson: (json) {
        final list = json as List<dynamic>;
        return list
            .map((item) => ScoredOpportunityItem.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      },
    );
  }

  Future<IncomeScenario> calculateIncomeScenario({
    required String opportunityId,
    required double customBudgetInr,
    double labourHours = 2.0,
    double landAcres = 0.0,
    String waterAvailability = 'seasonal_canal',
  }) {
    return _client.post<IncomeScenario>(
      ApiConstants.incomeCalculateScenario,
      body: {
        'opportunity_id': opportunityId,
        'custom_budget_inr': customBudgetInr,
        'available_labour_hours_day': labourHours,
        'available_land_acres': landAcres,
        'water_availability': waterAvailability,
      },
      fromJson: (json) => IncomeScenario.fromJson(Map<String, dynamic>.from(json as Map)),
    );
  }

  Future<List<OpportunityComparisonItem>> compareOpportunities({
    required List<String> opportunityIds,
    required double customBudgetInr,
  }) {
    return _client.post<List<OpportunityComparisonItem>>(
      ApiConstants.incomeCompareOpportunities,
      body: {
        'opportunity_ids': opportunityIds,
        'custom_budget_inr': customBudgetInr,
      },
      fromJson: (json) {
        final list = json as List<dynamic>;
        return list
            .map((item) => OpportunityComparisonItem.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      },
    );
  }

  Future<List<SavedIncomePlan>> getSavedIncomePlans(String farmId) {
    return _client.get<List<SavedIncomePlan>>(
      ApiConstants.incomeFarmPlans(farmId),
      fromJson: (json) {
        final list = json as List<dynamic>;
        return list.map((item) => SavedIncomePlan.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      },
    );
  }

  Future<SavedIncomePlan> saveIncomePlan(
    String farmId, {
    required String opportunityId,
    required double chosenBudgetInr,
    String? notes,
  }) {
    return _client.post<SavedIncomePlan>(
      ApiConstants.incomeFarmPlans(farmId),
      body: {
        'opportunity_id': opportunityId,
        'chosen_budget_inr': chosenBudgetInr,
        if (notes != null) 'notes': notes,
      },
      fromJson: (json) => SavedIncomePlan.fromJson(Map<String, dynamic>.from(json as Map)),
    );
  }

  Future<void> deleteSavedIncomePlan(String farmId, String planId) {
    return _client.delete<void>(ApiConstants.incomeFarmPlanById(farmId, planId));
  }
}
