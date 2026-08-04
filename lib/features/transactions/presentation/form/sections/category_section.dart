import 'package:flutter/material.dart';

import '../../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../../categories/domain/entities/category_entity.dart';

/// Category chip grid — used for both expense and income.
/// In recurring mode the form passes a single selected id derived from the
/// multi-select Set; the form handles Set management in its setState callback.
class CategorySection extends StatelessWidget {
  const CategorySection({
    super.key,
    required this.recurringMode,
    required this.categories,
    required this.selectedId,
    required this.onSelectChange,
    required this.onAdd,
  });

  final bool recurringMode;
  final List<CategoryEntity> categories;
  final String? selectedId;
  final void Function(String? id) onSelectChange;
  final VoidCallback onAdd;

  static const _accent = Color(0xFF165b47);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: _accent.withValues(alpha: 0.35), width: 1.5),
        color: _accent.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.label_outline_rounded,
                  size: 16, color: _accent),
              const SizedBox(width: 6),
              const Text(
                'الفئة',
                style: TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 13, color: _accent),
                      SizedBox(width: 3),
                      Text(
                        'فئة جديدة',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Chips
          if (categories.isEmpty)
            Center(
              child: Text(
                'لا توجد فئات — اضغط + لإضافة فئة',
                style: TextStyle(
                  fontSize: 12,
                  color: _accent.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((c) {
                final isSelected = selectedId == c.id;
                final color = _parseHex(c.color);
                return GestureDetector(
                  onTap: () =>
                      onSelectChange(isSelected ? null : c.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color
                          : color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : color.withValues(alpha: 0.25),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIconPickerDialog.iconWidgetForName(
                          c.icon,
                          color: isSelected ? Colors.white : color,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          c.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  static Color _parseHex(String hex) {
    final v =
        int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x165b47;
    return Color(0xFF000000 | v);
  }
}
