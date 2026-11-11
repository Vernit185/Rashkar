/// Route path constants for CropNet AI navigation and URL synchronization.
abstract final class RoutePaths {
  /// Startup Splash & First-time Farmer Onboarding
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';

  /// Home / Dashboard (My Farms)
  static const String home = '/';

  /// Soil Testing & Metrics (Location-Based Soil Intelligence)
  static const String soilTesting = '/soil-testing';

  /// Crop Recommendation & Feasibility (Agricultural Crop Knowledge)
  static const String cropRecommendation = '/crop-recommendation';

  /// Agro-meteorology & Climate Intelligence
  static const String weather = '/weather';

  /// AI Dialogue & Advisory (Qwen3:8B Agronomic Dialogue)
  static const String advisory = '/advisory';

  /// Soil & Crop Assessment History
  static const String history = '/history';

  // --- Sub-routes & Detail Paths ---

  /// Register new farm
  static const String farmNew = '/farms/new';

  /// Farm boundary and details: /farms/:farmId
  static const String farmDetail = '/farms/:farmId';

  /// Farm soil intelligence report: /soil-testing/:farmId
  static const String soilDetail = '/soil-testing/:farmId';

  /// Farm weather & climate report: /weather/:farmId
  static const String weatherDetail = '/weather/:farmId';

  /// Crop feasibility & cultivation guide: /crop-recommendation/:cropId
  static const String cropDetail = '/crop-recommendation/:cropId';

  /// About CropNet AI
  static const String about = '/about';

  /// Authentication
  static const String login = '/login';
  static const String register = '/register';

  /// Soil Laboratory Workspace: /soil-testing/:farmId/lab
  static const String soilLabWorkspace = '/soil-testing/:farmId/lab';

  /// Soil Laboratory Upload: /soil-testing/:farmId/lab/upload
  static const String soilLabUpload = '/soil-testing/:farmId/lab/upload';

  /// Soil Laboratory Report Review: /soil-testing/:farmId/lab/reports/:reportId
  static const String soilLabReportReview = '/soil-testing/:farmId/lab/reports/:reportId';

  /// Soil Laboratory Report History: /soil-testing/:farmId/lab/history
  static const String soilLabHistory = '/soil-testing/:farmId/lab/history';

  /// Irrigation Water Intelligence Workspace: /farms/:farmId/water
  static const String farmWater = '/farms/:farmId/water';

  /// Satellite Vegetation Health Workspace: /farms/:farmId/vegetation
  static const String farmVegetation = '/farms/:farmId/vegetation';

  /// Unified Farm Health Dashboard: /farms/:farmId/health
  static const String farmHealthDashboard = '/farms/:farmId/health';

  /// Government Schemes catalogue: /schemes
  static const String schemes = '/schemes';

  /// Crop Doctor AI Pathology & Diagnostics
  static const String cropDoctor = '/crop-doctor';

  /// Unified Heat Risk Hub (Worker Heat Risk & Crop Heat Risk)
  static const String risk = '/risk';
  static const String riskWorkerHeat = '/risk/worker-heat';
  static const String riskCropHeat = '/risk/crop-heat';

  /// Extra Income & Diversification
  static const String extraIncome = '/extra-income';

  /// Government Scheme detail: /schemes/:schemeId
  static const String schemeDetail = '/schemes/:schemeId';

  /// Government Schemes admin panel: /schemes/admin
  static const String schemesAdmin = '/schemes/admin';

  /// Government Schemes admin — create: /schemes/admin/new
  static const String schemesAdminNew = '/schemes/admin/new';

  /// Government Schemes admin — edit: /schemes/admin/:schemeId/edit
  static const String schemesAdminEdit = '/schemes/admin/:schemeId/edit';

  // --- Parameter Path Helper Methods ---

  static String farmDetailPath(String farmId) => '/farms/$farmId';
  static String farmHealthDashboardPath(String farmId) => '/farms/$farmId/health';
  static String farmWaterPath(String farmId) => '/farms/$farmId/water';
  static String farmVegetationPath(String farmId) => '/farms/$farmId/vegetation';
  static String soilDetailPath(String farmId) => '/soil-testing/$farmId';
  static String soilLabWorkspacePath(String farmId) => '/soil-testing/$farmId/lab';
  static String soilLabUploadPath(String farmId) => '/soil-testing/$farmId/lab/upload';
  static String soilLabReportReviewPath(String farmId, String reportId) =>
      '/soil-testing/$farmId/lab/reports/$reportId';
  static String soilLabHistoryPath(String farmId) => '/soil-testing/$farmId/lab/history';
  static String weatherDetailPath(String farmId) => '/weather/$farmId';
  static String cropDetailPath(String cropId) => '/crop-recommendation/$cropId';
  static String schemeDetailPath(String schemeId) => '/schemes/$schemeId';
  static String schemeAdminEditPath(String schemeId) => '/schemes/admin/$schemeId/edit';
}
