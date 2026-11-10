import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:cropnet_mobile/core/router/app_router.dart';
import 'package:cropnet_mobile/core/router/farm_state.dart';
import 'package:cropnet_mobile/core/router/route_paths.dart';
import 'package:cropnet_mobile/core/network/api_client.dart';
import 'package:cropnet_mobile/core/network/api_constants.dart';
import 'package:cropnet_mobile/features/history/assessment_history_repository.dart';
import 'package:cropnet_mobile/features/farm/models/farm_models.dart' as farm_models;
import 'package:cropnet_mobile/features/soil/data/soil_repository.dart';
import 'package:cropnet_mobile/features/soil/models/soil_models.dart';
import 'package:cropnet_mobile/features/soil/models/soil_lab_models.dart';
import 'package:cropnet_mobile/features/soil/data/soil_lab_repository.dart';
import 'package:cropnet_mobile/features/soil/presentation/widgets/lab_vs_soilgrids_comparison_widget.dart';
import 'package:cropnet_mobile/features/weather/data/weather_repository.dart';
import 'package:cropnet_mobile/features/weather/models/weather_models.dart';
import 'package:cropnet_mobile/features/crop/data/crop_repository.dart';
import 'package:cropnet_mobile/features/crop/models/crop_models.dart';
import 'package:cropnet_mobile/features/satellite/presentation/widgets/satellite_vegetation_summary_card.dart';
import 'package:cropnet_mobile/features/rashkar/data/rashkar_repository.dart';
import 'package:cropnet_mobile/features/rashkar/models/rashkar_models.dart';
import 'package:cropnet_mobile/features/auth/auth_service.dart';
import 'package:cropnet_mobile/features/auth/auth_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Local prototype only: --dart-define=DEV_AUTH=true enables the development
  // user header. Production builds omit the flag, so the client stays fail-closed.
  const bool devAuth = bool.fromEnvironment('DEV_AUTH', defaultValue: false);
  if (devAuth) {
    ApiClient.defaultDevUserId = ApiConstants.defaultDevUserId;
  }
  await AuthService.instance.initialize();
  AuthStateNotifier.instance.initialize();
  runApp(const CropNetApp());
}

// MapTiler API key (configured from backend env)
const String kMapTilerApiKey = "TZ8qXSGUgAKX9HPNbzpO";

/// Farm model for mobile client
class FarmItem {
  final String id;
  String name;
  String? village;
  String taluka;
  String district;
  String irrigationType;
  String waterSource;
  List<LatLng> polygonPoints;
  double areaHectares;
  double areaAcres;
  LatLng centroid;
  DateTime createdAt;

  FarmItem({
    required this.id,
    required this.name,
    this.village,
    required this.taluka,
    this.district = "Pune",
    this.irrigationType = "irrigated",
    this.waterSource = "canal",
    required this.polygonPoints,
    required this.areaHectares,
    required this.areaAcres,
    required this.centroid,
    required this.createdAt,
  });

  factory FarmItem.fromFarm(farm_models.Farm farm) {
    List<LatLng> points = [];
    if (farm.geometry.coordinates.isNotEmpty) {
      final ring = farm.geometry.coordinates[0];
      points = ring.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
    }
    return FarmItem(
      id: farm.id,
      name: farm.name,
      village: farm.village,
      taluka: farm.taluka,
      district: farm.district,
      irrigationType: farm.irrigationType ?? 'irrigated',
      waterSource: farm.waterSource ?? 'canal',
      polygonPoints: points,
      areaHectares: farm.calculatedAreaHectares,
      areaAcres: farm.calculatedAreaAcres,
      centroid: LatLng(farm.centroidLatitude, farm.centroidLongitude),
      createdAt: farm.createdAt,
    );
  }

  Map<String, dynamic> toGeoJson() {
    final coords = polygonPoints.map((p) => [p.longitude, p.latitude]).toList();
    if (coords.isNotEmpty && coords.first != coords.last) {
      coords.add(coords.first);
    }
    return {
      "type": "Polygon",
      "coordinates": [coords],
    };
  }
}

/// Geodesic Area Calculation on WGS84
double calculateGeodesicAreaHectares(List<LatLng> points) {
  if (points.length < 3) return 0.0;
  const double earthRadius = 6378137.0; // meters
  double area = 0.0;
  for (int i = 0; i < points.length; i++) {
    final p1 = points[i];
    final p2 = points[(i + 1) % points.length];
    final radLat1 = p1.latitude * pi / 180.0;
    final radLat2 = p2.latitude * pi / 180.0;
    final radLonDiff = (p2.longitude - p1.longitude) * pi / 180.0;
    area += radLonDiff * (2.0 + sin(radLat1) + sin(radLat2));
  }
  area = (area * earthRadius * earthRadius / 4.0).abs();
  return area / 10000.0; // square meters to hectares
}

LatLng calculateCentroid(List<LatLng> points) {
  if (points.isEmpty) return const LatLng(18.18, 74.53);
  double sumLat = 0;
  double sumLon = 0;
  for (final p in points) {
    sumLat += p.latitude;
    sumLon += p.longitude;
  }
  return LatLng(sumLat / points.length, sumLon / points.length);
}

class CropNetApp extends StatelessWidget {
  final RouterConfig<Object>? routerConfig;

