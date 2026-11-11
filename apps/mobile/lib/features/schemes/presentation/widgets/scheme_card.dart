import 'package:flutter/material.dart';
import '../../../../shared/theme/rashkar_tokens.dart';
import '../../../../shared/theme/rashkar_components.dart';
import '../../models/scheme_models.dart';

Color schemeCategoryColor(String category) {
  switch (category) {
    case 'Crop Insurance':
      return const Color(0xFF00695C);
    case 'Financial Assistance':
      return RashkarColors.forest;
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
      return RashkarColors.orange;
    case 'State Schemes':
      return const Color(0xFFAD1457);
    default:
      return RashkarColors.leaf;
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

/// RASHKAR Design Language - Government Scheme Card (Spec 2 & Section 4 List Pattern)
/// White, 1px line border, 18px radius, no shadow.
class SchemeCard extends StatelessWidget {
  final GovernmentScheme scheme;
  final VoidCallback onTap;

  const SchemeCard({super.key, required this.scheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = scheme.isVerified ? RashkarStatusLevel.low : RashkarStatusLevel.moderate;

    return RashkarCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 44px Icon tile
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: RashkarColors.leafSoft,
                  borderRadius: RashkarRadii.iconTileBorderRadius,
                ),
                child: Icon(
                  schemeCategoryIcon(scheme.category),
                  size: 22,
                  color: RashkarColors.forest,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scheme.schemeName,
                      style: RashkarTypography.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${scheme.category} • ${scheme.governmentLevel}',
                      style: RashkarTypography.meta,
                    ),
                  ],
                ),
              ),
              RashkarStatusPill(status: status),
            ],
          ),
          if (scheme.description != null && scheme.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              scheme.description!,
              style: RashkarTypography.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          // Progress bar / Meta indicators
          Row(
            children: [
              if (scheme.state != null && scheme.state!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  margin: const EdgeInsets.only(right: 6.0),
                  decoration: const BoxDecoration(
                    color: RashkarColors.sand,
                    borderRadius: RashkarRadii.pillBorderRadius,
                  ),
                  child: Text(
                    scheme.state!,
                    style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600, color: RashkarColors.ink),
                  ),
                ),
              const Spacer(),
              const Text(
                'View Details',
                style: TextStyle(
                  fontFamily: RashkarTypography.primaryFont,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                  color: RashkarColors.forest,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: RashkarColors.forest),
            ],
          ),
        ],
      ),
    );
  }
}
