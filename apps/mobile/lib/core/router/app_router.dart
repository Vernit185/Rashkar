import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cropnet_mobile/core/router/advisory_screen.dart';
import 'package:cropnet_mobile/core/router/app_shell.dart';
import 'package:cropnet_mobile/core/router/farm_resolution.dart';
import 'package:cropnet_mobile/core/router/farm_state.dart';
import 'package:cropnet_mobile/core/router/history_screen.dart';
import 'package:cropnet_mobile/core/router/route_error_screen.dart';
import 'package:cropnet_mobile/core/router/route_names.dart';
import 'package:cropnet_mobile/core/router/route_paths.dart';
import 'package:cropnet_mobile/features/auth/auth_service.dart';
import 'package:cropnet_mobile/features/auth/auth_state.dart';
import 'package:cropnet_mobile/features/auth/presentation/login_screen.dart';
import 'package:cropnet_mobile/features/auth/presentation/register_screen.dart';
import 'package:cropnet_mobile/features/soil/presentation/screens/soil_report_history_screen.dart';
import 'package:cropnet_mobile/features/soil/presentation/screens/soil_report_review_screen.dart';
import 'package:cropnet_mobile/features/soil/presentation/screens/soil_report_upload_screen.dart';
import 'package:cropnet_mobile/features/water/presentation/screens/water_workspace_screen.dart';
import 'package:cropnet_mobile/features/satellite/presentation/screens/satellite_vegetation_screen.dart';
import 'package:cropnet_mobile/features/farm_health/presentation/screens/farm_health_dashboard_screen.dart';
import 'package:cropnet_mobile/features/schemes/presentation/screens/schemes_list_screen.dart';
import 'package:cropnet_mobile/features/schemes/presentation/screens/scheme_detail_screen.dart';
import 'package:cropnet_mobile/features/schemes/presentation/screens/scheme_admin_screen.dart';
import 'package:cropnet_mobile/features/schemes/presentation/screens/scheme_editor_screen.dart';
import 'package:cropnet_mobile/features/crop_doctor/presentation/screens/crop_doctor_screen.dart';
import 'package:cropnet_mobile/features/rashkar/presentation/screens/risk_hub_screen.dart';
import 'package:cropnet_mobile/features/rashkar/presentation/screens/extra_income_screen.dart';
import 'package:cropnet_mobile/main.dart';

// Navigator Keys for Root and Stateful Shell Branches
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final GlobalKey<NavigatorState> _shellNavigatorHome =
    GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final GlobalKey<NavigatorState> _shellNavigatorSoil =
    GlobalKey<NavigatorState>(debugLabel: 'shellSoil');
final GlobalKey<NavigatorState> _shellNavigatorCrops =
    GlobalKey<NavigatorState>(debugLabel: 'shellCrops');
final GlobalKey<NavigatorState> _shellNavigatorWeather =
    GlobalKey<NavigatorState>(debugLabel: 'shellWeather');
final GlobalKey<NavigatorState> _shellNavigatorAdvisory =
    GlobalKey<NavigatorState>(debugLabel: 'shellAdvisory');
final GlobalKey<NavigatorState> _shellNavigatorHistory =
    GlobalKey<NavigatorState>(debugLabel: 'shellHistory');
final GlobalKey<NavigatorState> _shellNavigatorSchemes =
    GlobalKey<NavigatorState>(debugLabel: 'shellSchemes');
final GlobalKey<NavigatorState> _shellNavigatorCropDoctor =
    GlobalKey<NavigatorState>(debugLabel: 'shellCropDoctor');
final GlobalKey<NavigatorState> _shellNavigatorRisk =
    GlobalKey<NavigatorState>(debugLabel: 'shellRisk');
final GlobalKey<NavigatorState> _shellNavigatorExtraIncome =
    GlobalKey<NavigatorState>(debugLabel: 'shellExtraIncome');

