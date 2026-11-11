import 'package:flutter/material.dart';
import 'package:cropnet_mobile/core/router/farm_state.dart';
import 'package:cropnet_mobile/features/advisory/data/advisory_repository.dart';
import 'package:cropnet_mobile/features/advisory/models/advisory_models.dart';
import 'package:cropnet_mobile/features/soil/data/soil_repository.dart';
import 'package:cropnet_mobile/features/soil/models/soil_models.dart';
import 'package:cropnet_mobile/main.dart' show FarmItem;
import 'package:cropnet_mobile/core/network/api_client.dart';
import 'package:cropnet_mobile/core/network/api_constants.dart';
import 'package:cropnet_mobile/shared/theme/rashkar_colors.dart';

/// Chat message model for Agricultural AI Assistant & Advisory session.
class AdvisoryMessage {
  final String id;
  final String sender; // 'user' or 'assistant'
  final String text;
  final String? provenance;
  final String? generationSource;
  final DateTime timestamp;
  final bool isError;
  final StructuredAdvisoryCard? structuredCard;
  final List<FollowUpQuestion>? followUpQuestions;
  final String? decisionId;

  const AdvisoryMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.provenance,
    this.generationSource,
    required this.timestamp,
    this.isError = false,
    this.structuredCard,
    this.followUpQuestions,
    this.decisionId,
  });

  bool get isUser => sender == 'user';
}

/// Feature 2: Agricultural AI Assistant & Advisory Screen (Phase 5.8.1 Redesign).
///
/// Integrates:
/// - Deterministic Agricultural Decision Engine (sole authority for crop suitability).
/// - Constrained Qwen3:8B conversational explanation interface.
/// - Clean 6-section Structured Advisory Card rendering (Direct Answer, What This Means,
///   Verified Observations, What Needs Attention, Recommended Next Steps, Evidence & Sources).
/// - Contextual 1-touch diagnostic follow-up answering without duplication.
/// - Bilingual English and Marathi support with zero text clipping.
class AdvisoryScreen extends StatefulWidget {
  const AdvisoryScreen({super.key});

  @override
  State<AdvisoryScreen> createState() => _AdvisoryScreenState();
}

