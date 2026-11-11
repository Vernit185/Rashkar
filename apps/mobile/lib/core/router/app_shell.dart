import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cropnet_mobile/core/router/farm_state.dart';
import 'package:cropnet_mobile/core/router/route_paths.dart';
import 'package:cropnet_mobile/shared/theme/rashkar_colors.dart';
import 'package:cropnet_mobile/shared/widgets/rashkar_ui.dart';

/// Clean, farmer-first responsive navigation shell organized around everyday
/// farm tasks while keeping every backend module cleanly reachable.
class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = FarmRepository.instance;
      if (repo.farms.isEmpty && !repo.isLoading) {
        repo.loadFarms();
      }
    });
  }

  void _selectBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  String _currentUriPath(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return '';
    }
  }

  String _activePageTitle(BuildContext context) {
    final branch = widget.navigationShell.currentIndex;
    final path = _currentUriPath(context);
    switch (branch) {
      case 0:
        return 'Home';
      case 1:
        return 'Soil Check';
      case 2:
        return 'Crop Guide';
      case 3:
        return 'Weather Forecast';
      case 4:
        return 'Ask Rashkar';
      case 5:
        return 'History';
      case 6:
        return 'Government Help';
      case 7:
        return 'Crop Doctor';
      case 8:
        return path.contains('crop-heat') ? 'Crop Heat Risk' : 'Worker Heat Risk';
      case 9:
        return 'Earn More';
      default:
        return 'Rashkar';
    }
  }

  void _openSelectedFarmDetail(BuildContext context) {
    final repo = FarmRepository.instance;
    if (repo.farms.isEmpty) {
      _selectBranch(0);
      return;
    }
    final farmId = repo.selectedFarmId ?? repo.farms.first.id;
    context.push(RoutePaths.farmDetailPath(farmId));
  }

  void _openSelectedFarmHealth(BuildContext context) {
    final repo = FarmRepository.instance;
    if (repo.farms.isEmpty) {
      _selectBranch(0);
      return;
    }
    final farmId = repo.selectedFarmId ?? repo.farms.first.id;
    context.push(RoutePaths.farmHealthDashboardPath(farmId));
  }

  void _openMoreSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RashkarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetCtx) {
        Widget item({
          required IconData icon,
          required String title,
          String? subtitle,
          required bool selected,
          required VoidCallback onTap,
        }) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? RashkarColors.mintBg : RashkarColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? RashkarColors.forest : RashkarColors.ink,
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 15.5,
                color: RashkarColors.ink,
              ),
            ),
            subtitle: subtitle != null
                ? Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: RashkarColors.mutedInk),
                  )
                : null,
            trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: RashkarColors.mutedInk),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              onTap();
            },
          );
        }

        final idx = widget.navigationShell.currentIndex;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'All Farm Services',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: RashkarColors.ink,
                    ),
                  ),
                ),
                const Divider(),
                item(
                  icon: Icons.add_location_alt_outlined,
                  title: 'Setup New Farm (Wizard)',
                  subtitle: 'Step-by-step onboarding for a new plot or crop',
                  selected: false,
                  onTap: () => context.push(RoutePaths.onboarding),
                ),
                item(
                  icon: Icons.landscape_outlined,
                  title: 'My Farm & Boundaries',
                  subtitle: 'View saved plots, map & edit farm details',
                  selected: false,
                  onTap: () => _openSelectedFarmDetail(context),
                ),
                item(
                  icon: Icons.favorite_border_rounded,
                  title: 'Farm Health',
                  subtitle: 'Overall soil, water & plant check',
                  selected: false,
                  onTap: () => _openSelectedFarmHealth(context),
                ),
                item(
                  icon: Icons.medical_services_outlined,
                  title: 'Crop Doctor',
                  subtitle: 'Check leaf spots or crop damage with a photo',
                  selected: idx == 7,
                  onTap: () => _selectBranch(7),
                ),
                item(
                  icon: Icons.account_balance_outlined,
                  title: 'Government Help',
                  subtitle: 'Benefits, subsidies & crop insurance schemes',
                  selected: idx == 6,
                  onTap: () => _selectBranch(6),
                ),
                item(
                  icon: Icons.question_answer_outlined,
                  title: 'Ask Rashkar',
                  subtitle: 'Ask farming questions in simple words',
                  selected: idx == 4,
                  onTap: () => _selectBranch(4),
                ),
                const Divider(height: 16),
                item(
                  icon: Icons.terrain_outlined,
                  title: 'Soil',
                  subtitle: 'Soil testing & lab report upload',
                  selected: idx == 1,
                  onTap: () => _selectBranch(1),
                ),
                item(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Weather',
                  subtitle: 'Daily forecast & seasonal rain normals',
                  selected: idx == 3,
                  onTap: () => _selectBranch(3),
                ),
                item(
                  icon: Icons.menu_book_outlined,
                  title: 'Crop Guide',
                  subtitle: 'Suitable crops & varieties',
                  selected: idx == 2,
                  onTap: () => _selectBranch(2),
                ),
                item(
                  icon: Icons.history_outlined,
                  title: 'History',
                  subtitle: 'Past farm checks & saved plans',
                  selected: idx == 5,
                  onTap: () => _selectBranch(5),
                ),
                item(
                  icon: Icons.info_outline,
                  title: 'About Rashkar',
                  selected: false,
                  onTap: () => context.push(RoutePaths.about),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopUtilityBar(BuildContext context, {required bool compact}) {
    final pageTitle = _activePageTitle(context);

    return Container(
      height: 58,
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
      decoration: const BoxDecoration(
        color: RashkarColors.surface,
        border: Border(
          bottom: BorderSide(color: RashkarColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              pageTitle,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: RashkarColors.ink,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: FarmRepository.instance,
            builder: (context, _) {
              final farms = FarmRepository.instance.farms;
              final selectedId = FarmRepository.instance.selectedFarmId;
              if (farms.isEmpty) return const SizedBox.shrink();
              return RashkarFarmPickerButton(
                farms: farms,
                selectedFarmId: selectedId,
                onSelected: (f) => FarmRepository.instance.selectFarm(f.id),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context) {
    final branch = widget.navigationShell.currentIndex;
    final path = _currentUriPath(context);
    final isCropHeat = branch == 8 && path.contains('crop-heat');
    final isWorkerHeat = branch == 8 && !isCropHeat;

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: RashkarColors.surface,
        border: Border(
          right: BorderSide(color: RashkarColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _selectBranch(0),
              child: const RashkarLogoBadge(
                size: 32,
                showWordmark: true,
                darkBackground: false,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _SidebarTaskLink(
                  label: 'Home',
                  icon: branch == 0 ? Icons.home_rounded : Icons.home_outlined,
                  selected: branch == 0,
                  onTap: () => _selectBranch(0),
                ),
                _SidebarTaskLink(
                  label: 'Worker Heat Risk',
                  icon: isWorkerHeat ? Icons.wb_sunny_rounded : Icons.wb_sunny_outlined,
                  selected: isWorkerHeat,
                  onTap: () => context.go(RoutePaths.riskWorkerHeat),
                ),
                _SidebarTaskLink(
                  label: 'Crop Heat Risk',
                  icon: isCropHeat ? Icons.grass_rounded : Icons.grass_outlined,
                  selected: isCropHeat,
                  onTap: () => context.go(RoutePaths.riskCropHeat),
                ),
                _SidebarTaskLink(
                  label: 'Earn More',
                  icon: branch == 9 ? Icons.savings_rounded : Icons.savings_outlined,
                  selected: branch == 9,
                  onTap: () => _selectBranch(9),
                ),
                _SidebarTaskLink(
                  label: 'My Farm',
                  icon: Icons.landscape_outlined,
                  selected: false,
                  onTap: () => _openSelectedFarmDetail(context),
                ),
                _SidebarTaskLink(
                  label: 'Farm Health',
                  icon: Icons.favorite_border_rounded,
                  selected: false,
                  onTap: () => _openSelectedFarmHealth(context),
                ),
                _SidebarTaskLink(
                  label: 'Crop Doctor',
                  icon: branch == 7 ? Icons.medical_services_rounded : Icons.medical_services_outlined,
                  selected: branch == 7,
                  onTap: () => _selectBranch(7),
                ),
                _SidebarTaskLink(
                  label: 'Government Help',
                  icon: branch == 6 ? Icons.account_balance_rounded : Icons.account_balance_outlined,
                  selected: branch == 6,
                  onTap: () => _selectBranch(6),
                ),
                _SidebarTaskLink(
                  label: 'Setup New Farm',
                  icon: Icons.add_location_alt_outlined,
                  selected: false,
                  onTap: () => context.push(RoutePaths.onboarding),
                ),
                _SidebarTaskLink(
                  label: 'Ask Rashkar',
                  icon: branch == 4 ? Icons.question_answer_rounded : Icons.question_answer_outlined,
                  selected: branch == 4,
                  onTap: () => _selectBranch(4),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Divider(height: 1),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 2, 16, 4),
                  child: Text(
                    'More Tools',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: RashkarColors.mutedInk,
                    ),
                  ),
                ),
                _SidebarTaskLink(
                  label: 'Soil',
                  icon: branch == 1 ? Icons.terrain_rounded : Icons.terrain_outlined,
                  selected: branch == 1,
                  onTap: () => _selectBranch(1),
                ),
                _SidebarTaskLink(
                  label: 'Weather',
                  icon: branch == 3 ? Icons.cloud_rounded : Icons.cloud_outlined,
                  selected: branch == 3,
                  onTap: () => _selectBranch(3),
                ),
                _SidebarTaskLink(
                  label: 'Crops',
                  icon: branch == 2 ? Icons.menu_book_rounded : Icons.menu_book_outlined,
                  selected: branch == 2,
                  onTap: () => _selectBranch(2),
                ),
                _SidebarTaskLink(
                  label: 'History',
                  icon: branch == 5 ? Icons.history_rounded : Icons.history_outlined,
                  selected: branch == 5,
                  onTap: () => _selectBranch(5),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _SidebarTaskLink(
              label: 'About Rashkar',
              icon: Icons.info_outline_rounded,
              selected: false,
              onTap: () => context.push(RoutePaths.about),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletRail(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: RashkarColors.surface,
        border: Border(right: BorderSide(color: RashkarColors.border, width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: NavigationRail(
                  backgroundColor: RashkarColors.surface,
                  selectedIndex: widget.navigationShell.currentIndex,
                  onDestinationSelected: _selectBranch,
                  labelType: NavigationRailLabelType.all,
                  indicatorColor: RashkarColors.mintBg,
                  selectedIconTheme: const IconThemeData(color: RashkarColors.forest, size: 22),
                  unselectedIconTheme: const IconThemeData(color: RashkarColors.mutedInk, size: 21),
                  selectedLabelTextStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: RashkarColors.forest,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: RashkarColors.mutedInk,
                  ),
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.0),
                    child: RashkarLogoBadge(size: 34, darkBackground: false),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.terrain_outlined),
                      selectedIcon: Icon(Icons.terrain),
                      label: Text('Soil'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.menu_book_outlined),
                      selectedIcon: Icon(Icons.menu_book),
                      label: Text('Crops'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.cloud_outlined),
                      selectedIcon: Icon(Icons.cloud),
                      label: Text('Weather'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.question_answer_outlined),
                      selectedIcon: Icon(Icons.question_answer),
                      label: Text('Ask'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history),
                      label: Text('History'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.account_balance_outlined),
                      selectedIcon: Icon(Icons.account_balance),
                      label: Text('Help'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.medical_services_outlined),
                      selectedIcon: Icon(Icons.medical_services),
                      label: Text('Doctor'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.wb_sunny_outlined),
                      selectedIcon: Icon(Icons.wb_sunny),
                      label: Text('Heat Risk'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.savings_outlined),
                      selectedIcon: Icon(Icons.savings),
                      label: Text('Earn More'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWideDesktop = width >= 980;
    final isTablet = width >= 780 && width < 980;

    if (isWideDesktop || isTablet) {
      return Scaffold(
        backgroundColor: RashkarColors.canvas,
        body: Row(
          children: [
            if (isWideDesktop) _buildDesktopSidebar(context) else _buildTabletRail(context),
            Expanded(
              child: Column(
                children: [
                  _buildTopUtilityBar(context, compact: isTablet),
                  Expanded(child: widget.navigationShell),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final idx = widget.navigationShell.currentIndex;
    final path = _currentUriPath(context);
    final isCropHeat = idx == 8 && path.contains('crop-heat');
    final isWorkerHeat = idx == 8 && !isCropHeat;

    final mobileIndex = switch (idx) {
      0 => 0,
      8 => isCropHeat ? 2 : 1,
      9 => 3,
      _ => 4,
    };

    return Scaffold(
      backgroundColor: RashkarColors.canvas,
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: RashkarColors.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: mobileIndex,
          onDestinationSelected: (barIdx) {
            switch (barIdx) {
              case 0:
                _selectBranch(0);
              case 1:
                if (isWorkerHeat) {
                  _selectBranch(8);
                } else {
                  context.go(RoutePaths.riskWorkerHeat);
                }
              case 2:
                context.go(RoutePaths.riskCropHeat);
              case 3:
                _selectBranch(9);
              case 4:
                _openMoreSheet(context);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.wb_sunny_outlined),
              selectedIcon: Icon(Icons.wb_sunny_rounded),
              label: 'Heat Risk',
            ),
            NavigationDestination(
              icon: Icon(Icons.grass_outlined),
              selectedIcon: Icon(Icons.grass_rounded),
              label: 'My Crop',
            ),
            NavigationDestination(
              icon: Icon(Icons.savings_outlined),
              selectedIcon: Icon(Icons.savings_rounded),
              label: 'Earn More',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_rounded),
              selectedIcon: Icon(Icons.menu_open_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTaskLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTaskLink({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: selected ? RashkarColors.softMint : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? RashkarColors.forest : RashkarColors.mutedInk,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? RashkarColors.forestDark : RashkarColors.ink,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: RashkarColors.forest,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
