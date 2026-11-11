import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/rashkar_colors.dart';
import 'rashkar_ui.dart';

/// Single point rendered on [RashkarTempRiskBandChart].
class RashkarChartSeriesPoint {
  final String label;
  final double primaryValue;
  final double? secondaryValue;

  const RashkarChartSeriesPoint({
    required this.label,
    required this.primaryValue,
    this.secondaryValue,
  });
}

/// Dual-line chart with horizontal risk-zone background bands inspired by the
/// Figma Weather Advanced View (`Temperature & humidity` chart).
class RashkarTempRiskBandChart extends StatelessWidget {
  final List<RashkarChartSeriesPoint> points;
  final String primaryLegend;
  final String secondaryLegend;
  final double height;
  final double? highThreshold;
  final double? extremeThreshold;

  const RashkarTempRiskBandChart({
    super.key,
    required this.points,
    this.primaryLegend = 'Temperature',
    this.secondaryLegend = 'Humidity',
    this.height = 190,
    this.highThreshold = 36,
    this.extremeThreshold = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _legendChip(
              color: RashkarColors.forest,
              label: primaryLegend,
              isDashed: false,
            ),
            if (points.any((p) => p.secondaryValue != null))
              _legendChip(
                color: RashkarColors.skyFg,
                label: secondaryLegend,
                isDashed: true,
              ),
            _legendChip(
              color: RashkarColors.extremeBg,
              label: 'Heat risk zones',
              isBand: true,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _TempRiskPainter(
              points: points,
              highThreshold: highThreshold,
              extremeThreshold: extremeThreshold,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Widget _legendChip({
    required Color color,
    required String label,
    bool isDashed = false,
    bool isBand = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isBand)
          Container(
            width: 12,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: RashkarColors.extremeBorder),
            ),
          )
        else
          Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
            child: isDashed
                ? const Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Colors.white),
                      child: SizedBox(width: 4, height: 3),
                    ),
                  )
                : null,
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: RashkarColors.mutedInk,
          ),
        ),
      ],
    );
  }
}

class _TempRiskPainter extends CustomPainter {
  final List<RashkarChartSeriesPoint> points;
  final double? highThreshold;
  final double? extremeThreshold;

