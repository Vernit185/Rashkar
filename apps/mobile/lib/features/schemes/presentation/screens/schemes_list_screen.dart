import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../shared/responsive/breakpoints.dart';
import '../../../../shared/theme/rashkar_tokens.dart';
import '../../../../shared/theme/rashkar_components.dart';
import '../../../../shared/widgets/centered_page_container.dart';
import '../../../../shared/widgets/responsive_scaffold.dart';
import '../../data/scheme_repository.dart';
import '../../models/scheme_models.dart';
import '../widgets/scheme_card.dart';

/// RASHKAR Design Language - Government Schemes Screen (Section 4 List Pattern)
/// Filter chips (selected = ink with white text), search input, cards with 1px line border,
/// 18px radius, no shadow, and centered empty state.
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
    } catch (_) {}
  }

  Future<void> _loadFilterOptions() async {
    try {
      final options = await _repository.getFilterOptions();
      if (mounted) setState(() => _filterOptions = options);
    } catch (_) {}
  }

  Future<void> _fetchSchemes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _repository.listSchemes(
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        category: _selectedCategory,
        governmentLevel: _selectedLevel,
        state: _selectedState,
      );
      if (mounted) {
        setState(() {
          _schemes = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      currentIndex: 6,
      destinations: const [],
      body: CenteredPageContainer(
        maxWidth: AppBreakpoints.maxContentWidthReadable,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RashkarPageHeader(
              title: 'Government Schemes',
              subtitle: 'Subsidies, credit facilities and state-sponsored agricultural support',
              rightIcon: _isAdmin ? Icons.admin_panel_settings_outlined : null,
              onRightIconTap: _isAdmin ? () => context.push(RoutePaths.schemesAdmin) : null,
            ),
            const SizedBox(height: 12),
            _buildSearchBar(),
            const SizedBox(height: 14),
            _buildFilterSection(),
            const SizedBox(height: 16),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search schemes by title, keyword, or subsidy...',
        prefixIcon: const Icon(Icons.search_rounded, color: RashkarColors.muted),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 20, color: RashkarColors.muted),
                onPressed: () {
                  _searchController.clear();
                  _fetchSchemes();
                },
              )
            : null,
      ),
      onSubmitted: (_) => _fetchSchemes(),
    );
  }

  Widget _buildFilterSection() {
    final categories = _filterOptions.categories;
    final states = _filterOptions.states;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Chips (selected = ink with white text)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('All Categories', null, _selectedCategory == null),
              for (final cat in categories)
                _filterChip(cat, cat, _selectedCategory == cat),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Level Chips & State Selector
        Row(
          children: [
            _filterChip('All Levels', null, _selectedLevel == null),
            _filterChip('Central', 'Central', _selectedLevel == 'Central'),
            _filterChip('State', 'State', _selectedLevel == 'State'),
            if (states.isNotEmpty) ...[
              const SizedBox(width: 8),
              _buildStateDropdown(states),
            ],
          ],
        ),
      ],
    );
  }

  // Spec 4 List Screen: selected = ink with white text
  Widget _filterChip(String label, String? value, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
          decoration: BoxDecoration(
            color: selected ? RashkarColors.ink : RashkarColors.sand,
            borderRadius: RashkarRadii.pillBorderRadius,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: RashkarTypography.primaryFont,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : RashkarColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateDropdown(List<String> states) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: const BoxDecoration(
        color: RashkarColors.sand,
        borderRadius: RashkarRadii.pillBorderRadius,
      ),
      child: DropdownButton<String>(
        value: _selectedState,
        hint: const Text('All States', style: TextStyle(fontSize: 12.5, color: RashkarColors.ink)),
        isDense: true,
        underline: const SizedBox.shrink(),
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('All States')),
          for (final state in states) DropdownMenuItem<String>(value: state, child: Text(state)),
        ],
        onChanged: (val) {
          setState(() => _selectedState = val);
          _fetchSchemes();
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3, color: RashkarColors.forest),
            ),
            SizedBox(height: 12),
            Text('Loading government schemes...', style: RashkarTypography.meta),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: RashkarNotice(
          title: 'Unable to Load Schemes',
          message: _errorMessage!,
          type: RashkarNoticeType.error,
        ),
      );
    }

    if (_schemes.isEmpty) {
      return const RashkarEmptyState(
        icon: Icons.account_balance_outlined,
        title: 'No Schemes Found',
        subtitle: 'No government schemes match the selected category and level filters.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24.0),
      itemCount: _schemes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12.0),
      itemBuilder: (context, index) {
        final scheme = _schemes[index];
        return SchemeCard(
          scheme: scheme,
          onTap: () => context.push(RoutePaths.schemeDetailPath(scheme.id)),
        );
      },
    );
  }
}
