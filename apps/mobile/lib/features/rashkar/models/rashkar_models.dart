import 'dart:convert';
import 'package:cropnet_mobile/core/network/api_exception.dart';

/// Raised when a Rashkar feature detects genuinely missing farmer registration
/// fields so the UI can collect ONLY those missing fields and save them once.
class MissingSharedContextException implements Exception {
  final String code;
  final String message;
  final List<String> missingFields;

  const MissingSharedContextException({
    required this.code,
    required this.message,
    required this.missingFields,
  });

  static MissingSharedContextException? tryParse(Object error) {
    if (error is MissingSharedContextException) return error;
    if (error is ApiException && error.statusCode == 422 && error.details != null) {
      try {
        dynamic decoded = error.details;
        if (decoded is String) {
          decoded = jsonDecode(decoded);
        }
        if (decoded is Map) {
          final dynamic detailRaw = decoded['detail'] ?? decoded;
          if (detailRaw is Map && detailRaw['code'] != null) {
            return MissingSharedContextException(
              code: detailRaw['code'].toString(),
              message: detailRaw['message']?.toString() ?? 'Missing required farm profile inputs.',
              missingFields: List<String>.from(detailRaw['missing_fields'] ?? const []),
            );
          }
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  String toString() => message;
}

class SharedFarmerProfile {
  final String? farmerId;
  final String? fullName;
  final String? phoneNumber;
  final String preferredLanguage;
  final String? ageRange;
  final String? workPreference;
  final String? paybackHorizon;
  final String? familyManagementRole;
  final String? defaultWorkloadCategory;
  final String? defaultClothingType;
  final bool? defaultIsAcclimatised;
  final String? defaultSunExposure;
  final double? defaultExposureDurationHours;

  const SharedFarmerProfile({
    this.farmerId,
    this.fullName,
    this.phoneNumber,
    this.preferredLanguage = 'en',
    this.ageRange,
    this.workPreference,
    this.paybackHorizon,
    this.familyManagementRole,
    this.defaultWorkloadCategory,
    this.defaultClothingType,
    this.defaultIsAcclimatised,
    this.defaultSunExposure,
    this.defaultExposureDurationHours,
  });

  factory SharedFarmerProfile.fromJson(Map<String, dynamic> json) {
    return SharedFarmerProfile(
      farmerId: json['farmer_id'] as String?,
      fullName: json['full_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      preferredLanguage: json['preferred_language'] as String? ?? 'en',
      ageRange: json['age_range'] as String?,
      workPreference: json['work_preference'] as String?,
      paybackHorizon: json['payback_horizon'] as String?,
      familyManagementRole: json['family_management_role'] as String?,
      defaultWorkloadCategory: json['default_workload_category'] as String?,
      defaultClothingType: json['default_clothing_type'] as String?,
      defaultIsAcclimatised: json['default_is_acclimatised'] as bool?,
      defaultSunExposure: json['default_sun_exposure'] as String?,
      defaultExposureDurationHours: (json['default_exposure_duration_hours'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (farmerId != null) 'farmer_id': farmerId,
        if (fullName != null) 'full_name': fullName,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        'preferred_language': preferredLanguage,
        if (ageRange != null) 'age_range': ageRange,
        if (workPreference != null) 'work_preference': workPreference,
        if (paybackHorizon != null) 'payback_horizon': paybackHorizon,
        if (familyManagementRole != null) 'family_management_role': familyManagementRole,
        if (defaultWorkloadCategory != null) 'default_workload_category': defaultWorkloadCategory,
        if (defaultClothingType != null) 'default_clothing_type': defaultClothingType,
        if (defaultIsAcclimatised != null) 'default_is_acclimatised': defaultIsAcclimatised,
        if (defaultSunExposure != null) 'default_sun_exposure': defaultSunExposure,
        if (defaultExposureDurationHours != null) 'default_exposure_duration_hours': defaultExposureDurationHours,
      };
}

class FarmPlotRecord {
  final String plotId;
  final String farmId;
  final String plotName;
  final double areaAcres;
  final String? irrigationType;

  const FarmPlotRecord({
    required this.plotId,
    required this.farmId,
    required this.plotName,
    required this.areaAcres,
    this.irrigationType,
  });

  factory FarmPlotRecord.fromJson(Map<String, dynamic> json) {
    return FarmPlotRecord(
      plotId: json['plot_id']?.toString() ?? '',
      farmId: json['farm_id']?.toString() ?? '',
      plotName: json['plot_name']?.toString() ?? 'Plot',
      areaAcres: (json['area_acres'] as num?)?.toDouble() ?? 1.0,
      irrigationType: json['irrigation_type'] as String?,
    );
  }
}

class CropCycleRecord {
  final String cycleId;
  final String plotId;
  final String plotName;
  final String farmId;
  final String cropCode;
  final String? varietyName;
  final String season;
  final String sowingDate;
  final double? plantedAreaAcres;
  final String? irrigationType;
  final String? currentStageCode;
  final String? estimatedStageCode;
  final String? estimatedStageName;
  final int? daysAfterSowing;
  final bool isActive;

  const CropCycleRecord({
    required this.cycleId,
    required this.plotId,
    required this.plotName,
    required this.farmId,
    required this.cropCode,
    this.varietyName,
    required this.season,
    required this.sowingDate,
    this.plantedAreaAcres,
    this.irrigationType,
    this.currentStageCode,
    this.estimatedStageCode,
    this.estimatedStageName,
    this.daysAfterSowing,
    this.isActive = true,
  });

  factory CropCycleRecord.fromJson(Map<String, dynamic> json) {
    return CropCycleRecord(
      cycleId: json['cycle_id']?.toString() ?? '',
      plotId: json['plot_id']?.toString() ?? '',
      plotName: json['plot_name']?.toString() ?? 'Plot',
      farmId: json['farm_id']?.toString() ?? '',
      cropCode: json['crop_code']?.toString() ?? '',
      varietyName: json['variety_name'] as String?,
      season: json['season']?.toString() ?? 'kharif',
      sowingDate: json['sowing_date']?.toString() ?? '',
      plantedAreaAcres: (json['planted_area_acres'] as num?)?.toDouble(),
      irrigationType: json['irrigation_type'] as String?,
      currentStageCode: json['current_stage_code'] as String?,
      estimatedStageCode: json['estimated_stage_code'] as String?,
      estimatedStageName: json['estimated_stage_name'] as String?,
      daysAfterSowing: json['days_after_sowing'] as int?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class SharedResourceProfileDTO {
  final String farmId;
  final String? farmerId;
  final bool profileCompleted;
  final List<String> missingFields;
  final double? availableInvestmentInr;
  final double? monthlyOperatingBudgetInr;
  final double? totalFarmAcres;
  final double? cultivatedAcres;
  final double? availableLandAcres;
  final double? unusedLandAcres;
  final bool? fieldBundsAvailable;
  final bool? hasAnimalShed;
  final bool? hasStorageRoom;
  final bool? hasShadedSpace;
  final String? waterAvailability;
  final double? familyLaborHoursDay;
  final bool? hiredLaborPossible;
  final String? existingLivestock;
  final List<String> existingAssets;
  final List<String> cropByproducts;
  final bool? byproductSurplusAvailable;
  final List<String> interests;
  final bool? hasTransport;
  final bool? hasFpoAccess;
  final String? riskTolerance;
  final String? categoryPreference;
  final String? ageRange;
  final String? workPreference;
  final String? paybackHorizon;
  final String? familyManagementRole;
  final String? currentCropCode;
  final String? currentCropStage;

  const SharedResourceProfileDTO({
    required this.farmId,
    this.farmerId,
    required this.profileCompleted,
    this.missingFields = const [],
    this.availableInvestmentInr,
    this.monthlyOperatingBudgetInr,
    this.totalFarmAcres,
    this.cultivatedAcres,
    this.availableLandAcres,
    this.unusedLandAcres,
    this.fieldBundsAvailable,
    this.hasAnimalShed,
    this.hasStorageRoom,
    this.hasShadedSpace,
    this.waterAvailability,
    this.familyLaborHoursDay,
    this.hiredLaborPossible,
    this.existingLivestock,
    this.existingAssets = const [],
    this.cropByproducts = const [],
    this.byproductSurplusAvailable,
    this.interests = const [],
    this.hasTransport,
    this.hasFpoAccess,
    this.riskTolerance,
    this.categoryPreference,
    this.ageRange,
    this.workPreference,
    this.paybackHorizon,
    this.familyManagementRole,
    this.currentCropCode,
    this.currentCropStage,
  });

  factory SharedResourceProfileDTO.fromJson(Map<String, dynamic> json) {
    return SharedResourceProfileDTO(
      farmId: json['farm_id']?.toString() ?? '',
      farmerId: json['farmer_id'] as String?,
      profileCompleted: json['profile_completed'] as bool? ?? false,
      missingFields: List<String>.from(json['missing_fields'] ?? const []),
      availableInvestmentInr: (json['available_investment_inr'] as num?)?.toDouble(),
      monthlyOperatingBudgetInr: (json['monthly_operating_budget_inr'] as num?)?.toDouble(),
      totalFarmAcres: (json['total_farm_acres'] as num?)?.toDouble(),
      cultivatedAcres: (json['cultivated_acres'] as num?)?.toDouble(),
      availableLandAcres: (json['available_land_acres'] as num?)?.toDouble(),
      unusedLandAcres: (json['unused_land_acres'] as num?)?.toDouble(),
      fieldBundsAvailable: json['field_bunds_available'] as bool?,
      hasAnimalShed: json['has_animal_shed'] as bool?,
      hasStorageRoom: json['has_storage_room'] as bool?,
      hasShadedSpace: json['has_shaded_space'] as bool?,
      waterAvailability: json['water_availability'] as String?,
      familyLaborHoursDay: (json['family_labor_hours_day'] as num?)?.toDouble(),
      hiredLaborPossible: json['hired_labor_possible'] as bool?,
      existingLivestock: json['existing_livestock'] as String?,
      existingAssets: List<String>.from(json['existing_assets'] ?? const []),
      cropByproducts: List<String>.from(json['crop_byproducts'] ?? const []),
      byproductSurplusAvailable: json['byproduct_surplus_available'] as bool?,
      interests: List<String>.from(json['interests'] ?? const []),
      hasTransport: json['has_transport'] as bool?,
      hasFpoAccess: json['has_fpo_access'] as bool?,
      riskTolerance: json['risk_tolerance'] as String?,
      categoryPreference: json['category_preference'] as String?,
      ageRange: json['age_range'] as String?,
      workPreference: json['work_preference'] as String?,
      paybackHorizon: json['payback_horizon'] as String?,
      familyManagementRole: json['family_management_role'] as String?,
      currentCropCode: json['current_crop_code'] as String?,
      currentCropStage: json['current_crop_stage'] as String?,
    );
  }
}

class SharedFarmContext {
  final String farmId;
  final String farmName;
  final String taluka;
  final String district;
  final String state;
  final String? village;
  final double latitude;
  final double longitude;
  final double totalAreaAcres;
  final double totalAreaHectares;
  final String? irrigationType;
  final String? waterSource;
  final SharedFarmerProfile farmerProfile;
  final List<FarmPlotRecord> plots;
  final List<CropCycleRecord> cropCycles;
  final SharedResourceProfileDTO resourceProfile;
  final List<String> workerHeatMissingFields;
  final List<String> cropHeatMissingFields;
  final List<String> extraIncomeMissingFields;

  const SharedFarmContext({
    required this.farmId,
    required this.farmName,
    required this.taluka,
    required this.district,
    required this.state,
    this.village,
    required this.latitude,
    required this.longitude,
    required this.totalAreaAcres,
    required this.totalAreaHectares,
    this.irrigationType,
    this.waterSource,
    required this.farmerProfile,
    this.plots = const [],
    this.cropCycles = const [],
    required this.resourceProfile,
    this.workerHeatMissingFields = const [],
    this.cropHeatMissingFields = const [],
    this.extraIncomeMissingFields = const [],
  });

  factory SharedFarmContext.fromJson(Map<String, dynamic> json) {
    return SharedFarmContext(
      farmId: json['farm_id']?.toString() ?? '',
      farmName: json['farm_name']?.toString() ?? 'Farm',
      taluka: json['taluka']?.toString() ?? 'Baramati',
      district: json['district']?.toString() ?? 'Pune',
      state: json['state']?.toString() ?? 'Maharashtra',
      village: json['village'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 18.18,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 74.53,
      totalAreaAcres: (json['total_area_acres'] as num?)?.toDouble() ?? 0.0,
      totalAreaHectares: (json['total_area_hectares'] as num?)?.toDouble() ?? 0.0,
      irrigationType: json['irrigation_type'] as String?,
      waterSource: json['water_source'] as String?,
      farmerProfile: SharedFarmerProfile.fromJson(
        Map<String, dynamic>.from(json['farmer_profile'] ?? {}),
      ),
      plots: (json['plots'] as List<dynamic>? ?? [])
          .map((p) => FarmPlotRecord.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      cropCycles: (json['crop_cycles'] as List<dynamic>? ?? [])
          .map((c) => CropCycleRecord.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
      resourceProfile: SharedResourceProfileDTO.fromJson(
        Map<String, dynamic>.from(json['resource_profile'] ?? {}),
      ),
      workerHeatMissingFields: List<String>.from(json['worker_heat_missing_fields'] ?? const []),
      cropHeatMissingFields: List<String>.from(json['crop_heat_missing_fields'] ?? const []),
      extraIncomeMissingFields: List<String>.from(json['extra_income_missing_fields'] ?? const []),
    );
  }
}

// ==================== WORKER HEAT MODELS ====================

class WorkerHourlyProjection {
  final int forecastHourOffset;
  final String validTimeIst;
  final double airTempC;
  final double relativeHumidityPct;
  final double windSpeedMs;
  final double solarIrradianceWm2;
  final double wbgtEstimatedC;
  final double wbgtEffectiveC;
  final String hazardLevel;
  final bool exceedsScreeningThreshold;
  final double thresholdLimitC;
  final String trend;
  final String workRestCycle;
  final double? heatIndexC;
  final double? utciC;

  WorkerHourlyProjection({
    required this.forecastHourOffset,
    required this.validTimeIst,
    required this.airTempC,
    required this.relativeHumidityPct,
    required this.windSpeedMs,
    required this.solarIrradianceWm2,
    required this.wbgtEstimatedC,
    required this.wbgtEffectiveC,
    required this.hazardLevel,
    required this.exceedsScreeningThreshold,
    required this.thresholdLimitC,
    required this.trend,
    required this.workRestCycle,
    this.heatIndexC,
    this.utciC,
  });

  factory WorkerHourlyProjection.fromJson(Map<String, dynamic> json) {
    return WorkerHourlyProjection(
      forecastHourOffset: json['forecast_hour_offset'] ?? 0,
      validTimeIst: json['valid_time_ist'] ?? '',
      airTempC: (json['air_temp_c'] as num?)?.toDouble() ?? 32.0,
      relativeHumidityPct: (json['relative_humidity_pct'] as num?)?.toDouble() ?? 50.0,
      windSpeedMs: (json['wind_speed_ms'] as num?)?.toDouble() ?? 1.5,
      solarIrradianceWm2: (json['solar_irradiance_wm2'] as num?)?.toDouble() ?? 500.0,
      wbgtEstimatedC: (json['wbgt_estimated_c'] as num?)?.toDouble() ?? 27.5,
      wbgtEffectiveC: (json['wbgt_effective_c'] as num?)?.toDouble() ?? 27.5,
      hazardLevel: json['hazard_level'] ?? 'LOW',
      exceedsScreeningThreshold: json['exceeds_screening_threshold'] ?? false,
      thresholdLimitC: (json['threshold_limit_c'] as num?)?.toDouble() ?? 28.0,
      trend: json['trend'] ?? 'STEADY',
      workRestCycle: json['work_rest_cycle'] ?? 'Continuous work',
      heatIndexC: (json['heat_index_c'] as num?)?.toDouble(),
      utciC: (json['utci_c'] as num?)?.toDouble(),
    );
  }
}

class WorkerHeatResponse {
  final String sessionId;
  final String generatedAtIst;
  final String farmLocationDisplay;
  final String weatherSourceName;
  final String weatherRetrievalTimeIst;
  final String isObservedOrForecast;
  final double currentAirTempC;
  final double currentRelativeHumidityPct;
  final double currentDewPointC;
  final double currentWindSpeedMs;
  final double currentWindSpeedKmh;
  final double currentSolarRadiationWm2;
  final double currentWbgtEstimatedC;
  final double? currentHeatIndexC;
  final double? currentUtciC;
  final Map<String, dynamic> personalizedHeatStrainScore;
  final Map<String, dynamic> topographicDownscaling;
  final Map<String, dynamic> mlForecastMetadata;
  final String nextAssessmentRefreshIst;
  final String dataConfidence;
  final String peakRiskHourIst;
  final String peakRiskReason;
  final List<WorkerHourlyProjection> hourlyProjections;
  final String workloadCategory;
  final String clothingType;
  final double clothingCavC;
  final bool isAcclimatised;
  final String sunExposure;
  final double exposureDurationHours;
  final String currentHazardLevel;
  final String maxHazardLevelInWindow;
  final double maxWbgtEffectiveC;
  final double screeningThresholdC;
  final String categorySelectionReason;
  final List<String> mainContributingFactors;
  final String workloadInteractionExplanation;
  final String methodologyReference;
  final String methodologyStandardsVersion;
  final String thresholdMeaningExplanation;
  final String safetyGuaranteeDisclaimer;
  final Map<String, dynamic> technicalDetails;
  final String disclaimer;
  final List<String> safetyCautions;
  final Map<String, dynamic> hydrationGuidance;
  final List<String> beforeWorkGuidance;
  final List<String> duringWorkGuidance;
  final List<String> highRiskActions;
  final Map<String, dynamic> emergencyTriage;
  final Map<String, String> localEmergencyContacts;
  final String thresholdComparisonMessage;
  final double thresholdDifferenceC;
  final String thresholdComparisonState;
  final double plannedShiftDurationHours;
  final int forecastCoverageHours;
  final bool shiftExceedsForecastCoverage;
  final String? coverageLimitationWarning;
  final String spatialResolution;
  final String gridCoordinates;
  final String validTimeIst;

  String get hazardLevel => currentHazardLevel.toLowerCase();

  WorkerHeatResponse({
    this.sessionId = '',
    this.generatedAtIst = '',
    this.farmLocationDisplay = '',
    this.weatherSourceName = 'WMO Global NWP / IMD',
    this.weatherRetrievalTimeIst = '',
    this.isObservedOrForecast = 'Forecast (Operational WMO NWP)',
    required this.currentAirTempC,
    required this.currentRelativeHumidityPct,
    this.currentDewPointC = 20.0,
    this.currentWindSpeedMs = 1.8,
    this.currentWindSpeedKmh = 6.5,
    this.currentSolarRadiationWm2 = 600.0,
    required this.currentWbgtEstimatedC,
    this.currentHeatIndexC,
    this.currentUtciC,
    this.personalizedHeatStrainScore = const {},
    this.topographicDownscaling = const {},
    this.mlForecastMetadata = const {},
    this.nextAssessmentRefreshIst = '',
    this.dataConfidence = 'HIGH',
    this.peakRiskHourIst = '',
    this.peakRiskReason = '',
    this.hourlyProjections = const [],
    this.workloadCategory = 'moderate',
    this.clothingType = 'standard_work_clothes',
    this.clothingCavC = 0.0,
    this.isAcclimatised = true,
    this.sunExposure = 'direct_sun',
    this.exposureDurationHours = 3.0,
    required this.currentHazardLevel,
    this.maxHazardLevelInWindow = 'MODERATE',
    this.maxWbgtEffectiveC = 28.0,
    this.screeningThresholdC = 28.0,
    this.thresholdComparisonMessage = '',
    this.thresholdDifferenceC = 0.0,
    this.thresholdComparisonState = 'BELOW',
    this.plannedShiftDurationHours = 4.0,
    this.forecastCoverageHours = 6,
    this.shiftExceedsForecastCoverage = false,
    this.coverageLimitationWarning,
    this.spatialResolution = '0.1° (~11 km grid resolution)',
    this.gridCoordinates = 'Lat 18.15°N, Lon 74.58°E',
    this.validTimeIst = 'Next 6 Hours',
    this.categorySelectionReason = '',
    this.mainContributingFactors = const [],
    this.workloadInteractionExplanation = '',
    this.methodologyReference = 'Liljegren et al. (2008)',
    this.methodologyStandardsVersion = 'ACGIH 2023 TLVs & ISO 7243:2017 screening action limits',
    this.thresholdMeaningExplanation = '',
    this.safetyGuaranteeDisclaimer = '',
    this.technicalDetails = const {},
    this.disclaimer = '',
    this.safetyCautions = const [],
    this.hydrationGuidance = const {},
    this.beforeWorkGuidance = const [],
    this.duringWorkGuidance = const [],
    this.highRiskActions = const [],
    this.emergencyTriage = const {},
    this.localEmergencyContacts = const {},
  });

  factory WorkerHeatResponse.fromJson(Map<String, dynamic> json) {
    final rawProjections = json['hourly_projections'] as List? ?? [];
    return WorkerHeatResponse(
      sessionId: json['session_id'] ?? '',
      generatedAtIst: json['generated_at_ist'] ?? '',
      farmLocationDisplay: json['farm_location_display'] ?? '',
      weatherSourceName: json['weather_source_name'] ?? 'Operational WMO NWP',
      weatherRetrievalTimeIst: json['weather_retrieval_time_ist'] ?? '',
      isObservedOrForecast: json['is_observed_or_forecast'] ?? 'Forecast (Operational WMO NWP)',
      currentAirTempC: (json['current_air_temp_c'] as num?)?.toDouble() ?? 32.0,
      currentRelativeHumidityPct: (json['current_relative_humidity_pct'] as num?)?.toDouble() ?? 50.0,
      currentDewPointC: (json['current_dew_point_c'] as num?)?.toDouble() ?? 21.0,
      currentWindSpeedMs: (json['current_wind_speed_ms'] as num?)?.toDouble() ?? 1.8,
      currentWindSpeedKmh: (json['current_wind_speed_kmh'] as num?)?.toDouble() ?? 6.5,
      currentSolarRadiationWm2: (json['current_solar_radiation_wm2'] as num?)?.toDouble() ?? 600.0,
      currentWbgtEstimatedC: (json['current_wbgt_estimated_c'] as num?)?.toDouble() ?? 27.8,
      currentHeatIndexC: (json['current_heat_index_c'] as num?)?.toDouble(),
      currentUtciC: (json['current_utci_c'] as num?)?.toDouble(),
      personalizedHeatStrainScore: Map<String, dynamic>.from(json['personalized_heat_strain_score'] ?? {}),
      topographicDownscaling: Map<String, dynamic>.from(json['topographic_downscaling'] ?? {}),
      mlForecastMetadata: Map<String, dynamic>.from(json['ml_forecast_metadata'] ?? {}),
      nextAssessmentRefreshIst: json['next_assessment_refresh_ist'] ?? '',
      dataConfidence: json['data_confidence'] ?? 'HIGH',
      peakRiskHourIst: json['peak_risk_hour_ist'] ?? '',
      peakRiskReason: json['peak_risk_reason'] ?? '',
      hourlyProjections: rawProjections.map((p) => WorkerHourlyProjection.fromJson(Map<String, dynamic>.from(p as Map))).toList(),
      workloadCategory: json['workload_category'] ?? 'moderate',
      clothingType: json['clothing_type'] ?? 'standard_work_clothes',
      clothingCavC: (json['clothing_cav_c'] as num?)?.toDouble() ?? 0.0,
      isAcclimatised: json['is_acclimatised'] ?? true,
      sunExposure: json['sun_exposure'] ?? 'direct_sun',
      exposureDurationHours: (json['exposure_duration_hours'] as num?)?.toDouble() ?? 3.0,
      currentHazardLevel: json['current_hazard_level'] ?? 'LOW',
      maxHazardLevelInWindow: json['max_hazard_level_in_window'] ?? 'MODERATE',
      maxWbgtEffectiveC: (json['max_wbgt_effective_c'] as num?)?.toDouble() ?? 28.0,
      screeningThresholdC: (json['screening_threshold_c'] as num?)?.toDouble() ?? 28.0,
      thresholdComparisonMessage: json['threshold_comparison_message'] ?? '',
      thresholdDifferenceC: (json['threshold_difference_c'] as num?)?.toDouble() ?? 0.0,
      thresholdComparisonState: json['threshold_comparison_state'] ?? 'BELOW',
      plannedShiftDurationHours: (json['planned_shift_duration_hours'] as num?)?.toDouble() ??
          (json['exposure_duration_hours'] as num?)?.toDouble() ??
          4.0,
      forecastCoverageHours: json['forecast_coverage_hours'] ?? 6,
      shiftExceedsForecastCoverage: json['shift_exceeds_forecast_coverage'] ?? false,
      coverageLimitationWarning: json['coverage_limitation_warning'],
      spatialResolution: json['spatial_resolution'] ?? '0.1° (~11 km grid resolution)',
      gridCoordinates: json['grid_coordinates'] ?? 'Lat 18.15°N, Lon 74.58°E',
      validTimeIst: json['valid_time_ist'] ?? 'Next 6 Hours',
      categorySelectionReason: json['category_selection_reason'] ?? '',
      mainContributingFactors: List<String>.from(json['main_contributing_factors'] ?? const []),
      workloadInteractionExplanation: json['workload_interaction_explanation'] ?? '',
      methodologyReference: json['methodology_reference'] ?? 'Liljegren et al. (2008)',
      methodologyStandardsVersion:
          json['methodology_standards_version'] ?? 'ACGIH 2023 TLVs & ISO 7243:2017 screening action limits',
      thresholdMeaningExplanation: json['threshold_meaning_explanation'] ?? '',
      safetyGuaranteeDisclaimer: json['safety_guarantee_disclaimer'] ?? '',
      technicalDetails: Map<String, dynamic>.from(json['technical_details'] ?? {}),
      disclaimer: json['disclaimer'] ?? '',
      safetyCautions: List<String>.from(json['safety_cautions'] ?? const []),
      hydrationGuidance: Map<String, dynamic>.from(json['hydration_guidance'] ?? {}),
      beforeWorkGuidance: List<String>.from(json['before_work_guidance'] ?? const []),
      duringWorkGuidance: List<String>.from(json['during_work_guidance'] ?? const []),
      highRiskActions: List<String>.from(json['high_risk_actions'] ?? const []),
      emergencyTriage: Map<String, dynamic>.from(json['emergency_triage'] ?? {}),
      localEmergencyContacts: Map<String, String>.from(
        (json['local_emergency_contacts'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v.toString())),
      ),
    );
  }
}

// ==================== CROP HEAT MODELS ====================

class CropDailyOutlook {
  final String date;
  final String dayLabel;
  final double tmaxC;
  final double tminC;
  final double hoursAboveCritical;
  final String riskCategory;
  final String explanation;

  CropDailyOutlook({
    required this.date,
    required this.dayLabel,
    required this.tmaxC,
    required this.tminC,
    required this.hoursAboveCritical,
    required this.riskCategory,
    required this.explanation,
  });

  factory CropDailyOutlook.fromJson(Map<String, dynamic> json) {
    return CropDailyOutlook(
      date: json['date'] ?? '',
      dayLabel: json['day_label'] ?? '',
      tmaxC: (json['tmax_c'] as num?)?.toDouble() ?? 35.0,
      tminC: (json['tmin_c'] as num?)?.toDouble() ?? 23.0,
      hoursAboveCritical: (json['hours_above_critical'] as num?)?.toDouble() ?? 0.0,
      riskCategory: json['risk_category'] ?? 'LOW',
      explanation: json['explanation'] ?? '',
    );
  }
}

class CropHeatIntervention {
  final String interventionId;
  final String titleEn;
  final String titleMr;
  final String descriptionEn;
  final String descriptionMr;
  final String whyAppropriate;
  final String evidenceCitation;
  final String category;
  final String? sourcePageOrTable;
  final String? agronomistReviewer;
  final String? applicationMethod;
  final String? applicationDose;
  final String? infrastructureRequirements;
  final String? triggerCondition;

  CropHeatIntervention({
    required this.interventionId,
    required this.titleEn,
    required this.titleMr,
    required this.descriptionEn,
    required this.descriptionMr,
    required this.whyAppropriate,
    required this.evidenceCitation,
    required this.category,
    this.sourcePageOrTable,
    this.agronomistReviewer,
    this.applicationMethod,
    this.applicationDose,
    this.infrastructureRequirements,
    this.triggerCondition,
  });

  factory CropHeatIntervention.fromJson(Map<String, dynamic> json) {
    return CropHeatIntervention(
      interventionId: json['intervention_id'] ?? '',
      titleEn: json['title_en'] ?? '',
      titleMr: json['title_mr'] ?? '',
      descriptionEn: json['description_en'] ?? '',
      descriptionMr: json['description_mr'] ?? '',
      whyAppropriate: json['why_appropriate'] ?? '',
      evidenceCitation: json['evidence_citation'] ?? '',
      category: json['category'] ?? 'VERIFIED_AGRONOMIC',
      sourcePageOrTable: json['source_page_or_table'],
      agronomistReviewer: json['agronomist_reviewer'],
      applicationMethod: json['application_method'],
      applicationDose: json['application_dose'],
      infrastructureRequirements: json['infrastructure_requirements'],
      triggerCondition: json['trigger_condition'],
    );
  }
}

class CropHeatAssessment {
  final String assessmentId;
  final String farmId;
  final String farmName;
  final String plotName;
  final String cropCode;
  final String cropCommonName;
  final String cropVariety;
  final String sowingDate;
  final int daysAfterSowing;
  final double cropAreaAcres;
  final String irrigationStatus;
  final String soilTexture;
  final String soilProvenanceLabel;
  final bool isSoilSynthetic;
  final bool isSeasonExpired;
  final String seasonStatus;
  final bool requiresSeasonUpdate;
  final String? seasonExpiryMessage;
  final String? growthStageCode;
  final String growthStageNameEn;
  final String growthStageNameMr;
  final List<Map<String, dynamic>> supportedStages;
  final String? farmerConfirmedStage;
  final double baseTempC;
  final double optimalTempMinC;
  final double optimalTempMaxC;
  final double criticalTmaxThresholdC;
  final double criticalTminThresholdC;
  final double tmaxForecastC;
  final double tminForecastC;
  final double hoursAboveCritical;
  final int consecutiveHotDays;
  final double daytimeExposureHours;
  final bool warmNightRespirationHazard;
  final double warmNightPenaltyScore;
  final double cumulativeHeatUnitsGdd;
  final String evidenceCitation;
  final String evidenceStatus;
  final List<CropDailyOutlook> dailyOutlook;
  final String daytimeHeatStressLevel;
  final String overallCropHeatRisk;
  final String physiologicalMechanism;
  final String stageBiologicalVulnerability;
  final List<CropHeatIntervention> recommendedInterventions;
  final List<Map<String, dynamic>> assessmentHistory;
  final Map<String, dynamic> personalizedCropVulnerabilityScore;
  final Map<String, dynamic> topographicDownscaling;

  CropHeatAssessment({
    required this.assessmentId,
    required this.farmId,
    required this.farmName,
    required this.plotName,
    required this.cropCode,
    required this.cropCommonName,
    this.cropVariety = 'Variety not recorded',
    required this.sowingDate,
    required this.daysAfterSowing,
    required this.cropAreaAcres,
    required this.irrigationStatus,
    required this.soilTexture,
    this.soilProvenanceLabel = 'CropNet Model Estimate (Unsampled Farm Coordinate)',
    this.isSoilSynthetic = true,
    this.isSeasonExpired = false,
    this.seasonStatus = 'ACTIVE',
    this.requiresSeasonUpdate = false,
    this.seasonExpiryMessage,
    this.growthStageCode,
    this.growthStageNameEn = '',
    this.growthStageNameMr = '',
    this.supportedStages = const [],
    this.farmerConfirmedStage,
    required this.baseTempC,
    required this.optimalTempMinC,
    required this.optimalTempMaxC,
    required this.criticalTmaxThresholdC,
    required this.criticalTminThresholdC,
    required this.tmaxForecastC,
    required this.tminForecastC,
    required this.hoursAboveCritical,
    required this.consecutiveHotDays,
    required this.daytimeExposureHours,
    required this.warmNightRespirationHazard,
    required this.warmNightPenaltyScore,
    required this.cumulativeHeatUnitsGdd,
    required this.evidenceCitation,
    required this.evidenceStatus,
    this.dailyOutlook = const [],
    required this.daytimeHeatStressLevel,
    required this.overallCropHeatRisk,
    required this.physiologicalMechanism,
    this.stageBiologicalVulnerability = '',
    this.recommendedInterventions = const [],
    this.assessmentHistory = const [],
    this.personalizedCropVulnerabilityScore = const {},
    this.topographicDownscaling = const {},
  });

  factory CropHeatAssessment.fromJson(Map<String, dynamic> json) {
    final rawOutlook = json['daily_outlook'] as List? ?? json['four_day_outlook'] as List? ?? [];
    final rawInterventions = json['recommended_interventions'] as List? ?? json['field_recommendations'] as List? ?? [];
    final rawStages = json['supported_stages'] as List? ?? [];
    final rawHistory = json['assessment_history'] as List? ?? [];

    return CropHeatAssessment(
      assessmentId: json['assessment_id'] ?? '',
      farmId: json['farm_id'] ?? '',
      farmName: json['farm_name'] ?? '',
      plotName: json['plot_name'] ?? '',
      cropCode: json['crop_code'] ?? 'soybean',
      cropCommonName: json['crop_common_name'] ?? json['crop_code'] ?? 'Crop',
      cropVariety: json['crop_variety'] ?? 'Variety not recorded',
      sowingDate: json['sowing_date'] ?? '',
      daysAfterSowing: json['days_after_sowing'] ?? 45,
      cropAreaAcres: (json['crop_area_acres'] as num?)?.toDouble() ?? 2.5,
      irrigationStatus: json['irrigation_status'] ?? 'Rainfed',
      soilTexture: json['soil_texture'] ?? 'Medium Black Vertisol',
      soilProvenanceLabel: json['soil_provenance_label'] ?? 'CropNet Model Estimate (Unsampled Farm Coordinate)',
      isSoilSynthetic: json['is_soil_synthetic'] ?? true,
      isSeasonExpired: json['is_season_expired'] ?? false,
      seasonStatus: json['season_status'] ?? 'ACTIVE',
      requiresSeasonUpdate: json['requires_season_update'] ?? false,
      seasonExpiryMessage: json['season_expiry_message'],
      growthStageCode: json['growth_stage_code'] ?? json['stage_code'],
      growthStageNameEn: json['growth_stage_name_en'] ?? '',
      growthStageNameMr: json['growth_stage_name_mr'] ?? '',
      supportedStages: rawStages
          .map((s) {
            if (s is Map) {
              final m = Map<String, dynamic>.from(s);
              final rawCode = m['stage_code']?.toString().trim();
              final safeCode = (rawCode != null && rawCode.isNotEmpty && rawCode != 'null') ? rawCode : 'stage_unknown';
              final rawName = m['stage_name_en'] ?? m['stage_name'] ?? m['name'];
              final name = (rawName != null && rawName.toString().trim().isNotEmpty && rawName.toString().trim() != 'null')
                  ? rawName.toString().trim()
                  : (safeCode != 'stage_unknown'
                      ? safeCode.replaceAll('stage_', '').replaceAll('_', ' ').toUpperCase()
                      : 'Growth Stage');
              return <String, dynamic>{
                'stage_code': safeCode,
                'stage_name': name,
                'stage_name_en': name,
                'das_range': m['das_range']?.toString() ?? '',
                'crit_tmax': (m['crit_tmax'] as num?)?.toDouble() ?? 36.0,
              };
            }
            return <String, dynamic>{};
          })
          .where((m) => m.isNotEmpty)
          .toList(),
      farmerConfirmedStage: json['farmer_confirmed_stage'],
      baseTempC: (json['base_temp_c'] as num?)?.toDouble() ?? 10.0,
      optimalTempMinC: (json['optimal_temp_min_c'] as num?)?.toDouble() ?? 24.0,
      optimalTempMaxC: (json['optimal_temp_max_c'] as num?)?.toDouble() ?? 30.0,
      criticalTmaxThresholdC: (json['critical_tmax_threshold_c'] as num?)?.toDouble() ?? 36.0,
      criticalTminThresholdC: (json['critical_tmin_threshold_c'] as num?)?.toDouble() ?? 22.0,
      tmaxForecastC: (json['tmax_forecast_c'] as num?)?.toDouble() ?? 34.0,
      tminForecastC: (json['tmin_forecast_c'] as num?)?.toDouble() ?? 23.0,
      hoursAboveCritical: (json['hours_above_critical'] as num?)?.toDouble() ?? 0.0,
      consecutiveHotDays: json['consecutive_hot_days'] ?? 0,
      daytimeExposureHours: (json['daytime_exposure_hours'] as num?)?.toDouble() ?? 0.0,
      warmNightRespirationHazard: json['warm_night_respiration_hazard'] ?? false,
      warmNightPenaltyScore: (json['warm_night_penalty_score'] as num?)?.toDouble() ?? 0.0,
      cumulativeHeatUnitsGdd: (json['cumulative_heat_units_gdd'] as num?)?.toDouble() ?? 15.0,
      evidenceCitation: json['evidence_citation'] ?? '',
      evidenceStatus: json['evidence_status'] ?? 'VERIFIED_PUBLISHED',
      dailyOutlook: rawOutlook.map((o) => CropDailyOutlook.fromJson(Map<String, dynamic>.from(o as Map))).toList(),
      daytimeHeatStressLevel: json['daytime_heat_stress_level'] ?? 'low',
      overallCropHeatRisk: json['overall_crop_heat_risk'] ?? 'low',
      physiologicalMechanism: json['physiological_mechanism'] ?? '',
      stageBiologicalVulnerability: json['stage_biological_vulnerability'] ?? '',
      recommendedInterventions:
          rawInterventions.map((i) => CropHeatIntervention.fromJson(Map<String, dynamic>.from(i as Map))).toList(),
      assessmentHistory: rawHistory.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      personalizedCropVulnerabilityScore: Map<String, dynamic>.from(json['personalized_crop_vulnerability_score'] ?? {}),
      topographicDownscaling: Map<String, dynamic>.from(json['topographic_downscaling'] ?? {}),
    );
  }
}

// ==================== INCOME DIVERSIFICATION MODELS ====================

class FarmerResourceProfile {
  final String farmId;
  final String farmerId;
  final double availableInvestmentInr;
  final double monthlyOperatingBudgetInr;
  final double? maxRiskCapitalInr;
  final bool willingToBorrow;
  final double? totalFarmAcres;
  final double? cultivatedAcres;
  final double availableLandAcres;
  final double unusedLandAcres;
  final bool fieldBundsAvailable;
  final bool hasAnimalShed;
  final bool hasStorageRoom;
  final bool hasShadedSpace;
  final String waterAvailability;
  final List<dynamic> waterMonthsAvailable;
  final double familyLaborHoursDay;
  final bool hiredLaborPossible;
  final String existingLivestock;
  final List<String> existingAssets;
  final List<String> cropByproducts;
  final bool byproductSurplusAvailable;
  final List<String> interests;
  final bool hasTransport;
  final bool hasFpoAccess;
  final double? distanceToApmcKm;
  final String riskTolerance;
  final String categoryPreference;
  final String? ageRange;
  final String workPreference;
  final String paybackHorizon;
  final String familyManagementRole;
  final String? currentCropCode;
  final String? currentCropStage;

  FarmerResourceProfile({
    required this.farmId,
    this.farmerId = '',
    this.availableInvestmentInr = 0.0,
    this.monthlyOperatingBudgetInr = 0.0,
    this.maxRiskCapitalInr,
    this.willingToBorrow = false,
    this.totalFarmAcres,
    this.cultivatedAcres,
    this.availableLandAcres = 0.0,
    this.unusedLandAcres = 0.0,
    this.fieldBundsAvailable = true,
    this.hasAnimalShed = false,
    this.hasStorageRoom = false,
    this.hasShadedSpace = false,
    this.waterAvailability = 'seasonal_canal',
    this.waterMonthsAvailable = const [],
    this.familyLaborHoursDay = 2.0,
    this.hiredLaborPossible = false,
    this.existingLivestock = 'none',
    this.existingAssets = const [],
    this.cropByproducts = const [],
    this.byproductSurplusAvailable = true,
    this.interests = const [],
    this.hasTransport = false,
    this.hasFpoAccess = false,
    this.distanceToApmcKm,
    this.riskTolerance = 'moderate',
    this.categoryPreference = 'all',
    this.ageRange = '36-45',
    this.workPreference = 'daily_physical',
    this.paybackHorizon = 'within_6_months',
    this.familyManagementRole = 'self',
    this.currentCropCode,
    this.currentCropStage,
  });

  bool get isZeroBudget => availableInvestmentInr <= 0.0 && monthlyOperatingBudgetInr <= 0.0;

  Map<String, dynamic> toJson() {
    return {
      'available_investment_inr': availableInvestmentInr,
      'monthly_operating_budget_inr': monthlyOperatingBudgetInr,
      if (maxRiskCapitalInr != null) 'max_risk_capital_inr': maxRiskCapitalInr,
      'willing_to_borrow': willingToBorrow,
      if (totalFarmAcres != null) 'total_farm_acres': totalFarmAcres,
      if (cultivatedAcres != null) 'cultivated_acres': cultivatedAcres,
      'available_land_acres': availableLandAcres,
      'unused_land_acres': unusedLandAcres,
      'field_bunds_available': fieldBundsAvailable,
      'has_animal_shed': hasAnimalShed,
      'has_storage_room': hasStorageRoom,
      'has_shaded_space': hasShadedSpace,
      'water_availability': waterAvailability,
      'water_months_available': waterMonthsAvailable,
      'family_labor_hours_day': familyLaborHoursDay,
      'hired_labor_possible': hiredLaborPossible,
      'existing_livestock': existingLivestock,
      'existing_assets': existingAssets,
      'crop_byproducts': cropByproducts,
      'byproduct_surplus_available': byproductSurplusAvailable,
      'interests': interests,
      'has_transport': hasTransport,
      'has_fpo_access': hasFpoAccess,
      if (distanceToApmcKm != null) 'distance_to_apmc_km': distanceToApmcKm,
      'risk_tolerance': riskTolerance,
      'category_preference': categoryPreference,
      if (ageRange != null) 'age_range': ageRange,
      'work_preference': workPreference,
      'payback_horizon': paybackHorizon,
      'family_management_role': familyManagementRole,
      if (currentCropCode != null) 'current_crop_code': currentCropCode,
      if (currentCropStage != null) 'current_crop_stage': currentCropStage,
    };
  }
}

class SavedIncomePlan {
  final String planId;
  final String farmId;
  final String opportunityId;
  final String opportunityTitle;
  final String category;
  final double plannedInvestmentInr;
  final double expectedAnnualIncomeInr;
  final double expectedAnnualSavingsInr;
  final double breakEvenMonths;
  final bool breakEvenReached;
  final String notes;
  final String createdAt;

  SavedIncomePlan({
    required this.planId,
    required this.farmId,
    required this.opportunityId,
    required this.opportunityTitle,
    required this.category,
    required this.plannedInvestmentInr,
    required this.expectedAnnualIncomeInr,
    required this.expectedAnnualSavingsInr,
    required this.breakEvenMonths,
    this.breakEvenReached = true,
    this.notes = '',
    required this.createdAt,
  });

  factory SavedIncomePlan.fromJson(Map<String, dynamic> json) {
    return SavedIncomePlan(
      planId: json['plan_id'] ?? '',
      farmId: json['farm_id'] ?? '',
      opportunityId: json['opportunity_id'] ?? '',
      opportunityTitle: json['opportunity_title'] ?? '',
      category: json['category'] ?? '',
      plannedInvestmentInr:
          (json['chosen_budget_inr'] as num?)?.toDouble() ?? (json['planned_investment_inr'] as num?)?.toDouble() ?? 0.0,
      expectedAnnualIncomeInr: (json['projected_annual_profit_inr'] as num?)?.toDouble() ??
          (json['expected_annual_income_inr'] as num?)?.toDouble() ??
          0.0,
      expectedAnnualSavingsInr: (json['projected_annual_savings_inr'] as num?)?.toDouble() ??
          (json['expected_annual_savings_inr'] as num?)?.toDouble() ??
          0.0,
      breakEvenMonths:
          (json['payback_months'] as num?)?.toDouble() ?? (json['break_even_months'] as num?)?.toDouble() ?? 0.0,
      breakEvenReached: json['break_even_reached'] as bool? ?? true,
      notes: json['notes'] ?? '',
      createdAt: json['created_at_utc'] ?? json['created_at'] ?? '',
    );
  }
}

class IncomeOpportunity {
  final String opportunityId;
  final String title;
  final String category;
  final bool isCostSaving;
  final String tagline;
  final List<String> targetCrops;
  final double minInvestmentInr;
  final double maxInvestmentInr;
  final double workingCapitalRequiredInr;
  final double requiredLandAcres;
  final String requiredSpaceType;
  final String waterRequirement;
  final double dailyLaborHours;
  final int paybackPeriodMonths;
  final double potentialAnnualProfitInr;
  final double potentialAnnualSavingsInr;
  final String riskLevel;
  final String summary;
  final String marketCommodity;
  final String marketBenchmarkPrice;
  final String marketSource;
  final bool marketVerified;
  final List<String> keyAssumptions;
  final List<String> keyRisks;
  final String sourceAttribution;
  final String minimumViableUnitDescription;
  final int productionCycleDays;
  final int revenueDelayMonths;

  IncomeOpportunity({
    required this.opportunityId,
    required this.title,
    required this.category,
    this.isCostSaving = false,
    this.tagline = '',
    this.targetCrops = const [],
    required this.minInvestmentInr,
    required this.maxInvestmentInr,
    this.workingCapitalRequiredInr = 0.0,
    this.requiredLandAcres = 0.25,
    this.requiredSpaceType = 'field',
    this.waterRequirement = 'low',
    this.dailyLaborHours = 2.0,
    required this.paybackPeriodMonths,
    required this.potentialAnnualProfitInr,
    this.potentialAnnualSavingsInr = 0.0,
    required this.riskLevel,
    required this.summary,
    this.marketCommodity = '',
    this.marketBenchmarkPrice = '',
    this.marketSource = '',
    this.marketVerified = true,
    required this.keyAssumptions,
    required this.keyRisks,
    required this.sourceAttribution,
    this.minimumViableUnitDescription = '',
    this.productionCycleDays = 90,
    this.revenueDelayMonths = 3,
  });

  factory IncomeOpportunity.fromJson(Map<String, dynamic> json) {
    return IncomeOpportunity(
      opportunityId: json['opportunity_id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      isCostSaving: json['is_cost_saving'] ?? false,
      tagline: json['tagline'] ?? '',
      targetCrops: List<String>.from(json['target_crops'] ?? const []),
      minInvestmentInr: (json['min_investment_inr'] as num?)?.toDouble() ?? 0.0,
      maxInvestmentInr: (json['max_investment_inr'] as num?)?.toDouble() ?? 0.0,
      workingCapitalRequiredInr: (json['working_capital_required_inr'] as num?)?.toDouble() ?? 0.0,
      requiredLandAcres: (json['required_land_acres'] as num?)?.toDouble() ?? 0.25,
      requiredSpaceType: json['required_space_type'] ?? 'field',
      waterRequirement: json['water_requirement'] ?? 'low',
      dailyLaborHours: (json['daily_labor_hours'] as num?)?.toDouble() ?? 2.0,
      paybackPeriodMonths: json['payback_period_months'] ?? 6,
      potentialAnnualProfitInr: (json['potential_annual_profit_inr'] as num?)?.toDouble() ?? 0.0,
      potentialAnnualSavingsInr: (json['potential_annual_savings_inr'] as num?)?.toDouble() ?? 0.0,
      riskLevel: json['risk_level'] ?? 'moderate',
      summary: json['summary'] ?? '',
      marketCommodity: json['market_commodity'] ?? '',
      marketBenchmarkPrice: json['market_benchmark_price'] ?? '',
      marketSource: json['market_source'] ?? '',
      marketVerified: json['market_verified'] ?? true,
      keyAssumptions: List<String>.from(json['key_assumptions'] ?? const []),
      keyRisks: List<String>.from(json['key_risks'] ?? const []),
      sourceAttribution: json['source_attribution'] ?? '',
      minimumViableUnitDescription: json['minimum_viable_unit_description'] ?? '',
      productionCycleDays: json['production_cycle_days'] ?? 90,
      revenueDelayMonths: json['revenue_delay_months'] ?? 3,
    );
  }
}

class ScoredOpportunityItem {
  final IncomeOpportunity opportunity;
  final int suitabilityScorePct;
  final bool isSuitable;
  final String suitabilityVerdict;
  final List<String> reasonsWhySuitable;
  final List<String> reasonsWhyUnsuitable;
  final String feasibilityStatus;
  final double capitalGapInr;
  final List<String> missingRequirements;
  final List<String> matchingResources;
  final double estimatedAnnualProfitInr;
  final double estimatedAnnualSavingsInr;
  final double paybackMonths;
  final String marketBenchmarkSummary;
  final String feasibilityCategory;
  final Map<String, dynamic>? tripartiteReturn;
  final Map<String, String>? farmerSummaryQa;

  ScoredOpportunityItem({
    required this.opportunity,
    required this.suitabilityScorePct,
    required this.isSuitable,
    required this.suitabilityVerdict,
    required this.reasonsWhySuitable,
    required this.reasonsWhyUnsuitable,
    this.feasibilityStatus = 'FEASIBLE_NOW',
    this.capitalGapInr = 0.0,
    this.missingRequirements = const [],
    this.matchingResources = const [],
    this.estimatedAnnualProfitInr = 0.0,
    this.estimatedAnnualSavingsInr = 0.0,
    this.paybackMonths = 1.0,
    this.marketBenchmarkSummary = '',
    this.feasibilityCategory = 'CAN_TRY_WITH_WHAT_YOU_HAVE',
    this.tripartiteReturn,
    this.farmerSummaryQa,
  });

  bool get isFeasible =>
      isSuitable &&
      (feasibilityStatus == 'FEASIBLE_NOW' ||
          feasibilityStatus == 'HIGHLY_FEASIBLE' ||
          feasibilityStatus == 'USES_EXISTING_RESOURCES');

  factory ScoredOpportunityItem.fromJson(Map<String, dynamic> json) {
    Map<String, String>? qaMap;
    if (json['farmer_summary_qa'] is Map) {
      qaMap = (json['farmer_summary_qa'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    return ScoredOpportunityItem(
      opportunity: IncomeOpportunity.fromJson(Map<String, dynamic>.from(json['opportunity'] ?? {})),
      suitabilityScorePct: json['suitability_score_pct'] ?? (json['suitability_score'] as num?)?.toInt() ?? 75,
      isSuitable: json['is_suitable'] ?? json['is_feasible'] ?? true,
      suitabilityVerdict: json['suitability_verdict'] ?? json['feasibility_status'] ?? 'Suitable',
      reasonsWhySuitable: List<String>.from(json['reasons_why_suitable'] ?? json['matching_resources'] ?? const []),
      reasonsWhyUnsuitable: List<String>.from(json['reasons_why_unsuitable'] ?? json['missing_requirements'] ?? const []),
      feasibilityStatus: json['feasibility_status'] ?? 'FEASIBLE_NOW',
      capitalGapInr: (json['capital_gap_inr'] as num?)?.toDouble() ?? 0.0,
      missingRequirements: List<String>.from(json['missing_requirements'] ?? const []),
      matchingResources: List<String>.from(json['matching_resources'] ?? const []),
      estimatedAnnualProfitInr: (json['estimated_annual_profit_inr'] as num?)?.toDouble() ?? 0.0,
      estimatedAnnualSavingsInr: (json['estimated_annual_savings_inr'] as num?)?.toDouble() ?? 0.0,
      paybackMonths: (json['payback_months'] as num?)?.toDouble() ?? 1.0,
      marketBenchmarkSummary: json['market_benchmark_summary'] ?? '',
      feasibilityCategory: json['feasibility_category'] ?? 'CAN_TRY_WITH_WHAT_YOU_HAVE',
      tripartiteReturn:
          json['tripartite_return'] is Map ? Map<String, dynamic>.from(json['tripartite_return'] as Map) : null,
      farmerSummaryQa: qaMap,
    );
  }
}

class FinancialScenarioDetail {
  final String name;
  final String priceAssumption;
  final String costAssumption;
  final double grossAnnualRevenueInr;
  final double annualMoneySavedInr;
  final double annualOpexInr;
  final double cashOperatingSurplusInr;
  final double imputedFamilyLaborCostInr;
  final double economicProfitInr;
  final double netAnnualProfitInr;
  final double breakEvenMonths;
  final bool breakEvenReached;
  final List<double> monthlyNetCashFlowInr;

  FinancialScenarioDetail({
    required this.name,
    required this.priceAssumption,
    required this.costAssumption,
    required this.grossAnnualRevenueInr,
    this.annualMoneySavedInr = 0.0,
    required this.annualOpexInr,
    this.cashOperatingSurplusInr = 0.0,
    this.imputedFamilyLaborCostInr = 0.0,
    this.economicProfitInr = 0.0,
    required this.netAnnualProfitInr,
    required this.breakEvenMonths,
    this.breakEvenReached = true,
    required this.monthlyNetCashFlowInr,
  });

  factory FinancialScenarioDetail.fromJson(Map<String, dynamic> json) {
    final rawFlows = json['monthly_net_cash_flow_inr'] as List? ?? [];
    return FinancialScenarioDetail(
      name: json['name'] ?? '',
      priceAssumption: json['price_assumption'] ?? '',
      costAssumption: json['cost_assumption'] ?? '',
      grossAnnualRevenueInr: (json['gross_annual_revenue_inr'] as num?)?.toDouble() ?? 0.0,
      annualMoneySavedInr: (json['annual_money_saved_inr'] as num?)?.toDouble() ?? 0.0,
      annualOpexInr: (json['annual_opex_inr'] as num?)?.toDouble() ?? 0.0,
      cashOperatingSurplusInr: (json['cash_operating_surplus_inr'] as num?)?.toDouble() ?? 0.0,
      imputedFamilyLaborCostInr: (json['imputed_family_labor_cost_inr'] as num?)?.toDouble() ?? 0.0,
      economicProfitInr: (json['economic_profit_inr'] as num?)?.toDouble() ?? 0.0,
      netAnnualProfitInr: (json['net_annual_profit_inr'] as num?)?.toDouble() ?? 0.0,
      breakEvenMonths: (json['break_even_months'] as num?)?.toDouble() ?? 0.0,
      breakEvenReached: json['break_even_reached'] as bool? ?? true,
      monthlyNetCashFlowInr: rawFlows.map((f) => (f as num).toDouble()).toList(),
    );
  }
}

class IncomeScenario {
  final String opportunityId;
  final String opportunityTitle;
  final String category;
  final bool isCostSaving;
  final double customBudgetInr;
  final double calculatedCapexInr;
  final double workingCapitalInr;
  final double totalInitialOutlayInr;
  final double calculatedOpexAnnualInr;
  final double calculatedGrossRevenueInr;
  final double calculatedAnnualSavingsInr;
  final double cashOperatingSurplusInr;
  final double imputedFamilyLaborCostInr;
  final double economicProfitInr;
  final double calculatedNetProfitAnnualInr;
  final double calculatedBreakEvenMonths;
  final bool breakEvenReached;
  final List<double> monthlyCashFlows;
  final List<String> assumptionsApplied;
  final List<String> risksToMonitor;
  final String sourceAttribution;
  final String disclaimer;
  final Map<String, FinancialScenarioDetail> scenarios;
  final Map<String, dynamic> localMandiBenchmark;
  final Map<String, dynamic> sensitivityAnalysis;

  IncomeScenario({
    required this.opportunityId,
    required this.opportunityTitle,
    this.category = '',
    this.isCostSaving = false,
    required this.customBudgetInr,
    required this.calculatedCapexInr,
    this.workingCapitalInr = 0.0,
    this.totalInitialOutlayInr = 0.0,
    required this.calculatedOpexAnnualInr,
    required this.calculatedGrossRevenueInr,
    this.calculatedAnnualSavingsInr = 0.0,
    this.cashOperatingSurplusInr = 0.0,
    this.imputedFamilyLaborCostInr = 0.0,
    this.economicProfitInr = 0.0,
    required this.calculatedNetProfitAnnualInr,
    required this.calculatedBreakEvenMonths,
    this.breakEvenReached = true,
    this.monthlyCashFlows = const [],
    required this.assumptionsApplied,
    required this.risksToMonitor,
    required this.sourceAttribution,
    required this.disclaimer,
    this.scenarios = const {},
    this.localMandiBenchmark = const {},
    this.sensitivityAnalysis = const {},
  });

  factory IncomeScenario.fromJson(Map<String, dynamic> json) {
    final rawScenarios = json['scenarios'] as Map<String, dynamic>? ?? {};
    final parsedScenarios = <String, FinancialScenarioDetail>{};
    rawScenarios.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        parsedScenarios[key] = FinancialScenarioDetail.fromJson(val);
      }
    });
    final rawFlows = json['monthly_cash_flows'] as List? ?? [];

    return IncomeScenario(
      opportunityId: json['opportunity_id'] ?? '',
      opportunityTitle: json['opportunity_title'] ?? '',
      category: json['category'] ?? '',
      isCostSaving: json['is_cost_saving'] as bool? ?? false,
      customBudgetInr: (json['custom_budget_inr'] as num?)?.toDouble() ?? 0.0,
      calculatedCapexInr: (json['calculated_capex_inr'] as num?)?.toDouble() ?? 0.0,
      workingCapitalInr: (json['working_capital_inr'] as num?)?.toDouble() ?? 0.0,
      totalInitialOutlayInr: (json['total_initial_outlay_inr'] as num?)?.toDouble() ?? 0.0,
      calculatedGrossRevenueInr: (json['calculated_gross_revenue_inr'] as num?)?.toDouble() ?? 0.0,
      calculatedAnnualSavingsInr: (json['calculated_annual_savings_inr'] as num?)?.toDouble() ?? 0.0,
      cashOperatingSurplusInr: (json['cash_operating_surplus_inr'] as num?)?.toDouble() ?? 0.0,
      imputedFamilyLaborCostInr: (json['imputed_family_labor_cost_inr'] as num?)?.toDouble() ?? 0.0,
      economicProfitInr: (json['economic_profit_inr'] as num?)?.toDouble() ?? 0.0,
      calculatedOpexAnnualInr: (json['calculated_opex_annual_inr'] as num?)?.toDouble() ?? 0.0,
      calculatedNetProfitAnnualInr: (json['calculated_net_profit_annual_inr'] as num?)?.toDouble() ?? 0.0,
      calculatedBreakEvenMonths: (json['calculated_break_even_months'] as num?)?.toDouble() ?? 0.0,
      breakEvenReached: json['break_even_reached'] as bool? ?? true,
      monthlyCashFlows: rawFlows.map((e) => (e as num).toDouble()).toList(),
      assumptionsApplied: List<String>.from(json['assumptions_applied'] ?? const []),
      risksToMonitor: List<String>.from(json['risks_to_monitor'] ?? const []),
      sourceAttribution: json['source_attribution'] ?? '',
      disclaimer: json['disclaimer'] ?? '',
      scenarios: parsedScenarios,
      localMandiBenchmark: Map<String, dynamic>.from(json['local_mandi_benchmark'] ?? {}),
      sensitivityAnalysis: Map<String, dynamic>.from(json['sensitivity_analysis'] ?? {}),
    );
  }
}

class OpportunityComparisonItem {
  final String opportunityId;
  final String title;
  final String category;
  final bool isCostSaving;
  final double initialInvestmentInr;
  final double netAnnualProfitInr;
  final double annualSavingsInr;
  final double paybackMonths;
  final bool breakEvenReached;
  final double landRequiredAcres;
  final String waterNeeds;
  final double dailyLaborHours;
  final String riskLevel;
  final String suitabilityVerdict;

  OpportunityComparisonItem({
    required this.opportunityId,
    required this.title,
    required this.category,
    this.isCostSaving = false,
    required this.initialInvestmentInr,
    required this.netAnnualProfitInr,
    this.annualSavingsInr = 0.0,
    required this.paybackMonths,
    this.breakEvenReached = true,
    required this.landRequiredAcres,
    required this.waterNeeds,
    required this.dailyLaborHours,
    required this.riskLevel,
    required this.suitabilityVerdict,
  });

  factory OpportunityComparisonItem.fromJson(Map<String, dynamic> json) {
    return OpportunityComparisonItem(
      opportunityId: json['opportunity_id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      isCostSaving: json['is_cost_saving'] ?? false,
      initialInvestmentInr: (json['initial_investment_inr'] as num?)?.toDouble() ?? 0.0,
      netAnnualProfitInr: (json['net_annual_profit_inr'] as num?)?.toDouble() ?? 0.0,
      annualSavingsInr: (json['annual_money_saved_inr'] as num?)?.toDouble() ??
          (json['annual_savings_inr'] as num?)?.toDouble() ??
          0.0,
      paybackMonths: (json['payback_months'] as num?)?.toDouble() ?? 0.0,
      breakEvenReached: json['break_even_reached'] as bool? ?? true,
      landRequiredAcres: (json['land_required_acres'] as num?)?.toDouble() ?? 0.0,
      waterNeeds: json['water_needs'] ?? '',
      dailyLaborHours: (json['daily_labor_hours'] as num?)?.toDouble() ?? 0.0,
      riskLevel: json['risk_level'] ?? '',
      suitabilityVerdict: json['suitability_verdict'] ?? '',
    );
  }
}
