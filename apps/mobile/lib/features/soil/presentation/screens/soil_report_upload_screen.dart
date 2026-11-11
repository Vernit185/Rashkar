import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/utils/native_file_picker.dart';
import '../../../../shared/theme/rashkar_colors.dart';
import '../../../../shared/widgets/centered_page_container.dart';
import '../../../../shared/widgets/rashkar_ui.dart';
import '../state/soil_lab_notifier.dart';

/// Validation result produced by [DocumentFileValidator].
class DocumentValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String mimeType;

  const DocumentValidationResult.success(this.mimeType)
      : isValid = true,
        errorMessage = null;

  const DocumentValidationResult.failure(this.errorMessage)
      : isValid = false,
        mimeType = '';
}

/// Strict client-side document validator enforcing 15MB limit, supported extensions,
/// and binary magic byte signatures (preventing corrupt or spoofed uploads).
class DocumentFileValidator {
  static const int maxFileSizeBytes = 15 * 1024 * 1024; // 15 Megabytes

  static DocumentValidationResult validate({
    required String filename,
    required List<int> bytes,
    int? sizeBytes,
  }) {
    final effectiveSize = sizeBytes != null && sizeBytes > 0 ? sizeBytes : bytes.length;

    if (effectiveSize == 0 || bytes.isEmpty) {
      return const DocumentValidationResult.failure(
        'Selected file is empty (0 bytes). Please choose a valid soil test document.',
      );
    }

    if (effectiveSize > maxFileSizeBytes) {
      final mb = (effectiveSize / (1024 * 1024)).toStringAsFixed(1);
      return DocumentValidationResult.failure(
        'File size ($mb MB) exceeds the maximum 15 MB limit. Please select a smaller or compressed document.',
      );
    }

    final lower = filename.toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot != -1 ? lower.substring(dot) : '';

    if (ext == '.pdf') {
      if (!_isValidPdf(bytes)) {
        return const DocumentValidationResult.failure(
          'Invalid PDF document: file signature does not match the standard PDF format.',
        );
      }
      return const DocumentValidationResult.success('application/pdf');
    } else if (ext == '.jpg' || ext == '.jpeg') {
      if (!_isValidJpeg(bytes)) {
        return const DocumentValidationResult.failure(
          'Invalid JPEG image: file signature does not match the standard JPEG format.',
        );
      }
      return const DocumentValidationResult.success('image/jpeg');
    } else if (ext == '.png') {
      if (!_isValidPng(bytes)) {
        return const DocumentValidationResult.failure(
          'Invalid PNG image: file signature does not match the standard PNG format.',
        );
      }
      return const DocumentValidationResult.success('image/png');
    } else {
      return const DocumentValidationResult.failure(
        'Unsupported document format. Please upload a PDF (.pdf), JPEG (.jpg, .jpeg), or PNG (.png) file.',
      );
    }
  }

  static bool _isValidPdf(List<int> bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46) { // F
      return true;
    }
    // Search within first 1024 bytes for UTF-8 BOM or header comment
    final searchLimit = bytes.length < 1024 ? bytes.length : 1024;
    for (int i = 0; i <= searchLimit - 4; i++) {
      if (bytes[i] == 0x25 &&
          bytes[i + 1] == 0x50 &&
          bytes[i + 2] == 0x44 &&
          bytes[i + 3] == 0x46) {
        return true;
      }
    }
    return false;
  }

  static bool _isValidJpeg(List<int> bytes) {
    // JPEG SOI marker: 0xFF 0xD8 0xFF
    return bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
  }

  static bool _isValidPng(List<int> bytes) {
    // PNG magic header: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }
}

/// Representation of a selected document file before uploading.
class UploadDocumentFile {
  final String name;
  final List<int> bytes;
  final String mimeType;
  final int sizeBytes;

  const UploadDocumentFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
    required this.sizeBytes,
  });

  bool get isPdf =>
      name.toLowerCase().endsWith('.pdf') || mimeType.toLowerCase().contains('pdf');

  bool get isImage =>
      name.toLowerCase().endsWith('.png') ||
      name.toLowerCase().endsWith('.jpg') ||
      name.toLowerCase().endsWith('.jpeg') ||
      mimeType.toLowerCase().contains('image');

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Typedef for custom file picker handler (used for test automation and headless execution).
typedef CustomFilePicker = Future<UploadDocumentFile?> Function();

/// Screen enabling farmers to upload physical laboratory soil test documents (PDF/images)
/// using the native device/browser file picker, with 15MB client-side validation,
/// magic-byte signature verification, sample metadata, and animated upload/processing states.
class SoilReportUploadScreen extends StatefulWidget {
  final String farmId;
  final SoilLabNotifier? notifier;
  final CustomFilePicker? customFilePicker;

  const SoilReportUploadScreen({
    super.key,
    required this.farmId,
    this.notifier,
    this.customFilePicker,
  });

  @override
  State<SoilReportUploadScreen> createState() => _SoilReportUploadScreenState();
}

