import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../shared/responsive/breakpoints.dart';
import '../../../../shared/theme/rashkar_colors.dart';
import '../../../../shared/widgets/app_spacing.dart';
import '../../../../shared/widgets/centered_page_container.dart';
import '../../../../shared/widgets/rashkar_ui.dart';
import '../../../../shared/widgets/responsive_scaffold.dart';
import '../../data/scheme_repository.dart';
import '../../models/scheme_models.dart';
import '../widgets/scheme_card.dart';

/// Government Schemes dashboard with search, filters and a responsive card grid.
class SchemesListScreen extends StatefulWidget {
  final SchemeRepository? repository;

  const SchemesListScreen({super.key, this.repository});

  @override
  State<SchemesListScreen> createState() => _SchemesListScreenState();
}

class _SchemesListScreenState extends State<SchemesListScreen> {
  late final SchemeRepository _repository;

  final TextEditingController _searchController = TextEditingController();

  List<GovernmentScheme> _schemes = const [];
  SchemeFilterOptions _filterOptions = const SchemeFilterOptions();
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _showAllSchemes = false;
  String? _errorMessage;

  String? _selectedCategory;
  String? _selectedLevel;
  String? _selectedState;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SchemeRepository.instance;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadAdminStatus(), _loadFilterOptions()]);
    await _fetchSchemes();
  }

  Future<void> _loadAdminStatus() async {
    try {
      final isAdmin = await _repository.isAdmin();
      if (mounted) setState(() => _isAdmin = isAdmin);
    } catch (_) {
      // Admin status is optional; keep false on failure.
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      final options = await _repository.getFilterOptions();
      if (mounted) setState(() => _filterOptions = options);
    } catch (_) {
      // Fall back to the canonical category list.
    }
  }

  Future<void> _fetchSchemes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final schemes = await _repository.listSchemes(
        search: _searchController.text,
        category: _selectedCategory,
        governmentLevel: _selectedLevel,
        state: _selectedState,
        status: 'ACTIVE',
      );
      if (!mounted) return;
      setState(() {
        _schemes = schemes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _onSearchSubmitted(String value) => _fetchSchemes();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      backgroundColor: RashkarColors.canvas,
      currentIndex: 0,
      destinations: const [],
      appBar: AppBar(
        title: const Text('Government Help', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchSchemes,
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Manage Schemes',
              onPressed: () => context.push(RoutePaths.schemesAdmin),
            ),
        ],
      ),
      body: CenteredPageContainer(
        maxWidth: AppBreakpoints.maxContentWidthWide,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RashkarHeroBanner(
              eyebrow: 'FINANCIAL ASSISTANCE & SUBSIDIES',
              title: 'Government Help',
              subtitle: 'Find government schemes that may help your farm.',
            ),
            const SizedBox(height: 14),
            RashkarCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchBar(),
                  AppSpacing.verticalSpaceMD,
                  _buildFilters(),
                ],
              ),
            ),
            AppSpacing.verticalSpaceMD,
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onSubmitted: _onSearchSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search schemes by name, description or department…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            _searchController.clear();
            _fetchSchemes();
          },
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final categories = _filterOptions.categories.isNotEmpty
        ? _filterOptions.categories
        : kSchemeCategories;
    final states = _filterOptions.states;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('All Categories', null, _selectedCategory == null),
              for (final category in categories)
                _filterChip(category, category, _selectedCategory == category),
            ],
          ),
        ),
        AppSpacing.verticalSpaceSM,
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _filterChip('All Levels', null, _selectedLevel == null),
            _filterChip('Central', 'Central', _selectedLevel == 'Central'),
            _filterChip('State', 'State', _selectedLevel == 'State'),
            if (states.isNotEmpty) _buildStateDropdown(states),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, String? value, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            if (value == null && label.startsWith('All Categories')) {
              _selectedCategory = null;
            } else if (value == null && label.startsWith('All Levels')) {
              _selectedLevel = null;
            } else if (value == 'Central' || value == 'State') {
              _selectedLevel = value;
            } else {
              _selectedCategory = value;
            }
          });
          _fetchSchemes();
        },
      ),
    );
  }

  Widget _buildStateDropdown(List<String> states) {
    return DropdownButton<String>(
      value: _selectedState,
      hint: const Text('All States', style: TextStyle(fontSize: 13)),
      isDense: true,
      underline: const SizedBox.shrink(),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All States')),
        for (final state in states) DropdownMenuItem<String>(value: state, child: Text(state)),
      ],
      onChanged: (value) {
        setState(() => _selectedState = value);
        _fetchSchemes();
      },
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_schemes.isEmpty) {
      return _buildEmptyState();
    }

    final displayList = _showAllSchemes ? _schemes : _schemes.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_showAllSchemes && _schemes.length > 3) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RECOMMENDED SCHEMES FOR YOUR FARM',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: RashkarColors.forest,
                    letterSpacing: 0.8,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text('View all (${_schemes.length})'),
                  onPressed: () => setState(() => _showAllSchemes = true),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 220,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              final scheme = displayList[index];
              return SchemeCard(
                scheme: scheme,
                onTap: () => context.push(RoutePaths.schemeDetailPath(scheme.id)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          AppSpacing.verticalSpaceMD,
          const Text('Could not load Government Schemes.',
              style: TextStyle(fontWeight: FontWeight.w600)),
          AppSpacing.verticalSpaceXS,
          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey)),
          AppSpacing.verticalSpaceMD,
          FilledButton.icon(
            onPressed: _fetchSchemes,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_outlined, size: 48, color: Colors.blueGrey),
          SizedBox(height: 12),
          Text('No schemes match your filters.',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
        ],
      ),
    );
  }
}
