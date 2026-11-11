import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/router/farm_state.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/utils/browser_geolocation.dart';
import '../../../../core/utils/polygon_validator.dart';
import '../../../../features/farm/models/farm_models.dart' as farm_models;
import '../../../../features/rashkar/data/rashkar_repository.dart';
import '../../../../features/rashkar/models/rashkar_models.dart';
import '../../../../shared/theme/rashkar_colors.dart';
import '../../../../shared/widgets/centered_page_container.dart';
import '../../../../shared/widgets/rashkar_ui.dart';

const String kMapTilerApiKey = "TZ8qXSGUgAKX9HPNbzpO";

/// First-Time Farmer Onboarding Wizard (Specification Part 3).
///
/// Implements a simple, progressive one-question-at-a-time experience for
/// Indian smallholder farmers:
/// - Step 1: Farmer name
/// - Step 2: Farmer age (explaining personalized heat rest schedules)
/// - Step 3: Farm location (GPS or manual taluka selection + interactive map)
/// - Step 4: Farm area (acres)
/// - Step 5: Current crop (visual choices + "I haven't planted anything yet")
/// - Step 6: Crop details (sowing date & irrigation, or Skip)
/// - Finish: "Your farm is ready!" confirmation -> Go to Home
class FarmerOnboardingWizard extends StatefulWidget {
  final VoidCallback? onCompleted;

  const FarmerOnboardingWizard({super.key, this.onCompleted});

  @override
  State<FarmerOnboardingWizard> createState() => _FarmerOnboardingWizardState();
}

class _FarmerOnboardingWizardState extends State<FarmerOnboardingWizard> {
  int _currentStep = 1;
  final int _totalSteps = 6;

  // Step 1: Farmer Name
  final _nameController = TextEditingController();
  final _farmNameController = TextEditingController();

  // Step 2: Age
  final _ageController = TextEditingController(text: '42');
  String _selectedAgeRange = '36-45';

  // Step 3: Location
  final MapController _mapController = MapController();
  final String _selectedState = 'Maharashtra';
  final String _selectedDistrict = 'Pune';
  String _selectedTaluka = 'Baramati';
  String? _village;
  final List<LatLng> _polygonPoints = [];
  LatLng? _gpsLocation;
  bool _isLocatingGps = false;
  String? _gpsStatusMessage;
  PolygonValidationResult? _polygonValidation;
  bool _hasSelfIntersection = false;
  double _calculatedAreaAcres = 0.0;
  double _calculatedAreaSqM = 0.0;

  final Map<String, LatLng> _talukaCenters = {
    'Baramati': const LatLng(18.18, 74.53),
    'Indapur': const LatLng(18.15, 75.05),
    'Maval': const LatLng(18.76, 73.68),
    'Mulshi': const LatLng(18.53, 73.61),
  };

  // Step 4: Farm Area
  final _areaController = TextEditingController(text: '5.0');
  String _areaUnit = 'Acres';

  // Step 5: Current Crop
  String? _selectedCropCode = 'sugarcane'; // null means "not planted yet"
  bool _hasNoCrop = false;

  final List<Map<String, dynamic>> _cropOptions = [
    {'code': 'sugarcane', 'name': 'Sugarcane', 'sub': 'ऊस', 'icon': Icons.grass_rounded},
    {'code': 'soybean', 'name': 'Soybean', 'sub': 'सोयाबीन', 'icon': Icons.grain_rounded},
    {'code': 'cotton', 'name': 'Cotton', 'sub': 'कापूस', 'icon': Icons.cloud_outlined},
    {'code': 'gram', 'name': 'Chickpea / Gram', 'sub': 'हरभरा', 'icon': Icons.spa_outlined},
    {'code': 'onion', 'name': 'Onion', 'sub': 'कांदा', 'icon': Icons.circle_outlined},
    {'code': 'wheat', 'name': 'Wheat', 'sub': 'गहू', 'icon': Icons.agriculture_outlined},
    {'code': 'pomegranate', 'name': 'Pomegranate', 'sub': 'डाळिंब', 'icon': Icons.eco_outlined},
  ];

  // Step 6: Crop Details
  final _sowingDateController = TextEditingController();
  String _irrigationType = 'irrigated';
  String _waterSource = 'canal';

