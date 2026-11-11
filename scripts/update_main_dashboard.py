p = r'd:\CSE AIML\Rashkar\apps\mobile\lib\main.dart'
c = open(p, 'r', encoding='utf-8').read().replace('\r\n', '\n')

start_idx = c.find('class MyFarmsDashboard extends StatelessWidget {')
end_marker = '// 2. ADD / EDIT FARM SCREEN WITH MAP DRAWING'
end_idx = c.find(end_marker)
assert start_idx != -1 and end_idx != -1, f'Indices not found: start={start_idx}, end={end_idx}'

new_dashboard = """class MyFarmsDashboard extends StatelessWidget {
  final List<FarmItem> farms;
  final Function(FarmItem) onAddFarm;
  final Function(FarmItem) onUpdateFarm;
  final Function(String) onDeleteFarm;

  const MyFarmsDashboard({
    super.key,
    required this.farms,
    required this.onAddFarm,
    required this.onUpdateFarm,
    required this.onDeleteFarm,
  });

  @override
  Widget build(BuildContext context) {
    final repo = FarmRepository.instance;

    return Scaffold(
      backgroundColor: RashkarColors.cream,
      floatingActionButton: RashkarFab(
        tooltip: 'Register New Farm',
        icon: Icons.add_location_alt_rounded,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => AddEditFarmScreen(onSave: onAddFarm),
            ),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: () => repo.loadFarms(),
        color: RashkarColors.forest,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // RASHKAR Branded Hero
              RashkarBrandedHero(
                farmName: farms.isNotEmpty ? farms.first.name : 'Pune Pilot Zone',
                greeting: 'Operations & Field Telemetry',
                onNotificationsTap: () {},
                onSwitchFarm: () {},
              ),

              // Overlapping Status Hero Card
              Transform.translate(
                offset: const Offset(0, -60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      RashkarStatusHeroCard(
                        status: RashkarStatusLevel.low,
                        heroNumber: '${farms.length}',
                        heroUnit: 'Active Parcels',
                        explanation: 'Remote satellite telemetry, soil composition, and weather forecasting synchronized.',
                        updatedTime: 'Live Synced',
                      ),
                      const SizedBox(height: 16),
                      const RashkarNotice(
                        title: 'Field Season Synchronization',
                        message: 'Kharif crop cycle models active across Maval, Mulshi, Baramati and Indapur blocks.',
                        type: RashkarNoticeType.info,
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 96.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'My Registered Farms',
                          style: TextStyle(
                            fontFamily: RashkarTypography.primaryFont,
                            fontSize: 19.0,
                            fontWeight: FontWeight.w700,
                            color: RashkarColors.ink,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: RashkarColors.forest),
                          tooltip: 'Refresh Farms',
                          onPressed: () => repo.loadFarms(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (repo.isLoading && farms.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(
                          child: CircularProgressIndicator(color: RashkarColors.forest),
                        ),
                      )
                    else if (repo.error != null && farms.isEmpty)
                      RashkarEmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Unable to connect to CropNet server',
                        subtitle: repo.error!,
                        actionLabel: 'Retry Connection',
                        onAction: () => repo.loadFarms(),
                      )
                    else if (farms.isEmpty)
                      RashkarEmptyState(
                        icon: Icons.agriculture_rounded,
                        title: 'No farms registered yet',
                        subtitle: 'Tap "Register New Farm" to draw your plot on the map and begin agronomic analysis.',
                        actionLabel: 'Register New Farm',
                        onAction: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => AddEditFarmScreen(onSave: onAddFarm),
                            ),
                          );
                        },
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: farms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, idx) {
                          final farm = farms[idx];
                          return RashkarCard(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => FarmDetailScreen(
                                    farm: farm,
                                    onUpdate: onUpdateFarm,
                                    onDelete: onDeleteFarm,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: RashkarColors.leafSoft,
                                    borderRadius: RashkarRadii.iconTileBorderRadius,
                                  ),
                                  child: const Icon(
                                    Icons.agriculture_rounded,
                                    color: RashkarColors.forest,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(farm.name, style: RashkarTypography.cardTitle),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${farm.village != null ? "${farm.village}, " : ""}${farm.taluka}, ${farm.district}',
                                        style: RashkarTypography.meta,
                                      ),
                                    ],
                                  ),
                                ),
                                const RashkarStatusPill(
                                  status: RashkarStatusLevel.low,
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: RashkarColors.muted,
                                  size: 22,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
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
"""

c = c[:start_idx] + new_dashboard + c[end_idx:]
open(p, 'w', encoding='utf-8', newline='\n').write(c)
print('Successfully restyled MyFarmsDashboard')
