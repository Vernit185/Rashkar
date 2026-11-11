import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../shared/theme/rashkar_colors.dart';
import '../../../../shared/widgets/centered_page_container.dart';
import '../../models/soil_lab_models.dart';
import '../state/soil_lab_notifier.dart';

/// Screen allowing farmers to browse past uploaded soil test reports for a farm,
/// filter by status, inspect sample depths and dates, and jump into review or upload.
class SoilReportHistoryScreen extends StatefulWidget {
  final String farmId;
  final SoilLabNotifier? notifier;

  const SoilReportHistoryScreen({
    super.key,
    required this.farmId,
    this.notifier,
  });

  @override
  State<SoilReportHistoryScreen> createState() => _SoilReportHistoryScreenState();
}

class _SoilReportHistoryScreenState extends State<SoilReportHistoryScreen> {
  late final SoilLabNotifier _notifier;
  bool _ownsNotifier = false;

  SoilReportStatus? _filterStatus;

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
      _notifier.loadReports();
    });
  }

  @override
  void dispose() {
    if (_ownsNotifier) {
      _notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        final allReports = _notifier.reports;
        final filteredReports = _filterStatus == null
            ? allReports
            : allReports.where((r) => r.status == _filterStatus).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Soil Test Report History'),
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
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => _notifier.loadReports(),
              ),
              IconButton(
                icon: const Icon(Icons.upload_file),
                tooltip: 'Upload Report',
                onPressed: () => context.go(RoutePaths.soilLabUploadPath(widget.farmId)),
              ),
            ],
          ),
          body: CenteredPageContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(),
                const SizedBox(height: 16),
                _buildFilterChips(allReports),
                const SizedBox(height: 16),
                Expanded(
                  child: _notifier.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _notifier.errorMessage != null
                          ? _buildErrorView(_notifier.errorMessage!)
                          : filteredReports.isEmpty
                              ? _buildEmptyView(allReports.isEmpty)
                              : _buildReportList(filteredReports),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.go(RoutePaths.soilLabUploadPath(widget.farmId)),
            backgroundColor: RashkarColors.forest,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Upload New Report'),
          ),
        );
      },
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            radius: 18,
            child: Icon(Icons.science, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Physical Soil Laboratory Archive',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'All uploaded soil health cards and laboratory test certificates for this farm. '
                  'Confirmed reports directly inform crop suitability and fertilizer recommendations.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(List<SoilReportSummary> allReports) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: Text('All (${allReports.length})'),
            selected: _filterStatus == null,
            onSelected: (_) => setState(() => _filterStatus = null),
            selectedColor: const Color(0xFFC8E6C9),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(
              'Confirmed (${allReports.where((r) => r.status == SoilReportStatus.confirmed).length})',
            ),
            selected: _filterStatus == SoilReportStatus.confirmed,
            onSelected: (_) => setState(() => _filterStatus = SoilReportStatus.confirmed),
            selectedColor: const Color(0xFFC8E6C9),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(
              'Needs Review (${allReports.where((r) => r.status == SoilReportStatus.needsReview).length})',
            ),
            selected: _filterStatus == SoilReportStatus.needsReview,
            onSelected: (_) => setState(() => _filterStatus = SoilReportStatus.needsReview),
            selectedColor: const Color(0xFFFFE0B2),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(
              'Processing (${allReports.where((r) => r.status == SoilReportStatus.processing).length})',
            ),
            selected: _filterStatus == SoilReportStatus.processing,
            onSelected: (_) => setState(() => _filterStatus = SoilReportStatus.processing),
            selectedColor: const Color(0xFFBBDEFB),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(bool isCompletelyEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.science_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              isCompletelyEmpty
                  ? 'No Physical Soil Test Reports Uploaded'
                  : 'No reports matching this filter',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              isCompletelyEmpty
                  ? 'ISRIC SoilGrids provides estimated physical properties, but cannot quantify '
                      'bioavailable plant nutrients (Available N, P, K). Upload your official Soil Health '
                      'Card or lab certificate to unlock precision fertilizer recommendations.'
                  : 'Try selecting a different status filter above.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.go(RoutePaths.soilLabUploadPath(widget.farmId)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Soil Test Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _notifier.loadReports(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportList(List<SoilReportSummary> reports) {
    return ListView.builder(
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final item = reports[index];
        return _buildReportSummaryCard(item);
      },
    );
  }

  Widget _buildReportSummaryCard(SoilReportSummary report) {
    final isPdf = report.filename.toLowerCase().endsWith('.pdf');

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: report.status == SoilReportStatus.confirmed
              ? const Color(0xFF81C784)
              : Colors.grey.shade300,
          width: report.status == SoilReportStatus.confirmed ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          context.go(RoutePaths.soilLabReportReviewPath(widget.farmId, report.id));
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: isPdf ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                    radius: 20,
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.image,
                      color: isPdf ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.filename,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          report.laboratoryName ?? 'Official Soil Testing Laboratory',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(report.status),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildInfoPill(
                    Icons.layers_outlined,
                    'Depth: ${report.sampleDepth ?? "0-15cm"}',
                  ),
                  const SizedBox(width: 8),
                  _buildInfoPill(
                    Icons.calendar_today_outlined,
                    report.sampleDate != null
                        ? '${report.sampleDate!.year}-${report.sampleDate!.month.toString().padLeft(2, '0')}-${report.sampleDate!.day.toString().padLeft(2, '0')}'
                        : report.uploadTimestamp.toLocal().toString().split(' ').first,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoPill(
                    Icons.biotech_outlined,
                    '${report.measurementCount} Metrics',
                  ),
                ],
              ),
              if (report.keyMetrics.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: report.keyMetrics.entries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F8E9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFC8E6C9)),
                      ),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      context.go(RoutePaths.soilLabReportReviewPath(widget.farmId, report.id));
                    },
                    icon: Icon(
                      report.status == SoilReportStatus.confirmed
                          ? Icons.visibility
                          : Icons.rate_review,
                      size: 16,
                    ),
                    label: Text(
                      report.status == SoilReportStatus.confirmed
                          ? 'View Confirmed Report'
                          : 'Review & Confirm',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: report.status == SoilReportStatus.confirmed
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE65100),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.black54),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 10.5),
      ),
    );
  }
}