class _SoilReportUploadScreenState extends State<SoilReportUploadScreen> {
  late final SoilLabNotifier _notifier;
  bool _ownsNotifier = false;

  UploadDocumentFile? _selectedFile;
  String? _clientValidationError;

  final _labNameController = TextEditingController();
  final _samplingPointController = TextEditingController();
  String _sampleDepth = 'Not specified';
  DateTime? _sampleDate;

  final List<String> _depthOptions = [
    'Not specified',
    '0-15cm',
    '15-30cm',
    '0-30cm',
    '30-60cm',
    'Custom Depth',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.notifier != null) {
      _notifier = widget.notifier!;
    } else {
      _notifier = SoilLabNotifier(farmId: widget.farmId);
      _ownsNotifier = true;
    }
  }

  @override
  void dispose() {
    _labNameController.dispose();
    _samplingPointController.dispose();
    if (_ownsNotifier) {
      _notifier.dispose();
    }
    super.dispose();
  }

  void _processSelectedFile({
    required String filename,
    required List<int> bytes,
    required int sizeBytes,
    String? fallbackMime,
  }) {
    final validation = DocumentFileValidator.validate(
      filename: filename,
      bytes: bytes,
      sizeBytes: sizeBytes,
    );

    setState(() {
      final effectiveMime = validation.isValid
          ? validation.mimeType
          : (fallbackMime ?? 'application/octet-stream');

      _selectedFile = UploadDocumentFile(
        name: filename,
        bytes: bytes,
        mimeType: effectiveMime,
        sizeBytes: sizeBytes > 0 ? sizeBytes : bytes.length,
      );
      _clientValidationError = validation.errorMessage;
    });
  }

  void _clearFile() {
    setState(() {
      _selectedFile = null;
      _clientValidationError = null;
    });
  }

  Future<void> _pickFile() async {
    try {
      if (widget.customFilePicker != null) {
        final file = await widget.customFilePicker!();
        if (file != null) {
          _processSelectedFile(
            filename: file.name,
            bytes: file.bytes,
            sizeBytes: file.sizeBytes,
            fallbackMime: file.mimeType,
          );
        }
        return;
      }

      // Native browser/device file picker with platform-appropriate handling
      PlatformFile? picked;
      if (kIsWeb) {
        try {
          picked = await pickDocumentNative(
            allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
          );
        } catch (e) {
          debugPrint('Native web file picker error: $e');
        }
      } else {
        try {
          picked = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
          );
        } catch (_) {
          try {
            final files = await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
            );
            if (files.isNotEmpty) {
              picked = files.first;
            }
          } catch (_) {}
        }
      }

      // User cancelled picker dialog -> maintain existing state gracefully
      if (picked == null) {
        return;
      }

      final bytes = await picked.readAsBytes();
      final size = picked.lengthSync() ?? bytes.length;

      _processSelectedFile(
        filename: picked.name,
        bytes: bytes,
        sizeBytes: size,
        fallbackMime: null,
      );
    } catch (e) {
      setState(() {
        _clientValidationError = 'Failed to select document: $e';
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _sampleDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Select Sample Collection Date',
    );
    if (picked != null) {
      setState(() => _sampleDate = picked);
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedFile == null || _clientValidationError != null) return;

    final isSpecified = _sampleDepth.isNotEmpty && _sampleDepth != 'Not specified';
    final effectiveDepth = isSpecified ? _sampleDepth : null;
    final depthProv = isSpecified ? 'FARMER_PROVIDED' : 'UNKNOWN';

    final response = await _notifier.uploadReport(
      fileBytes: _selectedFile!.bytes,
      fileName: _selectedFile!.name,
      mimeType: _selectedFile!.mimeType,
      laboratoryName: _labNameController.text.trim().isNotEmpty
          ? _labNameController.text.trim()
          : null,
      sampleDepth: effectiveDepth,
      depthProvenance: depthProv,
      sampleCollectionDate: _sampleDate,
      samplingPointName: _samplingPointController.text.trim().isNotEmpty
          ? _samplingPointController.text.trim()
          : null,
    );

    if (!mounted) return;

    if (response != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report "${_selectedFile!.name}" uploaded successfully!'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );

      // Navigate to review screen
      final reportId = response.reportId;
      if (reportId.isNotEmpty) {
        context.go(RoutePaths.soilLabReportReviewPath(widget.farmId, reportId));
      } else {
        context.go(RoutePaths.soilLabHistoryPath(widget.farmId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Upload Soil Test Report'),
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.soilDetailPath(widget.farmId));
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Report History',
                onPressed: () => context.go(RoutePaths.soilLabHistoryPath(widget.farmId)),
              ),
            ],
          ),
          body: CenteredPageContainer.readable(
            scrollable: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 16),
                _buildUploadDropzone(),
                if (_clientValidationError != null) ...[
                  const SizedBox(height: 12),
                  _buildValidationErrorBanner(_clientValidationError!),
                ],
                if (_notifier.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildServerErrorBanner(_notifier.errorMessage!),
                ],
                const SizedBox(height: 20),
                _buildMetadataForm(),
                const SizedBox(height: 24),
                if (_notifier.isUploading || _notifier.isProcessing)
                  _buildProgressCard()
                else
                  _buildUploadButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFC8E6C9), width: 1.2),
      ),
      color: const Color(0xFFF1F8E9),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              radius: 20,
              child: Icon(Icons.science, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Physical Laboratory Ground Truth',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Upload your official laboratory soil test (Soil Health Card or accredited lab certificate). '
                    'Extracted bioavailable nutrients (Available N, P2O5, K2O) unlock precision fertilizer dosing '
                    'and verify crop suitability without relying on spatial estimates.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadDropzone() {
    final file = _selectedFile;
    if (file == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RashkarUploadDropzone(
            title: 'Upload Soil Test Document',
            subtitle: 'Supports PDF, JPEG, or PNG up to 15 MB · Soil Health Card or accredited lab report',
            icon: Icons.upload_file_rounded,
            isBusy: _notifier.isUploading || _notifier.isProcessing,
            onPrimaryTap: _pickFile,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.folder_open_outlined, size: 19),
            label: const Text('Browse Document'),
          ),
        ],
      );
    }

    return RashkarCard(
      padding: const EdgeInsets.all(18),
      borderColor: _clientValidationError == null ? RashkarColors.forest : RashkarColors.extremeBar,
      borderWidth: 1.8,
      child: Row(
        children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: file.isPdf ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                  child: Icon(
                    file.isPdf ? Icons.picture_as_pdf : Icons.image,
                    color: file.isPdf ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              file.formattedSize,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              file.isPdf ? 'PDF Document' : 'Image Scan',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: (_notifier.isUploading || _notifier.isProcessing) ? null : _pickFile,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Change'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF2E7D32)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  tooltip: 'Remove selected document',
                  onPressed: (_notifier.isUploading || _notifier.isProcessing) ? null : _clearFile,
                ),
              ],
            ),
    );
  }

  Widget _buildValidationErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFC62828), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFBF360C)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _notifier.clearErrors,
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataForm() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sample & Laboratory Metadata (Optional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Providing metadata improves extraction accuracy and report cross-validation.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sampleDepth,
                    decoration: const InputDecoration(
                      labelText: 'Sample Depth Interval',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: _depthOptions
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _sampleDepth = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Collection Date',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        _sampleDate != null
                            ? '${_sampleDate!.year}-${_sampleDate!.month.toString().padLeft(2, '0')}-${_sampleDate!.day.toString().padLeft(2, '0')}'
                            : 'Select date',
                        style: TextStyle(
                          color: _sampleDate != null ? Colors.black87 : Colors.black45,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _labNameController,
              decoration: const InputDecoration(
                labelText: 'Testing Laboratory Name',
                hintText: 'e.g. Pune District Soil Testing Laboratory',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                prefixIcon: Icon(Icons.business, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _samplingPointController,
              decoration: const InputDecoration(
                labelText: 'Sampling Point / Parcel Name',
                hintText: 'e.g. North Plot - Block A',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                prefixIcon: Icon(Icons.place_outlined, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final progress = _notifier.uploadProgress;
    final percent = (progress * 100).toInt();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 12),
                Text(
                  _notifier.isUploading ? 'Uploading Document ($percent%)' : 'Processing OCR Extraction...',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
              ),
            ),
            const SizedBox(height: 14),
            _buildProcessingStep(
              title: '1. Secure Document Storage',
              subtitle: 'Encrypted transfer to private cloud storage',
              isCompleted: progress >= 0.5,
              isActive: progress < 0.5,
            ),
            const SizedBox(height: 8),
            _buildProcessingStep(
              title: '2. Multi-Modal Vision & OCR Analysis',
              subtitle: 'Extracting tabular nutrient metrics via GLM-OCR',
              isCompleted: progress >= 0.9,
              isActive: progress >= 0.5 && progress < 0.9,
            ),
            const SizedBox(height: 8),
            _buildProcessingStep(
              title: '3. Agronomic Verification Guardrails',
              subtitle: 'Isolating bioavailable NPK from total elemental counts',
              isCompleted: progress >= 1.0,
              isActive: progress >= 0.9,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
  }) {
    return Row(
      children: [
        Icon(
          isCompleted
              ? Icons.check_circle
              : (isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked),
          color: isCompleted
              ? const Color(0xFF2E7D32)
              : (isActive ? const Color(0xFF1565C0) : Colors.grey.shade400),
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.black87 : (isCompleted ? Colors.black87 : Colors.black45),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton() {
    final canUpload = _selectedFile != null &&
        _clientValidationError == null &&
        !_notifier.isUploading &&
        !_notifier.isProcessing;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: canUpload ? _handleUpload : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.cloud_upload),
        label: const Text(
          'Upload & Extract Soil Parameters',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
