import 'package:flutter/material.dart';

import '../../core/router/farm_state.dart';
import '../../main.dart';
import '../theme/rashkar_colors.dart';

/// Rashkar stylized sprouting seed / crop emblem badge matching the Figma header.
class RashkarLogoBadge extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final bool darkBackground;

  const RashkarLogoBadge({
    super.key,
    this.size = 34,
    this.showWordmark = false,
    this.darkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: darkBackground ? RashkarColors.forestTint : RashkarColors.forestTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.eco_rounded,
          color: Colors.white,
          size: size * 0.60,
        ),
      ),
    );

    if (!showWordmark) return badge;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rashkar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: darkBackground ? Colors.white : RashkarColors.ink,
                ),
              ),
              Text(
                'Farmer Service',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: darkBackground
                      ? RashkarColors.forestTextMuted
                      : RashkarColors.mutedInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Clean AgriNova-inspired card with pale sage border and subtle surface styling.
class RashkarCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final bool selected;
  final VoidCallback? onTap;

  const RashkarCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.borderRadius = 12,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = selected
        ? RashkarColors.forest
        : (borderColor ?? RashkarColors.border);
    final effectiveWidth = selected ? 1.5 : borderWidth;
    final effectiveBg = backgroundColor ?? (selected ? RashkarColors.softMint : RashkarColors.surface);

    return Material(
      color: effectiveBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: effectiveBorder, width: effectiveWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// AgriNova-inspired clean, spacious hero banner with gentle mint background and crisp dark typography.
class RashkarHeroBanner extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? topRight;
  final Widget? farmSelector;
  final List<Widget> footerChildren;
  final EdgeInsetsGeometry padding;
  final bool lightMode;

  const RashkarHeroBanner({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.topRight,
    this.farmSelector,
    this.footerChildren = const [],
    this.padding = const EdgeInsets.all(22),
    this.lightMode = true,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = lightMode ? RashkarColors.ink : Colors.white;
    final subtitleColor = lightMode ? RashkarColors.mutedInk : RashkarColors.forestTextMuted;
    final eyebrowColor = lightMode ? RashkarColors.forest : RashkarColors.forestTextMuted;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: lightMode ? RashkarColors.softMint : RashkarColors.forest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: lightMode ? RashkarColors.paleSage : RashkarColors.forestDark,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null && eyebrow!.isNotEmpty) ...[
                      Text(
                        eyebrow!,
                        style: TextStyle(
                          color: eyebrowColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (topRight != null) ...[
                const SizedBox(width: 12),
                topRight!,
              ],
            ],
          ),
          if (farmSelector != null) ...[
            const SizedBox(height: 14),
            farmSelector!,
          ],
          if (footerChildren.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: footerChildren,
            ),
          ],
        ],
      ),
    );
  }
}

