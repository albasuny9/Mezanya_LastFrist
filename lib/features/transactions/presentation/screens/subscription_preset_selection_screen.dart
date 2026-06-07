import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:flutter/material.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../data/subscription_service_presets.dart';
import '../../domain/entities/subscription_service_preset.dart';
import 'recurring_transaction_composer_screen.dart';

class SubscriptionPresetSelectionScreen extends StatefulWidget {
  const SubscriptionPresetSelectionScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<SubscriptionPresetSelectionScreen> createState() =>
      _SubscriptionPresetSelectionScreenState();
}

class _SubscriptionPresetSelectionScreenState
    extends State<SubscriptionPresetSelectionScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSearching = _searchQuery.trim().isNotEmpty;
    final filteredPresets = isSearching
        ? subscriptionServicePresets
            .where((p) =>
                p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList()
        : subscriptionServicePresets;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('اختيار الاشتراك'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'ابحث عن خدمة (مثل: Netflix, Spotify)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: isSearching
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (!isSearching) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _customSubscriptionCard(theme),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: isSearching
                  ? _buildSearchResults(theme, filteredPresets)
                  : _buildCategorizedList(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customSubscriptionCard(ThemeData theme) {
    return InkWell(
      onTap: () => _navigateToComposer(null),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2E5CC6).withValues(alpha: 0.9),
              const Color(0xFF2E5CC6).withValues(alpha: 0.7),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E5CC6).withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.add_circle_outline_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اشتراك مخصص',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'أضف أي خدمة يدوياً وحدد تفاصيلها',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_left_rounded,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(
      ThemeData theme, List<SubscriptionServicePreset> presets) {
    if (presets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'لم نجد الخدمة التي تبحث عنها',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _navigateToComposer(null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة كاشتراك مخصص'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Text(
          'نتائج البحث (${presets.length})',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _buildGrid(presets),
      ],
    );
  }

  Widget _buildCategorizedList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: subscriptionServiceCategoryOrder.length,
      itemBuilder: (context, index) {
        final categoryId = subscriptionServiceCategoryOrder[index];
        if (categoryId == 'all') return const SizedBox.shrink();

        final presetsInCategory = subscriptionServicePresets
            .where((p) => p.categoryId == categoryId)
            .toList();

        if (presetsInCategory.isEmpty) return const SizedBox.shrink();

        final categoryLabel =
            subscriptionServiceCategoryLabels[categoryId] ?? 'خدمات أخرى';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: Text(
                categoryLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            _buildGrid(presetsInCategory),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildGrid(List<SubscriptionServicePreset> presets) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];
        return _presetTile(preset);
      },
    );
  }

  Widget _presetTile(SubscriptionServicePreset preset) {
    final color = _parseColor(preset.colorHex);
    return InkWell(
      onTap: () => _navigateToComposer(preset.id),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconData(preset.iconName),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                preset.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToComposer(String? presetId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecurringTransactionComposerScreen(
          cubit: widget.cubit,
          initialType: TransactionType.expense.value,
          initialWithinBudget: true,
          initialExpensePlanKind: ExpensePlanKind.subscription.value,
          subscriptionOnlyMode: true,
          initialSubscriptionPresetId: presetId,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'movie':
        return Icons.movie_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'auto_awesome':
        return Icons.auto_awesome_rounded;
      case 'cloud':
        return Icons.cloud_rounded;
      case 'storage':
        return Icons.storage_rounded;
      case 'security':
        return Icons.security_rounded;
      case 'laptop':
        return Icons.laptop_mac_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'bookmark':
        return Icons.bookmark_rounded;
      case 'computer':
        return Icons.computer_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'rocket_launch':
        return Icons.rocket_launch_rounded;
      case 'sports_esports':
        return Icons.sports_esports_rounded;
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'local_shipping':
        return Icons.local_shipping_rounded;
      default:
        return Icons.subscriptions_rounded;
    }
  }

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.grey;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
