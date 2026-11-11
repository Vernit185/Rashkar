import 'package:flutter/material.dart';
import 'package:cropnet_mobile/shared/theme/rashkar_tokens.dart';

// ==========================================
// 1. BUTTON (Spec 1)
// Variants: primary, secondary, ghost, danger, accent
// Full width or flexible, 56px min height, 16px radius, 16px/600, optional leading icon (10px gap)
// ==========================================
enum RashkarButtonVariant { primary, secondary, ghost, danger, accent }

class RashkarButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final RashkarButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;

  const RashkarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.variant = RashkarButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    BorderSide borderSide = BorderSide.none;

    switch (variant) {
      case RashkarButtonVariant.primary:
        bgColor = RashkarColors.forest;
        textColor = RashkarColors.white;
        break;
      case RashkarButtonVariant.secondary:
        bgColor = RashkarColors.white;
        textColor = RashkarColors.forest;
        borderSide = const BorderSide(color: Color(0x26214E34), width: 2.0); // 2px forest-15%
        break;
      case RashkarButtonVariant.ghost:
        bgColor = Colors.transparent;
        textColor = RashkarColors.forest;
        break;
      case RashkarButtonVariant.danger:
        bgColor = RashkarColors.risk;
        textColor = RashkarColors.white;
        break;
      case RashkarButtonVariant.accent:
        bgColor = RashkarColors.amber;
        textColor = RashkarColors.ink;
        break;
    }

    if (onPressed == null && !isLoading) {
      bgColor = RashkarColors.disabled;
      textColor = RashkarColors.white;
      borderSide = BorderSide.none;
    }

    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        else ...[
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 20, color: textColor),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: RashkarTypography.primaryFont,
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ],
    );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: RashkarSpacing.primaryButtonHeight,
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: RashkarRadii.buttonBorderRadius,
          side: borderSide,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. CARD (Spec 2)
// White, 1px #E6E6DC line border, 18px radius, NO shadow
// If clickable, hover/press border goes to forest at 30%
// ==========================================
class RashkarCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;

  const RashkarCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(RashkarSpacing.cardPadding),
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? RashkarColors.white,
        borderRadius: RashkarRadii.cardBorderRadius,
        border: Border.all(
          color: borderColor ?? RashkarColors.line,
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: RashkarRadii.cardBorderRadius,
          splashColor: const Color(0x1A214E34), // 10% forest
          highlightColor: const Color(0x0D214E34),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. PAGE HEADER (Top-level screens) (Spec 3)
// 26px/800 title, muted subtitle, optional 48px icon button on right
// ==========================================
class RashkarPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? rightIcon;
  final VoidCallback? onRightIconTap;

  const RashkarPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.rightIcon,
    this.onRightIconTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: RashkarSpacing.pageHeaderPadding,
        right: RashkarSpacing.pageHeaderPadding,
        top: 20.0,
        bottom: 12.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: RashkarTypography.pageTitle),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: RashkarTypography.meta),
                ],
              ],
            ),
          ),
          if (rightIcon != null)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: RashkarColors.white,
                borderRadius: RashkarRadii.buttonBorderRadius,
                border: Border.all(color: RashkarColors.line, width: 1.0),
              ),
              child: IconButton(
                icon: Icon(rightIcon, color: RashkarColors.ink, size: 22),
                onPressed: onRightIconTap,
              ),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. TOP BAR (Sub-pages) (Spec 4)
