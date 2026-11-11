import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:cropnet_mobile/features/rashkar/data/rashkar_repository.dart';
import 'package:cropnet_mobile/features/rashkar/models/rashkar_models.dart';
import 'package:cropnet_mobile/features/rashkar/presentation/screens/extra_income_screen.dart';
import 'package:cropnet_mobile/features/rashkar/presentation/screens/risk_hub_screen.dart';
import 'package:cropnet_mobile/main.dart';

FarmItem _makeTestFarm({String id = 'farm-baramati-1', String name = 'Baramati Sugarcane Farm'}) => FarmItem(
      id: id,
      name: name,
      taluka: 'Baramati',
      district: 'Pune',
      village: 'Malegaon',
      polygonPoints: [
        const LatLng(18.175, 74.525),
        const LatLng(18.175, 74.535),
        const LatLng(18.185, 74.535),
      ],
      areaHectares: 1.0,
      areaAcres: 2.47,
      centroid: const LatLng(18.18, 74.53),
      createdAt: DateTime(2025, 6, 1),
    );

class _FakeRashkarRepository implements RashkarRepository {
  bool workerMissingTriggered = false;
  bool cropMissingTriggered = false;
  bool incomeProfileMissing = false;

  String? lastWorkerWorkloadSaved;
  String? lastConfirmedCropStage;
  FarmerResourceProfile? lastSavedResourceProfile;
  final List<SavedIncomePlan> savedPlans = [];

  @override
  Future<SharedFarmContext> getSharedContext(String farmId) async {
    return SharedFarmContext(
      farmId: farmId,
      farmName: 'Baramati Sugarcane Farm',
      taluka: 'Baramati',
      district: 'Pune',
      state: 'Maharashtra',
      village: 'Malegaon',
      latitude: 18.18,
      longitude: 74.53,
      totalAreaAcres: 2.47,
      totalAreaHectares: 1.0,
      irrigationType: 'irrigated',
      waterSource: 'canal',
      farmerProfile: SharedFarmerProfile(
        farmerId: 'farmer-1',
        fullName: workerMissingTriggered ? null : 'Ramesh Kulkarni',
        phoneNumber: '+91-9876543210',
        ageRange: '36-45',
        workPreference: 'daily_physical',
        defaultWorkloadCategory: lastWorkerWorkloadSaved ?? 'moderate',
        defaultSunExposure: 'direct_sun',
        defaultIsAcclimatised: true,
        defaultExposureDurationHours: 3.0,
      ),
      plots: const [
        FarmPlotRecord(plotId: 'plot-1', farmId: 'farm-baramati-1', plotName: 'Plot A', areaAcres: 2.47),
      ],
      cropCycles: cropMissingTriggered
          ? const []
          : [
              CropCycleRecord(
                cycleId: 'cycle-1',
                plotId: 'plot-1',
                plotName: 'Plot A',
                farmId: farmId,
                cropCode: 'soybean',
                season: 'kharif',
                sowingDate: '2026-06-15',
                plantedAreaAcres: 2.47,
                currentStageCode: lastConfirmedCropStage ?? 'stage_flowering',
              ),
            ],
      resourceProfile: SharedResourceProfileDTO(
        farmId: farmId,
        farmerId: 'farmer-1',
        profileCompleted: !incomeProfileMissing,
        missingFields: incomeProfileMissing ? const ['available_investment_inr'] : const [],
        availableInvestmentInr: lastSavedResourceProfile?.availableInvestmentInr ?? 5000.0,
        availableLandAcres: 0.5,
        waterAvailability: 'seasonal_canal',
        familyLaborHoursDay: 2.5,
        ageRange: '36-45',
        workPreference: 'daily_physical',
        paybackHorizon: 'within_6_months',
        cropByproducts: const ['soybean_straw'],
      ),
    );
  }

  @override
  Future<SharedFarmContext> updateSharedContext(
    String farmId, {
    SharedFarmerProfile? farmerProfile,
    FarmerResourceProfile? resourceProfile,
  }) async {
    workerMissingTriggered = false;
    if (farmerProfile?.defaultWorkloadCategory != null) {
      lastWorkerWorkloadSaved = farmerProfile!.defaultWorkloadCategory;
    }
    return getSharedContext(farmId);
  }