  _TempRiskPainter({
    required this.points,
    this.highThreshold,
    this.extremeThreshold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 36.0;
    const rightPad = 12.0;
    const topPad = 14.0;
    const bottomPad = 26.0;

    final chartRect = Rect.fromLTWH(
      leftPad,
      topPad,
      (size.width - leftPad - rightPad).clamp(10.0, size.width),
      (size.height - topPad - bottomPad).clamp(10.0, size.height),
    );

    final primaries = points.map((e) => e.primaryValue).toList();
    final minVal = (primaries.reduce((a, b) => a < b ? a : b) - 3).floorToDouble();
    final maxVal = (primaries.reduce((a, b) => a > b ? a : b) + 3).ceilToDouble();
    final span = (maxVal - minVal).abs() < 4 ? 8.0 : (maxVal - minVal);

    double yForPrimary(double v) {
      final norm = ((v - minVal) / span).clamp(0.0, 1.0);
      return chartRect.bottom - norm * chartRect.height;
    }

    // Horizontal heat risk zone bands
    if (extremeThreshold != null && extremeThreshold! < maxVal) {
      final topY = chartRect.top;
      final extY = yForPrimary(extremeThreshold!).clamp(chartRect.top, chartRect.bottom);
      if (extY > topY) {
        canvas.drawRect(
          Rect.fromLTRB(chartRect.left, topY, chartRect.right, extY),
          Paint()..color = RashkarColors.extremeBg.withValues(alpha: 0.7),
        );
      }
    }
    if (highThreshold != null && highThreshold! < maxVal) {
      final topY = extremeThreshold != null
          ? yForPrimary(extremeThreshold!).clamp(chartRect.top, chartRect.bottom)
          : chartRect.top;
      final highY = yForPrimary(highThreshold!).clamp(chartRect.top, chartRect.bottom);
      if (highY > topY) {
        canvas.drawRect(
          Rect.fromLTRB(chartRect.left, topY, chartRect.right, highY),
          Paint()..color = RashkarColors.marigoldTint.withValues(alpha: 0.75),
        );
      }
    }

    // Horizontal subtle grid lines + Y-axis labels
    final gridPaint = Paint()
      ..color = RashkarColors.border
      ..strokeWidth = 1;
    const steps = 4;
    for (int i = 0; i <= steps; i++) {
      final frac = i / steps;
      final y = chartRect.bottom - frac * chartRect.height;
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);
      final labelVal = (minVal + frac * span).round();
      final tp = TextPainter(
        text: TextSpan(
          text: '$labelVal°',
          style: const TextStyle(
            fontSize: 10.5,
            color: RashkarColors.subtleInk,
            fontFeatures: [ui.FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    double xForIndex(int idx) {
      if (points.length <= 1) return chartRect.center.dx;
      return chartRect.left + (idx / (points.length - 1)) * chartRect.width;
    }

    // Dashed secondary series (humidity scaled 0..100 into chartRect height)
    final hasSec = points.any((p) => p.secondaryValue != null);
    if (hasSec) {
      final secPaint = Paint()
        ..color = RashkarColors.skyFg.withValues(alpha: 0.8)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < points.length - 1; i++) {
        final v1 = points[i].secondaryValue;
        final v2 = points[i + 1].secondaryValue;
        if (v1 == null || v2 == null) continue;
        final p1 = Offset(xForIndex(i), chartRect.bottom - (v1.clamp(0, 100) / 100.0) * chartRect.height);
        final p2 = Offset(xForIndex(i + 1), chartRect.bottom - (v2.clamp(0, 100) / 100.0) * chartRect.height);
        _drawDashedLine(canvas, p1, p2, secPaint);
      }
    }

    // Primary smooth line + dot markers
    final primaryPath = Path();
    for (int i = 0; i < points.length; i++) {
      final x = xForIndex(i);
      final y = yForPrimary(points[i].primaryValue);
      if (i == 0) {
        primaryPath.moveTo(x, y);
      } else {
        primaryPath.lineTo(x, y);
      }
    }
    canvas.drawPath(
      primaryPath,
      Paint()
        ..color = RashkarColors.forest
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    final dotFill = Paint()..color = RashkarColors.forest;
    final dotStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final labelStep = (points.length / 6).ceil().clamp(1, points.length);
    for (int i = 0; i < points.length; i++) {
      final x = xForIndex(i);
      final y = yForPrimary(points[i].primaryValue);
      canvas.drawCircle(Offset(x, y), 3.6, dotFill);
      canvas.drawCircle(Offset(x, y), 3.6, dotStroke);

      if (i % labelStep == 0 || i == points.length - 1) {
        final tp = TextPainter(
          text: TextSpan(
            text: points[i].label,
            style: const TextStyle(fontSize: 10, color: RashkarColors.mutedInk),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            (x - tp.width / 2).clamp(chartRect.left, chartRect.right - tp.width),
            chartRect.bottom + 6,
          ),
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    final total = (b - a).distance;
    if (total <= 0) return;
    const dash = 4.0;
    const gap = 3.5;
    double cur = 0;
    final dir = (b - a) / total;
    while (cur < total) {
      final end = (cur + dash).clamp(0.0, total);
      canvas.drawLine(a + dir * cur, a + dir * end, paint);
      cur += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TempRiskPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.highThreshold != highThreshold ||
        oldDelegate.extremeThreshold != extremeThreshold;
  }
}

/// Bar entry for [RashkarThresholdBarChart] (`Weather record` / monthly cashflow).
class RashkarBarPoint {
  final String label;
  final double value;
  final String? valueText;
  final Color? color;

  const RashkarBarPoint({
    required this.label,
    required this.value,
    this.valueText,
    this.color,
  });
}

/// Rounded pill vertical bar chart with optional dashed horizontal threshold cutoff
/// inspired by Figma `Weather record` (`figma_25_result_scrolled`).
class RashkarThresholdBarChart extends StatelessWidget {
  final List<RashkarBarPoint> bars;
  final double? thresholdValue;
  final String? thresholdLabel;
  final double height;

  const RashkarThresholdBarChart({
    super.key,
    required this.bars,
    this.thresholdValue,
    this.thresholdLabel,
    this.height = 148,
  });

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();

    final maxAbs = bars
        .map((b) => b.value.abs())
        .fold<double>(1.0, (a, b) => a > b ? a : b);
    final effectiveMax = (thresholdValue != null && thresholdValue! > maxAbs)
        ? thresholdValue! * 1.1
        : maxAbs * 1.15;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          if (thresholdValue != null && thresholdValue! >= 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24 + ((thresholdValue! / effectiveMax) * (height - 48)).clamp(0, height - 48),
              child: Row(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final count = (constraints.maxWidth / 8).floor().clamp(4, 60);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            count,
                            (_) => Container(
                              width: 4,
                              height: 1.5,
                              color: RashkarColors.extremeBar,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (thresholdLabel != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      thresholdLabel!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: RashkarColors.extremeBar,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: bars.map((b) {
              final ratio = (b.value.abs() / effectiveMax).clamp(0.08, 1.0);
              final isNeg = b.value < 0;
              final barColor = b.color ??
                  (isNeg
                      ? RashkarColors.highBar
                      : (thresholdValue != null && b.value >= thresholdValue!
                          ? RashkarColors.extremeBar
                          : RashkarColors.forest));
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        b.valueText ?? b.value.toStringAsFixed(0),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: RashkarColors.ink,
                          fontFeatures: [ui.FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: (ratio * (height - 48)).clamp(8.0, height - 48),
                        constraints: const BoxConstraints(maxWidth: 34),
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                            bottom: Radius.circular(5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        b.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: RashkarColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Horizontal interval bar row inspired by Figma `Risk every 30 minutes` (`figma_18_weather_scrolled`).
class RashkarHorizontalRiskRow extends StatelessWidget {
  final String timeLabel;
  final double progress; // 0.0 .. 1.0
  final String valueText;
  final String severity;

  const RashkarHorizontalRiskRow({
    super.key,
    required this.timeLabel,
    required this.progress,
    required this.valueText,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    final style = RashkarColors.severityFor(severity);
    final pct = progress.clamp(0.1, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              timeLabel,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: RashkarColors.ink,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: RashkarColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(999),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct,
                child: Container(
                  decoration: BoxDecoration(
                    color: style.bar,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 48,
            child: Text(
              valueText,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: RashkarColors.ink,
                fontFeatures: [ui.FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerRight,
              child: RashkarSeverityBadge.fromRisk(severity, compact: true),
            ),
          ),
        ],
      ),
    );
  }
}

/// Healthy -> Stressed satellite gradient bar legend (`figma_25_result_scrolled`).
class RashkarVegetationLegendBar extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;

  const RashkarVegetationLegendBar({
    super.key,
    this.leftLabel = 'Healthy',
    this.rightLabel = 'Stressed',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          leftLabel,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: RashkarColors.forest,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(colors: RashkarColors.vegetationRamp),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          rightLabel,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: RashkarColors.extremeBar,
          ),
        ),
      ],
    );
  }
}
