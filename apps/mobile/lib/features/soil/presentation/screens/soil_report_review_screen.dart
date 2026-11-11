import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../shared/responsive/breakpoints.dart';
import '../../models/soil_lab_models.dart';
import '../state/soil_lab_notifier.dart';

/// Screen for reviewing, editing/correcting, and explicitly confirming
/// laboratory measurements extracted from an uploaded soil test report.
///
/// Responsive Layout:
/// - Desktop (>1024px): Side-by-side dual panel (Left: Document Preview, Right: Parameter Audit & Correction)
/// - Tablet & Mobile (<=1024px): Tabbed layout (Tab 1: Document Preview, Tab 2: Extracted Values)
class SoilReportReviewScreen extends StatefulWidget {
  final String farmId;
  final String reportId;
  final SoilLabNotifier? notifier;

  const SoilReportReviewScreen({
    super.key,
    required this.farmId,
    required this.reportId,
    this.notifier,
  });

  @override
  State<SoilReportReviewScreen> createState() => _SoilReportReviewScreenState();
}

class _SoilReportReviewScreenState extends State<SoilReportReviewScreen> {
  late final SoilLabNotifier _notifier;
  bool _ownsNotifier = false;

  // Track which measurement is currently expanded for inline editing
  String? _editingMeasurementId;
  final _editValueController = TextEditingController();
  final _editUnitController = TextEditingController();
  final _editDepthController = TextEditingController();
  final _editNotesController = TextEditingController();
  DateTime? _editDate;