  // Saving state
  bool _isSaving = false;
  bool _isCompleted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final past = DateTime.now().subtract(const Duration(days: 40));
    _sowingDateController.text =
        '${past.year}-${past.month.toString().padLeft(2, '0')}-${past.day.toString().padLeft(2, '0')}';
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _polygonPoints.add(point);
      _validatePolygon();
    });
  }

  void _undoLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
        _validatePolygon();
      });
    }
  }

  void _clearMapPoints() {
    setState(() {
      _polygonPoints.clear();
      _polygonValidation = null;
      _hasSelfIntersection = false;
      _calculatedAreaAcres = 0.0;
      _calculatedAreaSqM = 0.0;
    });
  }

  void _validatePolygon() {
    if (_polygonPoints.length < 3) {
      _polygonValidation = null;
      _hasSelfIntersection = false;
      _calculatedAreaAcres = 0.0;
      _calculatedAreaSqM = 0.0;
      return;
    }

    final val = PolygonValidator.validatePolygon(_polygonPoints);
    _polygonValidation = val;
    _hasSelfIntersection = !val.isValid && (val.errorMessage?.contains('cross') == true);
    if (val.isValid) {
      _calculatedAreaAcres = val.areaAcres;
      _calculatedAreaSqM = val.areaSquareMeters;
      _areaController.text = val.areaAcres.toStringAsFixed(1);
    }
  }

  Future<void> _handleUseMyLocation() async {
    setState(() {
      _isLocatingGps = true;
      _gpsStatusMessage = null;
    });

    try {
      final result = await getLiveBrowserLocation();
      if (!mounted) return;

      if (result.isSuccess) {
        final loc = LatLng(result.latitude, result.longitude);
        setState(() {
          _isLocatingGps = false;
          _gpsLocation = loc;
          final acc = result.accuracy != null ? ' (±${result.accuracy!.round()}m)' : '';
          _gpsStatusMessage = 'GPS found your position$acc. Tap around your field to mark boundary.';
        });
        _mapController.move(loc, 16.0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found location: ${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _isLocatingGps = false;
          _gpsStatusMessage = result.error ?? 'Could not detect GPS location.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text(result.error ?? 'GPS permission denied or unavailable. Please select your taluka below.'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocatingGps = false;
        _gpsStatusMessage = 'Error getting location: $e';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _farmNameController.dispose();
    _ageController.dispose();
    _areaController.dispose();
    _sowingDateController.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      _errorMessage = null;
    });

    if (_currentStep == 1) {
      if (_nameController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please enter your name to continue.');
        return;
      }
      if (_farmNameController.text.trim().isEmpty) {
        _farmNameController.text = "${_nameController.text.trim()}'s Farm";
      }
    } else if (_currentStep == 2) {
      final age = int.tryParse(_ageController.text.trim());
      if (age != null) {
        if (age < 35) {
          _selectedAgeRange = '18-35';
        } else if (age <= 45) {
          _selectedAgeRange = '36-45';
        } else if (age <= 60) {
          _selectedAgeRange = '46-60';
        } else {
          _selectedAgeRange = '60+';
        }
      }
    } else if (_currentStep == 3) {
      if (_polygonPoints.isNotEmpty && _polygonPoints.length < 3) {
        setState(() => _errorMessage = 'Please tap at least 3 points on the map to outline your farm boundary, or tap Reset.');
        return;
      }
      if (_polygonPoints.length >= 3) {
        final val = PolygonValidator.validatePolygon(_polygonPoints);
        if (!val.isValid) {
          setState(() => _errorMessage = val.errorMessage ?? 'Boundary lines cannot cross each other. Please tap Undo Point to fix.');
          return;
        }
        _calculatedAreaAcres = val.areaAcres;
        _calculatedAreaSqM = val.areaSquareMeters;
        _areaController.text = val.areaAcres.toStringAsFixed(1);
      }
    } else if (_currentStep == 4) {
      final area = double.tryParse(_areaController.text.trim());
      if (area == null || area <= 0) {
        setState(() => _errorMessage = 'Please enter a valid land size.');
        return;
      }
    } else if (_currentStep == 5) {
      if (!_hasNoCrop && _selectedCropCode == null) {
        setState(() => _errorMessage = 'Please choose a crop or select "I have not planted yet".');
        return;
      }
      if (_hasNoCrop) {
        // Skip step 6 if no crop planted
        _submitRegistration();
        return;
      }
    }

    if (_currentStep < _totalSteps) {
      setState(() => _currentStep++);
    } else {
      _submitRegistration();
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() {
        _errorMessage = null;
        _currentStep--;
      });
    }
  }

  Future<void> _submitRegistration() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_polygonPoints.length < 3) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Please mark at least 3 points on the map to outline your farm boundary.';
        });
        return;
      }

      final validation = PolygonValidator.validatePolygon(_polygonPoints);
      if (!validation.isValid) {
        setState(() {
          _isSaving = false;
          _errorMessage = validation.errorMessage ?? 'Invalid polygon boundary geometry.';
        });
        return;
      }

      final areaAcres = double.tryParse(_areaController.text.trim()) ?? validation.areaAcres;

      // Ensure closed, valid GeoJSON ring with [lon, lat] pairs (EPSG:4326)
      final List<List<double>> ring = PolygonValidator.toClosedGeoJsonRing(_polygonPoints);
      final geometry = farm_models.GeoJsonPolygon(coordinates: [ring]);

      final farmName = _farmNameController.text.trim().isNotEmpty
          ? _farmNameController.text.trim()
          : "${_nameController.text.trim()}'s Farm";

      final payload = farm_models.FarmCreate(
        name: farmName,
        village: _village?.trim().isNotEmpty == true ? _village!.trim() : 'Central Village',
        taluka: _selectedTaluka,
        district: _selectedDistrict,
        state: _selectedState,
        irrigationType: _irrigationType,
        waterSource: _waterSource,
        geometry: geometry,
      );

      // 1. Create farm via FarmRepository
      final savedFarm = await FarmRepository.instance.createFarm(payload);

      // 2. Save Shared Farmer Profile & Resource Profile
      final farmerName = _nameController.text.trim();
      final waterEnum = (_waterSource == 'borewell' || _waterSource == 'canal')
          ? 'seasonal_canal'
          : (_irrigationType == 'irrigated' ? 'reliable_year_round' : 'rainfed_limited');

      await RashkarRepository.instance.updateSharedContext(
        savedFarm.id,
        farmerProfile: SharedFarmerProfile(
          fullName: farmerName,
          ageRange: _selectedAgeRange,
          workPreference: 'daily_physical',
          defaultWorkloadCategory: 'moderate',
          defaultSunExposure: 'direct_sun',
        ),
        resourceProfile: FarmerResourceProfile(
          farmId: savedFarm.id,
          availableInvestmentInr: 25000.0,
          totalFarmAcres: areaAcres,
          waterAvailability: waterEnum,
          familyLaborHoursDay: 2.5,
          ageRange: _selectedAgeRange,
          workPreference: 'daily_physical',
          currentCropCode: !_hasNoCrop ? _selectedCropCode : null,
        ),
      );

      // 3. Save Active Crop Cycle if planted
      if (!_hasNoCrop && _selectedCropCode != null) {
        await RashkarRepository.instance.createCropCycle(
          savedFarm.id,
          plotName: 'Main Plot',
          cropCode: _selectedCropCode!,
          season: 'rabi',
          sowingDate: _sowingDateController.text.trim().isNotEmpty
              ? _sowingDateController.text.trim()
              : '2025-10-15',
          plantedAreaAcres: areaAcres,
          irrigationType: _irrigationType,
        );
      }

      FarmRepository.instance.selectedFarmId = savedFarm.id;

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isCompleted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Could not save farm details: $e';
        });
      }
    }
  }

  void _finishAndGoHome() {
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    } else {
      context.go(RoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCompleted) {
      return _buildCompletionScreen();
    }

    return Scaffold(
      backgroundColor: RashkarColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _currentStep > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: RashkarColors.ink),
                onPressed: _previousStep,
                tooltip: 'Back to previous question',
              )
            : null,
        title: Text(
          'Step $_currentStep of $_totalSteps',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: RashkarColors.mutedInk,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: CenteredPageContainer(
          maxWidth: 580,
          scrollable: true,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Subtle Step Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _currentStep / _totalSteps,
                  backgroundColor: RashkarColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(RashkarColors.forestTint),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 28),

              // Active Question Card
              RashkarCard(
                padding: const EdgeInsets.all(26),
                child: _buildCurrentQuestion(),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDEDEC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF5B7B1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFC0392B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF922B21)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Large Primary Action Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RashkarColors.forestTint,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : Text(
                          _currentStep == _totalSteps ? 'Finish & Save Farm' : 'Continue',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),

              // Skip option for optional steps (Step 6)
              if (_currentStep == 6) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _isSaving ? null : _submitRegistration,
                  child: const Text(
                    'I don’t know / Skip for now',
                    style: TextStyle(color: RashkarColors.mutedInk, fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentQuestion() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Name();
      case 2:
        return _buildStep2Age();
      case 3:
        return _buildStep3Location();
      case 4:
        return _buildStep4Area();
      case 5:
        return _buildStep5Crop();
      case 6:
        return _buildStep6Details();
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1: Farmer Name
  Widget _buildStep1Name() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What is your name?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: RashkarColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'We use this to address you and keep your farm recommendations organized.',
          style: TextStyle(fontSize: 14, color: RashkarColors.mutedInk),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: RashkarColors.ink),
          decoration: InputDecoration(
            labelText: 'Your Full Name',
            hintText: 'e.g. Ramesh Patil',
            prefixIcon: const Icon(Icons.person_outline_rounded, color: RashkarColors.forestTint),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: RashkarColors.forestTint, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _farmNameController,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 15, color: RashkarColors.ink),
          decoration: InputDecoration(
            labelText: 'Farm Nickname (Optional)',
            hintText: 'e.g. Patil Sugarcane Plot',
            prefixIcon: const Icon(Icons.agriculture_outlined, color: RashkarColors.mutedInk),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // STEP 2: Age
  Widget _buildStep2Age() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How old are you?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: RashkarColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your age helps us personalize worker heat safety, hydration alerts, and rest intervals during hot afternoons.',
          style: TextStyle(fontSize: 14, color: RashkarColors.mutedInk, height: 1.4),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _ageController,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: RashkarColors.ink),
          decoration: InputDecoration(
            labelText: 'Age in years',
            hintText: 'e.g. 42',
            suffixText: 'Years',
            prefixIcon: const Icon(Icons.calendar_today_outlined, color: RashkarColors.forestTint),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: RashkarColors.forestTint, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: ['18-35', '36-45', '46-60', '60+'].map((range) {
            final isSel = _selectedAgeRange == range;
            return ChoiceChip(
              label: Text(range),
              selected: isSel,
              selectedColor: RashkarColors.forestTint.withValues(alpha: 0.18),
              labelStyle: TextStyle(
                color: isSel ? RashkarColors.forestTint : RashkarColors.ink,
                fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
              ),
              onSelected: (_) {
                setState(() {
                  _selectedAgeRange = range;
                  if (range == '18-35') _ageController.text = '28';
                  if (range == '36-45') _ageController.text = '42';
                  if (range == '46-60') _ageController.text = '52';
                  if (range == '60+') _ageController.text = '65';
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // STEP 3: Location
  Widget _buildStep3Location() {
    final center = _gpsLocation ?? _talukaCenters[_selectedTaluka] ?? const LatLng(18.18, 74.53);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Where is your farm?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: RashkarColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Use GPS or select your taluka, then tap the corners of your field on the map to outline your farm.',
          style: TextStyle(fontSize: 14, color: RashkarColors.mutedInk, height: 1.4),
        ),
        const SizedBox(height: 16),

        // Action Buttons: Live GPS vs Select Taluka
        Row(
          children: [
            Expanded(
              flex: 3,
              child: OutlinedButton.icon(
                icon: _isLocatingGps
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: RashkarColors.forestTint),
                      )
                    : Icon(
                        Icons.my_location_rounded,
                        size: 18,
                        color: _gpsLocation != null ? RashkarColors.forestTint : RashkarColors.ink,
                      ),
                label: Text(_isLocatingGps ? 'Locating...' : 'Use My Location'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _gpsLocation != null ? RashkarColors.forestTint : RashkarColors.ink,
                  side: BorderSide(
                    color: _gpsLocation != null ? RashkarColors.forestTint : RashkarColors.border,
                    width: _gpsLocation != null ? 2 : 1,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _isLocatingGps ? null : _handleUseMyLocation,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedTaluka,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  labelText: 'Taluka',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _talukaCenters.keys.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedTaluka = val;
                    });
                    final newCenter = _talukaCenters[val]!;
                    _mapController.move(newCenter, 15.0);
                  }
                },
              ),
            ),
          ],
        ),

        if (_gpsStatusMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (_gpsLocation != null ? Colors.blue : Colors.orange).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (_gpsLocation != null ? Colors.blue : Colors.orange).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _gpsLocation != null ? Icons.place_rounded : Icons.info_outline,
                  size: 16,
                  color: _gpsLocation != null ? Colors.blue.shade700 : Colors.orange.shade800,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _gpsStatusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _gpsLocation != null ? Colors.blue.shade900 : Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Interactive Map with Drawing Controls (CropNet MapTiler Satellite Map)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 380,
            decoration: BoxDecoration(
              border: Border.all(
                color: _hasSelfIntersection
                    ? Colors.redAccent
                    : (_polygonPoints.length >= 3 ? RashkarColors.marigold : RashkarColors.border),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 16.0,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://api.maptiler.com/maps/satellite/{z}/{x}/{y}.jpg?key=$kMapTilerApiKey',
                      userAgentPackageName: 'com.cropnet.cropnet_mobile',
                      maxZoom: 19,
                    ),
                    if (_polygonPoints.length >= 3)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _polygonPoints,
                            color: _hasSelfIntersection
                                ? Colors.redAccent.withValues(alpha: 0.25)
                                : const Color(0x55214E34),
                            borderColor: _hasSelfIntersection
                                ? Colors.redAccent
                                : RashkarColors.marigold,
                            borderStrokeWidth: 3.0,
                          ),
                        ],
                      ),
                    if (_polygonPoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [..._polygonPoints, _polygonPoints.first],
                            color: _hasSelfIntersection
                                ? Colors.redAccent
                                : RashkarColors.highBar,
                            strokeWidth: 2.5,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (_gpsLocation != null)
                          Marker(
                            point: _gpsLocation!,
                            width: 32,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.withValues(alpha: 0.25),
                              ),
                              child: const Icon(
                                Icons.my_location_rounded,
                                color: Colors.blueAccent,
                                size: 24,
                              ),
                            ),
                          ),
                        ..._polygonPoints.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final pt = entry.value;
                          final isIntersecting = _hasSelfIntersection;
                          return Marker(
                            point: pt,
                            width: 24,
                            height: 24,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isIntersecting
                                    ? Colors.redAccent
                                    : (idx == 0 ? RashkarColors.forest : RashkarColors.marigold),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    color: isIntersecting || idx == 0 ? Colors.white : RashkarColors.ink,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),

                // Top Floating Banner (Teammate's exact design)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _hasSelfIntersection
                          ? const Color(0xEEB71C1C)
                          : RashkarColors.forestDark.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hasSelfIntersection
                              ? Icons.warning_amber_rounded
                              : (_polygonPoints.length < 3 ? Icons.touch_app_rounded : Icons.check_circle_rounded),
                          color: _hasSelfIntersection
                              ? Colors.white
                              : (_polygonPoints.length < 3 ? RashkarColors.marigold : const Color(0xFF9DE3B3)),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _hasSelfIntersection
                                ? 'Self-intersecting boundary (lines cross!)'
                                : (_polygonPoints.length < 3
                                    ? 'Tap/click map to add vertices (${3 - _polygonPoints.length} more needed for boundary)'
                                    : 'Boundary: ${(_calculatedAreaSqM / 10000.0).toStringAsFixed(2)} ha (${_calculatedAreaAcres.toStringAsFixed(2)} ac) • ${_polygonPoints.length} vertices'),
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (_polygonPoints.isNotEmpty) ...[
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: RashkarColors.marigold,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.undo_rounded, size: 16),
                            label: const Text('Undo Point', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            onPressed: _undoLastPoint,
                          ),
                          const SizedBox(width: 6),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFFB4AB),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            onPressed: _clearMapPoints,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Bottom Right GPS Centering Button
                Positioned(
                  bottom: 14,
                  right: 14,
                  child: FloatingActionButton.small(
                    backgroundColor: RashkarColors.surface,
                    foregroundColor: RashkarColors.forest,
                    onPressed: _handleUseMyLocation,
                    tooltip: 'Capture GPS Location',
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Live Guidance & Validation Feedback below Map
        if (_hasSelfIntersection)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Boundary lines cannot cross each other. Please tap "Undo Point" to fix.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_polygonPoints.length >= 3 && _polygonValidation?.isValid == true)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: RashkarColors.forestTint.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: RashkarColors.forestTint.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: RashkarColors.forestTint, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your farm is about ${_calculatedAreaAcres.toStringAsFixed(1)} acres (${_calculatedAreaSqM.round()} sq. m)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: RashkarColors.forestTint,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_polygonPoints.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app_outlined, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Marked ${_polygonPoints.length} point${_polygonPoints.length == 1 ? '' : 's'}. Tap ${3 - _polygonPoints.length} more corner${_polygonPoints.length == 1 ? 's' : ''} to complete your farm boundary.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          )
        else
          const Row(
            children: [
              Icon(Icons.touch_app_outlined, size: 16, color: RashkarColors.mutedInk),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tap corners around your field on the map to outline your farm boundary.',
                  style: TextStyle(fontSize: 12, color: RashkarColors.mutedInk),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // STEP 4: Farm Area
  Widget _buildStep4Area() {
    final bool hasBoundary = _polygonPoints.length >= 3 && !_hasSelfIntersection;
    final areaAcres = hasBoundary
        ? _calculatedAreaAcres
        : (double.tryParse(_areaController.text.trim()) ?? 5.0);
    final areaSqM = hasBoundary
        ? _calculatedAreaSqM
        : (areaAcres / 2.4710538 * 10000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasBoundary ? 'Farm Land Size Confirmed' : 'How much land do you have?',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: RashkarColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasBoundary
              ? 'Your farm area was calculated directly from your map boundary.'
              : 'Enter your total cultivated area. This calculates required water, seed quantity, and extra income potential.',
          style: const TextStyle(fontSize: 14, color: RashkarColors.mutedInk, height: 1.4),
        ),
        const SizedBox(height: 18),

        if (hasBoundary) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RashkarColors.forestTint.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RashkarColors.forestTint.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: RashkarColors.forestTint.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: RashkarColors.forestTint, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your farm is about ${areaAcres.toStringAsFixed(1)} acres',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: RashkarColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Approx. ${areaSqM.round()} square metres (${(areaSqM / 10000).toStringAsFixed(2)} hectares)',
                        style: const TextStyle(fontSize: 13, color: RashkarColors.mutedInk),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This area is automatically linked to your farm record. If you only cultivate part of this plot, you can adjust the number below:',
            style: TextStyle(fontSize: 13, color: RashkarColors.mutedInk),
          ),
          const SizedBox(height: 12),
        ],

        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _areaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: RashkarColors.ink),
                decoration: InputDecoration(
                  labelText: hasBoundary ? 'Cultivated Area' : 'Total Area',
                  hintText: 'e.g. 5.0',
                  prefixIcon: const Icon(Icons.aspect_ratio_rounded, color: RashkarColors.forestTint),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: RashkarColors.forestTint, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _areaUnit,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'Acres', child: Text('Acres')),
                  DropdownMenuItem(value: 'Gunthas', child: Text('Gunthas')),
                  DropdownMenuItem(value: 'Hectares', child: Text('Hectares')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _areaUnit = val);
                },
              ),
            ),
          ],
        ),

        if (!hasBoundary) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                _areaController.text = '5.0';
                _nextStep();
              },
              child: const Text('Skip for now (5 acres default)'),
            ),
          ),
        ],
      ],
    );
  }

  // STEP 5: Current Crop
  Widget _buildStep5Crop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What are you growing?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: RashkarColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select your main active crop in the field today.',
          style: TextStyle(fontSize: 14, color: RashkarColors.mutedInk),
        ),
        const SizedBox(height: 18),

        // List of common Maharashtra crops
        ..._cropOptions.map((crop) {
          final isSel = !_hasNoCrop && _selectedCropCode == crop['code'];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSel ? RashkarColors.forestTint.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSel ? RashkarColors.forestTint : RashkarColors.border,
                width: isSel ? 2 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Icon(crop['icon'] as IconData, color: isSel ? RashkarColors.forestTint : RashkarColors.mutedInk),
                title: Text(
                  crop['name'] as String,
                  style: TextStyle(
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: isSel ? RashkarColors.forestTint : RashkarColors.ink,
                  ),
                ),
                subtitle: Text(crop['sub'] as String, style: const TextStyle(fontSize: 12, color: RashkarColors.mutedInk)),
                trailing: isSel ? const Icon(Icons.check_circle_rounded, color: RashkarColors.forestTint) : null,
                onTap: () {
                  setState(() {
                    _hasNoCrop = false;
                    _selectedCropCode = crop['code'] as String;
                  });
                },
              ),
            ),
          );
        }),

        const SizedBox(height: 6),

        // Valid option: "I haven't planted anything yet"
        Container(
          decoration: BoxDecoration(
            color: _hasNoCrop ? RashkarColors.marigoldTint.withValues(alpha: 0.3) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasNoCrop ? RashkarColors.marigoldInk : RashkarColors.border,
              width: _hasNoCrop ? 2 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              leading: Icon(Icons.nature_people_outlined, color: _hasNoCrop ? RashkarColors.marigoldInk : RashkarColors.mutedInk),
              title: Text(
                'I haven’t planted anything yet',
                style: TextStyle(
                  fontWeight: _hasNoCrop ? FontWeight.w800 : FontWeight.w600,
                  color: _hasNoCrop ? RashkarColors.marigoldInk : RashkarColors.ink,
                ),
              ),
              subtitle: const Text('Field is currently resting or preparing for next season', style: TextStyle(fontSize: 12)),
              trailing: _hasNoCrop ? const Icon(Icons.check_circle_rounded, color: RashkarColors.marigoldInk) : null,
              onTap: () {
                setState(() {
                  _hasNoCrop = true;
                  _selectedCropCode = null;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // STEP 6: Crop Details (Sowing & Irrigation)
  Widget _buildStep6Details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Crop Details',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: RashkarColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Approximate sowing date and water source help us predict your heat-sensitive flowering and harvest window.',
          style: TextStyle(fontSize: 14, color: RashkarColors.mutedInk, height: 1.4),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _sowingDateController,
          decoration: InputDecoration(
            labelText: 'Sowing / Planting Date (YYYY-MM-DD)',
            hintText: 'e.g. 2025-10-15',
            prefixIcon: const Icon(Icons.event_outlined, color: RashkarColors.forestTint),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          initialValue: _waterSource,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Water Source',
            prefixIcon: const Icon(Icons.water_drop_outlined, color: RashkarColors.forestTint),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: 'canal', child: Text('Canal Water (कालवा)')),
            DropdownMenuItem(value: 'borewell', child: Text('Borewell / Tube well (बोअरवेल)')),
            DropdownMenuItem(value: 'well', child: Text('Open Well (विहीर)')),
            DropdownMenuItem(value: 'river', child: Text('River / Stream (नदी)')),
            DropdownMenuItem(value: 'rainfed', child: Text('Rainfed Only / No Irrigation (कोरडवाहू)')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _waterSource = val;
                _irrigationType = val == 'rainfed' ? 'rainfed' : 'irrigated';
              });
            }
          },
        ),
      ],
    );
  }

  // COMPLETION SCREEN
  Widget _buildCompletionScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CenteredPageContainer(
          maxWidth: 520,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: RashkarColors.forestTint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: RashkarColors.forestTint,
                    size: 52,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Your farm is ready!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: RashkarColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome, ${_nameController.text.trim()}! Your farm details have been registered into Rashkar.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: RashkarColors.mutedInk, height: 1.4),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _finishAndGoHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RashkarColors.forestTint,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Go to Home',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