/// Editorial screen header bar inside the warm cream canvas for desktop/web screens.
class RashkarScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  const RashkarScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (onBack != null) ...[
          Material(
            color: RashkarColors.surface,
            shape: const CircleBorder(
              side: BorderSide(color: RashkarColors.border),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.arrow_back_rounded, size: 20, color: RashkarColors.ink),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

/// Pill badge matching Figma's HIGH / EXTREME / MODERATE / LOW / Checking / Result ready pills.
class RashkarSeverityBadge extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;
  final Color borderColor;
  final IconData? icon;
  final bool compact;

  const RashkarSeverityBadge({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    required this.borderColor,
    this.icon,
    this.compact = false,
  });

  factory RashkarSeverityBadge.fromRisk(
    String? severity, {
    String? customLabel,
    bool compact = false,
  }) {
    final style = RashkarColors.severityFor(severity);
    return RashkarSeverityBadge(
      label: customLabel ?? style.label,
      foreground: style.foreground,
      background: style.background,
      borderColor: style.border,
      icon: style.icon,
      compact: compact,
    );
  }

  factory RashkarSeverityBadge.info(String label, {IconData? icon, bool compact = false}) {
    return RashkarSeverityBadge(
      label: label,
      foreground: RashkarColors.skyFg,
      background: RashkarColors.skyBg,
      borderColor: RashkarColors.skyBorder,
      icon: icon ?? Icons.info_outline,
      compact: compact,
    );
  }

  factory RashkarSeverityBadge.success(String label, {IconData? icon, bool compact = false}) {
    return RashkarSeverityBadge(
      label: label,
      foreground: RashkarColors.lowFg,
      background: RashkarColors.lowBg,
      borderColor: RashkarColors.lowBorder,
      icon: icon ?? Icons.check_circle_outline,
      compact: compact,
    );
  }

  factory RashkarSeverityBadge.marigold(String label, {IconData? icon, bool compact = false}) {
    return RashkarSeverityBadge(
      label: label,
      foreground: RashkarColors.ink,
      background: RashkarColors.marigold,
      borderColor: RashkarColors.marigoldBorder,
      icon: icon,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 11,
        vertical: compact ? 3.5 : 5.5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12.5 : 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: compact ? 10.5 : 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 4-band severity gauge (`LOW | MODERATE | HIGH | EXTREME`) inspired by the Figma Home hero card.
class RashkarRiskMeter extends StatelessWidget {
  final String? severity;
  final bool showLabels;
  final List<String> customLabels;

  const RashkarRiskMeter({
    super.key,
    required this.severity,
    this.showLabels = true,
    this.customLabels = const ['LOW', 'MODERATE', 'HIGH', 'EXTREME'],
  });

  @override
  Widget build(BuildContext context) {
    final activeStyle = RashkarColors.severityFor(severity);
    final activeIdx = activeStyle.levelIndex - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(4, (i) {
            final band = RashkarColors.severityBands[i];
            final isActive = i == activeIdx;
            final isFilled = i <= activeIdx;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
                child: Container(
                  height: isActive ? 12 : 8,
                  decoration: BoxDecoration(
                    color: isFilled ? band.bar : RashkarColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(4),
                    border: isActive
                        ? Border.all(color: band.foreground, width: 1.5)
                        : null,
                  ),
                ),
              ),
            );
          }),
        ),
        if (showLabels) ...[
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (i) {
              final isActive = i == activeIdx;
              final band = RashkarColors.severityBands[i];
              return Expanded(
                child: Text(
                  customLabels[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : (i == 3 ? TextAlign.right : TextAlign.center),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive ? band.foreground : RashkarColors.mutedInk,
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// 10-segment pill meter ("How sure are we?" / profile completion / checks completed).
class RashkarConfidenceSegments extends StatelessWidget {
  final int filledCount;
  final int totalSegments;
  final Color? fillColor;

  const RashkarConfidenceSegments({
    super.key,
    required this.filledCount,
    this.totalSegments = 10,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = fillColor ?? RashkarColors.forest;
    final clamped = filledCount.clamp(0, totalSegments);

    return Row(
      children: List.generate(totalSegments, (index) {
        final filled = index < clamped;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < totalSegments - 1 ? 5 : 0),
            child: Container(
              height: 9,
              decoration: BoxDecoration(
                color: filled ? activeColor : RashkarColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 2x2 Weather / Field KPI tile matching the Figma Weather metric tiles.
class RashkarMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color? iconBg;
  final Color? iconColor;

  const RashkarMetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.iconBg,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return RashkarCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 12,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg ?? RashkarColors.mintBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor ?? RashkarColors.forest),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: RashkarColors.mutedInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: RashkarColors.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (caption != null && caption!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: RashkarColors.mutedInk,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grouped key-value indicator row card ("Farm indicators" pattern from Figma Advanced Weather).
class RashkarIndicatorListCard extends StatelessWidget {
  final String? title;
  final List<MapEntry<String, String>> rows;

  const RashkarIndicatorListCard({
    super.key,
    this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title!.isNotEmpty) ...[
          Text(
            title!,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
        ],
        RashkarCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: List.generate(rows.length, (i) {
              final row = rows[i];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.key,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: RashkarColors.mutedInk,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            row.value,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: RashkarColors.ink,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < rows.length - 1) const Divider(height: 1),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// Action recommendation card with numbered step pill, time window, toggleable completion,
/// and optional expandable details (`figma_15_actions`).
class RashkarActionCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String? subtitle;
  final String? timeWindow;
  final IconData icon;
  final bool isDone;
  final VoidCallback? onToggleDone;
  final String? technicalDetail;

  const RashkarActionCard({
    super.key,
    required this.stepNumber,
    required this.title,
    this.subtitle,
    this.timeWindow,
    this.icon = Icons.check_circle_outline,
    this.isDone = false,
    this.onToggleDone,
    this.technicalDetail,
  });

  @override
  Widget build(BuildContext context) {
    return RashkarCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: isDone ? RashkarColors.mintBg.withValues(alpha: 0.45) : RashkarColors.surface,
      borderColor: isDone ? RashkarColors.mintBorder : RashkarColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDone ? RashkarColors.forest : RashkarColors.mintBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '$stepNumber',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: RashkarColors.forest,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: RashkarColors.ink,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: RashkarColors.mutedInk,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: RashkarColors.mintBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: RashkarColors.forest),
              ),
            ],
          ),
          if (timeWindow != null || onToggleDone != null || technicalDetail != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (timeWindow != null && timeWindow!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: RashkarColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 13, color: RashkarColors.mutedInk),
                        const SizedBox(width: 5),
                        Text(
                          timeWindow!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: RashkarColors.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (onToggleDone != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      backgroundColor: isDone ? RashkarColors.forest : RashkarColors.surface,
                      foregroundColor: isDone ? Colors.white : RashkarColors.forest,
                      side: BorderSide(
                        color: isDone ? RashkarColors.forest : RashkarColors.border,
                      ),
                    ),
                    onPressed: onToggleDone,
                    icon: Icon(isDone ? Icons.check_rounded : Icons.done, size: 15),
                    label: Text(
                      isDone ? 'Completed' : 'Mark as done',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            if (technicalDetail != null && technicalDetail!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                technicalDetail!,
                style: const TextStyle(fontSize: 12, color: RashkarColors.subtleInk),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Deep pine hero upload card (`Take photo of crop` / `Upload Soil Test Report`) with
/// marigold gold circular icon badge.
class RashkarUploadDropzone extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPrimaryTap;
  final bool isBusy;

  const RashkarUploadDropzone({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.camera_alt_outlined,
    required this.onPrimaryTap,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RashkarColors.softMint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: RashkarColors.paleSage, width: 1.2),
      ),
      child: InkWell(
        onTap: isBusy ? null : onPrimaryTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: RashkarColors.forest,
                  shape: BoxShape.circle,
                ),
                child: isBusy
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon, size: 26, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RashkarColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RashkarColors.mutedInk,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma warm marigold notice callout ("Please note" / scientific provenance caveat).
class RashkarNoticeCallout extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final bool isDanger;

  const RashkarNoticeCallout({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDanger ? RashkarColors.extremeBg : RashkarColors.marigoldTint;
    final border = isDanger ? RashkarColors.extremeBorder : RashkarColors.marigoldBorder;
    final fg = isDanger ? RashkarColors.extremeFg : RashkarColors.marigoldInk;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDanger ? RashkarColors.extremeFg : RashkarColors.ink,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-step segmented header (`Step 2 / 4` + horizontal progress segments + step labels).
class RashkarStepProgress extends StatelessWidget {
  final int currentStep; // 0-indexed
  final List<String> stepLabels;
  final ValueChanged<int>? onStepTap;

  const RashkarStepProgress({
    super.key,
    required this.currentStep,
    required this.stepLabels,
    this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(stepLabels.length, (i) {
            final activeOrDone = i <= currentStep;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < stepLabels.length - 1 ? 6 : 0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onStepTap != null ? () => onStepTap!(i) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: activeOrDone
                              ? RashkarColors.forest
                              : RashkarColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${i + 1}. ${stepLabels[i]}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              i == currentStep ? FontWeight.w800 : FontWeight.w600,
                          color: i == currentStep
                              ? RashkarColors.ink
                              : RashkarColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Connected vertical verification/history step tile (`figma_16_claim_result`).
class RashkarTimelineStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? timestamp;
  final String statusLabel;
  final bool isCompleted;
  final bool isLast;

  const RashkarTimelineStep({
    super.key,
    required this.title,
    required this.subtitle,
    this.timestamp,
    this.statusLabel = 'Done',
    this.isCompleted = true,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = isCompleted ? RashkarColors.forest : RashkarColors.skyFg;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_outline : Icons.schedule,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: RashkarColors.mintTrack,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: RashkarCard(
                padding: const EdgeInsets.all(14),
                borderRadius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: RashkarColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        isCompleted
                            ? RashkarSeverityBadge.success(statusLabel, compact: true)
                            : RashkarSeverityBadge.info(statusLabel, compact: true),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: RashkarColors.mutedInk,
                        height: 1.4,
                      ),
                    ),
                    if (timestamp != null && timestamp!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        timestamp!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: RashkarColors.subtleInk,
                        ),
                      ),
                    ],
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

/// Interactive plot selector pill button (`Nadi Kath Plot · 2.5 acres v`) wired to
/// [FarmRepository] so active plot stays synchronized across every Rashkar & CropNet module.
class RashkarFarmPickerButton extends StatelessWidget {
  final List<FarmItem> farms;
  final String? selectedFarmId;
  final ValueChanged<FarmItem> onSelected;
  final bool overDarkHero;

  const RashkarFarmPickerButton({
    super.key,
    required this.farms,
    required this.selectedFarmId,
    required this.onSelected,
    this.overDarkHero = false,
  });

  @override
  Widget build(BuildContext context) {
    if (farms.isEmpty) {
      return const SizedBox.shrink();
    }

    final current = farms.firstWhere(
      (f) => f.id == selectedFarmId,
      orElse: () => farms.first,
    );

    final bg = overDarkHero ? RashkarColors.forestTint : RashkarColors.surface;
    final fg = overDarkHero ? Colors.white : RashkarColors.ink;
    final border = overDarkHero
        ? Colors.white.withValues(alpha: 0.16)
        : RashkarColors.border;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showRashkarFarmPickerModal(
          context: context,
          farms: farms,
          selectedFarmId: current.id,
          onSelected: onSelected,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 18,
                color: overDarkHero ? Colors.white : RashkarColors.forest,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${current.name} (${current.areaAcres.toStringAsFixed(1)} acres)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal "Choose farm" switcher recreating `figma_31_plot_switcher`.
Future<void> showRashkarFarmPickerModal({
  required BuildContext context,
  required List<FarmItem> farms,
  required String? selectedFarmId,
  required ValueChanged<FarmItem> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: RashkarColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Center(
          widthFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: RashkarColors.borderStrong,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Choose farm',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: RashkarColors.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: farms.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final f = farms[idx];
                        final isSelected = f.id == selectedFarmId;
                        return RashkarCard(
                          selected: isSelected,
                          padding: const EdgeInsets.all(14),
                          onTap: () {
                            FarmRepository.instance.selectFarm(f.id);
                            onSelected(f);
                            Navigator.of(ctx).pop();
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: RashkarColors.mintBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.spa_outlined,
                                  color: RashkarColors.forest,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: RashkarColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${f.taluka}, ${f.district} · ${f.areaAcres.toStringAsFixed(2)} acres',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: RashkarColors.mutedInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: RashkarColors.forest,
                                  size: 22,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