// Sticky cream bg with 48px bordered white back button, 19px/700 title + subtitle
// ==========================================
class RashkarTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  const RashkarTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  @override
  Size get preferredSize => const Size.fromHeight(68.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: RashkarColors.cream,
        border: Border(bottom: BorderSide(color: RashkarColors.line, width: 1.0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: RashkarColors.white,
                borderRadius: RashkarRadii.buttonBorderRadius,
                border: Border.all(color: RashkarColors.line, width: 1.0),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: RashkarColors.ink, size: 22),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RashkarTypography.sectionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: RashkarTypography.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. BRANDED HERO (Dashboard) (Spec 6)
// Forest header with wordmark "RASHKAR", greeting, bell (red badge), context-switcher chip
// ==========================================
class RashkarBrandedHero extends StatelessWidget {
  final String farmName;
  final String greeting;
  final VoidCallback? onSwitchFarm;
  final VoidCallback? onNotificationsTap;
  final int unreadCount;

  const RashkarBrandedHero({
    super.key,
    required this.farmName,
    this.greeting = 'Good morning, Farmer',
    this.onSwitchFarm,
    this.onNotificationsTap,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RashkarColors.forest,
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 96.0), // 80px+ overlap area for status card
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Wordmark: Uppercase, 800 weight, 0.14em spacing
                const Text('RASHKAR', style: RashkarTypography.wordmark),
                Row(
                  children: [
                    // Notification Bell with red badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0x1AFFFFFF), // 10% white
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.notifications_none_rounded, color: RashkarColors.white, size: 22),
                            onPressed: onNotificationsTap,
                          ),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: RashkarColors.risk,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              greeting,
              style: const TextStyle(
                fontFamily: RashkarTypography.primaryFont,
                fontSize: 22.0,
                fontWeight: FontWeight.w700,
                color: RashkarColors.white,
              ),
            ),
            const SizedBox(height: 12),
            // Context switcher chip: white at 12%, rounded-full, thumbnail, chevron
            Material(
              color: const Color(0x1FFFFFFF), // 12% white
              borderRadius: RashkarRadii.pillBorderRadius,
              child: InkWell(
                onTap: onSwitchFarm,
                borderRadius: RashkarRadii.pillBorderRadius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: RashkarColors.leaf,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.landscape_rounded, size: 14, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        farmName,
                        style: const TextStyle(
                          fontFamily: RashkarTypography.primaryFont,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: RashkarColors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 7. STATUS HERO CARD (Spec 7)
// Top tinted with status soft color, 64px colored icon tile, big status word (34px/900),
// "Level X/4", hero number, 4-segment meter, explanation with 4px colored accent bar,
// footer with "Updated N min ago"
// ==========================================
class RashkarStatusHeroCard extends StatelessWidget {
  final RashkarStatusLevel status;
  final String heroNumber;
  final String heroUnit;
  final String explanation;
  final String updatedTime;

  const RashkarStatusHeroCard({
    super.key,
    required this.status,
    required this.heroNumber,
    this.heroUnit = '',
    required this.explanation,
    this.updatedTime = 'Updated just now',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RashkarColors.white,
        borderRadius: RashkarRadii.heroCardBorderRadius,
        border: Border.all(color: RashkarColors.line, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top tinted area with soft color
          Container(
            color: status.softColor,
            padding: const EdgeInsets.all(18.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 64px colored icon tile
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: status.color,
                    borderRadius: RashkarRadii.iconTileBorderRadius,
                  ),
                  child: Icon(status.icon, color: Colors.white, size: 34),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.label,
                        style: TextStyle(
                          fontFamily: RashkarTypography.primaryFont,
                          fontSize: 28.0,
                          fontWeight: FontWeight.w900,
                          color: status.textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Level ${status.level}/4',
                        style: TextStyle(
                          fontFamily: RashkarTypography.primaryFont,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: status.textColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                // Hero metric on right
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      heroNumber,
                      style: RashkarTypography.heroMetric.copyWith(color: status.textColor),
                    ),
                    if (heroUnit.isNotEmpty)
                      Text(
                        heroUnit,
                        style: TextStyle(
                          fontFamily: RashkarTypography.primaryFont,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: status.textColor,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Body content
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 4-segment meter
                RashkarFourSegmentMeter(level: status.level, activeColor: status.color),
                const SizedBox(height: 16),
                // Explanation with 4px colored accent bar
                Container(
                  padding: const EdgeInsets.only(left: 12.0),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: status.color, width: 4.0)),
                  ),
                  child: Text(
                    explanation,
                    style: RashkarTypography.body,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(updatedTime, style: RashkarTypography.meta),
                    const RashkarListenButton(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 8. 4-SEGMENT METER (Spec 7 & 8)
// 4-segment meter (filled segments = level)
// ==========================================
class RashkarFourSegmentMeter extends StatelessWidget {
  final int level; // 1 to 4
  final Color activeColor;

  const RashkarFourSegmentMeter({
    super.key,
    required this.level,
    this.activeColor = RashkarColors.forest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(4, (i) {
            final isFilled = i < level;
            return Expanded(
              child: Container(
                height: 8,
                margin: EdgeInsets.only(right: i < 3 ? 6.0 : 0.0),
                decoration: BoxDecoration(
                  color: isFilled ? activeColor : RashkarColors.sand,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Low', style: TextStyle(fontSize: 11, color: RashkarColors.muted, fontWeight: FontWeight.w500)),
            Text('Moderate', style: TextStyle(fontSize: 11, color: RashkarColors.muted, fontWeight: FontWeight.w500)),
            Text('High', style: TextStyle(fontSize: 11, color: RashkarColors.muted, fontWeight: FontWeight.w500)),
            Text('Extreme', style: TextStyle(fontSize: 11, color: RashkarColors.muted, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}

// ==========================================
// 9. STATUS PILL (Spec 8)
// Soft background, dark status text, icon plus uppercase label
// ==========================================
class RashkarStatusPill extends StatelessWidget {
  final RashkarStatusLevel status;

  const RashkarStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: status.softColor,
        borderRadius: RashkarRadii.pillBorderRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.textColor),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontFamily: RashkarTypography.primaryFont,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: status.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 10. ACTION LIST CARD (Spec 9)
// Rows with 48px leaf-soft icon tile, 15px/600 title, 12px meta, chevron, dividers
// ==========================================
class RashkarActionItem {
  final IconData icon;
  final String title;
  final String meta;
  final VoidCallback onTap;

  const RashkarActionItem({
    required this.icon,
    required this.title,
    required this.meta,
    required this.onTap,
  });
}

class RashkarActionListCard extends StatelessWidget {
  final String sectionTitle;
  final List<RashkarActionItem> actions;

  const RashkarActionListCard({
    super.key,
    this.sectionTitle = 'What should you do?',
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return RashkarCard(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(sectionTitle, style: RashkarTypography.cardTitle),
              const RashkarListenButton(),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final action = actions[index];
              return InkWell(
                onTap: action.onTap,
                borderRadius: RashkarRadii.buttonBorderRadius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Row(
                    children: [
                      // 48px leaf-soft icon tile
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: RashkarColors.leafSoft,
                          borderRadius: RashkarRadii.iconTileBorderRadius,
                        ),
                        child: Icon(action.icon, color: RashkarColors.forest, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action.title,
                              style: const TextStyle(
                                fontFamily: RashkarTypography.primaryFont,
                                fontSize: 15.0,
                                fontWeight: FontWeight.w600,
                                color: RashkarColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(action.meta, style: RashkarTypography.meta),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: RashkarColors.muted, size: 22),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 11. TIMELINE STRIP (Spec 10)
// Grid of period cells (label, icon, value, small colored status circle, tiny label)
// Current cell has cream background and bold label
// ==========================================
class RashkarTimelineCell {
  final String label;
  final IconData icon;
  final String value;
  final RashkarStatusLevel status;
  final bool isCurrent;

  const RashkarTimelineCell({
    required this.label,
    required this.icon,
    required this.value,
    required this.status,
    this.isCurrent = false,
  });
}

class RashkarTimelineStrip extends StatelessWidget {
  final List<RashkarTimelineCell> cells;

  const RashkarTimelineStrip({super.key, required this.cells});

  @override
  Widget build(BuildContext context) {
    return RashkarCard(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: cells.map((cell) {
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
              decoration: BoxDecoration(
                color: cell.isCurrent ? RashkarColors.cream : Colors.transparent,
                borderRadius: RashkarRadii.buttonBorderRadius,
                border: cell.isCurrent ? Border.all(color: RashkarColors.line, width: 1.0) : null,
              ),
              child: Column(
                children: [
                  Text(
                    cell.label,
                    style: TextStyle(
                      fontFamily: RashkarTypography.primaryFont,
                      fontSize: 12.0,
                      fontWeight: cell.isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: cell.isCurrent ? RashkarColors.forest : RashkarColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(cell.icon, size: 20, color: RashkarColors.ink),
                  const SizedBox(height: 6),
                  Text(
                    cell.value,
                    style: const TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: RashkarColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: cell.status.color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(cell.status.icon, size: 11, color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ==========================================
// 12. BAR ROW (Spec 11)
// label | rounded bar filled in status color | value | icon + status text
// ==========================================
class RashkarBarRow extends StatelessWidget {
  final String label;
  final double fraction; // 0.0 to 1.0
  final String valueText;
  final RashkarStatusLevel status;

  const RashkarBarRow({
    super.key,
    required this.label,
    required this.fraction,
    required this.valueText,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: RashkarColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 8,
                color: RashkarColors.sand,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(color: status.color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 50,
            child: Text(
              valueText,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w700, color: RashkarColors.ink),
            ),
          ),
          const SizedBox(width: 8),
          Icon(status.icon, size: 15, color: status.color),
        ],
      ),
    );
  }
}

// ==========================================
// 13. VERTICAL PROGRESS TRACKER (Spec 12)
// 48px step tiles (Done=forest check, Active=white w/ 2px forest border, Waiting=sand w/ grey icon)
// 2px connector line
// ==========================================
enum RashkarStepState { done, active, waiting }

class RashkarStepItem {
  final String title;
  final String explanation;
  final String timestamp;
  final RashkarStepState state;

  const RashkarStepItem({
    required this.title,
    required this.explanation,
    required this.timestamp,
    required this.state,
  });
}

class RashkarVerticalProgressTracker extends StatelessWidget {
  final List<RashkarStepItem> steps;

  const RashkarVerticalProgressTracker({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        Widget tile;
        Color pillBg;
        Color pillText;
        String pillLabel;

        switch (step.state) {
          case RashkarStepState.done:
            tile = Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: RashkarColors.forest,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
            );
            pillBg = RashkarColors.leafSoft;
            pillText = RashkarColors.forest;
            pillLabel = 'DONE';
            break;
          case RashkarStepState.active:
            tile = Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: RashkarColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: RashkarColors.forest, width: 2.5),
              ),
              child: const Icon(Icons.sync_rounded, color: RashkarColors.forest, size: 24),
            );
            pillBg = RashkarColors.infoSoft;
            pillText = RashkarColors.infoText;
            pillLabel = 'IN PROGRESS';
            break;
          case RashkarStepState.waiting:
            tile = Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: RashkarColors.sand,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.schedule_rounded, color: RashkarColors.muted, size: 24),
            );
            pillBg = RashkarColors.sand;
            pillText = RashkarColors.muted;
            pillLabel = 'WAITING';
            break;
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  tile,
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2.0,
                        color: RashkarColors.line,
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(step.title, style: RashkarTypography.cardTitle),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                            decoration: BoxDecoration(
                              color: pillBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              pillLabel,
                              style: TextStyle(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                                color: pillText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(step.explanation, style: RashkarTypography.body),
                      const SizedBox(height: 4),
                      Text(step.timestamp, style: RashkarTypography.meta),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ==========================================
// 14. SEGMENTED CONTROL (Spec 15)
// Sand track with 4px padding, selected segment white with subtle shadow, 48px tall
// ==========================================
class RashkarSegmentedControl<T> extends StatelessWidget {
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelected;

  const RashkarSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4.0),
      decoration: const BoxDecoration(
        color: RashkarColors.sand,
        borderRadius: RashkarRadii.buttonBorderRadius,
      ),
      child: Row(
        children: options.entries.map((entry) {
          final isSelected = entry.key == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? RashkarColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x14243329),
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontFamily: RashkarTypography.primaryFont,
                    fontSize: 14.0,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? RashkarColors.forest : RashkarColors.muted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ==========================================
// 15. TOGGLE (Spec 16)
// 52x32, forest when on, #CFD3C9 when off
// ==========================================
class RashkarToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const RashkarToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 32,
        padding: const EdgeInsets.all(3.0),
        decoration: BoxDecoration(
          color: value ? RashkarColors.forest : const Color(0xFFCFD3C9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 16. NOTICES (Spec 21)
// Info (#F2F5EC w/ info icon), Warning/Disclaimer (amberSoft w/ 2px amber border), Error (riskSoft, bold)
// ==========================================
enum RashkarNoticeType { info, warning, error }

class RashkarNotice extends StatelessWidget {
  final String message;
  final RashkarNoticeType type;
  final String? title;

  const RashkarNotice({
    super.key,
    required this.message,
    this.type = RashkarNoticeType.info,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Border? border;
    Color iconColor;
    Color textColor;
    IconData icon;

    switch (type) {
      case RashkarNoticeType.info:
        bg = const Color(0xFFF2F5EC);
        iconColor = RashkarColors.forest;
        textColor = RashkarColors.ink;
        icon = Icons.info_outline_rounded;
        break;
      case RashkarNoticeType.warning:
        bg = RashkarColors.amberSoft;
        border = Border.all(color: RashkarColors.amber, width: 2.0);
        iconColor = RashkarColors.amberText;
        textColor = RashkarColors.amberText;
        icon = Icons.warning_amber_rounded;
        break;
      case RashkarNoticeType.error:
        bg = RashkarColors.riskSoft;
        iconColor = RashkarColors.riskText;
        textColor = RashkarColors.riskText;
        icon = Icons.error_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: RashkarRadii.cardBorderRadius,
        border: border,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      fontFamily: RashkarTypography.primaryFont,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: RashkarTypography.primaryFont,
                    fontSize: 14.0,
                    fontWeight: type == RashkarNoticeType.error ? FontWeight.w600 : FontWeight.w400,
                    color: textColor,
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

// ==========================================
// 17. EMPTY STATE (Spec 22)
// Centered in card: 64px sand icon tile, 17px/700 title, one muted sentence, optional action
// ==========================================
class RashkarEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const RashkarEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return RashkarCard(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: RashkarColors.sand,
                borderRadius: RashkarRadii.iconTileBorderRadius,
              ),
              child: Icon(icon, size: 32, color: RashkarColors.muted),
            ),
            const SizedBox(height: 16),
            Text(title, style: RashkarTypography.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: RashkarTypography.body.copyWith(color: RashkarColors.muted),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              RashkarButton(
                label: actionLabel!,
                onPressed: onAction,
                fullWidth: false,
                variant: RashkarButtonVariant.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 18. LISTEN BUTTON (Spec 24)
// Leaf-soft pill with speaker icon and "Listen"
// ==========================================
class RashkarListenButton extends StatefulWidget {
  final VoidCallback? onListen;

  const RashkarListenButton({super.key, this.onListen});

  @override
  State<RashkarListenButton> createState() => _RashkarListenButtonState();
}

class _RashkarListenButtonState extends State<RashkarListenButton> {
  bool _isSpeaking = false;

  void _handleTap() {
    setState(() => _isSpeaking = !_isSpeaking);
    widget.onListen?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _isSpeaking ? RashkarColors.forest : RashkarColors.leafSoft,
      borderRadius: RashkarRadii.pillBorderRadius,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: RashkarRadii.pillBorderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isSpeaking ? Icons.pause_rounded : Icons.volume_up_rounded,
                size: 16,
                color: _isSpeaking ? Colors.white : RashkarColors.forest,
              ),
              const SizedBox(width: 6),
              Text(
                _isSpeaking ? 'Pause' : 'Listen',
                style: TextStyle(
                  fontFamily: RashkarTypography.primaryFont,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: _isSpeaking ? Colors.white : RashkarColors.forest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 19. PRELIMINARY AI BADGE (Rule 5 & Section 2)
// Amber "Preliminary" tag
// ==========================================
class RashkarPreliminaryBadge extends StatelessWidget {
  const RashkarPreliminaryBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: RashkarColors.amberSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: RashkarColors.amber, width: 1.0),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: RashkarColors.amberText),
          SizedBox(width: 4),
          Text(
            'PRELIMINARY AI',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: RashkarColors.amberText,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 20. FLOATING ACTION BUTTON (Spec 25)
// 64px amber circle, ink icon, bottom-right above nav
// Shadow: 0 6px 18px rgba(36,51,41,0.25)
// ==========================================
class RashkarFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const RashkarFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip = 'Action',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: RashkarColors.amber,
        shape: BoxShape.circle,
        boxShadow: RashkarShadows.fabAndToast,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(icon, size: 28, color: RashkarColors.ink),
          ),
        ),
      ),
    );
  }
}
