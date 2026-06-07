import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../data/subscription_service_presets.dart';
import '../../domain/entities/subscription_service_preset.dart';

Future<SubscriptionServicePreset?> showSubscriptionServicePickerSheet(
  BuildContext context, {
  String? selectedPresetId,
}) {
  return showModalBottomSheet<SubscriptionServicePreset>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SubscriptionServicePickerSheet(
      selectedPresetId: selectedPresetId,
    ),
  );
}

class _SubscriptionServicePickerSheet extends StatefulWidget {
  const _SubscriptionServicePickerSheet({
    required this.selectedPresetId,
  });

  final String? selectedPresetId;

  @override
  State<_SubscriptionServicePickerSheet> createState() =>
      _SubscriptionServicePickerSheetState();
}

class _SubscriptionServicePickerSheetState
    extends State<_SubscriptionServicePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategoryId = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SubscriptionServicePreset> get _filteredPresets {
    final query = _searchController.text.trim().toLowerCase();
    return subscriptionServicePresets.where((preset) {
      final matchesCategory = _selectedCategoryId == 'all' ||
          preset.categoryId == _selectedCategoryId;
      final matchesQuery = query.isEmpty ||
          preset.name.toLowerCase().contains(query) ||
          (subscriptionServiceCategoryLabels[preset.categoryId] ?? '')
              .toLowerCase()
              .contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredPresets = _filteredPresets;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 54,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختيار خدمة جاهزة',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'اختر من 100 خدمة جاهزة، ثم عدّل المبلغ والتكرار والوقت بالطريقة التي تناسبك.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'ابحث عن الخدمة',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: subscriptionServiceCategoryOrder.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final categoryId =
                          subscriptionServiceCategoryOrder[index];
                      return ChoiceChip(
                        selected: _selectedCategoryId == categoryId,
                        label: Text(
                          subscriptionServiceCategoryLabels[categoryId] ??
                              categoryId,
                        ),
                        onSelected: (_) {
                          setState(() => _selectedCategoryId = categoryId);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredPresets.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد خدمات مطابقة للبحث أو الفلتر الحالي.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filteredPresets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final preset = filteredPresets[index];
                      final selected = preset.id == widget.selectedPresetId;
                      final color = _parseColor(preset.colorHex);
                      return Material(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.of(context).pop(preset),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? color
                                    : theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.45),
                                width: selected ? 1.6 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child:
                                        AppIconPickerDialog.iconWidgetForName(
                                      preset.iconName,
                                      color: color,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        preset.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        subscriptionServiceCategoryLabels[
                                                preset.categoryId] ??
                                            preset.categoryId,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: color,
                                  )
                                else
                                  const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final value = hex.replaceAll('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }
}