/// Creates and configures the CropNet AI GoRouter instance.
GoRouter createCropNetRouter({
  String initialLocation = RoutePaths.home,
  List<NavigatorObserver>? observers,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    observers: observers,
    debugLogDiagnostics: false,
    refreshListenable: AuthStateNotifier.instance,
    redirect: (context, state) {
      final auth = AuthService.instance;
      // In unconfigured development mode, don't force redirect to login
      if (!auth.isConfigured) return null;

      final authNotifier = AuthStateNotifier.instance;
      if (authNotifier.isLoading) return null;

      final isAuth = authNotifier.isAuthenticated;
      final location = state.matchedLocation;
      final isAuthRoute = location == RoutePaths.login || location == RoutePaths.register;

      if (!isAuth && !isAuthRoute) {
        return RoutePaths.login;
      }
      if (isAuth && isAuthRoute) {
        return RoutePaths.home;
      }
      return null;
    },
    errorBuilder: (context, state) => AppRouteErrorScreen(
      error: state.error,
      uri: state.uri.toString(),
    ),
    routes: [
      // Persistent Shell Route using IndexedStack to preserve branch state across tab switches
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home / Dashboard (My Farms)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHome,
            routes: [
              GoRoute(
                path: RoutePaths.home,
                name: RouteNames.home,
                builder: (context, state) {
                  return ListenableBuilder(
                    listenable: FarmRepository.instance,
                    builder: (context, _) => MyFarmsDashboard(
                      farms: FarmRepository.instance.farms,
                      onAddFarm: (f) => FarmRepository.instance.addFarm(f),
                      onUpdateFarm: (f) => FarmRepository.instance.updateFarm(f),
                      onDeleteFarm: (id) => FarmRepository.instance.deleteFarm(id),
                    ),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'farms/new',
                    name: RouteNames.farmNew,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      return AddEditFarmScreen(
                        onSave: (farm) {
                          FarmRepository.instance.addFarm(farm);
                          context.pop();
                        },
                      );
                    },
                  ),
                  GoRoute(
                    path: 'farms/:farmId',
                    name: RouteNames.farmDetail,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final farmId = state.pathParameters['farmId'] ?? '';
                      return FarmRouteResolver(
                        farmId: farmId,
                        featureName: 'Farm Details',
                        builder: (context, farm) => FarmDetailScreen(
                          farm: farm,
                          onUpdate: (updated) => FarmRepository.instance.updateFarm(updated),
                          onDelete: (id) {
                            FarmRepository.instance.deleteFarm(id);
                            context.pop();
                          },
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'water',
                        name: RouteNames.farmWater,
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final farmId = state.pathParameters['farmId'] ?? '';
                          return FarmRouteResolver(
                            farmId: farmId,
                            featureName: 'Water Intelligence',
                            builder: (context, farm) => WaterWorkspaceScreen(
                              farmId: farm.id,
                              farmName: farm.name,
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'vegetation',
                        name: RouteNames.farmVegetation,
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final farmId = state.pathParameters['farmId'] ?? '';
                          return FarmRouteResolver(
                            farmId: farmId,
                            featureName: 'Satellite Vegetation',
                            builder: (context, farm) => SatelliteVegetationScreen(
                              farmId: farm.id,
                              farmName: farm.name,
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'health',
                        name: RouteNames.farmHealthDashboard,
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final farmId = state.pathParameters['farmId'] ?? '';
                          return FarmRouteResolver(
                            farmId: farmId,
                            featureName: 'Farm Health Dashboard',
                            builder: (context, farm) => FarmHealthDashboardScreen(
                              farmId: farm.id,
                              farm: farm,
                              simulateOffline: state.uri.queryParameters['offline'] == 'true',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Branch 1: Soil Testing & Metrics (Soil Intelligence)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSoil,
            routes: [
              GoRoute(
                path: RoutePaths.soilTesting,
                name: RouteNames.soilTesting,
                builder: (context, state) {
                  return ListenableBuilder(
                    listenable: FarmRepository.instance,
                    builder: (context, _) => SoilIntelligenceScreen(
                      farms: FarmRepository.instance.farms,
                    ),
                  );
                },
                routes: [
                  GoRoute(
                    path: ':farmId',
                    name: RouteNames.soilDetail,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final farmId = state.pathParameters['farmId'] ?? '';
                      return FarmRouteResolver(
                        farmId: farmId,
                        featureName: 'Soil Intelligence',
                        builder: (context, farm) => SoilIntelligenceReportScreen(farm: farm),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'lab',
                        name: RouteNames.soilLabWorkspace,
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final farmId = state.pathParameters['farmId'] ?? '';
                          return SoilReportHistoryScreen(farmId: farmId);
                        },
                        routes: [
                          GoRoute(
                            path: 'upload',
                            name: RouteNames.soilLabUpload,
                            parentNavigatorKey: rootNavigatorKey,
                            builder: (context, state) {
                              final farmId = state.pathParameters['farmId'] ?? '';
                              return SoilReportUploadScreen(farmId: farmId);
                            },
                          ),
                          GoRoute(
                            path: 'reports/:reportId',
                            name: RouteNames.soilLabReportReview,
                            parentNavigatorKey: rootNavigatorKey,
                            builder: (context, state) {
                              final farmId = state.pathParameters['farmId'] ?? '';
                              final reportId = state.pathParameters['reportId'] ?? '';
                              return SoilReportReviewScreen(
                                farmId: farmId,
                                reportId: reportId,
                              );
                            },
                          ),
                          GoRoute(
                            path: 'history',
                            name: RouteNames.soilLabHistory,
                            parentNavigatorKey: rootNavigatorKey,
                            builder: (context, state) {
                              final farmId = state.pathParameters['farmId'] ?? '';
                              return SoilReportHistoryScreen(farmId: farmId);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Branch 2: Crop Recommendation & Feasibility (Agricultural Knowledge Base)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorCrops,
            routes: [
              GoRoute(
                path: RoutePaths.cropRecommendation,
                name: RouteNames.cropRecommendation,
                builder: (context, state) => const CropCatalogScreen(),
                routes: [
                  GoRoute(
                    path: ':cropId',
                    name: RouteNames.cropDetail,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final cropId = state.pathParameters['cropId'] ?? '';
                      try {
                        final crop = kCropKnowledgeBase.firstWhere((c) => c.id == cropId);
                        return CropDetailScreen(crop: crop, lang: WeatherLanguage.english);
                      } catch (_) {
                        return AppRouteErrorScreen(
                          uri: state.uri.toString(),
                          error: Exception('Crop with ID "$cropId" not found in knowledge base.'),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),

          // Branch 3: Agro-meteorology (Weather & Climate Intelligence)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorWeather,
            routes: [
              GoRoute(
                path: RoutePaths.weather,
                name: RouteNames.weather,
                builder: (context, state) {
                  return ListenableBuilder(
                    listenable: FarmRepository.instance,
                    builder: (context, _) => WeatherIntelligenceScreen(
                      farms: FarmRepository.instance.farms,
                    ),
                  );
                },
                routes: [
                  GoRoute(
                    path: ':farmId',
                    name: RouteNames.weatherDetail,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final farmId = state.pathParameters['farmId'] ?? '';
                      return FarmRouteResolver(
                        farmId: farmId,
                        featureName: 'Weather Intelligence',
                        builder: (context, farm) => WeatherClimateReportScreen(farm: farm),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // Branch 4: AI Dialogue & Advisory (Qwen3:8B Agronomic Dialogue)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorAdvisory,
            routes: [
              GoRoute(
                path: RoutePaths.advisory,
                name: RouteNames.advisory,
                builder: (context, state) => const AdvisoryScreen(),
              ),
            ],
          ),

          // Branch 5: Soil & Crop Assessment History
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHistory,
            routes: [
              GoRoute(
                path: RoutePaths.history,
                name: RouteNames.history,
                builder: (context, state) => const AssessmentHistoryScreen(),
              ),
            ],
          ),

          // Branch 6: Government Schemes
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSchemes,
            routes: [
              GoRoute(
                path: RoutePaths.schemes,
                name: RouteNames.schemes,
                builder: (context, state) => const SchemesListScreen(),
                routes: [
                  GoRoute(
                    path: 'admin',
                    name: RouteNames.schemesAdmin,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const SchemeAdminScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        name: RouteNames.schemesAdminNew,
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => const SchemeEditorScreen(),
                      ),
                      GoRoute(
                        path: ':schemeId/edit',
                        name: RouteNames.schemesAdminEdit,
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final schemeId = state.pathParameters['schemeId'] ?? '';
                          return SchemeEditorScreen(schemeId: schemeId);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: ':schemeId',
                    name: RouteNames.schemeDetail,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final schemeId = state.pathParameters['schemeId'] ?? '';
                      return SchemeDetailScreen(schemeId: schemeId);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Branch 7: Crop Doctor AI Pathology & Diagnostics
          StatefulShellBranch(
            navigatorKey: _shellNavigatorCropDoctor,
            routes: [
              GoRoute(
                path: RoutePaths.cropDoctor,
                name: RouteNames.cropDoctor,
                builder: (context, state) => const CropDoctorScreen(),
              ),
            ],
          ),

          // Branch 8: Heat Risk Hub (Worker Heat Risk & Crop Heat Risk)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorRisk,
            routes: [
              GoRoute(
                path: RoutePaths.risk,
                name: RouteNames.risk,
                builder: (context, state) {
                  final tabParam = state.uri.queryParameters['tab'];
                  final initialTab = tabParam == 'crop' ? 1 : 0;
                  return RiskHubScreen(
                    initialTab: initialTab,
                    initialFarmId: state.uri.queryParameters['farmId'],
                  );
                },
                routes: [
                  GoRoute(
                    path: 'worker-heat',
                    name: RouteNames.riskWorkerHeat,
                    builder: (context, state) => RiskHubScreen(
                      initialTab: 0,
                      initialFarmId: state.uri.queryParameters['farmId'],
                    ),
                  ),
                  GoRoute(
                    path: 'crop-heat',
                    name: RouteNames.riskCropHeat,
                    builder: (context, state) => RiskHubScreen(
                      initialTab: 1,
                      initialFarmId: state.uri.queryParameters['farmId'],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Branch 9: Extra Income & Diversification
          StatefulShellBranch(
            navigatorKey: _shellNavigatorExtraIncome,
            routes: [
              GoRoute(
                path: RoutePaths.extraIncome,
                name: RouteNames.extraIncome,
                builder: (context, state) => ExtraIncomeScreen(
                  initialFarmId: state.uri.queryParameters['farmId'],
                ),
              ),
            ],
          ),
        ],
      ),

      // Standalone top-level routes
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.register,
        name: RouteNames.register,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.about,
        name: RouteNames.about,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AboutCropNetScreen(),
      ),
    ],
  );
}

/// Global shared instance of the configured CropNet GoRouter
final GoRouter appRouter = createCropNetRouter();
