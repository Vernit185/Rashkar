import 'package:flutter/foundation.dart';

/// CropNet AI — Backend API Endpoints & Configuration Constants
///
/// Verified against FastAPI backend at `services/api/app/main.py` and `app/api/v1/router.py`.
class ApiConstants {
  ApiConstants._();

  /// Default API base URL.
  /// Configurable at compile-time via `--dart-define=API_BASE_URL=...`
  /// or dynamically resolved from the hosting origin in web environments.
  static String get defaultBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    // In web environments, if opened via LAN IP (e.g. from mobile phone at http://192.168.1.X:8080),
    // target the host on port 8000.
    if (kIsWeb && Uri.base.host.isNotEmpty && Uri.base.host != 'localhost' && Uri.base.host != '127.0.0.1') {
      return '${Uri.base.scheme}://${Uri.base.host}:8000';
    }
    return 'http://localhost:8000';
  }

  /// API V1 prefix
  static const String apiV1Prefix = '/api/v1';

  /// Development User ID header used in non-production environments
  static const String devUserIdHeader = 'X-Dev-User-Id';
  static const String defaultDevUserId = '00000000-0000-0000-0000-000000000001';

  // --- Health Endpoints ---
  static const String health = '$apiV1Prefix/health';

  // --- Farm Endpoints ---
  static const String farms = '$apiV1Prefix/farms';
  static String farmById(String farmId) => '$apiV1Prefix/farms/$farmId';
  static String farmHealthSnapshot(String farmId, {bool forceRefresh = false, String? targetSeason}) {
    final queryParams = <String>[];
    if (forceRefresh) queryParams.add('force_refresh=true');
    if (targetSeason != null && targetSeason.isNotEmpty) {
      queryParams.add('target_season=${Uri.encodeQueryComponent(targetSeason)}');
    }
    final qs = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    return '$apiV1Prefix/farms/$farmId/health-snapshot$qs';
  }
  static String farmSoilAnalyse(String farmId) => '$apiV1Prefix/farms/$farmId/soil/analyse';
  static String farmSoil(String farmId) => '$apiV1Prefix/farms/$farmId/soil';
  static String farmSoilHistory(String farmId) => '$apiV1Prefix/farms/$farmId/soil/history';

  // --- Weather Endpoints (nested under farms) ---
  static String farmWeatherCurrent(String farmId) => '$apiV1Prefix/farms/$farmId/weather/current';
  static String farmWeatherForecast(String farmId) => '$apiV1Prefix/farms/$farmId/weather/forecast';
  static String farmWeatherHistory(String farmId) => '$apiV1Prefix/farms/$farmId/weather/history';
  static String farmClimateSummary(String farmId) => '$apiV1Prefix/farms/$farmId/weather/climate-summary';

  // --- Soil Global Endpoints ---
  static const String soilProviders = '$apiV1Prefix/soil/providers';
  static const String soilLayers = '$apiV1Prefix/soil/layers';
  static const String soilPilotCoverage = '$apiV1Prefix/soil/pilot-coverage';
  static String soilFarmProfile(String farmId) => '$apiV1Prefix/soil/farms/$farmId/profile';
  static const String soilExtractPolygon = '$apiV1Prefix/soil/extract-polygon';

  // --- Crop Knowledge Base Endpoints ---
  static const String crops = '$apiV1Prefix/crops';
  static String cropById(String cropId) => '$apiV1Prefix/crops/$cropId';
  static String cropRequirements(String cropId) => '$apiV1Prefix/crops/$cropId/requirements';
  static String cropSources(String cropId) => '$apiV1Prefix/crops/$cropId/sources';
  static const String cropsSeed = '$apiV1Prefix/crops/seed';

  // --- Agriculture Reference & Intelligence Endpoints ---
  static const String agricultureSeasons = '$apiV1Prefix/agriculture/seasons';
  static const String agricultureEvaluateFarm = '$apiV1Prefix/agriculture/evaluate-farm';
  static String agricultureDecision(String decisionId) => '$apiV1Prefix/agriculture/decision/$decisionId';
  static const String agricultureFollowUp = '$apiV1Prefix/agriculture/follow-up';
  static const String agricultureExplainDecision = '$apiV1Prefix/agriculture/explain-decision';
  static const String agricultureConversation = '$apiV1Prefix/agriculture/conversation';

  // --- Government Schemes Endpoints ---
  static const String schemes = '$apiV1Prefix/schemes';
  static const String schemesFilters = '$apiV1Prefix/schemes/filters';
  static const String schemesAdminStatus = '$apiV1Prefix/schemes/admin/status';
  static const String schemesSeed = '$apiV1Prefix/schemes/seed';
  static String schemeById(String schemeId) => '$apiV1Prefix/schemes/$schemeId';
  static String schemeStatus(String schemeId) => '$apiV1Prefix/schemes/$schemeId/status';

  // --- Shared Farmer / Plot / Crop Context (Integrated Rashkar Single Source of Truth) ---
  static String farmSharedContext(String farmId) => '$apiV1Prefix/farms/$farmId/shared-context';
  static String farmPlots(String farmId) => '$apiV1Prefix/farms/$farmId/plots';
  static String farmCropCycles(String farmId) => '$apiV1Prefix/farms/$farmId/crop-cycles';
  static String farmCropCycleStage(String farmId, String cycleId) =>
      '$apiV1Prefix/farms/$farmId/crop-cycles/$cycleId/stage';

  // --- Rashkar Risk Intelligence Endpoints ---
  static const String cropHeatSupportedCrops = '$apiV1Prefix/risk/crop-heat/supported-crops';
  static String farmWorkerHeat(String farmId) => '$apiV1Prefix/risk/farms/$farmId/worker-heat';
  static String farmCropHeat(String farmId) => '$apiV1Prefix/risk/farms/$farmId/crop-heat';
  static const String cropDoctorPredict = '$apiV1Prefix/crop-doctor/predict';
  static const String cropDoctorStatus = '$apiV1Prefix/crop-doctor/status';
  static const String heatRiskCrop = '$apiV1Prefix/risk/crop-heat';
  static const String heatRiskWorker = '$apiV1Prefix/risk/worker-heat';
  static const String heatRiskCrops = '$apiV1Prefix/risk/crop-heat/supported-crops';
  static String heatRiskFarm(String farmId) => '$apiV1Prefix/risk/farms/$farmId';

  // --- Rashkar Extra Income Endpoints ---
  static const String incomeOpportunities = '$apiV1Prefix/income/opportunities';
  static const String incomeCalculateScenario = '$apiV1Prefix/income/calculate-scenario';
  static const String incomeCompareOpportunities = '$apiV1Prefix/income/compare-opportunities';
  static String incomeFarmProfile(String farmId) => '$apiV1Prefix/income/farms/$farmId/profile';
  static String incomeFarmDiscover(String farmId) => '$apiV1Prefix/income/farms/$farmId/discover';
  static String incomeFarmPlans(String farmId) => '$apiV1Prefix/income/farms/$farmId/plans';
  static String incomeFarmPlanById(String farmId, String planId) => '$apiV1Prefix/income/farms/$farmId/plans/$planId';
}