  @override
  void initState() {
    super.initState();
    if (widget.notifier != null) {
      _notifier = widget.notifier!;
    } else {
      _notifier = SoilLabNotifier(farmId: widget.farmId);
      _ownsNotifier = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifier.loadReportDetail(widget.reportId);
    });
  }

  @override
  void dispose() {
    _editValueController.dispose();
    _editUnitController.dispose();
    _editDepthController.dispose();
    _editNotesController.dispose();
    if (_ownsNotifier) {
      _notifier.dispose();
    }
    super.dispose();
  }

  void _startEditing(SoilMeasurementItem item) {
    setState(() {
      _editingMeasurementId = item.id;
      _editValueController.text =
          item.effectiveValue != null ? item.effectiveValue.toString() : '';
      _editUnitController.text = item.effectiveUnit;
      _editDepthController.text = item.sampleDepth ?? '';
      _editNotesController.text = item.farmerNotes ?? '';
      _editDate = item.testDate;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMeasurementId = null;
    });
  }

  void _applyBufferedEdit(SoilMeasurementItem item) {
    final parsedValue = double.tryParse(_editValueController.text.trim());
    final update = SoilMeasurementUpdate(
      measurementId: item.id,
      correctedValue: parsedValue,
      correctedUnit: _editUnitController.text.trim().isNotEmpty
          ? _editUnitController.text.trim()
          : item.originalUnit,
      sampleDepth: _editDepthController.text.trim().isNotEmpty
          ? _editDepthController.text.trim()
          : item.sampleDepth,
      testDate: _editDate,
      farmerNotes: _editNotesController.text.trim().isNotEmpty
          ? _editNotesController.text.trim()
          : null,
      verificationStatus: MeasurementVerificationStatus.farmerCorrected,
    );

    _notifier.bufferMeasurementEdit(item.id, update);

    setState(() {
      _editingMeasurementId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated "${item.displayName}" locally. Confirm below to finalize.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleConfirmTranscription() async {
    final success = await _notifier.confirmTranscription(widget.reportId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcription confirmed! Lab measurements activated in Soil Intelligence.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;

    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        final report = _notifier.activeReport;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              report != null ? 'Review: ${report.filename}' : 'Soil Report Review',
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.soilLabHistoryPath(widget.farmId));
                }
              },
            ),
            actions: [
              if (report != null) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: _buildStatusBadge(report.status),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reload Report',
                  onPressed: () => _notifier.loadReportDetail(widget.reportId),
                ),
              ],
            ],
          ),
          body: _notifier.isLoading && report == null
              ? const Center(child: CircularProgressIndicator())
              : report == null
                  ? _buildNotFoundView()
                  : isDesktop
                      ? _buildDesktopDualPanel(report)
                      : _buildMobileTabbedView(report),
        );
      },
    );
  }

  Widget _buildNotFoundView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_notifier.errorMessage ?? 'Report not found.'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _notifier.loadReportDetail(widget.reportId),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Desktop layout (> 1024px): Side-by-side 50/50 split view
  Widget _buildDesktopDualPanel(SoilReportDetail report) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel (50%): Document Viewer & Provenance
        Expanded(
          flex: 1,
          child: Container(
            color: const Color(0xFFF5F5F5),
            height: double.infinity,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _buildDocumentPreviewPanel(report),
            ),
          ),
        ),

        const VerticalDivider(width: 1, color: Colors.black12),

        // Right Panel (50%): Parameter Audit & Confirmation
        Expanded(
          flex: 1,
          child: SizedBox(
            height: double.infinity,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: _buildParameterAuditForm(report),
            ),
          ),
        ),
      ],
    );
  }

  /// Tablet & Mobile layout (<= 1024px): 2-Tab Controller with sticky actions
  Widget _buildMobileTabbedView(SoilReportDetail report) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: const Color(0xFF1B5E20),
              unselectedLabelColor: Colors.black54,
              indicatorColor: const Color(0xFF2E7D32),
              indicatorWeight: 3,
              tabs: [
                const Tab(
                  icon: Icon(Icons.description_outlined),
                  text: 'Document Preview',
                ),
                Tab(
                  icon: const Icon(Icons.biotech_outlined),
                  text: 'Extracted Metrics (${report.measurements.length})',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildDocumentPreviewPanel(report),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildParameterAuditForm(report),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Left / Tab 1: Document Preview Panel
  Widget _buildDocumentPreviewPanel(SoilReportDetail report) {
    final isPdf = report.mimeType.contains('pdf') || report.filename.toLowerCase().endsWith('.pdf');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Document Provenance Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.image,
                      color: isPdf ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        report.filename,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
                _buildMetadataRow('Laboratory', report.laboratoryName ?? 'Not reported'),
                _buildMetadataRow('Lab Number', report.labNumber ?? 'Not reported'),
                _buildMetadataRow(
                  'Date Received',
                  report.dateReceived != null ? _formatDate(report.dateReceived!) : 'Not reported',
                ),
                _buildMetadataRow(
                  'Date Processed',
                  report.dateProcessed != null ? _formatDate(report.dateProcessed!) : 'Not reported',
                ),
                _buildMetadataRow(
                  'Sample Collection Date',
                  report.sampleDate != null ? _formatDate(report.sampleDate!) : 'Not reported',
                ),
                _buildMetadataRow(
                  'Sample Depth',
                  report.sampleDepth != null
                      ? '${report.sampleDepth} (Source: ${report.depthProvenanceDisplay})'
                      : 'Not reported (Source: Unknown)',
                ),
                _buildMetadataRow(
                  'File Size',
                  '${(report.fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
                ),
                _buildMetadataRow(
                  'Uploaded On',
                  report.uploadTimestamp.toLocal().toString().split('.').first,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Document Viewer Canvas
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 380),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: report.documentUrl != null && !isPdf
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    report.documentUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _buildDocumentPlaceholder(report, isPdf),
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                )
              : _buildDocumentPlaceholder(report, isPdf),
        ),

        const SizedBox(height: 12),

        // External document action
        if (report.documentUrl != null)
          OutlinedButton.icon(
            onPressed: () {
              // On web, document link opens in fresh tab
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Document URL: ${report.documentUrl}'),
                  action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open Original Document in New Tab'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1B5E20),
              side: const BorderSide(color: Color(0xFF1B5E20)),
            ),
          ),
      ],
    );
  }

  Widget _buildDocumentPlaceholder(SoilReportDetail report, bool isPdf) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file_outlined,
            size: 64,
            color: isPdf ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
          ),
          const SizedBox(height: 14),
          Text(
            isPdf ? 'PDF Soil Health Card Preview' : 'Scanned Laboratory Report',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Document: ${report.filename}\nEncrypted in private tenant storage.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.3),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'OCR Multi-Modal Vision Processing Completed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Right / Tab 2: Parameter Audit, Correction Form & Explicit Confirmation
  Widget _buildParameterAuditForm(SoilReportDetail report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top instruction / warning banner
        if (report.isConfirmed)
          _buildConfirmedNotice(report)
        else
          _buildAuditRequiredNotice(),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Extracted Parameters (${report.measurements.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (!report.isConfirmed)
              TextButton.icon(
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Re-run OCR'),
                onPressed: () => _notifier.reprocess(report.id),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // List of extracted measurements
        if (report.measurements.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Text(
                'No parameters detected. Document may be low resolution or unsupported format.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          )
        else
          ...report.measurements.map((m) => _buildMeasurementCard(m, report.isConfirmed)),

        const SizedBox(height: 24),

        // Explicit Confirmation Section
        _buildConfirmationCard(report),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAuditRequiredNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFB74D), width: 1.2),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.rate_review, color: Color(0xFFE65100), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farmer Verification Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Color(0xFFE65100),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Compare each extracted nutrient value below against your original report. '
                  'You may correct any misread number, unit, or depth before confirming. '
                  'Unconfirmed measurements are strictly barred from agronomic evaluations.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5D4037), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmedNotice(SoilReportDetail report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF81C784), width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Color(0xFF2E7D32), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Farmer-Confirmed Laboratory Record',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Verified transcription active in Soil Intelligence. Confirmed on '
                  '${report.confirmedAt != null ? report.confirmedAt!.toLocal().toString().split('.').first : "recorded date"}.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF2E7D32)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementCard(SoilMeasurementItem item, bool isConfirmed) {
    final isEditing = _editingMeasurementId == item.id;
    final isCorrected = item.isFarmerCorrected;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isCorrected
              ? const Color(0xFF1565C0)
              : (item.isConfirmed ? const Color(0xFF2E7D32) : Colors.grey.shade300),
          width: isCorrected ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Builder(builder: (_) {
                        final details = <String>[
                          'Key: ${item.parameterKey}',
                          if (item.pageNumber != null) 'Page: ${item.pageNumber}',
                          if (item.sampleDesignation != null && item.sampleDesignation!.isNotEmpty)
                            'Sample: ${item.sampleDesignation}',
                          if (item.sampleDepth != null && item.sampleDepth!.isNotEmpty)
                            'Depth: ${item.sampleDepth}',
                        ];
                        return Text(
                          details.join(' • '),
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                        );
                      }),
                    ],
                  ),
                ),
                _buildVerificationBadge(item.verificationStatus),
              ],
            ),

            const SizedBox(height: 10),

            if (isEditing) ...[
              _buildInlineEditForm(item),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    item.effectiveValue != null ? item.effectiveValue.toString() : 'Not detected',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: item.effectiveValue != null ? const Color(0xFF1B5E20) : Colors.black45,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.effectiveUnit,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
                  ),
                  const Spacer(),
                  _buildConfidenceChip(item.extractionConfidence),
                ],
              ),

              if (item.analyticalMethod != null || item.labRating != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (item.analyticalMethod != null)
                      Text(
                        'Method: ${item.analyticalMethod}',
                        style: const TextStyle(fontSize: 11, color: Colors.black54, fontStyle: FontStyle.italic),
                      ),
                    if (item.labRating != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Rating: ${item.labRating}',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF00695C)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              if (item.farmerNotes != null && item.farmerNotes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Note: ${item.farmerNotes}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF1565C0)),
                ),
              ],

              if (!isConfirmed) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _startEditing(item),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit / Correct Value'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInlineEditForm(SoilMeasurementItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Farmer Correction Form',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _editValueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Corrected Value',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _editUnitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _editDepthController,
            decoration: const InputDecoration(
              labelText: 'Sample Depth Interval (e.g. 0-15cm)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _editNotesController,
            decoration: const InputDecoration(
              labelText: 'Correction Notes (optional)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _cancelEditing,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _applyBufferedEdit(item),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Apply Edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationCard(SoilReportDetail report) {
    if (report.isConfirmed) {
      return Card(
        color: const Color(0xFFF1F8E9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF81C784)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Transcription is fully confirmed. Bioavailable nutrients are integrated into farm advisory.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B5E20)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF81C784), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Text(
                  'Explicit Farmer Confirmation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'A farmer confirming the transcription confirms that the extracted values match the '
              'physical laboratory report. It does not independently authenticate the laboratory '
              'or validate the scientific method. Once confirmed, these laboratory measurements '
              'take precedence over geospatial digital estimates (ISRIC SoilGrids) for this farm.',
              style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.35),
            ),
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              child: CheckboxListTile(
                value: _notifier.confirmationAccepted,
                onChanged: _notifier.toggleConfirmationCheck,
                title: const Text(
                  'I confirm that I have reviewed these extracted measurements against my physical laboratory report.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _notifier.confirmationAccepted && !_notifier.isConfirming
                    ? _handleConfirmTranscription
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _notifier.isConfirming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _notifier.isConfirming
                      ? 'Confirming Transcription...'
                      : 'Confirm Transcription (Activate Lab Results)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(SoilReportStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case SoilReportStatus.confirmed:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case SoilReportStatus.needsReview:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
      case SoilReportStatus.processing:
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        break;
      case SoilReportStatus.failed:
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.black87;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildVerificationBadge(MeasurementVerificationStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case MeasurementVerificationStatus.farmerConfirmed:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case MeasurementVerificationStatus.farmerCorrected:
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        break;
      case MeasurementVerificationStatus.rejected:
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        break;
      default:
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFE65100);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 10.5),
      ),
    );
  }

  Widget _buildConfidenceChip(double confidence) {
    Color color;
    String label;
    final percent = (confidence * 100).toInt();

    if (confidence >= 0.85) {
      color = const Color(0xFF2E7D32);
      label = 'High ($percent%)';
    } else if (confidence >= 0.60) {
      color = const Color(0xFFE65100);
      label = 'Medium ($percent%)';
    } else {
      color = const Color(0xFFC62828);
      label = 'Low ($percent%)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 155,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