  @override
  Future<FarmPlotRecord> createPlot(
    String farmId, {
    required String plotName,
    required double areaAcres,
    String? irrigationType,
  }) async {
    return FarmPlotRecord(plotId: 'plot-new', farmId: farmId, plotName: plotName, areaAcres: areaAcres);
  }

  @override
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
  }) async {
    cropMissingTriggered = false;
    return CropCycleRecord(
      cycleId: 'cycle-created-1',
      plotId: plotId ?? 'plot-1',
      plotName: plotName,
      farmId: farmId,
      cropCode: cropCode,
      season: season,
      sowingDate: sowingDate,
      plantedAreaAcres: plantedAreaAcres ?? 2.0,
      currentStageCode: farmerConfirmedStage ?? 'stage_vegetative',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getSupportedHeatCrops() async {
    return const [
      {'crop_code': 'soybean', 'common_name_en': 'Soybean'},
      {'crop_code': 'sugarcane', 'common_name_en': 'Sugarcane'},
    ];
  }

  @override
  Future<WorkerHeatResponse> assessWorkerHeat(
    String farmId, {
    String? workloadCategory,
    String? clothingType,
    bool? isAcclimatised,
    String? sunExposure,
    double? exposureDurationHours,
    bool saveAsDefault = true,
  }) async {
    if (workerMissingTriggered) {
      throw const MissingSharedContextException(
        code: 'MISSING_WORKER_CONTEXT',
        message: 'Farmer full name is required before assessing worker heat risk.',
        missingFields: ['farmer_profile.full_name'],
      );
    }
    final wl = workloadCategory ?? lastWorkerWorkloadSaved ?? 'moderate';
    if (saveAsDefault && workloadCategory != null) {
      lastWorkerWorkloadSaved = workloadCategory;
    }
    return WorkerHeatResponse(
      farmLocationDisplay: 'Baramati, Pune',
      currentAirTempC: 37.5,
      currentRelativeHumidityPct: 38.0,
      currentWbgtEstimatedC: wl == 'heavy' ? 30.8 : 28.4,
      currentHazardLevel: wl == 'heavy' ? 'HIGH' : 'MODERATE',
      maxHazardLevelInWindow: 'HIGH',
      peakRiskHourIst: '14:00 IST',
      categorySelectionReason: 'WBGT assessed for $wl workload in open agricultural plot.',
      workloadCategory: wl,
      hourlyProjections: [
        WorkerHourlyProjection(
          forecastHourOffset: 0,
          validTimeIst: '12:00 IST',
          airTempC: 36.5,
          relativeHumidityPct: 40.0,
          windSpeedMs: 2.0,
          solarIrradianceWm2: 750.0,
          wbgtEstimatedC: 28.4,
          wbgtEffectiveC: 28.4,
          hazardLevel: 'MODERATE',
          exceedsScreeningThreshold: false,
          thresholdLimitC: 28.0,
          trend: 'RISING',
          workRestCycle: '45 min work / 15 min rest',
        ),
      ],
    );
  }

  @override
  Future<CropHeatAssessment> assessCropHeat(
    String farmId, {
    String? plotId,
    String? cycleId,
    String? farmerConfirmedStage,
    double? forecastTmaxC,
    double? forecastTminC,
  }) async {
    if (cropMissingTriggered) {
      throw const MissingSharedContextException(
        code: 'MISSING_CROP_CONTEXT',
        message: 'Register crop species and sowing date for Crop Heat Risk.',
        missingFields: ['crop_cycles'],
      );
    }
    final stage = farmerConfirmedStage ?? lastConfirmedCropStage ?? 'stage_flowering';
    lastConfirmedCropStage = stage;
    final isPodFill = stage == 'stage_pod_fill';

    return CropHeatAssessment(
      assessmentId: 'crop-assess-1',
      farmId: farmId,
      farmName: 'Baramati Sugarcane Farm',
      plotName: 'Plot A',
      cropCode: 'soybean',
      cropCommonName: 'Soybean',
      sowingDate: '2026-06-15',
      daysAfterSowing: 45,
      cropAreaAcres: 2.47,
      irrigationStatus: 'irrigated',
      soilTexture: 'Vertisol',
      // Explicitly verify null/empty display string never leaks 'null' literal in UI
      growthStageCode: stage,
      growthStageNameEn: isPodFill ? 'Pod Filling' : 'null',
      supportedStages: const [
        {'stage_code': 'stage_flowering', 'stage_name_en': 'Flowering', 'crit_tmax': 35.0},
        {'stage_code': 'stage_pod_fill', 'stage_name_en': 'Pod Filling', 'crit_tmax': 33.5},
      ],
      farmerConfirmedStage: stage,
      baseTempC: 10.0,
      optimalTempMinC: 24.0,
      optimalTempMaxC: 30.0,
      criticalTmaxThresholdC: isPodFill ? 33.5 : 35.0,
      criticalTminThresholdC: 22.0,
      tmaxForecastC: 36.2,
      tminForecastC: 23.0,
      hoursAboveCritical: 4.5,
      consecutiveHotDays: 2,
      daytimeExposureHours: 5.0,
      warmNightRespirationHazard: true,
      warmNightPenaltyScore: 18.0,
      cumulativeHeatUnitsGdd: 520.0,
      evidenceCitation: 'ICAR-IISR Soybean Heat Physiology Bulletin',
      evidenceStatus: 'VERIFIED_PUBLISHED',
      daytimeHeatStressLevel: 'high',
      overallCropHeatRisk: isPodFill ? 'CRITICAL' : 'HIGH',
      physiologicalMechanism: isPodFill ? 'Seed abortion and pod shattering' : 'Pollen viability drop',
      dailyOutlook: [
        CropDailyOutlook(
          date: '2026-07-01',
          dayLabel: 'Today',
          tmaxC: 36.2,
          tminC: 23.0,
          hoursAboveCritical: 4.5,
          riskCategory: isPodFill ? 'CRITICAL' : 'HIGH',
          explanation: 'Afternoon canopy heat stress during reproductive phase.',
        ),
      ],
      recommendedInterventions: [
        CropHeatIntervention(
          interventionId: 'int-1',
          titleEn: 'Light Evening Furrow Irrigation',
          titleMr: '',
          descriptionEn: 'Apply light irrigation before peak noon heat to cool root zone.',
          descriptionMr: '',
          whyAppropriate: 'Evaporative cooling reduces canopy temperature by 2-3°C.',
          evidenceCitation: 'MPKV Rahuri Advisory',
          category: 'IRRIGATION_COOLING',
        ),
      ],
    );
  }

  @override
  Future<SharedResourceProfileDTO> getFarmResourceProfile(String farmId) async {
    return SharedResourceProfileDTO(
      farmId: farmId,
      farmerId: 'farmer-1',
      profileCompleted: !incomeProfileMissing,
      missingFields: incomeProfileMissing ? const ['available_investment_inr'] : const [],
      availableInvestmentInr: lastSavedResourceProfile?.availableInvestmentInr ?? 5000.0,
      availableLandAcres: 0.5,
      waterAvailability: 'seasonal_canal',
      familyLaborHoursDay: 2.5,
      ageRange: '36-45',
      workPreference: 'daily_physical',
      paybackHorizon: 'within_6_months',
      cropByproducts: const ['soybean_straw'],
    );
  }

  @override
  Future<SharedResourceProfileDTO> saveFarmResourceProfile(String farmId, FarmerResourceProfile profile) async {
    incomeProfileMissing = false;
    lastSavedResourceProfile = profile;
    return getFarmResourceProfile(farmId);
  }

  @override
  Future<List<ScoredOpportunityItem>> discoverFarmOpportunities(
    String farmId, {
    FarmerResourceProfile? overrideProfile,
  }) async {
    return [
      ScoredOpportunityItem(
        opportunity: IncomeOpportunity(
          opportunityId: 'OPP_COMPOST_COST_SAVING_01',
          title: 'On-Farm NADEP Residue Composting',
          category: 'zero_cash',
          isCostSaving: true,
          tagline: 'Turn soybean straw into input savings with ₹0 extra cash',
          minInvestmentInr: 0.0,
          maxInvestmentInr: 0.0,
          requiredLandAcres: 0.0,
          requiredSpaceType: 'bund',
          waterRequirement: 'low',
          dailyLaborHours: 1.0,
          paybackPeriodMonths: 3,
          potentialAnnualProfitInr: 0.0,
          potentialAnnualSavingsInr: 8700.0,
          riskLevel: 'low',
          summary: 'Converts surplus farm biomass into cured compost replacing bagged fertiliser.',
          keyAssumptions: const ['Uses surplus 50% residue after fodder reserve'],
          keyRisks: const ['Maintain pit moisture every 15 days'],
          sourceAttribution: 'MPKV Rahuri / NABARD Model',
        ),
        suitabilityScorePct: 92,
        isSuitable: true,
        suitabilityVerdict: 'High Fit',
        reasonsWhySuitable: const ['Zero extra cash needed', 'Residue available'],
        reasonsWhyUnsuitable: const [],
        feasibilityStatus: 'FEASIBLE_NOW',
        matchingResources: const ['Residue & family labor available'],
        farmerSummaryQa: const {
          'what_is_it': 'Biomass composting unit',
          'why_suits_my_farm': 'Uses existing soybean straw',
          'what_will_i_need': '₹0 extra cash and 1 hr/day family labor',
          'how_will_i_earn_or_save': 'Saves ₹8,700/year in fertilizer costs',
          'when_will_i_receive_money': 'Within 3 months at next sowing dose',
          'what_to_be_careful_about': 'Reserve 50% straw for cattle feed first',
        },
      ),
    ];
  }

  @override
  Future<IncomeScenario> calculateIncomeScenario({
    required String opportunityId,
    required double customBudgetInr,
    double labourHours = 2.0,
    double landAcres = 0.0,
    String waterAvailability = 'seasonal_canal',
  }) async {
    return IncomeScenario(
      opportunityId: opportunityId,
      opportunityTitle: 'On-Farm NADEP Residue Composting',
      category: 'zero_cash',
      isCostSaving: true,
      customBudgetInr: customBudgetInr,
      calculatedCapexInr: 0.0,
      calculatedOpexAnnualInr: 500.0,
      calculatedGrossRevenueInr: 0.0,
      calculatedAnnualSavingsInr: 8700.0,
      calculatedNetProfitAnnualInr: 8200.0,
      calculatedBreakEvenMonths: 3.0,
      assumptionsApplied: const ['50% residue feed reserve deducted'],
      risksToMonitor: const ['Moisture loss in peak summer'],
      sourceAttribution: 'MPKV Rahuri',
      disclaimer: 'Planning estimates only.',
      scenarios: {
        'conservative': FinancialScenarioDetail(
          name: 'conservative',
          priceAssumption: 'Conservative replacement',
          costAssumption: 'Higher labor',
          grossAnnualRevenueInr: 0.0,
          netAnnualProfitInr: 6200.0,
          annualOpexInr: 500.0,
          breakEvenMonths: 4.0,
          monthlyNetCashFlowInr: List.filled(12, 500.0),
        ),
        'base': FinancialScenarioDetail(
          name: 'base',
          priceAssumption: 'Standard replacement',
          costAssumption: 'Normal',
          grossAnnualRevenueInr: 0.0,
          netAnnualProfitInr: 8200.0,
          annualOpexInr: 500.0,
          breakEvenMonths: 3.0,
          monthlyNetCashFlowInr: List.filled(12, 680.0),
        ),
      },
    );
  }

  @override
  Future<List<OpportunityComparisonItem>> compareOpportunities({
    required List<String> opportunityIds,
    required double customBudgetInr,
  }) async {
    return [
      OpportunityComparisonItem(
        opportunityId: 'OPP_COMPOST_COST_SAVING_01',
        title: 'On-Farm NADEP Residue Composting',
        category: 'zero_cash',
        isCostSaving: true,
        initialInvestmentInr: 0.0,
        netAnnualProfitInr: 0.0,
        annualSavingsInr: 8700.0,
        paybackMonths: 3.0,
        landRequiredAcres: 0.0,
        waterNeeds: 'low',
        dailyLaborHours: 1.0,
        riskLevel: 'low',
        suitabilityVerdict: 'High Fit',
      ),
    ];
  }

  @override
  Future<List<SavedIncomePlan>> getSavedIncomePlans(String farmId) async {
    return List.of(savedPlans);
  }

  @override
  Future<SavedIncomePlan> saveIncomePlan(
    String farmId, {
    required String opportunityId,
    required double chosenBudgetInr,
    String? notes,
  }) async {
    final plan = SavedIncomePlan(
      planId: 'plan-${savedPlans.length + 1}',
      farmId: farmId,
      opportunityId: opportunityId,
      opportunityTitle: 'On-Farm NADEP Residue Composting',
      category: 'zero_cash',
      plannedInvestmentInr: chosenBudgetInr,
      expectedAnnualIncomeInr: 8200.0,
      expectedAnnualSavingsInr: 8700.0,
      breakEvenMonths: 3.0,
      createdAt: '2026-11-10T10:00:00Z',
    );
    savedPlans.add(plan);
    return plan;
  }

  @override
  Future<void> deleteSavedIncomePlan(String farmId, String planId) async {
    savedPlans.removeWhere((p) => p.planId == planId);
  }
}

void main() {
  void setDesktopViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('Rashkar Integrated UI Tests', () {
    testWidgets('RiskHubScreen shows missing worker context prompt once and assesses after save', (tester) async {
      setDesktopViewport(tester);
      final repo = _FakeRashkarRepository()..workerMissingTriggered = true;
      await tester.pumpWidget(
        MaterialApp(
          home: RiskHubScreen(
            initialTab: 0,
            repository: repo,
            farmsOverride: [_makeTestFarm()],
            initialFarmId: 'farm-baramati-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complete Missing Worker Profile Details (Saved Once)'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Ramesh Kulkarni');
      await scrollAndTap(tester, find.text('Save to Farm Profile & Assess Worker Risk'));

      expect(repo.workerMissingTriggered, isFalse);
      expect(find.text('Outdoor Work Condition'), findsOneWidget);
      expect(find.text('MODERATE'), findsAtLeastNWidgets(1));
    });

    testWidgets('RiskHubScreen Crop Heat tab avoids null strings and recalculates stage thresholds', (tester) async {
      setDesktopViewport(tester);
      final repo = _FakeRashkarRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: RiskHubScreen(
            initialTab: 1,
            repository: repo,
            farmsOverride: [_makeTestFarm()],
            initialFarmId: 'farm-baramati-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifies literal 'null' never appears even when growthStageNameEn returns 'null'
      expect(find.textContaining('null'), findsNothing);
      expect(find.text('Confirm Crop Stage'), findsOneWidget);
      expect(find.text('35.0°C'), findsOneWidget);

      await scrollAndTap(tester, find.text('Pod Filling (33.5°C limit)'));

      expect(repo.lastConfirmedCropStage, 'stage_pod_fill');
      expect(find.text('33.5°C'), findsOneWidget);
      expect(find.textContaining('SOYBEAN · Pod Filling Stage'), findsOneWidget);
    });

    testWidgets('ExtraIncomeScreen collects missing profile once, discovers opportunities, and saves plan', (tester) async {
      setDesktopViewport(tester);
      final repo = _FakeRashkarRepository()..incomeProfileMissing = true;
      await tester.pumpWidget(
        MaterialApp(
          home: ExtraIncomeScreen(
            repository: repo,
            farmsOverride: [_makeTestFarm()],
            initialFarmId: 'farm-baramati-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tell Us Your Farm Resource Profile (Saved Once)'), findsOneWidget);
      await scrollAndTap(tester, find.text('Save Resource Profile & Discover Opportunities'));

      expect(repo.incomeProfileMissing, isFalse);
      expect(find.text('Earn More'), findsAtLeastNWidgets(1));
      expect(find.text('On-Farm NADEP Residue Composting'), findsAtLeastNWidgets(1));

      // Open 6-question farmer summary sheet
      await scrollAndTap(tester, find.text('Farmer Summary (6 Plain Questions)'));
      expect(find.text('1. What is it?'), findsOneWidget);
      expect(find.text('6. What should I be careful about?'), findsOneWidget);
      await scrollAndTap(tester, find.text('Back to Opportunities'));

      // Save plan
      await scrollAndTap(tester, find.text('Save This Opportunity to My Farm Plan'));
      expect(repo.savedPlans.length, 1);
      expect(find.text('My Saved Farm Plans (1)'), findsOneWidget);
    });
  });
}
