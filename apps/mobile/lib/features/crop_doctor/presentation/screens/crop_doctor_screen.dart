import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../../core/network/api_constants.dart';
import '../../../../shared/theme/rashkar_colors.dart';
import '../../../../shared/widgets/centered_page_container.dart';
import '../../../../shared/widgets/rashkar_ui.dart';
import '../../../../shared/widgets/responsive_grid.dart';

class CropDoctorScreen extends StatefulWidget {
  const CropDoctorScreen({super.key});

  @override
  State<CropDoctorScreen> createState() => _CropDoctorScreenState();
}

class _CropDoctorScreenState extends State<CropDoctorScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _diagnosisResult;
  String? _errorMessage;
  String? _uploadedFileName;
  String? _selectedSampleName; // only set when a sample preset is tapped
  final Set<int> _completedSteps = {};

  final List<Map<String, String>> _samplePresets = [
    {
      'label': 'Tomato Early Blight',
      'filename': 'Tomato_Early_blight_sample.jpg',
      'icon': '🍅',
    },
    {
      'label': 'Potato Late Blight',
      'filename': 'Potato_Late_blight_sample.jpg',
      'icon': '🥔',
    },
    {
      'label': 'Corn Common Rust',
      'filename': 'Corn_Common_rust_sample.jpg',
      'icon': '🌽',
    },
    {
      'label': 'Healthy Foliage',
      'filename': 'Tomato_healthy_leaf.jpg',
      'icon': '🌿',
    },
  ];

  // ── Real image upload → /predict ──────────────────────────────────────────

  Future<void> _pickAndUploadImage() async {
    List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
    } catch (e) {
      setState(() => _errorMessage = 'Could not open file picker: $e');
      return;
    }

    if (files.isEmpty) return; // user cancelled

    final file = files.first;
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      setState(() => _errorMessage = 'Could not read the selected image: $e');
      return;
    }

    if (bytes.isEmpty) {
      setState(() => _errorMessage = 'Selected image is empty.');
      return;
    }

    await _diagnoseBytes(bytes: bytes, filename: file.name);
  }

  String _buildApiUrl(String path) {
    final base = ApiConstants.defaultBaseUrl.endsWith('/')
        ? ApiConstants.defaultBaseUrl.substring(0, ApiConstants.defaultBaseUrl.length - 1)
        : ApiConstants.defaultBaseUrl;
    return '$base$path';
  }

  Future<void> _diagnoseBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _diagnosisResult = null;
      _completedSteps.clear();
      _uploadedFileName = filename;
      _selectedSampleName = null;
    });

    try {
      final uri = Uri.parse(_buildApiUrl('/api/v1/crop-doctor/predict'));
      final ext = filename.split('.').last.toLowerCase();
      final mime = switch (ext) {
        'png' => MediaType('image', 'png'),
        'webp' => MediaType('image', 'webp'),
        _ => MediaType('image', 'jpeg'),
      };

      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filename,
            contentType: mime,
          ),
        );

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        setState(() {
          _diagnosisResult = jsonDecode(body) as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "We couldn't check this photo right now. Please try again.";
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _errorMessage = "We couldn't check this photo right now. Please check your connection and try again.";
        _isLoading = false;
      });
    }
  }

  // ── Sample preset → /predict-sample ──────────────────────────────────────

  Future<void> _diagnoseSample(String sampleName) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _diagnosisResult = null;
      _completedSteps.clear();
      _selectedSampleName = sampleName;
      _uploadedFileName = null;
    });

    try {
      final uri = Uri.parse(_buildApiUrl('/api/v1/crop-doctor/predict-sample'));
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sample_name': sampleName}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _diagnosisResult = jsonDecode(response.body) as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "We couldn't check this photo right now. Please try again.";
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _errorMessage = "We couldn't check this photo right now. Please check your connection and try again.";
        _isLoading = false;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 940;

    // Confidence display — only computed when result exists
    final confStr =
        _diagnosisResult?['confidence']?.toString() ?? '0%';
    final confPct =
        double.tryParse(confStr.replaceAll('%', '').trim()) ?? 0.0;
    final confSegments = (confPct / 10.0).round().clamp(1, 10);
    final isHealthy = _diagnosisResult?['is_healthy'] == true;
    final adviceList =
        (_diagnosisResult?['actionable_advice'] as List<dynamic>?) ?? const [];

    // Step progress: 0 = nothing, 1 = picked/loading, 2 = result
    final stepIndex = _isLoading
        ? 1
        : _diagnosisResult != null
            ? 2
            : 0;

    final leftCapturePanel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Step progress ────────────────────────────────────────
        RashkarCard(
          padding: const EdgeInsets.all(16),
          child: RashkarStepProgress(
            currentStep: stepIndex,
            stepLabels: const ['Photo / Sample', 'AI Analysis', 'Treatment'],
          ),
        ),
        const SizedBox(height: 14),

        // ── Upload area ──────────────────────────────────────────
        RashkarUploadDropzone(
          title: _uploadedFileName != null
              ? '✓ $_uploadedFileName'
              : 'Take or upload a leaf photo',
          subtitle: _uploadedFileName != null
              ? 'Tap to upload a different image'
              : 'JPG / PNG from camera or gallery',
          icon:
              _uploadedFileName != null ? Icons.check_circle_outline : Icons.camera_alt_outlined,
          isBusy: _isLoading,
          onPrimaryTap: _isLoading ? () {} : _pickAndUploadImage,
        ),
        const SizedBox(height: 20),

        // ── Sample presets ───────────────────────────────────────
        const Text(
          'Or try a built-in sample',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: RashkarColors.ink),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap a sample to see how the AI analysis works.',
          style:
              TextStyle(fontSize: 12.5, color: RashkarColors.mutedInk),
        ),
        const SizedBox(height: 10),
        ResponsiveGrid(
          mobileColumns: 2,
          tabletColumns: 2,
          desktopColumns: 2,
          spacing: 10,
          runSpacing: 10,
          children: _samplePresets.map((preset) {
            final fname = preset['filename']!;
            final isSelected = _selectedSampleName == fname;
            return RashkarCard(
              selected: isSelected,
              padding: const EdgeInsets.all(14),
              backgroundColor: RashkarColors.surface,
              onTap: _isLoading ? null : () => _diagnoseSample(fname),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: RashkarColors.cropPastelBg(preset['label']),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(
                          child: Text(preset['icon']!,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            size: 20, color: RashkarColors.forest),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    preset['label']!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: RashkarColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Demo sample',
                    style: TextStyle(
                        fontSize: 11.5, color: RashkarColors.mutedInk),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );

    final rightResultPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Error ────────────────────────────────────────────────
        if (_errorMessage != null) ...[
          RashkarNoticeCallout(
            title: 'Leaf check issue',
            message: _errorMessage!,
            isDanger: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              onPressed: () {
                if (_selectedSampleName != null) {
                  _diagnoseSample(_selectedSampleName!);
                } else {
                  setState(() => _errorMessage = null);
                }
              },
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Loading spinner ──────────────────────────────────────
        if (_isLoading)
          const RashkarCard(
            padding: EdgeInsets.all(36),
            child: Column(
              children: [
                CircularProgressIndicator(color: RashkarColors.forest),
                SizedBox(height: 14),
                Text(
                  'Analyzing leaf photo with plant pathology engine…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: RashkarColors.mutedInk),
                ),
              ],
            ),
          ),

        // ── Results ──────────────────────────────────────────────
        if (_diagnosisResult != null) ...[
          // (1) POSSIBLE PROBLEM
          Container(
            decoration: BoxDecoration(
              color: RashkarColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: RashkarColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: RashkarColors.forest,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RashkarSeverityBadge.marigold('ASSESSED PROBLEM'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isHealthy ? const Color(0xFFC8E6C9) : const Color(0xFFFFCDD2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isHealthy ? 'Healthy Foliage' : 'Treatment Needed',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isHealthy ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${_diagnosisResult!['crop_name']} — ${_diagnosisResult!['condition']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Engine: ${_diagnosisResult!['model_architecture'] ?? 'MobileNetV2'}',
                        style: const TextStyle(
                          color: RashkarColors.forestTextMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // (2) WHAT THE FARMER SHOULD KNOW
                      const Text(
                        'What you should know:',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: RashkarColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isHealthy ? RashkarColors.mintBg : const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isHealthy ? RashkarColors.mintBorder : const Color(0xFFFFD54F),
                          ),
                        ),
                        child: Text(
                          isHealthy
                              ? 'No fungal or bacterial disease lesions were found on this leaf. The foliage appears healthy and well-nourished.'
                              : 'This leaf pattern matches ${_diagnosisResult!['condition']}. Fungal and bacterial leaf spots can spread to other crops during humid weather and reduce crop yields if left untreated.',
                          style: const TextStyle(fontSize: 13, color: RashkarColors.ink, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // (3) SUGGESTED NEXT STEPS
          const Text(
            'Suggested next steps for your crop:',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: RashkarColors.ink),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < adviceList.length; i++) ...[
            RashkarActionCard(
              stepNumber: i + 1,
              title: adviceList[i].toString(),
              icon: isHealthy
                  ? Icons.eco_outlined
                  : Icons.healing_outlined,
              isDone: _completedSteps.contains(i),
              onToggleDone: () {
                setState(() {
                  if (_completedSteps.contains(i)) {
                    _completedSteps.remove(i);
                  } else {
                    _completedSteps.add(i);
                  }
                });
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),

          // (4) MODEL UNCERTAINTY AND SCREENING LIMITATIONS
          RashkarCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Model Confidence & Assessment Details',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: RashkarColors.ink),
                      ),
                    ),
                    RashkarSeverityBadge.success(confStr, compact: true),
                  ],
                ),
                const SizedBox(height: 10),
                RashkarConfidenceSegments(filledCount: confSegments),
                const SizedBox(height: 8),
                Text(
                  'Model confidence is $confStr based on computer vision comparison against agricultural leaf disease signatures.',
                  style: const TextStyle(fontSize: 12, color: RashkarColors.mutedInk),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFE65100), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Screening Limitation: This AI vision assessment is a preliminary screening tool based on leaf photographs. Before applying chemical fungicides or pesticides, confirm severe symptoms with your local agricultural officer, Krishi Vigyan Kendra (KVK), or university extension specialist.',
                        style: TextStyle(fontSize: 11.5, color: RashkarColors.mutedInk, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );

    final bool isIdle = _diagnosisResult == null && !_isLoading && _errorMessage == null;

    return Scaffold(
      backgroundColor: RashkarColors.canvas,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.healing_outlined,
                color: RashkarColors.forest),
            SizedBox(width: 8),
            Text(
              'Check a Leaf Problem',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: CenteredPageContainer(
        maxWidth: 1200,
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RashkarHeroBanner(
              eyebrow: 'CROP DOCTOR',
              title: 'Check a Leaf Problem',
              subtitle: 'Take or upload a clear photo of the affected leaf.',
            ),
            const SizedBox(height: 16),
            if (isIdle)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: leftCapturePanel,
                ),
              )
            else if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: leftCapturePanel),
                  const SizedBox(width: 20),
                  Expanded(flex: 7, child: rightResultPanel),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  leftCapturePanel,
                  const SizedBox(height: 18),
                  rightResultPanel,
                ],
              ),
          ],
        ),
      ),
    );
  }
}