class _AdvisoryScreenState extends State<AdvisoryScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AdvisoryRepository _advisoryRepo = AdvisoryRepository();
  final SoilRepository _soilRepo = SoilRepository();
  final ApiClient _apiClient = ApiClient();

  // Farm Context State
  String? _selectedTaluka;
  String? _selectedDistrict;
  String? _selectedFarmId;
  double? _soilPh;
  bool _isLabVerifiedSoil = false;
  bool? _irrigationAvailable;
  String? _irrigationSource;
  String _selectedSeason = 'rabi'; // 'kharif', 'rabi', 'summer'
  String _selectedLanguage = 'en'; // 'en' or 'mr'

  // Evaluation & Explanation State
  String? _decisionId;
  FarmEvaluationResponse? _evaluation;
  AgriculturalExplanationResponse? _lastExplanation;
  bool _isEvaluating = false;
  bool _isSendingMessage = false;
  bool _isLlmOnline = true;
  bool _showFeasibilityBoard = false;
  String? _errorMessage;

  late List<AdvisoryMessage> _messages;

  @override
  void initState() {
    super.initState();
    _resetConversation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadFarmsAndContext();
        _checkLlmHealth();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Check LLM runtime availability via GET /api/v1/health
  Future<void> _checkLlmHealth() async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>(
        ApiConstants.health,
        timeout: const Duration(seconds: 4),
        fromJson: (json) => json as Map<String, dynamic>,
      );
      if (mounted && res['llm_runtime'] != null) {
        final llm = res['llm_runtime'] as Map<String, dynamic>;
        setState(() {
          _isLlmOnline = (llm['ollama_server_online'] == true) && (llm['model_available'] == true);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLlmOnline = false);
      }
    }
  }

  /// Initial load of registered farms belonging to the user
  Future<void> _loadFarmsAndContext() async {
    if (FarmRepository.instance.farms.isEmpty) {
      await FarmRepository.instance.loadFarms();
    }
    if (!mounted) return;

    final farms = FarmRepository.instance.farms;
    if (farms.isNotEmpty) {
      final selectedId = FarmRepository.instance.selectedFarmId;
      final selected = (selectedId != null ? FarmRepository.instance.getFarmById(selectedId) : null) ?? farms.first;
      setState(() {
        _selectedFarmId = selected.id;
        _selectedTaluka = selected.taluka;
        _selectedDistrict = selected.district;
        _irrigationAvailable = selected.irrigationType != 'rainfed';
        _irrigationSource = selected.waterSource;
      });
      _fetchFarmSoilProfile(selected.id);
    } else {
      setState(() {
        _selectedFarmId = null;
        _selectedTaluka = null;
        _selectedDistrict = null;
        _soilPh = null;
        _irrigationAvailable = null;
        _irrigationSource = null;
      });
    }
    _resetConversation();
  }

  /// Fetch soil profile to obtain measured or estimated pH
  Future<void> _fetchFarmSoilProfile(String farmId) async {
    try {
      final profile = await _soilRepo.getFarmSoilProfile(farmId);
      if (mounted) {
        if (profile.ph?.value != null) {
          final phVal = profile.ph!.value!;
          if (phVal >= 3.0 && phVal <= 11.0) {
            setState(() {
              _soilPh = phVal;
              _isLabVerifiedSoil = profile.ph!.verificationStatus == VerificationStatus.laboratoryVerified;
            });
            _resetConversation();
          } else {
            setState(() {
              _soilPh = null;
              _isLabVerifiedSoil = false;
            });
            _resetConversation();
          }
        } else {
          setState(() {
            _soilPh = null;
            _isLabVerifiedSoil = false;
          });
          _resetConversation();
        }
      }
    } catch (_) {
      // Retain null if soil profile is not yet available
    }
  }

  void _onFarmSelected(String? farmId) {
    if (farmId == null) return;
    final farm = FarmRepository.instance.getFarmById(farmId);
    setState(() {
      _selectedFarmId = farmId;
      if (farm != null) {
        _selectedTaluka = farm.taluka;
        _selectedDistrict = farm.district;
        _irrigationAvailable = farm.irrigationType != 'rainfed';
        _irrigationSource = farm.waterSource;
        _soilPh = null;
      }
      _decisionId = null;
      _evaluation = null;
      _lastExplanation = null;
      _errorMessage = null;
    });
    if (farm != null) {
      _fetchFarmSoilProfile(farm.id);
    }
    _resetConversation();
  }

  void _resetConversation() {
    _decisionId = null;
    _evaluation = null;
    _lastExplanation = null;
    _errorMessage = null;

    final isMr = _selectedLanguage == 'mr';
    final seasonName = _getSeasonDisplayLabel(_selectedSeason, isMr);
    final currentFarm = _getCurrentFarm();

    if (currentFarm == null) {
      _messages = [
        AdvisoryMessage(
          id: 'msg-init-empty',
          sender: 'assistant',
          text: isMr
              ? 'नमस्ते! क्रॉपनेट एआय कृषी सल्लागार प्रणालीमध्ये आपले स्वागत आहे. '
                'प्रमाणित पीक मूल्यमापन आणि सल्ला सुरू करण्यासाठी कृपया तुमचे शेत निवडा किंवा नवीन शेत नोंदवा.'
              : 'Namaste! Welcome to CropNet AI Agronomic Advisory. '
                'Please select or register a farm to begin agricultural evaluation and dialogue.',
          provenance: '[CropNet System Notice | Verified Authentication Required]',
          generationSource: 'system',
          timestamp: DateTime.now(),
        ),
      ];
      return;
    }

    final taluka = currentFarm.taluka;
    final farmName = currentFarm.name;

    _messages = [
      AdvisoryMessage(
        id: 'msg-init-1',
        sender: 'assistant',
        text: isMr
            ? 'नमस्ते! मी $farmName ($taluka, $seasonName हंगाम) परिसरातील आपल्या शेतासाठी कृषी सल्लागार प्रणालीशी जोडलेला आहे. '
              'पिकांची निवड, माती मर्यादा, किंवा सिंचनानुसार योग्य सल्ला हवा असल्यास विचारा.'
            : 'Namaste! Welcome to CropNet AI Agricultural Advisory. '
              'I am connected to the agricultural intelligence engine for $farmName in $taluka ($seasonName Season). '
              'Ask any question regarding crop feasibility, soil constraints, or irrigation decisions.',
        provenance: '[llm_qwen3_8b | Guardrails: Verified | Sources: MPKV Rahuri / ICAR / CRIDA]',
        generationSource: 'llm_qwen3_8b',
        timestamp: DateTime.now(),
      ),
    ];
  }

  FarmItem? _getCurrentFarm() {
    final farms = FarmRepository.instance.farms;
    if (_selectedFarmId != null) {
      return FarmRepository.instance.getFarmById(_selectedFarmId!);
    }
    if (farms.isNotEmpty) {
      return farms.first;
    }
    return null;
  }

  /// Trigger deterministic farm evaluation against Phase 5.1 FastAPI endpoints
  Future<void> _runDeterministicEvaluation({String? userQuery, String? focusCrop}) async {
    final currentFarm = _getCurrentFarm();
    if (currentFarm == null) {
      setState(() {
        _errorMessage = _selectedLanguage == 'mr'
            ? 'मूल्यांकन सुरू करण्यासाठी कृपया प्रथम शेत निवडा किंवा नोंदवा.'
            : 'Select or register a farm to begin evaluation.';
      });
      return;
    }

    setState(() {
      _isEvaluating = true;
      _errorMessage = null;
    });

    double? safePh = _soilPh;
    if (safePh != null && (safePh < 3.0 || safePh > 11.0)) {
      safePh = null;
    }

    final contextInput = FarmContextInput(
      farmId: currentFarm.id,
      taluka: _selectedTaluka ?? currentFarm.taluka,
      district: _selectedDistrict ?? currentFarm.district,
      latitude: currentFarm.centroid.latitude,
      longitude: currentFarm.centroid.longitude,
      soilPh: safePh,
      irrigationAvailable: _irrigationAvailable ?? (currentFarm.irrigationType != 'rainfed'),
      irrigationSource: _irrigationSource ?? currentFarm.waterSource,
      targetSeason: _selectedSeason,
      language: _selectedLanguage,
      userQuery: userQuery,
      targetCrops: focusCrop != null ? [focusCrop] : null,
    );

    try {
      final eval = await _advisoryRepo.evaluateFarm(contextInput);
      _decisionId = eval.decisionId;
      _evaluation = eval;

      // Request natural-language explanation grounded in this validated decision
      try {
        final explanation = await _advisoryRepo.explainDecision(
          eval.decisionId,
          language: _selectedLanguage,
          focusCrop: focusCrop,
        );
        _lastExplanation = explanation;

        final badge = _buildProvenanceBadge(
          generationSource: explanation.generationSource,
          citations: explanation.authoritativeCitations,
          validationPassed: explanation.validationPassed,
        );

        if (mounted) {
          setState(() {
            _messages.add(
              AdvisoryMessage(
                id: 'eval-exp-${DateTime.now().millisecondsSinceEpoch}',
                sender: 'assistant',
                text: explanation.explanationText,
                provenance: badge,
                generationSource: explanation.generationSource,
                timestamp: DateTime.now(),
                structuredCard: explanation.structuredCard,
                followUpQuestions: explanation.followUpQuestions,
                decisionId: eval.decisionId,
              ),
            );
          });
        }
      } catch (_) {
        // Safe deterministic fallback explanation on Ollama offline / timeout
        final fallbackText = _generateLocalDeterministicSummary(eval, _selectedLanguage);
        final badge = _buildProvenanceBadge(
          generationSource: 'deterministic_fallback',
          citations: eval.cropOutcomes.expand((o) => o.citations).toList(),
          validationPassed: true,
        );

        if (mounted) {
          setState(() {
            _messages.add(
              AdvisoryMessage(
                id: 'eval-fallback-${DateTime.now().millisecondsSinceEpoch}',
                sender: 'assistant',
                text: fallbackText,
                provenance: badge,
                generationSource: 'deterministic_fallback',
                timestamp: DateTime.now(),
                followUpQuestions: eval.followUpQuestions,
                decisionId: eval.decisionId,
              ),
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        String userFriendlyError = e.toString().replaceAll('Exception: ', '');
        if (userFriendlyError.contains('soil_ph') || userFriendlyError.contains('less than or equal to 11')) {
          userFriendlyError = _selectedLanguage == 'mr'
              ? 'मातीचे सामू (pH) मूल्य अवैध आहे. कृपया शेताचे माती प्रोफाइल किंवा अहवाल तपासा.'
              : 'Invalid soil pH measurement detected. Please check your farm soil profile.';
        }
        setState(() {
          _errorMessage = userFriendlyError;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEvaluating = false;
        });
        _scrollToBottom();
      }
    }
  }

  /// Submit diagnostic follow-up answer to re-evaluate farm context
  Future<void> _submitFollowUpAnswer(String questionId, String parameter, dynamic answer) async {
    if (_decisionId == null) return;

    setState(() {
      _isEvaluating = true;
      _errorMessage = null;
    });

    final isMr = _selectedLanguage == 'mr';
    final userMsgText = isMr
        ? 'नोंदवलेली माहिती: $parameter = $answer'
        : 'Diagnostic input provided: $parameter = $answer';

    setState(() {
      _messages.add(
        AdvisoryMessage(
          id: 'user-ans-${DateTime.now().millisecondsSinceEpoch}',
          sender: 'user',
          text: userMsgText,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();

    try {
      final updatedEval = await _advisoryRepo.processFollowUp(
        _decisionId!,
        {parameter: answer},
      );

      setState(() {
        _evaluation = updatedEval;
        _decisionId = updatedEval.decisionId;
      });

      // Request updated natural language explanation and structured card
      try {
        final explanation = await _advisoryRepo.explainDecision(
          updatedEval.decisionId,
          language: _selectedLanguage,
        );
        _lastExplanation = explanation;

        final badge = _buildProvenanceBadge(
          generationSource: explanation.generationSource,
          citations: explanation.authoritativeCitations,
          validationPassed: explanation.validationPassed,
        );

        if (mounted) {
          setState(() {
            _messages.add(
              AdvisoryMessage(
                id: 're-eval-${DateTime.now().millisecondsSinceEpoch}',
                sender: 'assistant',
                text: explanation.explanationText,
                provenance: badge,
                generationSource: explanation.generationSource,
                timestamp: DateTime.now(),
                structuredCard: explanation.structuredCard,
                followUpQuestions: explanation.followUpQuestions,
                decisionId: updatedEval.decisionId,
              ),
            );
          });
        }
      } catch (_) {
        final fallbackText = _generateLocalDeterministicSummary(updatedEval, _selectedLanguage);
        final badge = _buildProvenanceBadge(
          generationSource: 'deterministic_fallback',
          citations: updatedEval.cropOutcomes.expand((o) => o.citations).toList(),
          validationPassed: true,
        );

        if (mounted) {
          setState(() {
            _messages.add(
              AdvisoryMessage(
                id: 're-eval-fallback-${DateTime.now().millisecondsSinceEpoch}',
                sender: 'assistant',
                text: fallbackText,
                provenance: badge,
                generationSource: 'deterministic_fallback',
                timestamp: DateTime.now(),
                followUpQuestions: updatedEval.followUpQuestions,
                decisionId: updatedEval.decisionId,
              ),
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Follow-up submission failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEvaluating = false;
        });
        _scrollToBottom();
      }
    }
  }

  /// Submit user message to conversational dialogue endpoint
  Future<void> _sendMessage(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final userMsg = AdvisoryMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      sender: 'user',
      text: trimmed,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isSendingMessage = true;
      _errorMessage = null;
    });
    _textController.clear();
    _scrollToBottom();

    // Check if query is asking about chickpea or another crop
    String? focusCrop;
    final lower = trimmed.toLowerCase();
    if (lower.contains('chickpea') || lower.contains('हरभरा') || lower.contains('चना')) {
      focusCrop = 'chickpea';
    } else if (lower.contains('pomegranate') || lower.contains('डाळिंब')) {
      focusCrop = 'pomegranate';
    } else if (lower.contains('sugarcane') || lower.contains('ऊस')) {
      focusCrop = 'sugarcane';
    }

    // If no decision evaluated yet, run evaluation first with this query
    if (_decisionId == null) {
      await _runDeterministicEvaluation(userQuery: trimmed, focusCrop: focusCrop);
      if (mounted) setState(() => _isSendingMessage = false);
      return;
    }

    try {
      final history = _messages
          .where((m) => m.id != userMsg.id && !m.isError)
          .map((m) => ConversationMessage(
                role: m.sender == 'user' ? 'user' : 'assistant',
                content: m.text,
              ))
          .toList();

      final response = await _advisoryRepo.processConversation(
        _decisionId!,
        trimmed,
        language: _selectedLanguage,
        history: history,
      );

      _lastExplanation = response;
      final badge = _buildProvenanceBadge(
        generationSource: response.generationSource,
        citations: response.authoritativeCitations,
        validationPassed: response.validationPassed,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            AdvisoryMessage(
              id: 'reply-${DateTime.now().millisecondsSinceEpoch}',
              sender: 'assistant',
              text: response.explanationText,
              provenance: badge,
              generationSource: response.generationSource,
              timestamp: DateTime.now(),
              structuredCard: response.structuredCard,
              followUpQuestions: response.followUpQuestions,
              decisionId: _decisionId,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        final isMr = _selectedLanguage == 'mr';
        final fallbackNotice = isMr
            ? 'सल्लागार मॉडेल तात्पुरते अनुपलब्ध आहे. तथापि, वरील प्रमाणित पीक मूल्यांकन निष्कर्ष निश्चित नियमांनुसार वैध आहेत.'
            : 'LLM dialogue service is currently unreachable. The deterministic crop feasibility outcomes above remain fully verified and authoritative.';
        const badge = '[deterministic_fallback | Guardrails: Enforced | Sources: MPKV Rahuri / ICAR]';

        setState(() {
          _messages.add(
            AdvisoryMessage(
              id: 'err-${DateTime.now().millisecondsSinceEpoch}',
              sender: 'assistant',
              text: fallbackNotice,
              provenance: badge,
              generationSource: 'deterministic_fallback',
              timestamp: DateTime.now(),
              isError: false,
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Construct provenance and generation source badge
  String _buildProvenanceBadge({
    required String generationSource,
    required List<CitationMetadata> citations,
    bool validationPassed = true,
  }) {
    final Set<String> orgs = {};
    for (final c in citations) {
      if (c.organization.isNotEmpty) {
        orgs.add(c.organization);
      }
    }
    final sourcesStr = orgs.isNotEmpty ? orgs.join(' / ') : 'MPKV Rahuri / ICAR';

    if (generationSource == 'llm_qwen3_8b') {
      final guardrailStr = validationPassed ? 'Verified' : 'Fallback';
      return '[llm_qwen3_8b | Guardrails: $guardrailStr | Sources: $sourcesStr]';
    } else {
      return '[deterministic_fallback | Guardrails: Enforced | Sources: $sourcesStr]';
    }
  }

  /// Safe local deterministic outcome summarizer for fallbacks (zero raw headers)
  String _generateLocalDeterministicSummary(FarmEvaluationResponse eval, String lang) {
    final isMr = lang == 'mr';
    final taluka = eval.talukaResolved ?? _selectedTaluka;
    final season = _getSeasonDisplayLabel(eval.targetSeason ?? _selectedSeason, isMr);

    final buffer = StringBuffer();
    if (isMr) {
      buffer.writeln('CropNet प्रमाणित पीक मूल्यमापन निकाल — $taluka ($season):\n');
      for (final o in eval.cropOutcomes) {
        final status = o.decisionState.getFarmerFriendlyLabel(true);
        final cropName = o.marathiName ?? o.commonName;
        buffer.writeln('• $cropName: $status');
        if (o.limitingFactors.isNotEmpty) {
          buffer.writeln('   - मर्यादा: ${o.limitingFactors.join(", ")}');
        }
        if (o.explanation.isNotEmpty) {
          buffer.writeln('   - स्पष्टीकरण: ${o.explanation}');
        }
        buffer.writeln();
      }
    } else {
      buffer.writeln('CropNet Deterministic Crop Feasibility Outcomes for $taluka ($season Season):\n');
      for (final o in eval.cropOutcomes) {
        final status = o.decisionState.getFarmerFriendlyLabel(false);
        buffer.writeln('• ${o.commonName} (${o.scientificName}): $status');
        if (o.limitingFactors.isNotEmpty) {
          buffer.writeln('   - Limiting Factors: ${o.limitingFactors.join(", ")}');
        }
        if (o.reproductiveRiskWarnings.isNotEmpty) {
          buffer.writeln('   - Thermal Warnings: ${o.reproductiveRiskWarnings.join(", ")}');
        }
        if (o.explanation.isNotEmpty) {
          buffer.writeln('   - Explanation: ${o.explanation}');
        }
        buffer.writeln();
      }
    }
    return buffer.toString().trim();
  }

  Color _getFeasibilityColor(DecisionState state, bool isDisqualified) {
    if (isDisqualified || state == DecisionState.unsuitableVerifiedConstraint) {
      return const Color(0xFFC62828); // Red
    }
    switch (state) {
      case DecisionState.verifiedSuitable:
        return const Color(0xFF2E7D32); // Green
      case DecisionState.regionalScreeningOnly:
      case DecisionState.conditionallySuitablePendingData:
      case DecisionState.requiresRegionalValidation:
        return const Color(0xFFE65100); // Amber/Orange
      case DecisionState.unsuitableVerifiedConstraint:
        return const Color(0xFFC62828); // Red
      case DecisionState.abstainInsufficientEvidence:
        return const Color(0xFF546E7A); // Slate Grey
    }
  }

  String _getSeasonDisplayLabel(String season, bool isMr) {
    switch (season.toLowerCase()) {
      case 'kharif':
        return isMr ? 'खरीप (पावसाळी)' : 'Kharif (Monsoon)';
      case 'rabi':
        return isMr ? 'रब्बी (हिवाळी)' : 'Rabi (Winter)';
      case 'summer':
        return isMr ? 'उन्हाळी (Zaid)' : 'Summer (Zaid)';
      default:
        return season;
    }
  }

  List<String> get _bilingualPromptSuggestions {
    if (_selectedLanguage == 'mr') {
      return [
        'मी कोणते पीक घ्यावे?',
        'आज पिकाला पाणी द्यावे का?',
        'उष्णतेपासून पिकाचे संरक्षण कसे करावे?',
        'दुपारच्या उन्हात शेतात काम करणे सुरक्षित आहे का?',
      ];
    } else {
      return [
        'Which crop should I grow?',
        'Should I water my crop today?',
        'How can I protect my crop from heat?',
        'Is it safe to work in outdoor heat today?',
      ];
    }
  }

  // ---------------------------------------------------------------------------
  // Build Methods: Top Header, Compact Farm Bar, and Main Area
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isMr = _selectedLanguage == 'mr';
    final currentFarm = _getCurrentFarm();

    return Scaffold(
      backgroundColor: RashkarColors.canvas,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: RashkarColors.forest,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isMr ? 'राशकर विचारा (CropNet AI)' : 'CropNet AI · Ask Rashkar',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
            Text(
              isMr
                  ? 'शासकीय व संशोधन संस्था प्रमाणित कृषी सल्ला'
                  : 'Deterministic ICAR & MPKV Decision Engine',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: RashkarColors.forestTextMuted),
            ),
          ],
        ),
        actions: [
          // Farm Switcher Pill in Header
          if (currentFarm != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: InkWell(
                onTap: () => _showFarmSelectorDialog(isMr),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        currentFarm.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ),

          _buildLlmStatusPill(isMr),
          // Bilingual Toggle (EN / मराठी)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white38),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLanguageButton('EN', 'en', active: _selectedLanguage == 'en'),
                _buildLanguageButton('मराठी', 'mr', active: _selectedLanguage == 'mr'),
              ],
            ),
          ),

          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isMr ? 'सत्र पुन्हा सुरू करा' : 'Restart Advisory Session',
            onPressed: () => setState(_resetConversation),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1100;

          return Column(
            children: [
              // 1. Compact Farm Context Banner across top (replaces cramped 50% split)
              _buildCompactFarmContextBanner(isMr, currentFarm, constraints.maxWidth),

              // 2. Main Workspace
              Expanded(
                child: isWide && _showFeasibilityBoard
                    ? Row(
                        children: [
                          Expanded(
                            flex: 7,
                            child: _buildChatWorkspace(isMr),
                          ),
                          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE0E0E0)),
                          SizedBox(
                            width: 340,
                            child: _buildFeasibilitySideRail(isMr),
                          ),
                        ],
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 960),
                          child: _buildChatWorkspace(isMr),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Compact header status pill showing LLM + Deterministic status
  Widget _buildLlmStatusPill(bool isMr) {
    final label = _isLlmOnline
        ? (_selectedLanguage == 'mr' ? 'Qwen3:8B सक्रिय' : 'Qwen3:8B Active')
        : (_selectedLanguage == 'mr' ? 'निश्चित मॉडेल' : 'Deterministic Mode');
    final color = _isLlmOnline ? const Color(0xFF81C784) : const Color(0xFFFFB74D);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(160)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageButton(String label, String langCode, {required bool active}) {
    return InkWell(
      onTap: () {
        if (_selectedLanguage != langCode) {
          setState(() {
            _selectedLanguage = langCode;
            _resetConversation();
          });
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? const Color(0xFF1B5E20) : Colors.white70,
          ),
        ),
      ),
    );
  }

  /// Compact Horizontal Farm Context Banner (Part 2 UX Redesign)
  Widget _buildCompactFarmContextBanner(bool isMr, FarmItem? farm, double screenWidth) {
    if (farm == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFFFFF8E1),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: Color(0xFFF57F17)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isMr
                    ? 'सल्ला सुरू करण्यासाठी कृपया प्रथम शेत नोंदवा किंवा निवडा.'
                    : 'Select or register a farm to begin agricultural feasibility analysis.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF5D4037)),
              ),
            ),
          ],
        ),
      );
    }

    final phText = _soilPh != null
        ? '${_soilPh!.toStringAsFixed(1)} ${_isLabVerifiedSoil ? (isMr ? "(प्रयोगशाळा)" : "(Lab)") : (isMr ? "(SoilGrids)" : "(SoilGrids)")}'
        : (isMr ? 'माती चाचणी आवश्यक' : 'Soil test required');
    final irrigText = farm.irrigationType != 'rainfed'
        ? farm.waterSource.capitalize()
        : (isMr ? 'जिरायती' : 'Rainfed');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Left: Farm Name, Taluka & Area
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.agriculture, size: 20, color: Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farm.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  Text(
                    '${farm.taluka}, ${farm.district} • ${farm.areaAcres.toStringAsFixed(1)} ac',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),

          // Center: Season Selector & Soil/Water Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Season Selector Pills
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSeasonPill('kharif', isMr ? 'खरीप' : 'Kharif'),
                    _buildSeasonPill('rabi', isMr ? 'रब्बी' : 'Rabi'),
                    _buildSeasonPill('summer', isMr ? 'उन्हाळी' : 'Summer'),
                  ],
                ),
              ),

              // Soil pH Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.science, size: 13, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 4),
                    Text(
                      _soilPh != null ? 'pH: $phText' : phText,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
                    ),
                  ],
                ),
              ),

              // Irrigation Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F5FE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB3E5FC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.water_drop, size: 13, color: Color(0xFF0277BD)),
                    const SizedBox(width: 4),
                    Text(
                      irrigText,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0277BD)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Right: Action buttons
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Evaluate Farm Crops Button
              ElevatedButton.icon(
                onPressed: _isEvaluating ? null : () => _runDeterministicEvaluation(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isEvaluating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow, size: 16),
                label: Text(isMr ? 'पिकांचे मूल्यांकन करा' : 'Evaluate Farm'),
              ),

              // 10-Crop Feasibility Board Toggle Button
              OutlinedButton.icon(
                onPressed: () {
                  if (screenWidth >= 1100) {
                    setState(() => _showFeasibilityBoard = !_showFeasibilityBoard);
                  } else {
                    _showFeasibilityBottomSheet(isMr);
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1B5E20),
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.grid_view, size: 15),
                label: Text(
                  _evaluation != null
                      ? '${isMr ? "पीक तक्ता" : "Feasibility"} (${_evaluation!.cropOutcomes.length})'
                      : (isMr ? 'पीक तक्ता' : 'Feasibility Board'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonPill(String seasonCode, String displayLabel) {
    final active = _selectedSeason == seasonCode;
    return InkWell(
      onTap: () {
        if (_selectedSeason != seasonCode) {
          setState(() {
            _selectedSeason = seasonCode;
            _resetConversation();
          });
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1B5E20) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          displayLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  void _showFarmSelectorDialog(bool isMr) {
    final farms = FarmRepository.instance.farms;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMr ? 'शेत निवडा' : 'Select Farm'),
        content: SizedBox(
          width: 360,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: farms.length,
            itemBuilder: (c, idx) {
              final f = farms[idx];
              final isSelected = f.id == _selectedFarmId;
              return ListTile(
                leading: Icon(Icons.landscape, color: isSelected ? const Color(0xFF1B5E20) : Colors.grey),
                title: Text(f.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text('${f.taluka}, ${f.district} (${f.areaAcres.toStringAsFixed(1)} ac)'),
                trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF1B5E20)) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _onFarmSelected(f.id);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isMr ? 'रद्द करा' : 'Cancel'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Chat Conversation Workspace
  // ---------------------------------------------------------------------------

  Widget _buildChatWorkspace(bool isMr) {
    return Column(
      children: [
        _buildQuickPromptChipsBar(),
        if (_errorMessage != null) _buildErrorBanner(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _messages.length,
            itemBuilder: (ctx, idx) => _buildMessageBubble(_messages[idx]),
          ),
        ),
        if (_isSendingMessage || _isEvaluating) _buildThinkingIndicator(isMr),
        if (_lastExplanation != null && _lastExplanation!.governanceNotice.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Text(
              _lastExplanation!.governanceNotice,
              style: const TextStyle(fontSize: 10, color: Colors.black45, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        _buildChatInputBar(isMr),
      ],
    );
  }

  Widget _buildQuickPromptChipsBar() {
    final prompts = _bilingualPromptSuggestions;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          final p = prompts[idx];
          return ActionChip(
            label: Text(p, style: const TextStyle(fontSize: 11.5, color: Color(0xFF1B5E20))),
            backgroundColor: const Color(0xFFE8F5E9),
            side: const BorderSide(color: Color(0xFFC8E6C9)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: () => _sendMessage(p),
          );
        },
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMessage!, style: const TextStyle(fontSize: 11.5, color: Colors.red))),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            onPressed: () => setState(() => _errorMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator(bool isMr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B5E20))),
          const SizedBox(width: 8),
          Text(
            isMr ? 'CropNet AI विचार करत आहे...' : 'CropNet AI is reasoning from verified agronomic evidence...',
            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInputBar(bool isMr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: RashkarColors.surface,
        border: Border(top: BorderSide(color: RashkarColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: isMr
                    ? 'शेती किंवा पिकांविषयी प्रश्न विचारा (उदा. काळी जमीन हरभऱ्यासाठी योग्य आहे का?)...'
                    : 'Ask about crop feasibility, soil, or irrigation (e.g. Can I grow chickpea in heavy clay soil?)...',
                hintStyle: const TextStyle(fontSize: 12.5, color: RashkarColors.subtleInk),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: RashkarColors.canvas,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: RashkarColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: RashkarColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: RashkarColors.forest, width: 1.6),
                ),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: RashkarColors.forest,
            radius: 22,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 19),
              onPressed: () => _sendMessage(_textController.text),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Message Bubble Rendering (Safe Native Widgets, No Raw Markdown/Dict Leaks)
  // ---------------------------------------------------------------------------

  Widget _buildMessageBubble(AdvisoryMessage msg) {
    final isUser = msg.isUser;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * (MediaQuery.sizeOf(context).width > 700 ? 0.70 : 0.85),
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RashkarColors.forest,
            borderRadius: BorderRadius.circular(18).copyWith(bottomRight: Radius.zero),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person, size: 14, color: Colors.white70),
                  SizedBox(width: 4),
                  Text('Farmer', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                msg.text,
                style: const TextStyle(fontSize: 13.5, color: Colors.white, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    // Assistant Message: Render Structured Card if available, else clean formatted bubble
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * (MediaQuery.sizeOf(context).width > 700 ? 0.85 : 0.95),
        ),
        child: msg.structuredCard != null
            ? _buildStructuredCardWidget(msg.structuredCard!, msg)
            : _buildSimpleAssistantBubble(msg),
      ),
    );
  }

  /// Simple Assistant Bubble with safe formatting (zero raw headers/dicts)
  Widget _buildSimpleAssistantBubble(AdvisoryMessage msg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RashkarColors.surface,
        borderRadius: BorderRadius.circular(14).copyWith(bottomLeft: Radius.zero),
        border: Border.all(color: RashkarColors.paleSage),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology, size: 18, color: RashkarColors.forest),
              SizedBox(width: 6),
              Text(
                'CropNet AI Assistant',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: RashkarColors.forest),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSafeFormattedText(msg.text, isUser: false, baseStyle: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.45)),
          if (msg.provenance != null) ...[
            const SizedBox(height: 10),
            _buildProvenanceTag(msg.provenance!),
          ],
        ],
      ),
    );
  }

  /// Standardized 6-Section Structured Advisory Card (Phase 5.8.1 UX Standard)
  Widget _buildStructuredCardWidget(StructuredAdvisoryCard card, AdvisoryMessage msg) {
    final isMr = _selectedLanguage == 'mr';

    // Status Color & Icon
    Color statusBgColor = const Color(0xFFFFF3E0);
    Color statusTextColor = const Color(0xFFE65100);
    IconData statusIcon = Icons.info_outline;

    if (card.cropStatusCode == 'VERIFIED_SUITABLE') {
      statusBgColor = const Color(0xFFE8F5E9);
      statusTextColor = const Color(0xFF2E7D32);
      statusIcon = Icons.check_circle_outline;
    } else if (card.cropStatusCode == 'UNSUITABLE_VERIFIED_CONSTRAINT') {
      statusBgColor = const Color(0xFFFFEBEE);
      statusTextColor = const Color(0xFFC62828);
      statusIcon = Icons.cancel_outlined;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header with Title & Status Label Callout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAF9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, size: 18, color: Color(0xFF1B5E20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        card.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B5E20)),
                      ),
                    ),
                  ],
                ),
                if (card.cropStatusLabel != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusTextColor.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusTextColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            card.cropStatusLabel!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusTextColor,
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

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Section A: Direct Answer (Highlighted callout)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMr ? 'थेट उत्तर (Direct Answer):' : 'Direct Answer:',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.directAnswer,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Section B: What This Means
                Text(
                  isMr ? 'याचा अर्थ काय?' : 'What this means',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  card.whatThisMeans,
                  style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.45),
                ),
                const SizedBox(height: 14),

                // 4. Section C: What We Found (Verified Observations)
                if (card.observations.isNotEmpty) ...[
                  Text(
                    isMr ? 'तपासलेली माहिती व निरीक्षणे' : 'What we found (Verified Observations)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: card.observations.map((obs) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              obs.parameter,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              obs.value,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              obs.source,
                              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // 5. Section D: What Needs Attention (Amber alert)
                if (card.whatNeedsAttention.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE65100)),
                            const SizedBox(width: 6),
                            Text(
                              isMr ? 'काय काळजी घ्यावी / मर्यादा:' : 'What needs attention:',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...card.whatNeedsAttention.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 6. Section E: Recommended Next Steps
                if (card.nextSteps.isNotEmpty) ...[
                  Text(
                    isMr ? 'पुढील पावले' : 'Recommended next steps',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  ...card.nextSteps.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1B5E20),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 14),
                ],

                // 7. Contextual Diagnostic Follow-Up Questions (Deduplicated, single location)
                if (msg.followUpQuestions != null && msg.followUpQuestions!.isNotEmpty) ...[
                  _buildContextualFollowUpQuestionsCard(msg.followUpQuestions!, isMr),
                  const SizedBox(height: 14),
                ],

                // 8. Section F: Evidence & Sources
                if (card.evidenceReferences.isNotEmpty) ...[
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    dense: true,
                    title: Row(
                      children: [
                        const Icon(Icons.menu_book, size: 14, color: Color(0xFF1B5E20)),
                        const SizedBox(width: 6),
                        Text(
                          isMr ? 'संदर्भ व वैज्ञानिक पुरावे' : 'Evidence & Institutional Sources',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        ),
                      ],
                    ),
                    children: card.evidenceReferences.map((citation) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                citation,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],

                // Provenance tag
                if (msg.provenance != null) _buildProvenanceTag(msg.provenance!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Contextual diagnostic follow-up question card embedded in the message flow
  Widget _buildContextualFollowUpQuestionsCard(List<FollowUpQuestion> questions, bool isMr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, size: 16, color: Color(0xFF1B5E20)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isMr
                      ? 'अचूक सल्ल्यासाठी आवश्यक माहिती (कृपया उत्तर द्या):'
                      : 'Diagnostic Follow-Up: Tap an option to update assessment',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...questions.map((q) {
            final qText = isMr ? q.questionTextMr : q.questionTextEn;
            final opts = q.options ?? const [];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    qText,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  if (q.agronomicRationale.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      q.agronomicRationale,
                      style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                    ),
                  ],
                  if (opts.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: opts.map((opt) {
                        return ActionChip(
                          label: Text(opt, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          onPressed: _isEvaluating ? null : () => _submitFollowUpAnswer(q.questionId, q.targetParameter, opt),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProvenanceTag(String provenance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Text(
        provenance,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2E7D32),
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  /// Safe text formatter that cleanly handles bold, bullets, and paragraphs without raw headers
  Widget _buildSafeFormattedText(String rawText, {required bool isUser, required TextStyle baseStyle}) {
    // Strip raw markdown headings ###, ####
    final cleanText = rawText.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');
    final paragraphs = cleanText.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((para) {
        final trimmed = para.trim();
        if (trimmed.isEmpty) return const SizedBox.shrink();

        final lines = trimmed.split('\n');
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((line) {
              final l = line.trim();
              if (l.startsWith('• ') || l.startsWith('- ')) {
                final content = l.substring(2);
                return Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: baseStyle.copyWith(fontWeight: FontWeight.bold)),
                      Expanded(child: _buildRichInlineSpans(content, baseStyle)),
                    ],
                  ),
                );
              }
              return _buildRichInlineSpans(l, baseStyle);
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRichInlineSpans(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start), style: baseStyle));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: baseStyle.copyWith(fontWeight: FontWeight.bold),
      ));
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: baseStyle));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }
    return Text.rich(TextSpan(children: spans));
  }

  // ---------------------------------------------------------------------------
  // Feasibility Side Rail / Bottom Sheet (10 Crops Matrix)
  // ---------------------------------------------------------------------------

  Widget _buildFeasibilitySideRail(bool isMr) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view, size: 18, color: Color(0xFF1B5E20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isMr ? 'पीक मूल्यमापन तक्ता (१० पिके)' : 'Crop Feasibility Board (10 Crops)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1B5E20)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => setState(() => _showFeasibilityBoard = false),
              ),
            ],
          ),
          const Divider(height: 16),
          Expanded(child: _buildFeasibilityList(isMr)),
        ],
      ),
    );
  }

  void _showFeasibilityBottomSheet(bool isMr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (c, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.grid_view, size: 20, color: Color(0xFF1B5E20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isMr ? 'प्रमाणित पीक मूल्यमापन तक्ता' : 'Deterministic Feasibility Board',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20)),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(child: _buildFeasibilityList(isMr, scrollController: scrollController)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeasibilityList(bool isMr, {ScrollController? scrollController}) {
    if (_evaluation == null || _evaluation!.cropOutcomes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assessment_outlined, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                isMr
                    ? '१० पिकांचे मूल्यमापन पाहण्यासाठी वरील "पिकांचे मूल्यांकन करा" बटण दाबा.'
                    : 'Tap "Evaluate Farm" above to run deterministic suitability analysis for 10 crops.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: _evaluation!.cropOutcomes.length,
      itemBuilder: (ctx, idx) {
        final outcome = _evaluation!.cropOutcomes[idx];
        final color = _getFeasibilityColor(outcome.decisionState, outcome.isDisqualified);
        final friendlyLabel = outcome.decisionState.getFarmerFriendlyLabel(isMr);
        final cropName = isMr && outcome.marathiName != null
            ? '${outcome.marathiName} (${outcome.commonName})'
            : outcome.commonName;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: color.withAlpha(100), width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cropName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withAlpha(120)),
                      ),
                      child: Text(
                        friendlyLabel,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ],
                ),
                if (outcome.limitingFactors.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${isMr ? "मर्यादा:" : "Constraints:"} ${outcome.limitingFactors.join(", ")}',
                    style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 12, color: Color(0xFF1B5E20)),
                    label: Text(
                      isMr ? 'या पिकाबद्दल विचारा' : 'Ask about this crop',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                      _sendMessage(isMr ? '$cropName पिकाबद्दल सविस्तर माहिती सांगा.' : 'Tell me more about growing ${outcome.commonName}.');
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