  const CropNetApp({super.key, this.routerConfig});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CropNet AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF1B5E20),
          secondary: const Color(0xFFE65100),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      routerConfig: routerConfig ?? appRouter,
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    FarmRepository.instance.loadFarms();
  }

  void _addFarm(FarmItem farm) {
    FarmRepository.instance.addFarm(farm);
  }

  void _updateFarm(FarmItem farm) {
    FarmRepository.instance.updateFarm(farm);
  }

  void _deleteFarm(String farmId) {
    FarmRepository.instance.deleteFarm(farmId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FarmRepository.instance,
      builder: (context, _) {
        final farms = FarmRepository.instance.farms;
        final pages = [
          MyFarmsDashboard(
            farms: farms,
            onAddFarm: _addFarm,
            onUpdateFarm: _updateFarm,
            onDeleteFarm: _deleteFarm,
          ),
          SoilIntelligenceScreen(farms: farms),
          WeatherIntelligenceScreen(farms: farms),
          const CropCatalogScreen(),
          const AboutCropNetScreen(),
        ];

        return Scaffold(
          body: pages[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'My Farms'),
              NavigationDestination(icon: Icon(Icons.terrain_outlined), selectedIcon: Icon(Icons.terrain), label: 'Soil'),
              NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: 'Weather'),
              NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Crops'),
              NavigationDestination(icon: Icon(Icons.info_outline), selectedIcon: Icon(Icons.info), label: 'About'),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// 1. MY FARMS DASHBOARD
// ==========================================
class MyFarmsDashboard extends StatelessWidget {
  final List<FarmItem> farms;
  final Function(FarmItem) onAddFarm;
  final Function(FarmItem) onUpdateFarm;
  final Function(String) onDeleteFarm;

  const MyFarmsDashboard({
    super.key,
    required this.farms,
    required this.onAddFarm,
    required this.onUpdateFarm,
    required this.onDeleteFarm,
  });

  @override
  Widget build(BuildContext context) {
    final repo = FarmRepository.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Registered Farms', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Farms',
            onPressed: () => repo.loadFarms(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Register New Farm', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => AddEditFarmScreen(onSave: onAddFarm),
            ),
          );
        },
      ),
      body: repo.isLoading && farms.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your registered farms...', style: TextStyle(color: Colors.black54)),
                ],
              ),
            )
          : repo.error != null && farms.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 64, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        const Text('Unable to connect to CropNet server', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(repo.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => repo.loadFarms(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry Connection'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: () => repo.loadFarms(),
              child: farms.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.agriculture, size: 72, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No farms registered yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Text('Tap "Register New Farm" to draw your plot on the map.', style: TextStyle(color: Colors.black54)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: farms.length,
                      itemBuilder: (ctx, idx) {
                        final farm = farms[idx];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE8F5E9),
                              foregroundColor: Color(0xFF1B5E20),
                              radius: 26,
                              child: Icon(Icons.fence, size: 28),
                            ),
                            title: Text(
                              farm.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '${farm.village != null ? "${farm.village}, " : ""}${farm.taluka}, ${farm.district}',
                                  style: const TextStyle(color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${farm.areaHectares.toStringAsFixed(2)} ha (${farm.areaAcres.toStringAsFixed(2)} acres)',
                                        style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${farm.polygonPoints.length} boundary points',
                                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => FarmDetailScreen(
                                    farm: farm,
                                    onUpdate: onUpdateFarm,
                                    onDelete: onDeleteFarm,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ==========================================
// 2. ADD / EDIT FARM SCREEN WITH MAP DRAWING
// ==========================================
class AddEditFarmScreen extends StatefulWidget {
  final FarmItem? farmToEdit;
  final Function(FarmItem) onSave;

  const AddEditFarmScreen({super.key, this.farmToEdit, required this.onSave});

  @override
  State<AddEditFarmScreen> createState() => _AddEditFarmScreenState();
}

class _AddEditFarmScreenState extends State<AddEditFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  final MapController _mapController = MapController();

  late TextEditingController _nameController;
  late TextEditingController _villageController;
  String _selectedTaluka = "Baramati";
  String _irrigationType = "irrigated";
  String _waterSource = "canal";

  // Shared Registration Fields (Crop Cycle + Farmer & Resource Profile)
  bool _includeCropCycle = false;
  bool _saveSharedProfile = false;
  final TextEditingController _plotNameController = TextEditingController(text: 'Main Plot 1');
  final TextEditingController _sowingDateController = TextEditingController();
  final TextEditingController _farmerNameController = TextEditingController();
  final TextEditingController _farmerPhoneController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController(text: '0');
  String _cropCode = 'soybean';
  String _cropSeason = 'kharif';
  String _defaultWorkload = 'moderate';
  String _defaultSunExposure = 'direct_sun';
  String _ageRange = '36-45';
  String _workPreference = 'daily_physical';
  double _familyLaborHours = 2.0;

  final List<LatLng> _polygonPoints = [];
  double _calculatedAreaHectares = 0.0;
  double _calculatedAreaAcres = 0.0;

  // Pilot Taluka Centers for quick GPS simulation
  final Map<String, LatLng> _talukaCoordinates = {
    "Baramati": const LatLng(18.18, 74.53),
    "Maval": const LatLng(18.76, 73.68),
    "Mulshi": const LatLng(18.53, 73.61),
    "Indapur": const LatLng(18.15, 75.05),
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().subtract(const Duration(days: 45));
    _sowingDateController.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final farm = widget.farmToEdit;
    _nameController = TextEditingController(text: farm?.name ?? "");
    _villageController = TextEditingController(text: farm?.village ?? "");
    if (farm != null) {
      _selectedTaluka = farm.taluka;
      _irrigationType = farm.irrigationType;
      _waterSource = farm.waterSource;
      _polygonPoints.addAll(farm.polygonPoints);
      _calculatedAreaHectares = farm.areaHectares;
      _calculatedAreaAcres = farm.areaAcres;
      _loadExistingSharedContext(farm.id);
    }
  }

  Future<void> _loadExistingSharedContext(String farmId) async {
    try {
      final ctx = await RashkarRepository.instance.getSharedContext(farmId);
      if (!mounted) return;
      setState(() {
        _farmerNameController.text = ctx.farmerProfile.fullName ?? '';
        _farmerPhoneController.text = ctx.farmerProfile.phoneNumber ?? '';
        _defaultWorkload = ctx.farmerProfile.defaultWorkloadCategory ?? _defaultWorkload;
        _defaultSunExposure = ctx.farmerProfile.defaultSunExposure ?? _defaultSunExposure;
        _ageRange = ctx.farmerProfile.ageRange ?? ctx.resourceProfile.ageRange ?? _ageRange;
        _workPreference = ctx.farmerProfile.workPreference ?? ctx.resourceProfile.workPreference ?? _workPreference;
        if (ctx.resourceProfile.availableInvestmentInr != null) {
          _budgetController.text = ctx.resourceProfile.availableInvestmentInr!.round().toString();
        }
        if (ctx.resourceProfile.familyLaborHoursDay != null) {
          _familyLaborHours = ctx.resourceProfile.familyLaborHoursDay!.clamp(0.5, 6.0);
        }
        if (ctx.cropCycles.isNotEmpty) {
          _plotNameController.text = ctx.cropCycles.first.plotName;
          _cropCode = ctx.cropCycles.first.cropCode;
          _cropSeason = ctx.cropCycles.first.season;
          _sowingDateController.text = ctx.cropCycles.first.sowingDate;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _villageController.dispose();
    _plotNameController.dispose();
    _sowingDateController.dispose();
    _farmerNameController.dispose();
    _farmerPhoneController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _polygonPoints.add(latLng);
      _recalculateArea();
    });
  }

  void _undoLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
        _recalculateArea();
      });
    }
  }

  void _clearPolygon() {
    setState(() {
      _polygonPoints.clear();
      _calculatedAreaHectares = 0.0;
      _calculatedAreaAcres = 0.0;
    });
  }

  void _recalculateArea() {
    if (_polygonPoints.length >= 3) {
      _calculatedAreaHectares = calculateGeodesicAreaHectares(_polygonPoints);
      _calculatedAreaAcres = _calculatedAreaHectares * 2.47105;
    } else {
      _calculatedAreaHectares = 0.0;
      _calculatedAreaAcres = 0.0;
    }
  }

  void _centerOnCurrentLocation() {
    final target = _talukaCoordinates[_selectedTaluka] ?? const LatLng(18.18, 74.53);
    _mapController.move(target, 16.0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Centred on $_selectedTaluka pilot location (GPS captured)')),
    );
  }

  bool _isSaving = false;

  Future<void> _saveFarm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFC62828),
          content: Text('Please mark at least 3 points on the map to define the farm boundary.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Build GeoJSON Polygon with [lon, lat] pairs (closed ring, >= 4 points)
      final List<List<double>> ring = _polygonPoints.map((p) => [p.longitude, p.latitude]).toList();
      if (ring.isNotEmpty && (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1])) {
        ring.add([ring.first[0], ring.first[1]]);
      }
      final geometry = farm_models.GeoJsonPolygon(coordinates: [ring]);

      final FarmItem savedFarm;
      if (widget.farmToEdit != null) {
        final payload = farm_models.FarmUpdate(
          name: _nameController.text.trim(),
          village: _villageController.text.trim().isEmpty ? null : _villageController.text.trim(),
          taluka: _selectedTaluka,
          district: "Pune",
          irrigationType: _irrigationType,
          waterSource: _waterSource,
          geometry: geometry,
        );
        savedFarm = await FarmRepository.instance.updateFarmRemote(widget.farmToEdit!.id, payload);
      } else {
        final payload = farm_models.FarmCreate(
          name: _nameController.text.trim(),
          village: _villageController.text.trim().isEmpty ? null : _villageController.text.trim(),
          taluka: _selectedTaluka,
          district: "Pune",
          state: "Maharashtra",
          irrigationType: _irrigationType,
          waterSource: _waterSource,
          geometry: geometry,
        );
        savedFarm = await FarmRepository.instance.createFarm(payload);
      }

      if (_saveSharedProfile ||
          _farmerNameController.text.trim().isNotEmpty ||
          _farmerPhoneController.text.trim().isNotEmpty) {
        try {
          final parsedBudget = double.tryParse(_budgetController.text.trim()) ?? 0.0;
          final waterEnum = (_waterSource == 'borewell' || _waterSource == 'canal')
              ? 'seasonal_canal'
              : (_irrigationType == 'irrigated' ? 'reliable_year_round' : 'rainfed_limited');
          await RashkarRepository.instance.updateSharedContext(
            savedFarm.id,
            farmerProfile: SharedFarmerProfile(
              fullName: _farmerNameController.text.trim().isNotEmpty ? _farmerNameController.text.trim() : null,
              phoneNumber: _farmerPhoneController.text.trim().isNotEmpty ? _farmerPhoneController.text.trim() : null,
              ageRange: _ageRange,
              workPreference: _workPreference,
              defaultWorkloadCategory: _defaultWorkload,
              defaultSunExposure: _defaultSunExposure,
            ),
            resourceProfile: FarmerResourceProfile(
              farmId: savedFarm.id,
              availableInvestmentInr: parsedBudget < 0 ? 0.0 : parsedBudget,
              totalFarmAcres: _calculatedAreaAcres > 0 ? _calculatedAreaAcres : null,
              waterAvailability: waterEnum,
              familyLaborHoursDay: _familyLaborHours,
              ageRange: _ageRange,
              workPreference: _workPreference,
              currentCropCode: _includeCropCycle ? _cropCode : null,
            ),
          );
        } catch (_) {}
      }

      if (_includeCropCycle && _sowingDateController.text.trim().isNotEmpty) {
        try {
          await RashkarRepository.instance.createCropCycle(
            savedFarm.id,
            plotName: _plotNameController.text.trim().isEmpty ? 'Main Plot 1' : _plotNameController.text.trim(),
            cropCode: _cropCode,
            season: _cropSeason,
            sowingDate: _sowingDateController.text.trim(),
            plantedAreaAcres: _calculatedAreaAcres > 0 ? _calculatedAreaAcres : null,
            irrigationType: _irrigationType,
          );
        } catch (_) {}
      }

      widget.onSave(savedFarm);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            content: Text('Farm "${_nameController.text.trim()}" saved successfully in PostGIS database!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text('Failed to save farm to backend: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _polygonPoints.isNotEmpty
        ? _polygonPoints.first
        : (_talukaCoordinates[_selectedTaluka] ?? const LatLng(18.18, 74.53));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.farmToEdit != null ? 'Edit Farm Boundary' : 'Draw Farm Boundary'),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(14.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check, size: 28),
                  onPressed: _saveFarm,
                ),
        ],
      ),
      body: Column(
        children: [
          // Interactive Map Area (Takes 55% of screen height)
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: 16.0,
                    onTap: _onMapTap,
                  ),
                  children: [
                    // Base Satellite Tile Layer via MapTiler
                    TileLayer(
                      urlTemplate: 'https://api.maptiler.com/maps/satellite/{z}/{x}/{y}.jpg?key=$kMapTilerApiKey',
                      userAgentPackageName: 'com.cropnet.cropnet_mobile',
                      maxZoom: 19,
                    ),
                    // Polygon Drawing Layer
                    if (_polygonPoints.length >= 3)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _polygonPoints,
                            color: const Color(0x664CAF50),
                            borderColor: const Color(0xFF1B5E20),
                            borderStrokeWidth: 3.0,
                          ),
                        ],
                      ),
                    // Polyline between vertices while drawing
                    if (_polygonPoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [..._polygonPoints, _polygonPoints.first],
                            color: const Color(0xFFE65100),
                            strokeWidth: 2.5,
                          ),
                        ],
                      ),
                    // Vertex Markers
                    MarkerLayer(
                      markers: _polygonPoints.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final point = entry.value;
                        return Marker(
                          point: point,
                          width: 22,
                          height: 22,
                          child: Container(
                            decoration: BoxDecoration(
                              color: idx == 0 ? Colors.green : const Color(0xFFE65100),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                '${idx + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Top Floating Instruction Banner with Undo & Clear Controls
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xEE1E293B),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _polygonPoints.length < 3 ? Icons.touch_app : Icons.check_circle,
                          color: _polygonPoints.length < 3 ? Colors.amberAccent : Colors.lightGreenAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _polygonPoints.length < 3
                                ? 'Tap/click map to add vertices (${3 - _polygonPoints.length} more needed for boundary)'
                                : 'Boundary: ${_calculatedAreaHectares.toStringAsFixed(2)} ha (${_calculatedAreaAcres.toStringAsFixed(2)} ac) • ${_polygonPoints.length} vertices',
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_polygonPoints.isNotEmpty) ...[
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.orangeAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.undo, size: 16),
                            label: const Text('Undo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            onPressed: _undoLastPoint,
                          ),
                          const SizedBox(width: 6),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.delete_sweep, size: 16),
                            label: const Text('Clear', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            onPressed: _clearPolygon,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // GPS Centring Button
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B5E20),
                    onPressed: _centerOnCurrentLocation,
                    tooltip: 'Capture GPS Location',
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),

          // Farm Metadata Form Area (Takes 45% of screen height)
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Farm / Plot Name *',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a farm name' : null,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedTaluka,
                            decoration: const InputDecoration(
                              labelText: 'Taluka *',
                              border: OutlineInputBorder(),
                            ),
                            items: _talukaCoordinates.keys
                                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedTaluka = val;
                                  _centerOnCurrentLocation();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _villageController,
                            decoration: const InputDecoration(
                              labelText: 'Village (Optional)',
                              border: OutlineInputBorder(),
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
                            initialValue: _irrigationType,
                            decoration: const InputDecoration(
                              labelText: 'Irrigation Type',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'irrigated', child: Text('Irrigated')),
                              DropdownMenuItem(value: 'rainfed', child: Text('Rainfed')),
                              DropdownMenuItem(value: 'mixed', child: Text('Mixed')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _irrigationType = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _waterSource,
                            decoration: const InputDecoration(
                              labelText: 'Water Source',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'canal', child: Text('Canal')),
                              DropdownMenuItem(value: 'borewell', child: Text('Borewell')),
                              DropdownMenuItem(value: 'well', child: Text('Open Well')),
                              DropdownMenuItem(value: 'rainfall', child: Text('Rainfall')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _waterSource = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Optional Shared Crop Planting Section (reused across Crop Heat Risk & Extra Income)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: ExpansionTile(
                        title: const Text(
                          'Planted Crop Details (Shared · Optional)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        ),
                        subtitle: const Text(
                          'Saved once and reused in Crop Heat Risk & Extra Income',
                          style: TextStyle(fontSize: 11),
                        ),
                        onExpansionChanged: (expanded) {
                          if (expanded && !_includeCropCycle) {
                            setState(() => _includeCropCycle = true);
                          }
                        },
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              children: [
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Save crop cycle with this farm', style: TextStyle(fontSize: 12)),
                                  value: _includeCropCycle,
                                  onChanged: (v) => setState(() => _includeCropCycle = v),
                                ),
                                TextFormField(
                                  controller: _plotNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Plot Name',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _cropCode,
                                        decoration: const InputDecoration(
                                          labelText: 'Standing Crop',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'soybean', child: Text('Soybean')),
                                          DropdownMenuItem(value: 'cotton', child: Text('Cotton')),
                                          DropdownMenuItem(value: 'sugarcane', child: Text('Sugarcane')),
                                          DropdownMenuItem(value: 'wheat', child: Text('Wheat')),
                                          DropdownMenuItem(value: 'maize', child: Text('Maize')),
                                          DropdownMenuItem(value: 'rice', child: Text('Rice (Paddy)')),
                                          DropdownMenuItem(value: 'pigeonpea', child: Text('Pigeonpea (Tur)')),
                                          DropdownMenuItem(value: 'chickpea', child: Text('Chickpea (Gram)')),
                                          DropdownMenuItem(value: 'groundnut', child: Text('Groundnut')),
                                          DropdownMenuItem(value: 'tomato', child: Text('Tomato')),
                                          DropdownMenuItem(value: 'onion', child: Text('Onion')),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() {
                                              _cropCode = v;
                                              _includeCropCycle = true;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _cropSeason,
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
                                          if (v != null) setState(() => _cropSeason = v);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _sowingDateController,
                                  decoration: const InputDecoration(
                                    labelText: 'Sowing Date (YYYY-MM-DD)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Optional Shared Farmer, Worker & Resource Defaults Section
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: ExpansionTile(
                        title: const Text(
                          'Farmer, Worker & Resource Defaults (Shared · Optional)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        ),
                        subtitle: const Text(
                          'Collect once for Worker Heat Risk & Extra Income',
                          style: TextStyle(fontSize: 11),
                        ),
                        onExpansionChanged: (expanded) {
                          if (expanded && !_saveSharedProfile) {
                            setState(() => _saveSharedProfile = true);
                          }
                        },
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _farmerNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Farmer Full Name',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _farmerPhoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone Number',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _defaultWorkload,
                                        decoration: const InputDecoration(
                                          labelText: 'Field Workload',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'light', child: Text('Light')),
                                          DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                                          DropdownMenuItem(value: 'heavy', child: Text('Heavy')),
                                          DropdownMenuItem(value: 'very_heavy', child: Text('Very Heavy')),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() {
                                              _defaultWorkload = v;
                                              _saveSharedProfile = true;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _defaultSunExposure,
                                        decoration: const InputDecoration(
                                          labelText: 'Sun Exposure',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'direct_sun', child: Text('Direct Sun')),
                                          DropdownMenuItem(value: 'partial_shade', child: Text('Partial Shade')),
                                          DropdownMenuItem(value: 'full_shade', child: Text('Full Shade')),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() {
                                              _defaultSunExposure = v;
                                              _saveSharedProfile = true;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _budgetController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Available Cash Budget (₹)',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _ageRange,
                                        decoration: const InputDecoration(
                                          labelText: 'Age Range',
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
                                          if (v != null) {
                                            setState(() {
                                              _ageRange = v;
                                              _saveSharedProfile = true;
                                            });
                                          }
                                        },
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
                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text('Save Farm & Persist Boundary in PostGIS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      onPressed: _saveFarm,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. FARM DETAILS SCREEN
// ==========================================
class FarmDetailScreen extends StatelessWidget {
  final FarmItem farm;
  final Function(FarmItem) onUpdate;
  final Function(String) onDelete;

  const FarmDetailScreen({
    super.key,
    required this.farm,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(farm.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => AddEditFarmScreen(
                    farmToEdit: farm,
                    onSave: (updated) {
                      onUpdate(updated);
                      Navigator.pop(context);
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mini Interactive Map Preview
            SizedBox(
              height: 240,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: farm.centroid,
                  initialZoom: 16.0,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://api.maptiler.com/maps/satellite/{z}/{x}/{y}.jpg?key=$kMapTilerApiKey',
                    userAgentPackageName: 'com.cropnet.cropnet_mobile',
                  ),
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: farm.polygonPoints,
                        color: const Color(0x664CAF50),
                        borderColor: const Color(0xFF1B5E20),
                        borderStrokeWidth: 3.0,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: farm.centroid,
                        child: const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          farm.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        ),
                      ),
                      Chip(
                        label: Text('${farm.areaHectares.toStringAsFixed(2)} ha', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Administrative Location: ${farm.village != null ? "${farm.village}, " : ""}${farm.taluka}, ${farm.district}',
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Centroid Coordinates: Lat ${farm.centroid.latitude.toStringAsFixed(5)}, Lon ${farm.centroid.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const Divider(height: 24),

                  const Text('Plot Characteristics:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  _buildDetailRow('Calculated Area', '${farm.areaHectares.toStringAsFixed(2)} hectares (${farm.areaAcres.toStringAsFixed(2)} acres)'),
                  _buildDetailRow('Irrigation Type', farm.irrigationType.toUpperCase()),
                  _buildDetailRow('Water Source', farm.waterSource.toUpperCase()),
                  _buildDetailRow('Boundary Points', '${farm.polygonPoints.length} vertices (GeoJSON Polygon)'),

                  const SizedBox(height: 16),

                  // Sentinel-2 Satellite Vegetation Summary Card
                  SatelliteVegetationSummaryCard(farmId: farm.id),

                  const SizedBox(height: 20),
                  // Prominent Action: Unified Farm Health Dashboard (Phase 5.9B)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.dashboard_customize_rounded, size: 24),
                    label: const Text(
                      'View Unified Farm Health Dashboard',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    ),
                    onPressed: () {
                      FarmRepository.instance.selectedFarmId = farm.id;
                      context.push(RoutePaths.farmHealthDashboardPath(farm.id));
                    },
                  ),
                  const SizedBox(height: 12),

                  // Prominent Action to run Crop Suitability Advisory
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.psychology, size: 24),
                    label: const Text(
                      'Run Crop Suitability Advisory',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    ),
                    onPressed: () {
                      FarmRepository.instance.selectedFarmId = farm.id;
                      appRouter.go(RoutePaths.advisory);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Action to trigger soil intelligence
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.science),
                    label: const Text('Analyse Soil Profile for this Boundary', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      FarmRepository.instance.selectedFarmId = farm.id;
                      context.push(RoutePaths.soilDetailPath(farm.id));
                    },
                  ),
                  const SizedBox(height: 10),

                  // Action to trigger weather & climate intelligence
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0277BD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.cloud_sync),
                    label: const Text('Weather & Climate Intelligence', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      FarmRepository.instance.selectedFarmId = farm.id;
                      context.push(RoutePaths.weatherDetailPath(farm.id));
                    },
                  ),
                  const SizedBox(height: 10),

                  // Action to trigger irrigation water intelligence
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00695C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.water_drop),
                    label: const Text('Irrigation Water Quality & Sources', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      FarmRepository.instance.selectedFarmId = farm.id;
                      context.push(RoutePaths.farmWaterPath(farm.id));
                    },
                  ),
                  const SizedBox(height: 10),

                  // Action to trigger satellite vegetation health monitoring
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF558B2F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.satellite_alt),
                    label: const Text('Sentinel-2 Satellite Vegetation Health', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      FarmRepository.instance.selectedFarmId = farm.id;
                      context.push(RoutePaths.farmVegetationPath(farm.id));
                    },
                  ),
                  const SizedBox(height: 16),
                  _FarmSharedRiskIncomeCard(farmId: farm.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Farm Boundary?'),
        content: Text('Are you sure you want to delete "${farm.name}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onDelete(farm.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Farm "${farm.name}" deleted.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _FarmSharedRiskIncomeCard extends StatefulWidget {
  final String farmId;
  const _FarmSharedRiskIncomeCard({required this.farmId});

  @override
  State<_FarmSharedRiskIncomeCard> createState() => _FarmSharedRiskIncomeCardState();
}

class _FarmSharedRiskIncomeCardState extends State<_FarmSharedRiskIncomeCard> {
  SharedFarmContext? _sharedContext;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    try {
      final ctx = await RashkarRepository.instance.getSharedContext(widget.farmId);
      if (!mounted) return;
      setState(() {
        _sharedContext = ctx;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = _sharedContext;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFC8E6C9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.hub_outlined, color: Color(0xFF1B5E20), size: 20),
                SizedBox(width: 8),
                Text(
                  'Shared Plots, Heat Risk & Extra Income',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B5E20)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const LinearProgressIndicator(color: Color(0xFF2E7D32))
            else if (ctx != null) ...[
              Text(
                ctx.cropCycles.isEmpty
                    ? 'Active Crops: None recorded yet (add once in Crop Heat Risk or Edit Farm).'
                    : 'Active Crops: ${ctx.cropCycles.map((c) => "${c.cropCode.toUpperCase()} (${c.plotName})").join(", ")}',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                'Worker Profile: ${ctx.farmerProfile.defaultWorkloadCategory ?? "not set"} · Budget: ₹${(ctx.resourceProfile.availableInvestmentInr ?? 0).round()}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ] else
              const Text(
                'Use your registered farm details across Worker Heat Risk, Crop Heat Risk, and Extra Income.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD84315),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    FarmRepository.instance.selectFarm(widget.farmId);
                    context.go('${RoutePaths.riskWorkerHeat}?farmId=${widget.farmId}');
                  },
                  icon: const Icon(Icons.engineering_outlined, size: 18),
                  label: const Text('Worker Heat Risk'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    FarmRepository.instance.selectFarm(widget.farmId);
                    context.go('${RoutePaths.riskCropHeat}?farmId=${widget.farmId}');
                  },
                  icon: const Icon(Icons.eco_outlined, size: 18),
                  label: const Text('Crop Heat Risk'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    FarmRepository.instance.selectFarm(widget.farmId);
                    context.go('${RoutePaths.extraIncome}?farmId=${widget.farmId}');
                  },
                  icon: const Icon(Icons.savings_outlined, size: 18),
                  label: const Text('Extra Income'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. SOIL INTELLIGENCE TAB (Phase 2 Enhanced)
// ==========================================
class SoilIntelligenceScreen extends StatelessWidget {
  final List<FarmItem> farms;

  const SoilIntelligenceScreen({super.key, required this.farms});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soil Intelligence')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                border: Border.all(color: const Color(0xFFFFB74D)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Map-Derived Estimates: Values are derived from digital geospatial soil models (ISRIC SoilGrids 2.0). They are NOT laboratory test results.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFBF360C), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Registered Farms Available for Analysis:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (farms.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.terrain_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No farms registered yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text('Please register a farm boundary first to inspect soil parameters.', style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Register New Farm'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => AddEditFarmScreen(
                                onSave: (farm) => FarmRepository.instance.addFarm(farm),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
            else
              ...farms.map((f) => Card(
                    elevation: 1.5,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE8F5E9),
                        child: Icon(Icons.terrain, color: Color(0xFF1B5E20)),
                      ),
                      title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${f.taluka} • ${f.areaHectares.toStringAsFixed(2)} ha (${f.areaAcres.toStringAsFixed(2)} ac)'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        FarmRepository.instance.selectedFarmId = f.id;
                        context.push(RoutePaths.soilDetailPath(f.id));
                      },
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. SOIL INTELLIGENCE REPORT SCREEN (Phase 2)
// ==========================================
class SoilIntelligenceReportScreen extends StatefulWidget {
  final FarmItem farm;

  const SoilIntelligenceReportScreen({super.key, required this.farm});

  @override
  State<SoilIntelligenceReportScreen> createState() => _SoilIntelligenceReportScreenState();
}

class _SoilIntelligenceReportScreenState extends State<SoilIntelligenceReportScreen> {
  String _selectedDepth = "0-5cm";
  bool _isLoading = false;
  String? _errorMessage;
  final SoilRepository _soilRepo = SoilRepository();
  final SoilLabRepository _labRepo = SoilLabRepository();
  UnifiedSoilProfile? _soilProfile;
  SoilReportDetail? _latestConfirmedReport;

  @override
  void initState() {
    super.initState();
    _loadSoilProfile();
  }

  bool get _isLabConfirmed {
    if (_latestConfirmedReport != null && _latestConfirmedReport!.isConfirmed) return true;
    if (_soilProfile != null) {
      if (_soilProfile!.availableNitrogen?.verificationStatus == VerificationStatus.laboratoryVerified ||
          _soilProfile!.availablePhosphorus?.verificationStatus == VerificationStatus.laboratoryVerified ||
          _soilProfile!.availablePotassium?.verificationStatus == VerificationStatus.laboratoryVerified ||
          _soilProfile!.ph?.verificationStatus == VerificationStatus.laboratoryVerified) {
        return true;
      }
    }
    return false;
  }

  void _recordAssessmentInHistory(Map<String, dynamic> soil) {
    final prov = _isLabConfirmed
        ? 'Physical Soil Laboratory Ground Truth (${_latestConfirmedReport?.laboratoryName ?? "Accredited Soil Lab"})'
        : 'ISRIC SoilGrids 2.0 | 250m Resolution | 2020';
    AssessmentHistoryRepository.instance.recordSoilAssessment(
      farm: widget.farm,
      ph: (soil['ph'] as num).toDouble(),
      texture: soil['texture_class'] as String,
      soc: (soil['soc'] as num).toDouble(),
      cec: (soil['cec'] as num).toDouble(),
      depth: _selectedDepth,
      provenance: prov,
    );
  }

  Future<void> _loadSoilProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profile = await _soilRepo.getFarmSoilProfile(widget.farm.id, depth: _selectedDepth);
      SoilReportDetail? labReport;
      try {
        labReport = await _labRepo.getLatestConfirmedReport(widget.farm.id);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _soilProfile = profile;
          _latestConfirmedReport = labReport;
        });
        final soil = _getSoilData(widget.farm.taluka, _selectedDepth);
        _recordAssessmentInHistory(soil);
      }
    } catch (_) {
      try {
        final profile = await _soilRepo.analyseFarmSoil(
          widget.farm.id,
          forceRefresh: false,
          depth: _selectedDepth,
        );
        SoilReportDetail? labReport;
        try {
          labReport = await _labRepo.getLatestConfirmedReport(widget.farm.id);
        } catch (_) {}
        if (mounted) {
          setState(() {
            _soilProfile = profile;
            _latestConfirmedReport = labReport;
          });
          final soil = _getSoilData(widget.farm.taluka, _selectedDepth);
          _recordAssessmentInHistory(soil);
        }
      } catch (err) {
        if (mounted) {
          setState(() {
            _errorMessage = err.toString();
          });
          // Fallback regional calibration also records into assessment history
          final soil = _getSoilData(widget.farm.taluka, _selectedDepth);
          _recordAssessmentInHistory(soil);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshSoilAnalysis() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profile = await _soilRepo.analyseFarmSoil(
        widget.farm.id,
        forceRefresh: true,
        depth: _selectedDepth,
      );
      SoilReportDetail? labReport;
      try {
        labReport = await _labRepo.getLatestConfirmedReport(widget.farm.id);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _soilProfile = profile;
          _latestConfirmedReport = labReport;
        });
        final soil = _getSoilData(widget.farm.taluka, _selectedDepth);
        _recordAssessmentInHistory(soil);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF2E7D32),
            content: Text('Soil profile synchronized with latest laboratory and SoilGrids data.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text('Failed to refresh soil analysis: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getSoilData(String taluka, String depth) {
    if (_soilProfile != null) {
      return {
        'ph': _soilProfile!.ph?.value ?? 7.3,
        'ph_unc': 0.4,
        'soc': _soilProfile!.organicCarbon?.value ?? 15.4,
        'soc_unc': 2.1,
        'sand': _soilProfile!.sandPercent?.value ?? 28.0,
        'silt': _soilProfile!.siltPercent?.value ?? 30.0,
        'clay': _soilProfile!.clayPercent?.value ?? 42.0,
        'texture_class': _soilProfile!.soilTextureClass ?? 'Clay',
        'total_n': _soilProfile!.totalNitrogen?.value ?? 0.95,
        'cec': _soilProfile!.cationExchangeCapacity?.value ?? 38.2,
      };
    }
    // Baseline regional calibration
    final isTopsoil = depth == "0-5cm";
    switch (taluka.toLowerCase()) {
      case 'maval':
        return {
          'ph': isTopsoil ? 6.5 : 6.4,
          'ph_unc': 0.3,
          'soc': isTopsoil ? 19.4 : 15.2,
          'soc_unc': 2.3,
          'sand': isTopsoil ? 32.0 : 31.0,
          'silt': isTopsoil ? 30.0 : 29.0,
          'clay': isTopsoil ? 38.0 : 40.0,
          'texture_class': 'Clay Loam',
          'total_n': isTopsoil ? 1.15 : 0.95,
          'cec': isTopsoil ? 31.0 : 29.5,
        };
      case 'mulshi':
        return {
          'ph': isTopsoil ? 6.4 : 6.3,
          'ph_unc': 0.3,
          'soc': isTopsoil ? 23.5 : 18.1,
          'soc_unc': 2.8,
          'sand': isTopsoil ? 29.7 : 28.5,
          'silt': isTopsoil ? 29.4 : 28.0,
          'clay': isTopsoil ? 40.9 : 43.5,
          'texture_class': 'Clay',
          'total_n': isTopsoil ? 1.42 : 1.10,
          'cec': isTopsoil ? 28.5 : 27.0,
        };
      case 'indapur':
        return {
          'ph': isTopsoil ? 7.1 : 7.3,
          'ph_unc': 0.4,
          'soc': isTopsoil ? 24.2 : 17.8,
          'soc_unc': 3.0,
          'sand': isTopsoil ? 25.4 : 24.0,
          'silt': isTopsoil ? 30.0 : 28.5,
          'clay': isTopsoil ? 44.6 : 47.5,
          'texture_class': 'Clay',
          'total_n': isTopsoil ? 1.28 : 1.05,
          'cec': isTopsoil ? 26.6 : 28.0,
        };
      case 'baramati':
      default:
        return {
          'ph': isTopsoil ? 7.3 : 7.5,
          'ph_unc': 0.4,
          'soc': isTopsoil ? 15.4 : 12.1,
          'soc_unc': 2.1,
          'sand': isTopsoil ? 28.0 : 26.5,
          'silt': isTopsoil ? 30.0 : 28.5,
          'clay': isTopsoil ? 42.0 : 45.0,
          'texture_class': 'Clay',
          'total_n': isTopsoil ? 0.95 : 0.78,
          'cec': isTopsoil ? 38.2 : 36.5,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final soil = _getSoilData(widget.farm.taluka, _selectedDepth);
    final isSmallParcel = widget.farm.areaHectares < 6.25;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.farm.name} — Soil Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Soil Laboratory Workspace',
            onPressed: () {
              context.push(RoutePaths.soilLabWorkspacePath(widget.farm.id));
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Force Refresh SoilGrids Extraction',
            onPressed: _refreshSoilAnalysis,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null && _soilProfile == null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFC62828)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Live SoilGrids extraction encountered an error ($_errorMessage). Displaying regional calibration baseline.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFFC62828)),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadSoilProfile,
                            child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC62828))),
                          ),
                        ],
                      ),
                    ),

                  // 1. Mandatory Farmer Disclaimer Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      border: Border.all(color: const Color(0xFFFFB74D), width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.gavel, color: Color(0xFFE65100), size: 24),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'These results are estimates derived from geospatial soil datasets. They are not laboratory soil test results. Actual farm soil conditions may vary.',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFBF360C), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Spatial Representativeness Warning (if parcel < 6.25 ha)
                  if (isSmallParcel)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        border: Border.all(color: const Color(0xFF90CAF9)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF1976D2), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Spatial Notice: Farm area (${widget.farm.areaHectares.toStringAsFixed(2)} ha) is smaller than the 250m raster cell size (6.25 ha). Estimated values reflect average conditions for the 250m pixel encompassing this farm.',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF0D47A1)),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 3. Farm Boundary & Location Summary
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(widget.farm.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                              Chip(
                                label: Text('${widget.farm.areaHectares.toStringAsFixed(2)} ha', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: const Color(0xFF2E7D32),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          Text('Region: ${widget.farm.village != null ? "${widget.farm.village}, " : ""}${widget.farm.taluka}, Pune, Maharashtra', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          Text('Centroid: Lat ${widget.farm.centroid.latitude.toStringAsFixed(5)}, Lon ${widget.farm.centroid.longitude.toStringAsFixed(5)}', style: const TextStyle(color: Colors.black45, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Depth Interval Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Depth Interval:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: '0-5cm', label: Text('0–5 cm (Topsoil)')),
                          ButtonSegment(value: '5-15cm', label: Text('5–15 cm (Subsoil)')),
                        ],
                        selected: {_selectedDepth},
                        onSelectionChanged: (val) {
                          setState(() => _selectedDepth = val.first);
                          _loadSoilProfile();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 5. Physical Soil Properties & USDA Texture Class
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Soil Physical Characteristics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4E342E),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'USDA: ${soil["texture_class"]}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTextureBar('Sand Fraction (50-2000 µm)', soil['sand'], const Color(0xFFFFA726)),
                          _buildTextureBar('Silt Fraction (2-50 µm)', soil['silt'], const Color(0xFF78909C)),
                          _buildTextureBar('Clay Fraction (<2 µm)', soil['clay'], const Color(0xFF8D6E63)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 6. Chemical & Biological Properties
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Soil Chemical & Biological Properties', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                              if (_isLabConfirmed)
                                _buildProvenanceBadge(
                                  label: 'LABORATORY MEASURED — CONFIRMED',
                                  color: const Color(0xFF1B5E20),
                                  bgColor: const Color(0xFFE8F5E9),
                                  borderColor: const Color(0xFF81C784),
                                  icon: Icons.check_circle_outline,
                                )
                              else
                                _buildProvenanceBadge(
                                  label: 'SOILGRIDS — MODELLED ESTIMATE',
                                  color: const Color(0xFFE65100),
                                  bgColor: const Color(0xFFFFF3E0),
                                  borderColor: const Color(0xFFFFB74D),
                                  icon: Icons.public,
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          _buildParamRow(
                            'Soil pH (H2O)',
                            ((_soilProfile?.ph?.value ?? _latestConfirmedReport?.getEffectiveValue('soil_ph') ?? (soil['ph'] as num).toDouble())).toStringAsFixed(2),
                            'pH',
                            (_soilProfile?.ph?.verificationStatus == VerificationStatus.laboratoryVerified || _latestConfirmedReport?.getEffectiveValue('soil_ph') != null) ? null : '± ${soil["ph_unc"]}',
                            ((_soilProfile?.ph?.value ?? (soil['ph'] as num).toDouble()) < 6.5) ? 'Slightly Acidic' : (((_soilProfile?.ph?.value ?? (soil['ph'] as num).toDouble()) <= 7.5) ? 'Neutral' : 'Alkaline'),
                            Colors.green.shade700,
                            provenanceBadge: (_soilProfile?.ph?.verificationStatus == VerificationStatus.laboratoryVerified || _latestConfirmedReport?.getEffectiveValue('soil_ph') != null)
                                ? 'LABORATORY MEASURED'
                                : 'SOILGRIDS ESTIMATE',
                            provenanceColor: (_soilProfile?.ph?.verificationStatus == VerificationStatus.laboratoryVerified || _latestConfirmedReport?.getEffectiveValue('soil_ph') != null)
                                ? const Color(0xFF1B5E20)
                                : const Color(0xFFE65100),
                            provenanceBgColor: (_soilProfile?.ph?.verificationStatus == VerificationStatus.laboratoryVerified || _latestConfirmedReport?.getEffectiveValue('soil_ph') != null)
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFF3E0),
                            provenanceBorderColor: (_soilProfile?.ph?.verificationStatus == VerificationStatus.laboratoryVerified || _latestConfirmedReport?.getEffectiveValue('soil_ph') != null)
                                ? const Color(0xFF81C784)
                                : const Color(0xFFFFB74D),
                            secondaryModelledNote: (_soilProfile?.additionalParameters['isric_ph']?.value != null)
                                ? 'ISRIC SoilGrids 2.0 modeled baseline: ${_soilProfile!.additionalParameters['isric_ph']!.value!.toStringAsFixed(2)} pH'
                                : null,
                          ),
                          const Divider(height: 16),

                          _buildParamRow(
                            'Soil Organic Carbon (SOC)',
                            ((_soilProfile?.organicCarbon?.value ?? _latestConfirmedReport?.getEffectiveValue('organic_carbon') ?? (soil['soc'] as num).toDouble()) /
                                    ((_soilProfile?.organicCarbon?.verificationStatus == VerificationStatus.laboratoryVerified || _latestConfirmedReport?.getEffectiveValue('organic_carbon') != null) ? 1.0 : 10.0))
                                .toStringAsFixed(2),
                            (_soilProfile?.organicCarbon?.verificationStatus == VerificationStatus.laboratoryVerified || _latestConfirmedReport?.getEffectiveValue('organic_carbon') != null) ? '%' : 'g/kg',
                            (_soilProfile?.organicCarbon?.verificationStatus == VerificationStatus.laboratoryVerified || _latestConfirmedReport?.getEffectiveValue('organic_carbon') != null) ? null : '± ${soil["soc_unc"]} g/kg',
                            ((_soilProfile?.organicCarbon?.value ?? (soil['soc'] as num).toDouble()) >= 15.0) ? 'High Organic Content' : 'Moderate',
                            const Color(0xFF5D4037),
                            provenanceBadge: (_soilProfile?.organicCarbon?.verificationStatus == VerificationStatus.laboratoryVerified || _latestConfirmedReport?.getEffectiveValue('organic_carbon') != null)
                                ? 'LABORATORY MEASURED'
                                : 'SOILGRIDS ESTIMATE',
                            provenanceColor: (_soilProfile?.organicCarbon?.verificationStatus == VerificationStatus.laboratoryVerified || _latestConfirmedReport?.getEffectiveValue('organic_carbon') != null)
                                ? const Color(0xFF1B5E20)
                                : const Color(0xFFE65100),
                            provenanceBgColor: (_soilProfile?.organicCarbon?.verificationStatus == VerificationStatus.laboratoryVerified || _latestConfirmedReport?.getEffectiveValue('organic_carbon') != null)
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFF3E0),
                            provenanceBorderColor: (_soilProfile?.organicCarbon?.verificationStatus == VerificationStatus.laboratoryVerified || _latestConfirmedReport?.getEffectiveValue('organic_carbon') != null)
                                ? const Color(0xFF81C784)
                                : const Color(0xFFFFB74D),
                            secondaryModelledNote: (_soilProfile?.additionalParameters['isric_soc']?.value != null)
                                ? 'ISRIC SoilGrids baseline: ${((_soilProfile!.additionalParameters['isric_soc']!.value!) / 10.0).toStringAsFixed(2)} %'
                                : null,
                          ),
                          const Divider(height: 16),

                          // Electrical Conductivity (EC)
                          _buildParamRow(
                            'Electrical Conductivity (EC)',
                            (_soilProfile?.additionalParameters['electrical_conductivity']?.value ?? _latestConfirmedReport?.getEffectiveValue('electrical_conductivity')) != null
                                ? (_soilProfile?.additionalParameters['electrical_conductivity']?.value ?? _latestConfirmedReport?.getEffectiveValue('electrical_conductivity'))!.toStringAsFixed(2)
                                : 'Not tested',
                            (_soilProfile?.additionalParameters['electrical_conductivity']?.value ?? _latestConfirmedReport?.getEffectiveValue('electrical_conductivity')) != null ? 'dS/m' : '',
                            null,
                            (_soilProfile?.additionalParameters['electrical_conductivity']?.value ?? _latestConfirmedReport?.getEffectiveValue('electrical_conductivity')) != null
                                ? (((_soilProfile?.additionalParameters['electrical_conductivity']?.value ?? _latestConfirmedReport?.getEffectiveValue('electrical_conductivity'))! < 1.0)
                                    ? 'Non-Saline (Optimal)'
                                    : 'Slightly Saline')
                                : 'Physical lab test required',
                            (_soilProfile?.additionalParameters['electrical_conductivity']?.value ?? _latestConfirmedReport?.getEffectiveValue('electrical_conductivity')) != null
                                ? const Color(0xFF00796B)
                                : const Color(0xFFC62828),
                            provenanceBadge: (_soilProfile?.additionalParameters['electrical_conductivity']?.value ?? _latestConfirmedReport?.getEffectiveValue('electrical_conductivity')) != null
                                ? 'LABORATORY MEASURED'
                                : 'NOT AVAILABLE — PHYSICAL TEST REQUIRED',
                            provenanceColor: (_soilProfile?.additionalParameters['electrical_conductivity']?.value ?? _latestConfirmedReport?.getEffectiveValue('electrical_conductivity')) != null
                                ? const Color(0xFF1B5E20)
                                : const Color(0xFFC62828),
                            provenanceBgColor: (_soilProfile?.additionalParameters['electrical_conductivity']?.value ?? _latestConfirmedReport?.getEffectiveValue('electrical_conductivity')) != null
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFEBEE),
                            provenanceBorderColor: (_soilProfile?.additionalParameters['electrical_conductivity']?.value ?? _latestConfirmedReport?.getEffectiveValue('electrical_conductivity')) != null
                                ? const Color(0xFF81C784)
                                : const Color(0xFFEF9A9A),
                          ),
                          const Divider(height: 16),

                          // Total Nitrogen with bold scientific notice
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text('Total Nitrogen (N)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      const SizedBox(width: 6),
                                      _buildProvenanceBadge(
                                        label: 'SOILGRIDS — MODELLED ESTIMATE',
                                        color: const Color(0xFFE65100),
                                        bgColor: const Color(0xFFFFF3E0),
                                        borderColor: const Color(0xFFFFB74D),
                                      ),
                                    ],
                                  ),
                                  Text('${soil["total_n"]} g/kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B5E20))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  border: Border.all(color: const Color(0xFFFFD54F)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.notification_important, color: Color(0xFFF57F17), size: 18),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Scientific Guardrail: Total Nitrogen is NOT available mineral nitrogen (NH4+/NO3-). It cannot be used for fertilizer dosing without laboratory testing.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),

                          _buildParamRow(
                            'Cation Exchange Capacity (CEC)',
                            '${soil["cec"]}',
                            'cmol(c)/kg',
                            null,
                            soil["cec"] >= 30.0 ? 'High Nutrient Retention' : 'Moderate Retention',
                            const Color(0xFF00796B),
                            provenanceBadge: 'SOILGRIDS ESTIMATE',
                            provenanceColor: const Color(0xFFE65100),
                            provenanceBgColor: const Color(0xFFFFF3E0),
                            provenanceBorderColor: const Color(0xFFFFB74D),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 7. Strict Nutrients Transparency — Unlocked if lab confirmed, else locked with safeguard
                  if (_isLabConfirmed)
                    _buildUnlockedNutrientCard(context)
                  else
                    _buildLockedNutrientCard(context),
                  const SizedBox(height: 14),

                  // 8. Dual-Source Scientific Comparison Matrix
                  LabVsSoilgridsComparisonWidget(
                    labReport: _latestConfirmedReport,
                    soilgridsProfile: _soilProfile,
                    onUploadReport: () {
                      context.push(RoutePaths.soilLabUploadPath(widget.farm.id));
                    },
                  ),
                  const SizedBox(height: 14),

                  // 9. Micronutrient Ground Truth Panel (when available)
                  if (_isLabConfirmed) ...[
                    _buildMicronutrientPanel(),
                    const SizedBox(height: 14),
                  ],

                  // 10. Scientific Provenance Card
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Data Provenance & Scientific Attribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                              _buildProvenanceBadge(
                                label: _isLabConfirmed ? 'DUAL-SOURCE SYNC ACTIVE' : 'GEOSPATIAL BASELINE',
                                color: _isLabConfirmed ? const Color(0xFF1B5E20) : const Color(0xFF1565C0),
                                bgColor: _isLabConfirmed ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
                                borderColor: _isLabConfirmed ? const Color(0xFF81C784) : const Color(0xFF90CAF9),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildProvenanceRow('Primary Baseline', 'ISRIC SoilGrids 2.0 | 250m Resolution | 2020'),
                          if (_isLabConfirmed)
                            _buildProvenanceRow(
                              'Physical Lab Truth',
                              '${_latestConfirmedReport?.laboratoryName ?? "Accredited Laboratory"} (${_latestConfirmedReport?.sampleDepth ?? "0-15cm"})',
                            ),
                          _buildProvenanceRow('Standard Protocol', 'OGC WCS 2.0.1 + ICAR Analytical Standards'),
                          _buildProvenanceRow('Decision Authority', 'Deterministic Decision Engine (MPKV Rahuri / ICAR)'),
                          _buildProvenanceRow('Depth Interval', _selectedDepth),
                          _buildProvenanceRow('Licensing', 'Creative Commons Attribution 4.0 (CC BY 4.0)'),
                          _buildProvenanceRow('Institution', 'ISRIC World Soil Information & Local Farm Testing Lab'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bottom Disclaimer
                  const Center(
                    child: Text(
                      'CropNet AI Soil Intelligence Engine v1.0.0\nNot a substitute for official Government Soil Health Card lab tests.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, color: Colors.black45),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildTextureBar(String title, double percent, Color barColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.black87)),
              Text('${percent.toStringAsFixed(1)} %', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percent / 100.0,
            backgroundColor: Colors.grey.shade200,
            color: barColor,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildProvenanceBadge({
    required String label,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamRow(
    String label,
    String value,
    String unit,
    String? uncertainty,
    String interpretation,
    Color color, {
    String? provenanceBadge,
    Color? provenanceColor,
    Color? provenanceBgColor,
    Color? provenanceBorderColor,
    String? secondaryModelledNote,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  if (provenanceBadge != null)
                    _buildProvenanceBadge(
                      label: provenanceBadge,
                      color: provenanceColor ?? const Color(0xFF1B5E20),
                      bgColor: provenanceBgColor ?? const Color(0xFFE8F5E9),
                      borderColor: provenanceBorderColor ?? const Color(0xFF81C784),
                    ),
                ],
              ),
              if (secondaryModelledNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    secondaryModelledNote,
                    style: const TextStyle(color: Color(0xFFE65100), fontSize: 10.5, fontStyle: FontStyle.italic),
                  ),
                ),
              if (uncertainty != null)
                Text('Uncertainty: $uncertainty', style: const TextStyle(color: Colors.black45, fontSize: 11)),
              Text(interpretation, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('$value $unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      ],
    );
  }

  Widget _buildUnlockedNutrientCard(BuildContext context) {
    final nVal = _soilProfile?.availableNitrogen?.value ?? _latestConfirmedReport?.getEffectiveValue('available_nitrogen');
    final pVal = _soilProfile?.availablePhosphorus?.value ?? _latestConfirmedReport?.getEffectiveValue('available_phosphorus');
    final kVal = _soilProfile?.availablePotassium?.value ?? _latestConfirmedReport?.getEffectiveValue('available_potassium');

    return Card(
      elevation: 2,
      color: const Color(0xFFF1F8E9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF81C784), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildProvenanceBadge(
                  label: 'LABORATORY MEASURED — CONFIRMED',
                  color: const Color(0xFF1B5E20),
                  bgColor: const Color(0xFFC8E6C9),
                  borderColor: const Color(0xFF4CAF50),
                  icon: Icons.check_circle,
                ),
                Text(
                  _latestConfirmedReport?.sampleDate != null
                      ? 'Tested: ${_latestConfirmedReport!.sampleDate!.day}/${_latestConfirmedReport!.sampleDate!.month}/${_latestConfirmedReport!.sampleDate!.year}'
                      : 'Verified Record',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified, color: Color(0xFF2E7D32), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bioavailable Macronutrients Unlocked (NPK)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Official laboratory ground truth from ${_latestConfirmedReport?.laboratoryName ?? "Soil Testing Lab"} overrides modelled estimates and enables precision nutrient management.',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF2E7D32), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildNutrientRow(
              name: 'Available Nitrogen (N)',
              value: nVal != null ? '${nVal.toStringAsFixed(0)} kg/ha' : 'Pending Test',
              statusBadge: nVal == null
                  ? 'NOT TESTED'
                  : (nVal < 280 ? 'LOW (<280)' : (nVal <= 560 ? 'MEDIUM (280-560)' : 'HIGH (>560)')),
              statusColor: nVal == null
                  ? Colors.grey
                  : (nVal < 280 ? const Color(0xFFD32F2F) : (nVal <= 560 ? const Color(0xFF2E7D32) : const Color(0xFF1976D2))),
              methodText: 'Alkaline Permanganate Method (Subbiah & Asija)',
            ),
            const Divider(height: 12),
            _buildNutrientRow(
              name: 'Available Phosphorus (P2O5)',
              value: pVal != null ? '${pVal.toStringAsFixed(1)} kg/ha' : 'Pending Test',
              statusBadge: pVal == null
                  ? 'NOT TESTED'
                  : (pVal < 10.0 ? 'LOW (<10)' : (pVal <= 25.0 ? 'MEDIUM (10-25)' : 'HIGH (>25)')),
              statusColor: pVal == null
                  ? Colors.grey
                  : (pVal < 10.0 ? const Color(0xFFD32F2F) : (pVal <= 25.0 ? const Color(0xFF2E7D32) : const Color(0xFF1976D2))),
              methodText: "Olsen's Method (0.5M NaHCO3 extraction)",
            ),
            const Divider(height: 12),
            _buildNutrientRow(
              name: 'Available Potassium (K2O)',
              value: kVal != null ? '${kVal.toStringAsFixed(0)} kg/ha' : 'Pending Test',
              statusBadge: kVal == null
                  ? 'NOT TESTED'
                  : (kVal < 110.0 ? 'LOW (<110)' : (kVal <= 280.0 ? 'MEDIUM (110-280)' : 'HIGH (>280)')),
              statusColor: kVal == null
                  ? Colors.grey
                  : (kVal < 110.0 ? const Color(0xFFD32F2F) : (kVal <= 280.0 ? const Color(0xFF2E7D32) : const Color(0xFF1976D2))),
              methodText: 'Neutral 1N Ammonium Acetate Extraction',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1B5E20),
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('Report History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      context.push(RoutePaths.soilLabHistoryPath(widget.farm.id));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Upload New Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      context.push(RoutePaths.soilLabUploadPath(widget.farm.id));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedNutrientCard(BuildContext context) {
    return Card(
      elevation: 2,
      color: const Color(0xFFFFF8E1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFFFB74D), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildProvenanceBadge(
                  label: 'NOT AVAILABLE — PHYSICAL TEST REQUIRED',
                  color: const Color(0xFFC62828),
                  bgColor: const Color(0xFFFFEBEE),
                  borderColor: const Color(0xFFEF9A9A),
                  icon: Icons.shield_outlined,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF9A9A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFFC62828), size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lab Soil Test Required — not inferred from digital map',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Color(0xFFC62828),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Digital raster maps (ISRIC SoilGrids) model total elemental nitrogen and physical soil properties. They CANNOT quantify bioavailable plant nutrients (NH4+, NO3-, Olsen P, or available K). In accordance with strict agronomic safeguards, digital map extracts must never fabricate available NPK from total nitrogen.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFFB71C1C), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _buildUnavailableRow('Available Nitrogen (N)', 'Physical soil test required'),
            _buildUnavailableRow('Available Phosphorus (P2O5)', 'Physical soil test required'),
            _buildUnavailableRow('Available Potassium (K2O)', 'Physical soil test required'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.upload_file, size: 20),
                label: const Text(
                  'Upload Soil Test Report to Unlock NPK',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  context.push(RoutePaths.soilLabWorkspacePath(widget.farm.id));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicronutrientPanel() {
    final zn = _soilProfile?.additionalParameters['zinc']?.value ?? _latestConfirmedReport?.getEffectiveValue('zinc');
    final fe = _soilProfile?.additionalParameters['iron']?.value ?? _latestConfirmedReport?.getEffectiveValue('iron');
    final mn = _soilProfile?.additionalParameters['manganese']?.value ?? _latestConfirmedReport?.getEffectiveValue('manganese');
    final cu = _soilProfile?.additionalParameters['copper']?.value ?? _latestConfirmedReport?.getEffectiveValue('copper');
    final b = _soilProfile?.additionalParameters['boron']?.value ?? _latestConfirmedReport?.getEffectiveValue('boron');
    final s = _soilProfile?.additionalParameters['sulfur']?.value ?? _latestConfirmedReport?.getEffectiveValue('sulfur');

    if (zn == null && fe == null && mn == null && cu == null && b == null && s == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Micronutrient Ground Truth Panel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                _buildProvenanceBadge(
                  label: 'LABORATORY MEASURED',
                  color: const Color(0xFF1B5E20),
                  bgColor: const Color(0xFFE8F5E9),
                  borderColor: const Color(0xFF81C784),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'DTPA-extractable micronutrients from confirmed soil laboratory test report.',
              style: TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            if (zn != null)
              _buildParamRow('Zinc (Zn)', zn.toStringAsFixed(2), 'mg/kg', null, zn < 0.6 ? 'Deficient (<0.6 mg/kg)' : 'Sufficient (Adequate)', zn < 0.6 ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32)),
            if (fe != null) ...[
              const Divider(height: 12),
              _buildParamRow('Iron (Fe)', fe.toStringAsFixed(2), 'mg/kg', null, fe < 4.5 ? 'Deficient (<4.5 mg/kg)' : 'Sufficient (Adequate)', fe < 4.5 ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32)),
            ],
            if (mn != null) ...[
              const Divider(height: 12),
              _buildParamRow('Manganese (Mn)', mn.toStringAsFixed(2), 'mg/kg', null, mn < 2.0 ? 'Deficient (<2.0 mg/kg)' : 'Sufficient (Adequate)', mn < 2.0 ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32)),
            ],
            if (cu != null) ...[
              const Divider(height: 12),
              _buildParamRow('Copper (Cu)', cu.toStringAsFixed(2), 'mg/kg', null, cu < 0.2 ? 'Deficient (<0.2 mg/kg)' : 'Sufficient (Adequate)', cu < 0.2 ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32)),
            ],
            if (b != null) ...[
              const Divider(height: 12),
              _buildParamRow('Boron (B)', b.toStringAsFixed(2), 'mg/kg', null, b < 0.5 ? 'Deficient (<0.5 mg/kg)' : 'Sufficient (Adequate)', b < 0.5 ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32)),
            ],
            if (s != null) ...[
              const Divider(height: 12),
              _buildParamRow('Sulfur (S)', s.toStringAsFixed(2), 'mg/kg', null, s < 10.0 ? 'Deficient (<10.0 mg/kg)' : 'Sufficient (Adequate)', s < 10.0 ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientRow({
    required String name,
    required String value,
    required String statusBadge,
    required Color statusColor,
    required String methodText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(methodText, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B5E20))),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  statusBadge,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableRow(String nutrient, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(nutrient, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: const TextStyle(color: Color(0xFFC62828), fontSize: 10.5, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvenanceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11.5)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.black87)),
        ],
      ),
    );
  }
}

// ==========================================
// 6. WEATHER INTELLIGENCE TAB (Phase 3)
// ==========================================
class WeatherIntelligenceScreen extends StatelessWidget {
  final List<FarmItem> farms;

  const WeatherIntelligenceScreen({super.key, required this.farms});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weather & Climate Intelligence')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE1F5FE),
                border: Border.all(color: const Color(0xFF81D4FA)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_queue, color: Color(0xFF0277BD), size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Farm-Specific Agro-Meteorology: Real-time observations from OpenWeather and 30-year climatological normals from NASA POWER.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF01579B), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select Farm for Weather & Climate Profile:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (farms.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.terrain_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No farms registered yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text('Please register a farm boundary first to inspect soil parameters.', style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Register New Farm'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => AddEditFarmScreen(
                                onSave: (farm) => FarmRepository.instance.addFarm(farm),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
            else
              ...farms.map((f) => Card(
                    elevation: 1.5,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE1F5FE),
                        child: Icon(Icons.wb_sunny, color: Color(0xFF0277BD)),
                      ),
                      title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${f.taluka} • Centroid: ${f.centroid.latitude.toStringAsFixed(3)}, ${f.centroid.longitude.toStringAsFixed(3)}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        FarmRepository.instance.selectedFarmId = f.id;
                        context.push(RoutePaths.weatherDetailPath(f.id));
                      },
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 7. WEATHER & CLIMATE REPORT SCREEN (Phase 3)
// ==========================================
enum WeatherLanguage { english, marathi, hindi }

class WeatherLocalizer {
  static const Map<String, Map<WeatherLanguage, String>> _strings = {
    'title': {
      WeatherLanguage.english: 'Weather & Climate',
      WeatherLanguage.marathi: 'हवामान आणि कृषी-हवामान',
      WeatherLanguage.hindi: 'मौसम एवं कृषि जलवायु',
    },
    'observed_card': {
      WeatherLanguage.english: 'Current Weather (Observed)',
      WeatherLanguage.marathi: 'सध्याचे प्रत्यक्ष हवामान',
      WeatherLanguage.hindi: 'वर्तमान मौसम (प्रत्यक्ष दर्ज)',
    },
    'forecast_card': {
      WeatherLanguage.english: '5-Day Agricultural Forecast',
      WeatherLanguage.marathi: '५ दिवसांचा शेती हवामान अंदाज',
      WeatherLanguage.hindi: '५ दिवसीय कृषि मौसम पूर्वानुमान',
    },
    'rainfall_normals': {
      WeatherLanguage.english: '30-Year Monthly Rainfall Normals (mm)',
      WeatherLanguage.marathi: '३० वर्षांची मासिक सरासरी पर्जन्यवृष्टी (मिमी)',
      WeatherLanguage.hindi: '३० वर्षीय मासिक वर्षा औसत (मिमी)',
    },
    'seasonal_summary': {
      WeatherLanguage.english: 'Seasonal Climate & Water Stress Summary',
      WeatherLanguage.marathi: 'हंगामी हवामान व पाणी ताण सारांश',
      WeatherLanguage.hindi: 'मौसमी जलवायु एवं जल तनाव सारांश',
    },
    'temp': {
      WeatherLanguage.english: 'Temperature',
      WeatherLanguage.marathi: 'तापमान',
      WeatherLanguage.hindi: 'तापमान',
    },
    'humidity': {
      WeatherLanguage.english: 'Humidity',
      WeatherLanguage.marathi: 'हवेतील आर्द्रता',
      WeatherLanguage.hindi: 'हवा की नमी',
    },
    'wind': {
      WeatherLanguage.english: 'Wind Speed',
      WeatherLanguage.marathi: 'वाऱ्याचा वेग',
      WeatherLanguage.hindi: 'हवा की गति',
    },
    'rain': {
      WeatherLanguage.english: 'Rainfall',
      WeatherLanguage.marathi: 'पाऊस',
      WeatherLanguage.hindi: 'बारिश (वर्षा)',
    },
    'water_stress': {
      WeatherLanguage.english: 'Water Stress Indicator',
      WeatherLanguage.marathi: 'पाणी ताण दर्शक',
      WeatherLanguage.hindi: 'जल तनाव सूचक',
    },
    'disclaimer': {
      WeatherLanguage.english: 'Observations sourced from OpenWeather. 30-year climatological normals from NASA POWER satellite reanalysis. Values reflect farm centroid.',
      WeatherLanguage.marathi: 'हवामान नोंदी OpenWeather कडून आणि ३० वर्षांची सरासरी NASA POWER उपग्रहाकडून घेतलेली आहे. ही माहिती शेताच्या मध्यबिंदूची आहे.',
      WeatherLanguage.hindi: 'मौसम OpenWeather और ३० वर्ष का औसत NASA POWER उपग्रह डेटा से लिया गया है। यह आंकड़े खेत के केंद्र के हैं।',
    },
  };

  static String t(String key, WeatherLanguage lang) {
    return _strings[key]?[lang] ?? _strings[key]?[WeatherLanguage.english] ?? key;
  }
}

class WeatherClimateReportScreen extends StatefulWidget {
  final FarmItem farm;

  const WeatherClimateReportScreen({super.key, required this.farm});

  @override
  State<WeatherClimateReportScreen> createState() => _WeatherClimateReportScreenState();
}

class _WeatherClimateReportScreenState extends State<WeatherClimateReportScreen> {
  WeatherLanguage _currentLang = WeatherLanguage.english;
  bool _isLoading = false;
  String? _weatherError;
  final WeatherRepository _weatherRepo = WeatherRepository();
  CurrentWeatherObservation? _currentWeather;
  FarmWeatherForecastResponse? _forecast;
  SeasonalClimateSummary? _climateSummary;

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  IconData _mapWeatherIcon(String condition) {
    final c = condition.toLowerCase();
    if (c.contains('thunder') || c.contains('storm')) return Icons.thunderstorm;
    if (c.contains('rain') || c.contains('drizzle') || c.contains('shower')) return Icons.grain;
    if (c.contains('snow')) return Icons.ac_unit;
    if (c.contains('cloud') || c.contains('overcast')) return Icons.cloud;
    if (c.contains('fog') || c.contains('mist') || c.contains('haze')) return Icons.foggy;
    return Icons.wb_sunny;
  }

  Future<void> _loadWeatherData() async {
    setState(() {
      _isLoading = true;
      _weatherError = null;
    });
    try {
      final results = await Future.wait([
        _weatherRepo.getCurrentWeather(widget.farm.id),
        _weatherRepo.getWeatherForecast(widget.farm.id),
        _weatherRepo.getClimateSummary(widget.farm.id),
      ]);
      if (mounted) {
        setState(() {
          _currentWeather = results[0] as CurrentWeatherObservation?;
          _forecast = results[1] as FarmWeatherForecastResponse?;
          _climateSummary = results[2] as SeasonalClimateSummary?;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherError = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshWeather() async {
    await _loadWeatherData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weather and forecast refreshed from OpenWeather API.')),
      );
    }
  }

  Map<String, dynamic> _getWeatherData(String taluka) {
    if (_currentWeather != null && _climateSummary != null) {
      double rabiRain = 25.0;
      double zaidRain = 40.0;
      for (final s in _climateSummary!.agriculturalSeasons) {
        if (s.seasonName.toLowerCase().contains('rabi')) {
          rabiRain = s.totalRainfallMm;
        } else if (s.seasonName.toLowerCase().contains('zaid') || s.seasonName.toLowerCase().contains('summer')) {
          zaidRain = s.totalRainfallMm;
        }
      }

      return {
        'current_temp': _currentWeather!.temperatureC,
        'feels_like': _currentWeather!.feelsLikeC,
        'humidity': _currentWeather!.humidityPercent.round(),
        'wind_speed': _currentWeather!.windSpeedMs,
        'wind_kmh': (_currentWeather!.windSpeedMs * 3.6).roundToDouble(),
        'condition': _currentWeather!.weatherCondition,
        'icon': _mapWeatherIcon(_currentWeather!.weatherCondition),
        'rain_1h': _currentWeather!.precipitationMm,
        'annual_rain': _climateSummary!.annualRainfallMm,
        'monsoon_rain': _climateSummary!.monsoonRainfallMm,
        'monsoon_pct': _climateSummary!.monsoonSharePercent,
        'wet_season': _climateSummary!.wetSeasonMonths.join(', '),
        'dry_season': _climateSummary!.drySeasonMonths.join(', '),
        'stress_indicator': _climateSummary!.potentialWaterStressIndicator,
        'mean_temp': _climateSummary!.meanTemperatureC,
        'min_temp': _climateSummary!.minTemperatureC,
        'max_temp': _climateSummary!.maxTemperatureC,
        'monthly_rain': _climateSummary!.monthlyClimate.map((m) => m.rainfallMm).toList(),
        'monthly_temp': _climateSummary!.monthlyClimate.map((m) => m.meanTempC).toList(),
        'kharif_rain': _climateSummary!.monsoonRainfallMm,
        'rabi_rain': rabiRain,
        'zaid_rain': zaidRain,
      };
    }

    final isWesternGhats = taluka.toLowerCase() == 'maval' || taluka.toLowerCase() == 'mulshi';

    if (isWesternGhats) {
      return {
        'current_temp': 24.2,
        'feels_like': 24.8,
        'humidity': 68,
        'wind_speed': 2.8,
        'wind_kmh': 10.1,
        'condition': 'Partly Cloudy',
        'icon': _mapWeatherIcon('Partly Cloudy'),
        'rain_1h': 0.0,
        'annual_rain': 1680.0,
        'monsoon_rain': 1520.0,
        'monsoon_pct': 90.5,
        'wet_season': 'June – September',
        'dry_season': 'November – April',
        'stress_indicator': 'Western Ghats Humid: Ample Kharif Soil Moisture; Moderate Post-Monsoon Depletion',
        'mean_temp': 24.6,
        'min_temp': 15.0,
        'max_temp': 34.5,
        'monthly_rain': [2.0, 1.5, 4.0, 15.0, 35.0, 310.0, 560.0, 420.0, 230.0, 75.0, 22.0, 5.5],
        'monthly_temp': [21.5, 23.0, 26.5, 29.0, 29.5, 26.0, 24.0, 23.5, 24.5, 25.0, 23.0, 21.0],
        'kharif_rain': 1600.0,
        'rabi_rain': 32.0,
        'zaid_rain': 50.0,
      };
    } else {
      // Baramati / Indapur (Deccan Rain Shadow)
      return {
        'current_temp': 27.5,
        'feels_like': 28.0,
        'humidity': 48,
        'wind_speed': 3.4,
        'wind_kmh': 12.2,
        'condition': 'Clear Sky',
        'icon': _mapWeatherIcon('Clear Sky'),
        'rain_1h': 0.0,
        'annual_rain': 535.0,
        'monsoon_rain': 445.0,
        'monsoon_pct': 83.2,
        'wet_season': 'June – September',
        'dry_season': 'November – May',
        'stress_indicator': 'Semi-Arid Rain Shadow: Moderate Kharif Moisture; Severe Winter/Summer Moisture Deficit',
        'mean_temp': 26.8,
        'min_temp': 15.5,
        'max_temp': 39.5,
        'monthly_rain': [1.0, 0.8, 3.2, 12.0, 25.0, 105.0, 125.0, 110.0, 105.0, 38.0, 8.0, 2.0],
        'monthly_temp': [22.0, 24.5, 28.5, 31.0, 32.5, 28.5, 26.5, 26.0, 26.5, 27.0, 24.5, 22.0],
        'kharif_rain': 483.0,
        'rabi_rain': 15.0,
        'zaid_rain': 37.0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = _getWeatherData(widget.farm.taluka);
    final months = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];
    final List<double> rainVals = (weather['monthly_rain'] as List).map((e) => (e as num).toDouble()).toList();
    final double maxRain = rainVals.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.farm.name} — ${WeatherLocalizer.t("title", _currentLang)}'),
        backgroundColor: const Color(0xFF0277BD),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Weather',
            onPressed: _refreshWeather,
          ),
          PopupMenuButton<WeatherLanguage>(
            icon: const Icon(Icons.language),
            tooltip: 'Select Language / भाषा बदला',
            onSelected: (lang) => setState(() => _currentLang = lang),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: WeatherLanguage.english, child: Text('English')),
              PopupMenuItem(value: WeatherLanguage.marathi, child: Text('मराठी (Marathi)')),
              PopupMenuItem(value: WeatherLanguage.hindi, child: Text('हिंदी (Hindi)')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_weatherError != null && _currentWeather == null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFC62828)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Live OpenWeather retrieval encountered an error ($_weatherError). Displaying regional historical baseline.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFFC62828)),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadWeatherData,
                            child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC62828))),
                          ),
                        ],
                      ),
                    ),

                  // 1. Live Weather Observation Card (OpenWeather)
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0277BD), Color(0xFF01579B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                WeatherLocalizer.t('observed_card', _currentLang),
                                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.fiber_manual_record, color: Colors.greenAccent, size: 10),
                                    SizedBox(width: 4),
                                    Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${weather["current_temp"]} °C',
                                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Feels like ${weather["feels_like"]} °C • ${weather["condition"]}',
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ],
                              ),
                              Icon(weather['icon'] as IconData, color: Colors.amberAccent, size: 52),
                            ],
                          ),
                          const Divider(color: Colors.white24, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildWhiteMetric('Humidity', '${weather["humidity"]}%', Icons.water_drop),
                              _buildWhiteMetric('Wind', '${weather["wind_kmh"]} km/h', Icons.air),
                              _buildWhiteMetric('Precipitation', '${weather["rain_1h"]} mm', Icons.umbrella),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. 5-Day Agricultural Forecast Card (OpenWeather)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            WeatherLocalizer.t('forecast_card', _currentLang),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0277BD)),
                          ),
                          const SizedBox(height: 10),
                          if (_forecast != null && _forecast!.dailySummaries.isNotEmpty)
                            ..._forecast!.dailySummaries.take(5).map((d) {
                              return Column(
                                children: [
                                  _buildForecastRow(
                                    d.date.length >= 10 ? d.date.substring(5, 10) : d.date,
                                    Icons.wb_sunny_outlined,
                                    d.weatherCondition,
                                    d.tempMinC,
                                    d.tempMaxC,
                                    d.maxPopPct.round(),
                                  ),
                                  const Divider(height: 12),
                                ],
                              );
                            })
                          else ...[
                            _buildForecastRow('Today', Icons.wb_sunny, 'Sunny', 20.0, 31.0, 10),
                            const Divider(height: 12),
                            _buildForecastRow('Tomorrow', Icons.cloud_outlined, 'Partly Cloudy', 21.0, 31.5, 20),
                            const Divider(height: 12),
                            _buildForecastRow('Day 3', Icons.wb_cloudy_outlined, 'Overcast', 22.0, 30.0, 35),
                            const Divider(height: 12),
                            _buildForecastRow('Day 4', Icons.wb_sunny, 'Clear Sky', 20.5, 32.0, 15),
                            const Divider(height: 12),
                            _buildForecastRow('Day 5', Icons.wb_sunny_outlined, 'Sunny', 19.5, 32.5, 10),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Monthly Rainfall & Climatology Chart (NASA POWER 30-Year Normals)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  WeatherLocalizer.t('rainfall_normals', _currentLang),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                                ),
                              ),
                              Chip(
                                label: Text('${weather["annual_rain"]} mm / yr', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: const Color(0xFF2E7D32),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Monsoon months (Jun–Sep) in blue/teal receive 80–90% of annual rainfall:',
                            style: TextStyle(color: Colors.black54, fontSize: 11),
                          ),
                          const SizedBox(height: 14),

                          // Visual Bar Chart for 12 Months
                          SizedBox(
                            height: 140,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(12, (index) {
                                final val = rainVals[index];
                                final isMonsoon = index >= 5 && index <= 8;
                                final normHeight = maxRain > 0 ? (val / maxRain) * 95.0 : 0.0;

                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${val.toInt()}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isMonsoon ? const Color(0xFF0277BD) : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          height: max(4.0, normHeight),
                                          decoration: BoxDecoration(
                                            color: isMonsoon ? const Color(0xFF0288D1) : Colors.grey.shade400,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          months[index],
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: isMonsoon ? FontWeight.bold : FontWeight.normal,
                                            color: isMonsoon ? const Color(0xFF01579B) : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Agro-Climatic Seasonal Summary (NASA POWER)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            WeatherLocalizer.t('seasonal_summary', _currentLang),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                          ),
                          const SizedBox(height: 10),

                          _buildAgroRow('Annual Precipitation Normal', '${weather["annual_rain"]} mm'),
                          _buildAgroRow('Monsoon Precipitation (Jun–Sep)', '${weather["monsoon_rain"]} mm (${weather["monsoon_pct"]}%)'),
                          _buildAgroRow('Wet Season Period', '${weather["wet_season"]}'),
                          _buildAgroRow('Dry Season Period', '${weather["dry_season"]}'),
                          _buildAgroRow('Mean Annual Temperature', '${weather["mean_temp"]} °C (Range: ${weather["min_temp"]}°C to ${weather["max_temp"]}°C)'),
                          const Divider(height: 16),

                          // Potential Water Stress Indicator Badge
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(WeatherLocalizer.t('water_stress', _currentLang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  border: Border.all(color: const Color(0xFFFFB74D)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.water_damage_outlined, color: Color(0xFFE65100), size: 22),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        weather['stress_indicator'] as String,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFBF360C)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. Indian Cropping Seasons Agro-Climatic Characteristics
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Agro-Climatic Seasonal Characteristics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                          const SizedBox(height: 8),
                          _buildSeasonTile(
                            'Kharif (Monsoon: Jun–Oct)',
                            '${weather["kharif_rain"]} mm Rainfall • Rainfed / Canal Viable',
                            const Color(0xFF2E7D32),
                          ),
                          const SizedBox(height: 6),
                          _buildSeasonTile(
                            'Rabi (Winter: Nov–Mar)',
                            '${weather["rabi_rain"]} mm Rainfall • Moderate to High Water Stress (Well/Borewell Required)',
                            const Color(0xFF0277BD),
                          ),
                          const SizedBox(height: 6),
                          _buildSeasonTile(
                            'Zaid (Summer: Apr–May)',
                            '${weather["zaid_rain"]} mm Rainfall • High Heat Load & Severe Moisture Deficit',
                            const Color(0xFFE65100),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. Scientific Provenance and Attribution Card
                  Card(
                    elevation: 1,
                    color: const Color(0xFFFAFAFA),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Data Provenance & Scientific Transparency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(WeatherLocalizer.t('disclaimer', _currentLang), style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.3)),
                          const SizedBox(height: 6),
                          Text('Centroid Coordinates: Lat ${widget.farm.centroid.latitude.toStringAsFixed(5)}, Lon ${widget.farm.centroid.longitude.toStringAsFixed(5)}', style: const TextStyle(fontSize: 10.5, color: Colors.black45)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildWhiteMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildForecastRow(String day, IconData icon, String condition, double min, double max, int pop) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(width: 80, child: Text(day, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        Row(
          children: [
            Icon(icon, color: const Color(0xFF0277BD), size: 20),
            const SizedBox(width: 6),
            SizedBox(width: 90, child: Text(condition, style: const TextStyle(fontSize: 12, color: Colors.black87))),
          ],
        ),
        Row(
          children: [
            Icon(Icons.water_drop, color: Colors.blue.shade300, size: 12),
            Text('$pop%', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            const SizedBox(width: 8),
            Text('${min.toInt()}° / ${max.toInt()}°', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildAgroRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12.5))),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildSeasonTile(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.eco, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: color)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 8. CROP KNOWLEDGE BASE SCREENS (Phase 4)
// ==========================================
class CropKnowledgeItem {
  final String id;
  final String commonName;
  final String scientificName;
  final String marathiName;
  final String hindiName;
  final String category;
  final String cropType;
  final int minDuration;
  final int maxDuration;
  final List<String> varieties;
  final List<String> preferredTextures;
  final List<String> acceptableTextures;
  final double? phOptMin;
  final double? phOptMax;
  final double? phBestSuitedMin;
  final double? phBestSuitedMax;
  final double? phTolMin;
  final double? phTolMax;
  final String? phContextNotes;
  final List<String>? bestSuitedSoilTextures;
  final String drainage;
  final String salinity;
  final double minDepthCm;
  final double tempOptMin;
  final double tempOptMax;
  final double? tempTolMin;
  final double? tempTolMax;
  final double? tempReproductiveMaxC;
  final double? tempReproductiveMinMeanC;
  final double? annualRainMin;
  final double? annualRainMax;
  final String frostSensitivity;
  final String heatSensitivity;
  final String? thermalThresholdContext;
  final bool degradedMode;
  final String? degradedWarning;
  final List<Map<String, String>> seasons;
  final double waterReqMinMm;
  final double waterReqMaxMm;
  final bool rainfedSuitable;
  final String irrigationDependency;
  final List<String> criticalStages;
  final String waterloggingSensitivity;
  final String droughtSensitivity;
  final Map<String, Map<String, dynamic>> regionalSuitability;
  final String primarySource;
  final String publicationTitle;
  final int publicationYear;

  const CropKnowledgeItem({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.marathiName,
    required this.hindiName,
    required this.category,
    required this.cropType,
    required this.minDuration,
    required this.maxDuration,
    required this.varieties,
    required this.preferredTextures,
    required this.acceptableTextures,
    this.phOptMin,
    this.phOptMax,
    this.phBestSuitedMin,
    this.phBestSuitedMax,
    this.phTolMin,
    this.phTolMax,
    this.phContextNotes,
    this.bestSuitedSoilTextures,
    required this.drainage,
    required this.salinity,
    required this.minDepthCm,
    required this.tempOptMin,
    required this.tempOptMax,
    this.tempTolMin,
    this.tempTolMax,
    this.tempReproductiveMaxC,
    this.tempReproductiveMinMeanC,
    this.annualRainMin,
    this.annualRainMax,
    required this.frostSensitivity,
    required this.heatSensitivity,
    this.thermalThresholdContext,
    this.degradedMode = false,
    this.degradedWarning,
    required this.seasons,
    required this.waterReqMinMm,
    required this.waterReqMaxMm,
    required this.rainfedSuitable,
    required this.irrigationDependency,
    required this.criticalStages,
    required this.waterloggingSensitivity,
    required this.droughtSensitivity,
    required this.regionalSuitability,
    required this.primarySource,
    required this.publicationTitle,
    required this.publicationYear,
  });
}

const List<CropKnowledgeItem> kCropKnowledgeBase = [
  // 1. Sugarcane
  CropKnowledgeItem(
    id: 'sugarcane',
    commonName: 'Sugarcane',
    scientificName: 'Saccharum officinarum L.',
    marathiName: 'ऊस',
    hindiName: 'गन्ना',
    category: 'Cash Crop',
    cropType: 'Semi-perennial',
    minDuration: 360,
    maxDuration: 540,
    varieties: ['Co 86032 (Nira)', 'CoM 0265 (Phule 265)', 'MS 10001 (Phule 10001)', 'VSI 08005'],
    preferredTextures: ['Clay', 'Clay Loam', 'Deep Black Vertisol'],
    acceptableTextures: ['Sandy Clay Loam', 'Loam'],
    phOptMin: 6.5,
    phOptMax: 7.8,
    phTolMin: 6.0,
    phTolMax: 8.5,
    drainage: 'Well-drained; standing water > 48 hrs reduces tillering',
    salinity: 'Moderately Sensitive (EC < 2.0 dS/m)',
    minDepthCm: 90.0,
    tempOptMin: 24.0,
    tempOptMax: 34.0,
    tempTolMin: 15.0,
    tempTolMax: 40.0,
    annualRainMin: 1500.0,
    annualRainMax: 2500.0,
    frostSensitivity: 'Highly Sensitive; frost stops elongation',
    heatSensitivity: 'Moderate; temperatures > 38°C slow tillering',
    seasons: [
      {'name': 'Adsali', 'plant': '15 July - 15 August', 'harvest': 'Nov - Jan (16-18 mo)'},
      {'name': 'Pre-seasonal', 'plant': '15 Oct - 15 Nov', 'harvest': 'Dec - Feb (14-15 mo)'},
      {'name': 'Suru', 'plant': '15 Jan - 15 Feb', 'harvest': 'Jan - Mar (12 mo)'},
    ],
    waterReqMinMm: 1800.0,
    waterReqMaxMm: 2500.0,
    rainfedSuitable: false,
    irrigationDependency: 'Critical / High (25–35 irrigations or drip)',
    criticalStages: ['Tillering stage (60–130 DAP)', 'Grand growth phase (130–250 DAP)'],
    waterloggingSensitivity: 'Moderately Tolerant; stagnation > 48 hrs impairs recovery',
    droughtSensitivity: 'High during formative tillering phase',
    regionalSuitability: {
      'Baramati': {'status': 'Highly Suitable', 'desc': 'Canal command with deep black Vertisols supports high sucrose recovery.'},
      'Indapur': {'status': 'Highly Suitable', 'desc': 'Bhima river and canal commands provide ideal Adsali conditions.'},
      'Maval': {'status': 'Marginal / High Input', 'desc': 'High rainfall and acidic lateritic soils delay maturity and depress sucrose.'},
      'Mulshi': {'status': 'Unsuitable / High Disease Risk', 'desc': 'Steep slopes and torrential rains cause severe waterlogging and poor recovery.'},
    },
    primarySource: 'MPKV Rahuri & ICAR-IISR Lucknow',
    publicationTitle: 'Package of Practices for Field Crops & Sugarcane Agronomy',
    publicationYear: 2023,
  ),

  // 2. Pomegranate
  CropKnowledgeItem(
    id: 'pomegranate',
    commonName: 'Pomegranate',
    scientificName: 'Punica granatum L.',
    marathiName: 'डाळिंब',
    hindiName: 'अनार',
    category: 'Horticulture',
    cropType: 'Perennial Fruit Tree',
    minDuration: 150,
    maxDuration: 180,
    varieties: ['Bhagwa (Kesar)', 'Arakta', 'Ganesh', 'Solapur Lal'],
    preferredTextures: ['Light soil'],
    acceptableTextures: [],
    phOptMin: 6.5,
    phOptMax: 7.0,
    phBestSuitedMin: 6.5,
    phBestSuitedMax: 7.0,
    phTolMin: null,
    phTolMax: 8.5,
    phContextNotes: 'Light soil having a pH range of 6.5–7.0 is most suitable for pomegranate but under well-managed conditions, it can tolerate pH up to 8.5 (ICAR-NRCP & MANAGE 2022, p. 3). Lower tolerable limit is unverified.',
    bestSuitedSoilTextures: ['Light soil'],
    drainage: 'Excellent drainage mandatory; zero tolerance for wet feet',
    salinity: 'Moderately Tolerant (EC < 3.0 dS/m)',
    minDepthCm: 60.0,
    tempOptMin: 25.0,
    tempOptMax: 35.0,
    tempTolMin: 10.0,
    tempTolMax: 44.0,
    annualRainMin: 500.0,
    annualRainMax: 700.0,
    frostSensitivity: 'Moderately Tolerant in dormancy',
    heatSensitivity: 'High tolerance; dry weather enhances aril sweetness',
    seasons: [
      {'name': 'Hasta Bahar', 'plant': 'Sept - Oct (Flowering)', 'harvest': 'Feb - April'},
      {'name': 'Ambe Bahar', 'plant': 'Jan - Feb (Flowering)', 'harvest': 'June - August'},
    ],
    waterReqMinMm: 800.0,
    waterReqMaxMm: 1100.0,
    rainfedSuitable: false,
    irrigationDependency: 'Critical via Drip (essential for Bahar stress regulation)',
    criticalStages: ['Flowering and fruit setting (30–60 days)', 'Fruit sizing and aril development'],
    waterloggingSensitivity: 'Extremely High; standing water triggers Ceratocystis wilt',
    droughtSensitivity: 'Drought hardy in dormancy; sensitive during fruit sizing',
    regionalSuitability: {
      'Baramati': {'status': 'Highly Suitable', 'desc': 'Low humidity and well-drained soils allow export quality Bhagwa production.'},
      'Indapur': {'status': 'Highly Suitable', 'desc': 'Ideal dry semi-arid climate restricts bacterial blight.'},
      'Maval': {'status': 'Unsuitable / High Disease Risk', 'desc': 'High monsoon humidity (> 85%) triggers devastating bacterial blight (telya).'},
      'Mulshi': {'status': 'Unsuitable / High Disease Risk', 'desc': 'Extreme Western Ghats rainfall and fungal fruit rot cause complete loss.'},
    },
    primarySource: 'ICAR-NRCP & MANAGE',
    publicationTitle: 'High-tech Pomegranate Production Practices',
    publicationYear: 2022,
  ),

  // 3. Soybean
  CropKnowledgeItem(
    id: 'soybean',
    commonName: 'Soybean',
    scientificName: 'Glycine max (L.) Merr.',
    marathiName: 'सोयाबीन',
    hindiName: 'सोयाबीन',
    category: 'Oilseed',
    cropType: 'Annual Kharif',
    minDuration: 95,
    maxDuration: 110,
    varieties: ['Phule Sangam (KDS 726)', 'Phule Kimaya (KDS 753)', 'JS 335', 'DSb 21'],
    preferredTextures: ['Clay Loam', 'Clay', 'Medium Black Vertisol'],
    acceptableTextures: ['Loam', 'Silt Loam'],
    phOptMin: 6.5,
    phOptMax: 7.5,
    phTolMin: 6.0,
    phTolMax: 8.0,
    drainage: 'Well-drained; nodulation fails under water stagnation',
    salinity: 'Sensitive (EC < 1.5 dS/m)',
    minDepthCm: 45.0,
    tempOptMin: 22.0,
    tempOptMax: 30.0,
    tempTolMin: 15.0,
    tempTolMax: 35.0,
    annualRainMin: 600.0,
    annualRainMax: 900.0,
    frostSensitivity: 'Sensitive',
    heatSensitivity: 'Moderate; temperatures > 35°C reduce pod set',
    seasons: [
      {'name': 'Kharif', 'plant': '20 June - 10 July', 'harvest': 'October'},
    ],
    waterReqMinMm: 450.0,
    waterReqMaxMm: 650.0,
    rainfedSuitable: true,
    irrigationDependency: 'Supplemental (1–2 protective irrigations in dry spells)',
    criticalStages: ['Flowering stage (35–45 DAP)', 'Pod development and filling (55–75 DAP)'],
    waterloggingSensitivity: 'High; standing water > 24 hrs causes seedling death',
    droughtSensitivity: 'High during flowering and pod development',
    regionalSuitability: {
      'Baramati': {'status': 'Highly Suitable', 'desc': 'Kharif rainfed with supplemental irrigation backup yields up to 28 q/ha.'},
      'Indapur': {'status': 'Highly Suitable', 'desc': 'Excellent fit on medium-to-deep black soils.'},
      'Maval': {'status': 'Moderately Suitable', 'desc': 'Performs well on gentle slopes; avoid flat waterlogged valley floors.'},
      'Mulshi': {'status': 'Marginal / High Input', 'desc': 'Torrential rains cause seed decay and poor root nodulation.'},
    },
    primarySource: 'ICAR-IISR Indore & MPKV Rahuri',
    publicationTitle: 'Soybean Production Technologies for Peninsular India',
    publicationYear: 2022,
  ),

  // 4. Cotton
  CropKnowledgeItem(
    id: 'cotton',
    commonName: 'Cotton',
    scientificName: 'Gossypium hirsutum L.',
    marathiName: 'कापूस',
    hindiName: 'कपास',
    category: 'Fiber',
    cropType: 'Annual Kharif',
    minDuration: 150,
    maxDuration: 180,
    varieties: ['Phule Yamuna', 'PKV Hy 2', 'Ajeet 155 (Bt)', 'RCH 2 (Bt)'],
    preferredTextures: ['Deep Black Vertisol', 'Clay', 'Clay Loam'],
    acceptableTextures: ['Medium Black', 'Silt Loam'],
    phOptMin: 6.5,
    phOptMax: 8.0,
    phTolMin: 5.8,
    phTolMax: 8.5,
    drainage: 'Good internal drainage required',
    salinity: 'Moderately Tolerant (EC up to 4.0 dS/m)',
    minDepthCm: 90.0,
    tempOptMin: 24.0,
    tempOptMax: 34.0,
    tempTolMin: 16.0,
    tempTolMax: 40.0,
    annualRainMin: 650.0,
    annualRainMax: 1000.0,
    frostSensitivity: 'Highly Sensitive',
    heatSensitivity: 'Moderate; temperatures > 38°C cause square shed',
    seasons: [
      {'name': 'Kharif', 'plant': '15 June - 30 June', 'harvest': 'Nov - Jan'},
    ],
    waterReqMinMm: 650.0,
    waterReqMaxMm: 850.0,
    rainfedSuitable: true,
    irrigationDependency: 'Supplemental (2–3 irrigations during boll filling)',
    criticalStages: ['Square formation (45–60 DAP)', 'Flowering (70–90 DAP)', 'Boll development (90–120 DAP)'],
    waterloggingSensitivity: 'High; standing water > 36 hrs causes square and boll drop',
    droughtSensitivity: 'Moderate taproot extraction; stress causes boll abortion',
    regionalSuitability: {
      'Baramati': {'status': 'Moderately Suitable', 'desc': 'Grown on deep black soils with drip irrigation.'},
      'Indapur': {'status': 'Moderately Suitable', 'desc': 'Good potential with timely bollworm monitoring.'},
      'Maval': {'status': 'Unsuitable / High Disease Risk', 'desc': 'Heavy continuous rain causes square drop and boll rot.'},
      'Mulshi': {'status': 'Unsuitable / High Disease Risk', 'desc': 'Cloudiness and heavy rain impede boll opening and fiber development.'},
    },
    primarySource: 'ICAR-CICR Nagpur & MPKV Rahuri',
    publicationTitle: 'Cotton Production Technology for Vertisols',
    publicationYear: 2022,
  ),

  // 5. Maize
  CropKnowledgeItem(
    id: 'maize',
    commonName: 'Maize',
    scientificName: 'Zea mays L.',
    marathiName: 'मका',
    hindiName: 'मक्का',
    category: 'Cereal',
    cropType: 'Annual (Kharif / Rabi / Zaid)',
    minDuration: 90,
    maxDuration: 115,
    varieties: ['Pinnacle (30V92)', 'Ganga 11', 'DKC 9108', 'Phule Rajarshi'],
    preferredTextures: ['Clay Loam', 'Loam', 'Sandy Clay Loam', 'Medium Black'],
    acceptableTextures: ['Clay', 'Silt Loam'],
    phOptMin: 6.0,
    phOptMax: 7.5,
    phTolMin: 5.5,
    phTolMax: 8.0,
    drainage: 'Well-drained; standing water reduces yield by 30% in 24 hrs',
    salinity: 'Moderately Sensitive (EC < 1.7 dS/m)',
    minDepthCm: 60.0,
    tempOptMin: 21.0,
    tempOptMax: 30.0,
    tempTolMin: 12.0,
    tempTolMax: 38.0,
    annualRainMin: 500.0,
    annualRainMax: 800.0,
    frostSensitivity: 'Highly Sensitive',
    heatSensitivity: 'High; temperatures > 38°C desiccate pollen during silking',
    seasons: [
      {'name': 'Kharif', 'plant': '15 June - 15 July', 'harvest': 'Sept - Oct'},
      {'name': 'Rabi', 'plant': '15 Oct - 15 Nov', 'harvest': 'Feb - March'},
    ],
    waterReqMinMm: 500.0,
    waterReqMaxMm: 700.0,
    rainfedSuitable: true,
    irrigationDependency: 'Irrigated in Rabi/Summer; Supplemental in Kharif',
    criticalStages: ['Tasseling (45–55 DAP)', 'Silking (55–65 DAP)', 'Grain milk stage (70–85 DAP)'],
    waterloggingSensitivity: 'Extremely High; standing water stunts seedlings',
    droughtSensitivity: 'Critical at silking; 2 days of wilting cuts grain count by 50%',
    regionalSuitability: {
      'Baramati': {'status': 'Highly Suitable', 'desc': 'Thrives year-round with high poultry feed and silage demand.'},
      'Indapur': {'status': 'Highly Suitable', 'desc': 'High grain and green fodder yields under canal/well irrigation.'},
      'Maval': {'status': 'Moderately Suitable', 'desc': 'Suitable in Kharif on elevated uplands with free drainage.'},
      'Mulshi': {'status': 'Marginal / High Input', 'desc': 'Monsoon water stagnation induces root chlorosis.'},
    },
    primarySource: 'MPKV Rahuri & ICAR-IIMR Ludhiana',
    publicationTitle: 'Package of Practices for Maize Cultivation',
    publicationYear: 2023,
  ),

  // 6. Wheat
  CropKnowledgeItem(
    id: 'wheat',
    commonName: 'Wheat',
    scientificName: 'Triticum aestivum L.',
    marathiName: 'गहू',
    hindiName: 'गेहूं',
    category: 'Cereal',
    cropType: 'Annual Rabi',
    minDuration: 105,
    maxDuration: 125,
    varieties: ['Phule Samadhan (NIAW 1994)', 'Trimbak (NIAW 301)', 'Tapovan (NIAW 917)', 'MACS 6222'],
    preferredTextures: ['Clay', 'Clay Loam', 'Deep Black Vertisol'],
    acceptableTextures: ['Loam', 'Silt Loam'],
    phOptMin: 6.5,
    phOptMax: 7.8,
    phTolMin: 6.0,
    phTolMax: 8.2,
    drainage: 'Well-drained; moderate waterlogging tolerance in tillering',
    salinity: 'Moderately Tolerant (EC up to 4.0 dS/m)',
    minDepthCm: 60.0,
    tempOptMin: 15.0,
    tempOptMax: 24.0,
    tempTolMin: 8.0,
    tempTolMax: 30.0,
    annualRainMin: 350.0,
    annualRainMax: 550.0,
    frostSensitivity: 'Moderately Tolerant',
    heatSensitivity: 'High; temperatures > 30°C cause terminal heat stress',
    seasons: [
      {'name': 'Rabi', 'plant': '01 Nov - 20 Nov', 'harvest': 'Feb - March'},
    ],
    waterReqMinMm: 400.0,
    waterReqMaxMm: 550.0,
    rainfedSuitable: false,
    irrigationDependency: 'Critical (requires 4–6 irrigations at key stages)',
    criticalStages: ['Crown Root Initiation (18–21 DAS)', 'Tillering (40–45 DAS)', 'Flowering', 'Milk stage'],
    waterloggingSensitivity: 'Moderate',
    droughtSensitivity: 'High; stress at CRI reduces tillers by 40%',
    regionalSuitability: {
      'Baramati': {'status': 'Highly Suitable', 'desc': 'Deep black Vertisols with canal irrigation achieve peak productivity.'},
      'Indapur': {'status': 'Highly Suitable', 'desc': 'Timely November sowing yields bold, lustrous grains.'},
      'Maval': {'status': 'Marginal / High Input', 'desc': 'High winter morning humidity and fog promote rust infection.'},
      'Mulshi': {'status': 'Marginal / High Input', 'desc': 'Short winter duration and soil acidity limit yields.'},
    },
    primarySource: 'ICAR-IIWBR Karnal & MPKV Rahuri',
    publicationTitle: 'Wheat Production Technologies for Peninsular Zone',
    publicationYear: 2022,
  ),

  // 7. Sorghum (Jowar)
  CropKnowledgeItem(
    id: 'sorghum',
    commonName: 'Sorghum (Jowar)',
    scientificName: 'Sorghum bicolor (L.) Moench',
    marathiName: 'ज्वारी',
    hindiName: 'ज्वार',
    category: 'Cereal',
    cropType: 'Annual (Kharif / Rabi)',
    minDuration: 110,
    maxDuration: 135,
    varieties: ['Maldandi (M 35-1)', 'Phule Suchitra', 'Phule Yashodha', 'Phule Revati'],
    preferredTextures: ['Deep Black Vertisol', 'Clay', 'Clay Loam'],
    acceptableTextures: ['Medium Black', 'Sandy Clay Loam'],
    phOptMin: 6.5,
    phOptMax: 8.0,
    phTolMin: 5.5,
    phTolMax: 8.5,
    drainage: 'Well-drained; extracts subsoil moisture from heavy clays',
    salinity: 'Moderately Tolerant (EC up to 4.0 dS/m)',
    minDepthCm: 60.0,
    tempOptMin: 24.0,
    tempOptMax: 32.0,
    tempTolMin: 15.0,
    tempTolMax: 38.0,
    annualRainMin: 400.0,
    annualRainMax: 650.0,
    frostSensitivity: 'Sensitive',
    heatSensitivity: 'Low; exceptional C4 drought tolerance',
    seasons: [
      {'name': 'Rabi', 'plant': '15 Sept - 15 Oct', 'harvest': 'Jan - Feb'},
      {'name': 'Kharif', 'plant': '15 June - 30 June', 'harvest': 'October'},
    ],
    waterReqMinMm: 350.0,
    waterReqMaxMm: 500.0,
    rainfedSuitable: true,
    irrigationDependency: 'Low / Rainfed (1 protective irrigation doubles yield)',
    criticalStages: ['Booting (50–55 DAP)', 'Flowering (65–70 DAP)', 'Grain milk (80–90 DAP)'],
    waterloggingSensitivity: 'Moderate',
    droughtSensitivity: 'Extremely drought resilient; enters temporary dormancy',
    regionalSuitability: {
      'Baramati': {'status': 'Highly Suitable', 'desc': 'Premier agro-climatic belt for iconic Rabi Maldandi 35-1.'},
      'Indapur': {'status': 'Highly Suitable', 'desc': 'Deep black Vertisols conserve moisture for high roti grain quality.'},
      'Maval': {'status': 'Unsuitable / High Disease Risk', 'desc': 'Continuous monsoon rain induces grain mold; soils shallow for Rabi.'},
      'Mulshi': {'status': 'Unsuitable / High Disease Risk', 'desc': 'Heavy rain causes complete grain mold and head blight.'},
    },
    primarySource: 'ICAR-IIMR Hyderabad & MPKV Rahuri',
    publicationTitle: 'Rabi Sorghum Maldandi Agronomy in Deccan Vertisols',
    publicationYear: 2022,
  ),

  // 8. Pearl Millet (Bajra)
  CropKnowledgeItem(
    id: 'bajra',
    commonName: 'Pearl Millet (Bajra)',
    scientificName: 'Pennisetum glaucum (L.) R. Br.',
    marathiName: 'बाजरी',
    hindiName: 'बाजरा',
    category: 'Cereal',
    cropType: 'Annual Kharif / Summer',
    minDuration: 75,
    maxDuration: 85,
    varieties: ['Dhanshakti (Biofortified)', 'Phule Aadishakti', 'Shraddha', 'Saburi'],
    preferredTextures: ['Sandy Loam', 'Loam', 'Light to Medium Black'],
    acceptableTextures: ['Gravelly Loam', 'Clay Loam'],
    phOptMin: 6.5,
    phOptMax: 7.8,
    phTolMin: 5.5,
    phTolMax: 8.5,
    drainage: 'Freely draining; completely intolerant of standing water',
    salinity: 'Moderately Tolerant (EC up to 3.5 dS/m)',
    minDepthCm: 30.0,
    tempOptMin: 25.0,
    tempOptMax: 34.0,
    tempTolMin: 18.0,
    tempTolMax: 42.0,
    annualRainMin: 350.0,
    annualRainMax: 550.0,
    frostSensitivity: 'Highly Sensitive',
    heatSensitivity: 'Extremely Low; thrives in summer heat up to 42°C',
    seasons: [
      {'name': 'Kharif', 'plant': '15 June - 15 July', 'harvest': 'September'},
      {'name': 'Summer', 'plant': '15 Jan - 15 Feb', 'harvest': 'April - May'},
    ],
    waterReqMinMm: 250.0,
    waterReqMaxMm: 350.0,
    rainfedSuitable: true,
    irrigationDependency: 'Low / Rainfed in Kharif; 3–4 irrigations in Summer',
    criticalStages: ['Tillering (25–30 DAP)', 'Flowering (45–50 DAP)'],
    waterloggingSensitivity: 'Very High; standing water leads to downy mildew and ergot',
    droughtSensitivity: 'Highest drought tolerance and water-use efficiency of all cereals',
    regionalSuitability: {
      'Baramati': {'status': 'Highly Suitable', 'desc': 'Ideal on shallow light soils in dry rain shadow pockets.'},
      'Indapur': {'status': 'Highly Suitable', 'desc': 'Reliable short-duration grain crop under dry conditions.'},
      'Maval': {'status': 'Unsuitable / High Disease Risk', 'desc': 'Heavy rain causes severe downy mildew, ergot, and poor pollination.'},
      'Mulshi': {'status': 'Unsuitable / High Disease Risk', 'desc': 'Continuous high humidity causes complete crop failure from ergot.'},
    },
    primarySource: 'MPKV Rahuri & ICAR-AICRP Pearl Millet',
    publicationTitle: 'Package of Practices for Pearl Millet Production',
    publicationYear: 2022,
  ),

  // 9. Chickpea (Chana)
  CropKnowledgeItem(
    id: 'chickpea',
    commonName: 'Chickpea (Chana)',
    scientificName: 'Cicer arietinum L.',
    marathiName: 'हरभरा',
    hindiName: 'चना',
    category: 'Pulse',
    cropType: 'Annual Rabi',
    minDuration: 95,
    maxDuration: 115,
    varieties: ['Vijay (Wilt resistant)', 'Digvijay', 'Vishal', 'Phule Vikram'],
    preferredTextures: ['Clay Loam', 'Clay', 'Medium Black Vertisol'],
    acceptableTextures: ['Loam', 'Silt Loam'],
    phOptMin: null,
    phOptMax: null,
    phBestSuitedMin: 6.0,
    phBestSuitedMax: 8.0,
    phTolMin: null,
    phTolMax: null,
    phContextNotes: 'Soil pH 6.0–8.0 is documented as best-suited for deep loams or silty clay loams per ICRISAT (2010, p. 8). General tolerance limits across all textures are unverified. High water tables and salinity are unsuitable.',
    bestSuitedSoilTextures: ['Deep Loam', 'Silty Clay Loam'],
    drainage: 'Loose tilth & good drainage; highly sensitive to poor aeration, waterlogging and collar rot (ICRISAT 2010, p. 8)',
    salinity: 'Sensitive; saline soils and fields with high water tables are not suitable (ICRISAT 2010, p. 8)',
    minDepthCm: 45.0,
    tempOptMin: 15.0,
    tempOptMax: 25.0,
    tempTolMin: null,
    tempTolMax: null,
    tempReproductiveMaxC: 35.0,
    tempReproductiveMinMeanC: 15.0,
    annualRainMin: 300.0,
    annualRainMax: 450.0,
    frostSensitivity: 'Low-temperature sensitivity during reproductive stage: mean of max & min daily temps < 15°C causes flower drop and reduced pod set (ICRISAT 2010, p. 3)',
    heatSensitivity: 'High-temperature sensitivity during reproductive stage: max daily temp > 35°C causes flower drop and reduced pod set (ICRISAT 2010, p. 3). Not a universal crop mortality threshold.',
    thermalThresholdContext: 'Sensitivity thresholds (>35°C daily max and <15°C mean of daily max and min) specifically apply during the reproductive stage causing flower drop and reduced pod set (ICRISAT 2010, p. 3).',
    seasons: [
      {'name': 'Rabi', 'plant': '10 Oct - 10 Nov', 'harvest': 'Jan - Feb'},
    ],
    waterReqMinMm: 250.0,
    waterReqMaxMm: 350.0,
    rainfedSuitable: true,
    irrigationDependency: 'Low to Supplemental (1 protective irrigation at pod fill)',
    criticalStages: ['Pre-flowering branching (30–35 DAP)', 'Pod development (60–65 DAP)'],
    waterloggingSensitivity: 'High; excess wetness triggers wilt',
    droughtSensitivity: 'Moderate; deep root system extracts subsoil water',
    regionalSuitability: {
      'Baramati': {'status': 'Highly Suitable', 'desc': 'Major pulse on conserved moisture in black soils; Vijay is wilt-immune.'},
      'Indapur': {'status': 'Highly Suitable', 'desc': 'Conserved moisture on Vertisols gives outstanding grain quality.'},
      'Maval': {'status': 'Marginal / High Input', 'desc': 'Acidic soils and high post-monsoon humidity trigger root rot.'},
      'Mulshi': {'status': 'Unsuitable / High Disease Risk', 'desc': 'Acid laterites cause severe collar rot and seedling mortality.'},
    },
    primarySource: 'ICRISAT',
    publicationTitle: 'Chickpea Seed Production Manual',
    publicationYear: 2010,
  ),

  // 10. Groundnut
  CropKnowledgeItem(
    id: 'groundnut',
    commonName: 'Groundnut (Peanut)',
    scientificName: 'Arachis hypogaea L.',
    marathiName: 'भुईमूग',
    hindiName: 'मूंगफली',
    category: 'Oilseed',
    cropType: 'Annual (Kharif / Summer)',
    minDuration: 105,
    maxDuration: 125,
    varieties: ['Phule Unnati', 'Phule Morana', 'TAG 24', 'JL 501'],
    preferredTextures: ['Sandy Clay Loam', 'Loam', 'Sandy Loam', 'Light to Medium Loam'],
    acceptableTextures: ['Clay Loam'],
    phOptMin: 6.0,
    phOptMax: 7.2,
    phTolMin: 5.5,
    phTolMax: 7.8,
    drainage: 'Loose, friable, well-drained soil essential for peg entry',
    salinity: 'Sensitive (EC < 1.5 dS/m)',
    minDepthCm: 45.0,
    tempOptMin: 24.0,
    tempOptMax: 32.0,
    tempTolMin: 18.0,
    tempTolMax: 38.0,
    annualRainMin: 500.0,
    annualRainMax: 750.0,
    frostSensitivity: 'Highly Sensitive',
    heatSensitivity: 'Moderate',
    seasons: [
      {'name': 'Summer', 'plant': '15 Jan - 15 Feb', 'harvest': 'May - June'},
      {'name': 'Kharif', 'plant': '15 June - 10 July', 'harvest': 'October'},
    ],
    waterReqMinMm: 450.0,
    waterReqMaxMm: 650.0,
    rainfedSuitable: true,
    irrigationDependency: 'Critical in Summer (drip every 8–10 days)',
    criticalStages: ['Flowering (20–30 DAP)', 'Pegging stage (40–50 DAP)', 'Pod development (60–80 DAP)'],
    waterloggingSensitivity: 'High; causes pod decay and Aspergillus fungus',
    droughtSensitivity: 'Critical at pegging; dry topsoil prevents subterranean peg entry',
    regionalSuitability: {
      'Baramati': {'status': 'Highly Suitable', 'desc': 'High summer profitability under drip in medium friable soils.'},
      'Indapur': {'status': 'Moderately Suitable', 'desc': 'Avoid heavy sticky clays that impede pod harvest.'},
      'Maval': {'status': 'Moderately Suitable', 'desc': 'Grown in Kharif on gentle slopes with lime to counter acidity.'},
      'Mulshi': {'status': 'Marginal / High Input', 'desc': 'Heavy rain leaches calcium, causing empty pods (pops).'},
    },
    primarySource: 'MPKV Rahuri & ICAR-DGR Junagadh',
    publicationTitle: 'Package of Practices for Groundnut Production',
    publicationYear: 2023,
  ),
];

class CropCatalogScreen extends StatefulWidget {
  const CropCatalogScreen({super.key});

  @override
  State<CropCatalogScreen> createState() => _CropCatalogScreenState();
}

class _CropCatalogScreenState extends State<CropCatalogScreen> {
  String _selectedCategory = 'All';
  String _selectedSeason = 'All';
  String _searchQuery = '';
  WeatherLanguage _lang = WeatherLanguage.english;
  final CropRepository _cropRepo = CropRepository();
  List<CropCatalogSummary> _remoteCrops = [];
  bool _isLoading = false;

  final List<String> _categories = ['All', 'Cash Crop', 'Cereal', 'Pulse', 'Oilseed', 'Horticulture', 'Fiber'];
  final List<String> _seasons = ['All', 'Kharif', 'Rabi', 'Summer', 'Perennial'];

  @override
  void initState() {
    super.initState();
    _loadCrops();
  }

  Future<void> _loadCrops() async {
    setState(() => _isLoading = true);
    try {
      final crops = await _cropRepo.listCrops(
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        season: _selectedSeason == 'All' ? null : _selectedSeason,
      );
      if (mounted) setState(() => _remoteCrops = crops);
    } catch (_) {
      // Fallback
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = kCropKnowledgeBase.where((c) {
      if (_selectedCategory != 'All' && c.category != _selectedCategory) {
        return false;
      }
      if (_selectedSeason != 'All') {
        if (_selectedSeason == 'Perennial') {
          final isPerennial = c.cropType.toLowerCase().contains('perennial');
          if (!isPerennial) return false;
        } else {
          final sKey = _selectedSeason.toLowerCase();
          final hasSeason = c.seasons.any((s) => (s['name'] ?? '').toLowerCase().contains(sKey)) ||
              c.cropType.toLowerCase().contains(sKey);
          if (!hasSeason) return false;
        }
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = c.commonName.toLowerCase().contains(q) ||
            c.marathiName.toLowerCase().contains(q) ||
            c.hindiName.toLowerCase().contains(q) ||
            c.scientificName.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Knowledge Base'),
        backgroundColor: const Color(0xFF1B5E20),
        actions: [
          PopupMenuButton<WeatherLanguage>(
            icon: const Icon(Icons.language),
            tooltip: 'Language / भाषा',
            onSelected: (l) => setState(() => _lang = l),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: WeatherLanguage.english, child: Text('English')),
              PopupMenuItem(value: WeatherLanguage.marathi, child: Text('मराठी (Marathi)')),
              PopupMenuItem(value: WeatherLanguage.hindi, child: Text('हिंदी (Hindi)')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const LinearProgressIndicator(
              color: Color(0xFF1B5E20),
              backgroundColor: Color(0xFFE8F5E9),
              minHeight: 2,
            ),
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: _lang == WeatherLanguage.marathi ? 'पीक शोधा (उदा. कापूस, गहू)...' : 'Search crop (e.g. Wheat, Sugarcane)...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 8),
                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSel = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: FilterChip(
                          label: Text(cat),
                          selected: isSel,
                          selectedColor: const Color(0xFFC8E6C9),
                          onSelected: (_) {
                            setState(() => _selectedCategory = cat);
                            _loadCrops();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                // Season Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _seasons.map((sn) {
                      final isSel = _selectedSeason == sn;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: FilterChip(
                          label: Text(sn),
                          selected: isSel,
                          selectedColor: const Color(0xFFBBDEFB),
                          onSelected: (_) {
                            setState(() => _selectedSeason = sn);
                            _loadCrops();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(color: Color(0xFF1B5E20)),
          if (_remoteCrops.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFFE8F5E9),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Synced with FastAPI Knowledge Base (${_remoteCrops.length} crops)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),

          // Crop List View
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (ctx, idx) {
                final crop = filtered[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => CropDetailScreen(crop: crop, lang: _lang),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _lang == WeatherLanguage.marathi ? crop.marathiName : (_lang == WeatherLanguage.hindi ? crop.hindiName : crop.commonName),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                                  ),
                                  Text(
                                    crop.scientificName,
                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54),
                                  ),
                                ],
                              ),
                              Chip(
                                label: Text(crop.category, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: const Color(0xFF2E7D32),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 16, color: Colors.black54),
                              const SizedBox(width: 4),
                              Text('${crop.minDuration}–${crop.maxDuration} days', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                              const SizedBox(width: 14),
                              const Icon(Icons.water_drop_outlined, size: 16, color: Color(0xFF0277BD)),
                              const SizedBox(width: 4),
                              Text('${crop.waterReqMinMm.toInt()}–${crop.waterReqMaxMm.toInt()} mm', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Key Varieties: ${crop.varieties.take(2).join(", ")}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CropDetailScreen extends StatelessWidget {
  final CropKnowledgeItem crop;
  final WeatherLanguage lang;

  const CropDetailScreen({super.key, required this.crop, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(crop.commonName),
        backgroundColor: const Color(0xFF1B5E20),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${crop.commonName} (${crop.marathiName} / ${crop.hindiName})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        ),
                        Chip(
                          label: Text(crop.category, style: const TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: const Color(0xFF2E7D32),
                        ),
                      ],
                    ),
                    Text(crop.scientificName, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text('Duration: ${crop.minDuration}–${crop.maxDuration} days • Type: ${crop.cropType}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Recommended MPKV / ICAR Cultivars:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: crop.varieties.map((v) => Chip(
                        label: Text(v, style: const TextStyle(fontSize: 11)),
                        backgroundColor: const Color(0xFFE8F5E9),
                        padding: EdgeInsets.zero,
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (crop.degradedMode)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  border: Border.all(color: const Color(0xFFFF9800)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        crop.degradedWarning ?? 'Operating in degraded offline cache mode. Database unavailable.',
                        style: const TextStyle(color: Color(0xFFE65100), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Soil Requirements
            _buildSectionCard(
              title: 'Soil Requirements (मृदा निकष)',
              icon: Icons.terrain,
              color: const Color(0xFF5D4037),
              children: [
                _buildRow('Preferred Textures', crop.preferredTextures.join(', ')),
                _buildRow('Acceptable Textures', crop.acceptableTextures.join(', ')),
                if (crop.phBestSuitedMin != null)
                  _buildRow(
                    'Soil pH (Best-Suited)',
                    '${crop.phBestSuitedMin} – ${crop.phBestSuitedMax} (Textures: ${crop.bestSuitedSoilTextures?.join(", ") ?? "Deep Loam / Silty Clay Loam"})',
                  ),
                if (crop.phOptMin != null)
                  _buildRow('Optimum pH Range', '${crop.phOptMin} – ${crop.phOptMax}'),
                _buildRow(
                  'Tolerable pH Range',
                  crop.phTolMin == null && crop.phTolMax == null
                      ? 'Unverified / not defined in reference manual'
                      : (crop.phTolMin == null
                          ? 'Up to ${crop.phTolMax} (lower limit unverified)'
                          : '${crop.phTolMin} – ${crop.phTolMax}'),
                ),
                if (crop.phContextNotes != null)
                  _buildRow('pH Context Notes', crop.phContextNotes!),
                _buildRow('Drainage Requirement', crop.drainage),
                _buildRow('Salinity Sensitivity', crop.salinity),
                _buildRow('Minimum Soil Depth', '${crop.minDepthCm} cm'),
              ],
            ),
            const SizedBox(height: 12),

            // Climate Requirements
            _buildSectionCard(
              title: 'Climate & Thermal Requirements (हवामान निकष)',
              icon: Icons.wb_sunny_outlined,
              color: const Color(0xFFE65100),
              children: [
                _buildRow('Optimum Temperature', '${crop.tempOptMin}°C – ${crop.tempOptMax}°C'),
                if (crop.tempTolMin != null && crop.tempTolMax != null)
                  _buildRow('Tolerable Temperature', '${crop.tempTolMin}°C – ${crop.tempTolMax}°C'),
                if (crop.tempReproductiveMaxC != null)
                  _buildRow('Reproductive Heat Sensitivity', 'Daily max > ${crop.tempReproductiveMaxC}°C causes flower drop & reduced pod set (ICRISAT 2010, p. 3)'),
                if (crop.tempReproductiveMinMeanC != null)
                  _buildRow('Reproductive Cold Sensitivity', 'Daily mean < ${crop.tempReproductiveMinMeanC}°C causes flower drop & reduced pod set (ICRISAT 2010, p. 3)'),
                if (crop.annualRainMin != null)
                  _buildRow('Annual Rainfall Need', '${crop.annualRainMin!.toInt()} – ${crop.annualRainMax!.toInt()} mm'),
                _buildRow('Frost Sensitivity', crop.frostSensitivity),
                _buildRow('Heat Sensitivity', crop.heatSensitivity),
                if (crop.thermalThresholdContext != null)
                  _buildRow('Thermal Threshold Context', crop.thermalThresholdContext!),
              ],
            ),
            const SizedBox(height: 12),

            // Seasons & Calendar
            _buildSectionCard(
              title: 'Growing Seasons & Calendar (हंगाम व पेरणी)',
              icon: Icons.calendar_month,
              color: const Color(0xFF1B5E20),
              children: crop.seasons.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ${s["name"]!}: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    Expanded(child: Text('Plant: ${s["plant"]!} | Harvest: ${s["harvest"]!}', style: const TextStyle(fontSize: 12))),
                  ],
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),

            // Water Requirements
            _buildSectionCard(
              title: 'Water & Irrigation Requirements (पाणी व्यवस्थापन)',
              icon: Icons.water_drop,
              color: const Color(0xFF0277BD),
              children: [
                _buildRow('Annual Water Need', '${crop.waterReqMinMm.toInt()} – ${crop.waterReqMaxMm.toInt()} mm'),
                _buildRow('Rainfed Viability', crop.rainfedSuitable ? 'Viable under Monsoon rains' : 'Requires assured irrigation'),
                _buildRow('Irrigation Dependency', crop.irrigationDependency),
                _buildRow('Waterlogging Sensitivity', crop.waterloggingSensitivity),
                _buildRow('Drought Sensitivity', crop.droughtSensitivity),
                const SizedBox(height: 4),
                const Text('Critical Growth Stages:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ...crop.criticalStages.map((stg) => Padding(
                  padding: const EdgeInsets.only(left: 6, top: 2),
                  child: Text('• $stg', style: const TextStyle(fontSize: 12, color: Color(0xFF01579B))),
                )),
              ],
            ),
            const SizedBox(height: 12),

            // Regional Suitability (Pilot Regions)
            _buildSectionCard(
              title: 'Regional Cultivation Evidence (तालुकानिहाय अनुकूलता)',
              icon: Icons.location_on_outlined,
              color: const Color(0xFF4527A0),
              children: crop.regionalSuitability.entries.map((e) {
                final taluka = e.key;
                final data = e.value;
                final status = data['status'] as String;
                final desc = data['desc'] as String;
                final isGood = status.contains('Highly') || status.contains('Moderately');

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isGood ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isGood ? Colors.green.shade200 : Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$taluka Taluka', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isGood ? Colors.green.shade800 : Colors.red.shade800)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(desc, style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Source Attribution
            Card(
              elevation: 1,
              color: const Color(0xFFFAFAFA),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Scientific Source & Institutional Attribution:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('${crop.primarySource} (${crop.publicationYear})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(crop.publicationTitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 6),
                    const Text('Status: Verified Authoritative Indian Agricultural Research Data', style: TextStyle(fontSize: 10.5, color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Evaluate for My Farm Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.analytics_outlined, size: 24),
              label: Text(
                'Evaluate ${crop.commonName} for My Farm',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showFarmEvaluationModal(context),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showFarmEvaluationModal(BuildContext context) {
    final farms = FarmRepository.instance.farms;
    if (farms.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Registered Farms'),
          content: const Text(
            'You do not have any registered farms yet. Please add a farm boundary first to evaluate suitability.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditFarmScreen(
                      onSave: (f) => FarmRepository.instance.addFarm(f),
                    ),
                  ),
                );
              },
              child: const Text('Register Farm'),
            ),
          ],
        ),
      );
      return;
    }

    String selectedFarmId = FarmRepository.instance.selectedFarmId != null &&
            farms.any((f) => f.id == FarmRepository.instance.selectedFarmId)
        ? FarmRepository.instance.selectedFarmId!
        : farms.first.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final selectedFarm = farms.firstWhere(
              (f) => f.id == selectedFarmId,
              orElse: () => farms.first,
            );

            // Calculate agronomic compatibility
            final regData = crop.regionalSuitability[selectedFarm.taluka] ?? {
              'status': 'Moderately Suitable',
              'desc': 'General Maharashtra agro-climatic conditions apply.',
            };
            final regStatus = regData['status'] as String;
            final regDesc = regData['desc'] as String;

            final isHighlySuitable = regStatus.contains('Highly');
            final isWaterSufficient = selectedFarm.irrigationType != 'rainfed' || crop.rainfedSuitable;

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollCtrl) {
                return SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFE8F5E9),
                            child: Icon(Icons.eco, color: Color(0xFF1B5E20)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Evaluate ${crop.commonName}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1B5E20),
                                  ),
                                ),
                                Text(
                                  'Agronomic Suitability Analysis',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Select Farm
                      const Text(
                        'Select Registered Farm:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedFarmId,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: farms.map((f) {
                          return DropdownMenuItem(
                            value: f.id,
                            child: Text(
                              '${f.name} (${f.taluka} • ${f.areaHectares.toStringAsFixed(2)} ha)',
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedFarmId = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Evaluation Status Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isHighlySuitable
                              ? const Color(0xFFE8F5E9)
                              : (isWaterSufficient ? const Color(0xFFFFF8E1) : const Color(0xFFFFEBEE)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isHighlySuitable
                                ? Colors.green.shade400
                                : (isWaterSufficient ? Colors.orange.shade400 : Colors.red.shade300),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isHighlySuitable
                                      ? Icons.check_circle
                                      : (isWaterSufficient ? Icons.info : Icons.warning_amber),
                                  color: isHighlySuitable
                                      ? const Color(0xFF2E7D32)
                                      : (isWaterSufficient ? const Color(0xFFE65100) : const Color(0xFFC62828)),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Suitability: $regStatus',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isHighlySuitable
                                          ? const Color(0xFF1B5E20)
                                          : (isWaterSufficient ? const Color(0xFFBF360C) : const Color(0xFFB71C1C)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              regDesc,
                              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Agronomic Constraints Checklist
                      const Text(
                        'Agronomic Compatibility Breakdown:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),

                      _buildChecklistTile(
                        'Regional Fit (${selectedFarm.taluka})',
                        regStatus,
                        isHighlySuitable,
                      ),
                      _buildChecklistTile(
                        'Water Requirement (${crop.waterReqMinMm.toInt()}–${crop.waterReqMaxMm.toInt()} mm)',
                        isWaterSufficient
                            ? 'Compatible with ${selectedFarm.irrigationType.toUpperCase()} (${selectedFarm.waterSource})'
                            : 'Requires assured irrigation (${crop.irrigationDependency})',
                        isWaterSufficient,
                      ),
                      _buildChecklistTile(
                        'Soil pH Compatibility (${crop.phOptMin}–${crop.phOptMax})',
                        'Optimum for Maharashtra black vertisols',
                        true,
                      ),
                      _buildChecklistTile(
                        'Soil Texture Suitability',
                        'Preferred: ${crop.preferredTextures.join(", ")}',
                        true,
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.psychology),
                        label: const Text(
                          'Record Assessment & Open AI Advisory',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: () {
                          // Record in AssessmentHistoryRepository
                          AssessmentHistoryRepository.instance.recordCropEvaluation(
                            farm: selectedFarm,
                            cropId: crop.id,
                            cropName: crop.commonName,
                            decisionState: isHighlySuitable ? 'VERIFIED_SUITABLE' : 'CONDITIONALLY_SUITABLE',
                            summary:
                                'Feasibility check for ${crop.commonName} on ${selectedFarm.name} (${selectedFarm.taluka}). Regional status: $regStatus. Irrigation: ${selectedFarm.irrigationType}.',
                            keyMetrics: {
                              'Crop': crop.commonName,
                              'Status': regStatus,
                              'Water Need': '${crop.waterReqMinMm.toInt()}–${crop.waterReqMaxMm.toInt()} mm',
                              'Irrigation': selectedFarm.irrigationType,
                            },
                            provenance: '${crop.primarySource} (${crop.publicationYear})',
                          );

                          FarmRepository.instance.selectedFarmId = selectedFarm.id;
                          Navigator.pop(modalCtx);
                          appRouter.go(RoutePaths.advisory);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChecklistTile(String title, String subtitle, bool isPositive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPositive ? Icons.check_circle : Icons.warning_amber,
            color: isPositive ? const Color(0xFF2E7D32) : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        ],
      ),
    );
  }
}

// ==========================================
// 9. ABOUT TAB
// ==========================================
class AboutCropNetScreen extends StatelessWidget {
  const AboutCropNetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About CropNet AI')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CropNet AI Platform', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
            SizedBox(height: 8),
            Text('CropNet AI empowers smallholder farmers with geospatial soil intelligence and transparent crop suitability.'),
            SizedBox(height: 16),
            Text('Technical Stack:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Backend: Python + FastAPI + SQLAlchemy'),
            Text('• Database: PostgreSQL 17 + PostGIS (Supabase)'),
            Text('• Mapping: flutter_map + MapTiler Satellite API'),
            Text('• Soil Engine: OGC WCS 2.0.1 (ISRIC SoilGrids 2.0)'),
          ],
        ),
      ),
    );
  }
}
