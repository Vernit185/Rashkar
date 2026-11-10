import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cropnet_mobile/core/router/route_paths.dart';

/// Persistent shell layout supporting both web desktop and mobile form factors.
/// Wraps StatefulNavigationShell to preserve branch state across tab switches and back/forward navigation.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _openMoreSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
            leading: Icon(icon, color: selected ? const Color(0xFF1B5E20) : Colors.black87),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? const Color(0xFF1B5E20) : Colors.black87,
              ),
            ),
            subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
            selected: selected,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              onTap();
            },
          );
        }

        final idx = navigationShell.currentIndex;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                item(
                  icon: Icons.terrain_outlined,
                  title: 'Soil',
                  selected: idx == 1,
                  onTap: () => _onDestinationSelected(1),
                ),
                item(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Weather',
                  selected: idx == 3,
                  onTap: () => _onDestinationSelected(3),
                ),
                item(
                  icon: Icons.psychology_outlined,
                  title: 'Advisory',
                  selected: idx == 4,
                  onTap: () => _onDestinationSelected(4),
                ),
                item(
                  icon: Icons.history_outlined,
                  title: 'History',
                  selected: idx == 5,
                  onTap: () => _onDestinationSelected(5),
                ),
                item(
                  icon: Icons.account_balance_outlined,
                  title: 'Schemes',
                  selected: idx == 6,
                  onTap: () => _onDestinationSelected(6),
                ),
                item(
                  icon: Icons.medical_services_outlined,
                  title: 'Crop Doctor',
                  selected: idx == 7,
                  onTap: () => _onDestinationSelected(7),
                ),
                const Divider(),
                item(
                  icon: Icons.engineering_outlined,
                  title: 'Risk · Worker Heat Risk',
                  subtitle: 'WBGT outdoor heat safety for workers',
                  selected: false,
                  onTap: () => context.go(RoutePaths.riskWorkerHeat),
                ),
                item(
                  icon: Icons.eco_outlined,
                  title: 'Risk · Crop Heat Risk',
                  subtitle: 'Growth stage thermal tolerance & irrigation actions',
                  selected: false,
                  onTap: () => context.go(RoutePaths.riskCropHeat),
                ),
                item(
                  icon: Icons.info_outline,
                  title: 'About CropNet AI',
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: navigationShell.currentIndex,
                        onDestinationSelected: _onDestinationSelected,
                        labelType: NavigationRailLabelType.all,
                        leading: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Column(
                            children: [
                              CircleAvatar(
                                backgroundColor: Color(0xFF1B5E20),
                                foregroundColor: Colors.white,
                                radius: 20,
                                child: Icon(Icons.eco, size: 22),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'CropNet AI',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B5E20),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: IconButton(
                                icon: const Icon(Icons.info_outline),
                                tooltip: 'About CropNet AI',
                                onPressed: () => context.push(RoutePaths.about),
                              ),
                            ),
                          ),
                        ),
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.map_outlined),
                            selectedIcon: Icon(Icons.map),
                            label: Text('Farms'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.terrain_outlined),
                            selectedIcon: Icon(Icons.terrain),
                            label: Text('Soil'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.grass_outlined),
                            selectedIcon: Icon(Icons.grass),
                            label: Text('Crops'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.wb_sunny_outlined),
                            selectedIcon: Icon(Icons.wb_sunny),
                            label: Text('Weather'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.psychology_outlined),
                            selectedIcon: Icon(Icons.psychology),
                            label: Text('Advisory'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.history_outlined),
                            selectedIcon: Icon(Icons.history),
                            label: Text('History'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.account_balance_outlined),
                            selectedIcon: Icon(Icons.account_balance),
                            label: Text('Schemes'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.medical_services_outlined),
                            selectedIcon: Icon(Icons.medical_services),
                            label: Text('Crop Doctor'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.health_and_safety_outlined),
                            selectedIcon: Icon(Icons.health_and_safety),
                            label: Text('Risk'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.savings_outlined),
                            selectedIcon: Icon(Icons.savings),
                            label: Text('Extra Income'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    final idx = navigationShell.currentIndex;
    final mobileIndex = switch (idx) {
      0 => 0,
      2 => 1,
      8 => 2,
      9 => 3,
      _ => 4,
    };

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: mobileIndex,
        onDestinationSelected: (barIdx) {
          switch (barIdx) {
            case 0:
              _onDestinationSelected(0);
            case 1:
              _onDestinationSelected(2);
            case 2:
              _onDestinationSelected(8);
            case 3:
              _onDestinationSelected(9);
            case 4:
              _openMoreSheet(context);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Farms',
          ),
          NavigationDestination(
            icon: Icon(Icons.grass_outlined),
            selectedIcon: Icon(Icons.grass),
            label: 'Crops',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety),
            label: 'Risk',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Income',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu),
            selectedIcon: Icon(Icons.menu_open),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
