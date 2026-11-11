import 'package:flutter/material.dart';

import '../../../../shared/theme/rashkar_colors.dart';
import '../../../../shared/widgets/app_decorations.dart';
import '../../../../shared/widgets/app_spacing.dart';
import '../../../../shared/widgets/rashkar_ui.dart';
import '../../models/scheme_models.dart';

/// Colour and icon accent for each scheme category.
Color schemeCategoryColor(String category) {
  switch (category) {
    case 'Crop Insurance':
      return const Color(0xFF00695C);
    case 'Financial Assistance':
      return const Color(0xFF2E7D32);
    case 'Loans':
      return const Color(0xFF1565C0);
    case 'Irrigation':
      return const Color(0xFF0277BD);
    case 'Soil Health':
      return const Color(0xFF5D4037);
    case 'Machinery':
      return const Color(0xFF546E7A);
    case 'Seeds & Fertilizers':
      return const Color(0xFF6A1B9A);
    case 'Infrastructure':
      return const Color(0xFFE65100);
    case 'State Schemes':
      return const Color(0xFFAD1457);
    default:
      return AppDecorations.leafGreen;
  }
}

IconData schemeCategoryIcon(String category) {
  switch (category) {
    case 'Crop Insurance':
      return Icons.shield_outlined;
    case 'Financial Assistance':
      return Icons.account_balance_wallet_outlined;
    case 'Loans':
      return Icons.credit_card_outlined;
    case 'Irrigation':
      return Icons.water_drop_outlined;
    case 'Soil Health':
      return Icons.science_outlined;
    case 'Machinery':
      return Icons.agriculture_outlined;
    case 'Seeds & Fertilizers':
      return Icons.grass_outlined;
    case 'Infrastructure':
      return Icons.warehouse_outlined;
    case 'State Schemes':
      return Icons.location_city_outlined;
    default:
      return Icons.account_balance_outlined;
  }
}

/// A compact Government Scheme card shown in the dashboard grid.
class SchemeCard extends StatelessWidget {
  final GovernmentScheme scheme;
  final VoidCallback onTap;

  const SchemeCard({super.key, required this.scheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return RashkarCard(
      padding: AppSpacing.paddingAllMD,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: RashkarColors.softMint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: RashkarColors.paleSage),
                ),
                child: Icon(schemeCategoryIcon(scheme.category), size: 20, color: RashkarColors.forest),
              ),
              AppSpacing.horizontalSpaceSM,
              Expanded(
                child: Text(
                  scheme.schemeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: RashkarColors.ink,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.verticalSpaceSM,
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _chip(scheme.category, isPrimary: true),
              _chip(scheme.governmentLevel, isPrimary: false),
              if (scheme.state != null && scheme.state!.isNotEmpty)
                _chip(scheme.state!, isPrimary: false),
              if (!scheme.isVerified) _chip('Not verified', isWarning: true),
            ],
          ),
          if (scheme.description != null && scheme.description!.isNotEmpty) ...[
            AppSpacing.verticalSpaceSM,
            Text(
              scheme.description!,
              style: const TextStyle(fontSize: 13, color: RashkarColors.mutedInk, height: 1.35),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, {bool isPrimary = false, bool isWarning = false}) {
    Color bg = RashkarColors.canvas;
    Color fg = RashkarColors.mutedInk;
    Color border = RashkarColors.paleSage;

    if (isPrimary) {
      bg = RashkarColors.softMint;
      fg = RashkarColors.forestDark;
      border = RashkarColors.paleSage;
    } else if (isWarning) {
      bg = RashkarColors.marigoldTint;
      fg = RashkarColors.marigoldInk;
      border = RashkarColors.marigoldBorder;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppBorderRadius.pill,
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
